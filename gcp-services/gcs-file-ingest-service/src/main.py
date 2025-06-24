import logging
import json
import os
import pandas as pd
from flask import Flask, request, jsonify
from google.cloud import storage, bigquery
from utils import process_tsv_data

app = Flask(__name__)

# ENV vars
BQ_PROJECT = os.getenv("BQ_PROJECT")
BQ_DATASET = os.getenv("BQ_DATASET")
GCS_BUCKET = os.getenv("GCS_BUCKET")

# Mapping JSON file names to BQ table names
JSON_TABLES = {"hp.json": "hpo_terms", "mondo.json": "mondo_terms"}

ncbi_gene_schema = [
    bigquery.SchemaField("id", "STRING"),
    bigquery.SchemaField("symbol", "STRING"),
    bigquery.SchemaField("description", "STRING"),
    bigquery.SchemaField("gene_type", "STRING"),
    bigquery.SchemaField("nomenclature_id", "STRING"),
    bigquery.SchemaField("synonyms", "STRING", mode="REPEATED"),
    bigquery.SchemaField("omim_id", "STRING"),
]

submitter_organization_schema = [
    bigquery.SchemaField("organization", "STRING"),
    bigquery.SchemaField("id", "STRING"),
    bigquery.SchemaField("institution_type", "STRING"),
    bigquery.SchemaField("street_address", "STRING"),
    bigquery.SchemaField("city", "STRING"),
    bigquery.SchemaField("country", "STRING"),
    bigquery.SchemaField("number_of_clinvar_submissions", "INTEGER"),
    bigquery.SchemaField("date_last_submitted", "DATE"),
    bigquery.SchemaField("maximum_review_status", "STRING"),
    bigquery.SchemaField("collection_methods", "STRING", mode="REPEATED"),
    bigquery.SchemaField("novel_and_updates", "STRING"),
    bigquery.SchemaField(
        "clinical_significance_categories_submitted", "STRING", mode="REPEATED"
    ),
    bigquery.SchemaField("number_of_submissions_from_clinical_testing", "INTEGER"),
    bigquery.SchemaField("number_of_submissions_from_research", "INTEGER"),
    bigquery.SchemaField("number_of_submissions_from_literature_only", "INTEGER"),
    bigquery.SchemaField("number_of_submissions_from_curation", "INTEGER"),
    bigquery.SchemaField("number_of_submissions_from_phenotyping", "INTEGER"),
    bigquery.SchemaField(
        "somatic_clinical_impact_values_submitted", "STRING", mode="REPEATED"
    ),
    bigquery.SchemaField(
        "somatic_oncogenicity_values_submitted", "STRING", mode="REPEATED"
    ),
]

# Table configuration map: table_name -> config dict
TABLE_CONFIGS = {
    "ncbi_gene": {
        "schema": ncbi_gene_schema,
        "id_column": "GeneID",
        "delimiter": "|",
    },
    "submitter_organization": {
        "schema": submitter_organization_schema,
        "id_column": "organization ID",
        "delimiter": ",",
    },
    # Add more table configs as needed
}


def extract_json_nodes(content, file_name):
    """Extract fields from hp.json, mondo.json based on structure."""
    data = json.loads(content)
    nodes = data["graphs"][0]["nodes"]
    results = []

    for node in nodes:
        if "id" not in node or "lbl" not in node:
            continue

        id_compact = node["id"].rsplit("/", 1)[-1].replace("_", ":")
        lbl = node["lbl"]

        if "hp" in node["id"].lower() and file_name == "hp.json":
            results.append({"id": id_compact, "lbl": lbl})

        elif "mondo" in node["id"].lower() and file_name == "mondo.json":
            skos_matches = []

            for prop in node.get("meta", {}).get("basicPropertyValues", []):
                pred = prop.get("pred", "")
                if pred.startswith("http://www.w3.org/2004/02/skos/core#"):
                    match_type = pred.split("#")[-1]  # e.g., exactMatch
                    skos_matches.append(
                        {"relation": match_type, "value": prop.get("val")}
                    )

            results.append({"id": id_compact, "lbl": lbl, "skos_matches": skos_matches})

    logging.info(f"Extracted {len(results)} rows from {file_name}")
    return results


def process_json_from_gcs(bucket_name, file_name, table_name):
    """Load filtered JSON node data into BigQuery."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    file_content = blob.download_as_text()

    filtered_data = extract_json_nodes(file_content, file_name)
    if not filtered_data:
        return f"No relevant data found in {file_name}"

    df = pd.DataFrame(filtered_data)
    return load_to_bigquery(df, table_name)


def process_tsv_from_gcs(bucket_name, file_name, table_name):
    """
    Load TSV file as dataframe into BigQuery using table config map.
    Args:
        bucket_name (str): GCS bucket name.
        file_name (str): File name in GCS.
        table_name (str): Destination BigQuery table.
    """
    config = TABLE_CONFIGS.get(table_name)
    if not config:
        logging.error(f"Table '{table_name}' is not configured for TSV ingest.")
        return f"Table '{table_name}' is not configured for TSV ingest."

    schema = config.get("schema")

    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(file_name)
        tsv_data = blob.download_as_text()

        df = process_tsv_data(tsv_data, config)
        return load_to_bigquery(df, table_name, schema=schema)

    except Exception as e:
        logging.exception(f"Failed to process TSV {file_name}")
        return f"Error processing {file_name}: {str(e)}"


def load_to_bigquery(df, table_name, schema=None):
    table_id = f"{BQ_PROJECT}.{BQ_DATASET}.{table_name}"
    bq_client = bigquery.Client()

    job_config = bigquery.LoadJobConfig(
        schema=schema, write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE
    )

    job = bq_client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()
    logging.info(f"Loaded {len(df)} rows into {table_id}")
    return f"Loaded {len(df)} rows into {table_id}"


@app.route("/", methods=["POST"])
def handle_gcs_event():
    try:
        request_json = request.get_json(silent=True)
        if not request_json:
            logging.warning("No JSON received")
            return jsonify({"status": "error", "message": "Missing request body"}), 400

        bucket_name = request_json.get("bucket")
        file_name = request_json.get("name")
        if not bucket_name or not file_name:
            return jsonify(
                {"status": "error", "message": "Missing bucket or name"}
            ), 400

        logging.info(f"Triggered by file: {file_name}")

        if file_name in JSON_TABLES:
            table = JSON_TABLES[file_name]
            message = process_json_from_gcs(bucket_name, file_name, table)
        elif file_name == "ncbi_gene.txt":
            message = process_tsv_from_gcs(bucket_name, file_name, "ncbi_gene")
        elif file_name == "organization_summary.txt":
            message = process_tsv_from_gcs(
                bucket_name, file_name, "submitter_organization"
            )
        else:
            logging.info(f"Ignored file: {file_name}")
            message = f"Ignored file: {file_name}"

        return jsonify({"status": "success", "message": message}), 200

    except Exception as e:
        logging.exception("Unexpected error")
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    app.run(debug=True)
