import logging
import json
import os
import urllib.request
import pandas as pd
from flask import Flask, request, jsonify
from google.cloud import storage, bigquery
from utils import process_tsv_data

# ClinVar FTP URL for organization summary
CLINVAR_ORG_SUMMARY_URL = (
    "https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/organization_summary.txt"
)

app = Flask(__name__)

# ENV vars
BQ_PROJECT = os.getenv("BQ_PROJECT")
BQ_DATASET = os.getenv("BQ_DATASET")
GCS_BUCKET = os.getenv("GCS_BUCKET")

# Mapping JSON file names to BQ table names
JSON_TABLES = {"hp.json": "hpo_terms", "mondo.json": "mondo_terms"}

hgnc_gene_schema = [
    bigquery.SchemaField("hgnc_id", "STRING"),
    bigquery.SchemaField("symbol", "STRING"),
    bigquery.SchemaField("name", "STRING"),
    bigquery.SchemaField("locus_group", "STRING"),
    bigquery.SchemaField("locus_type", "STRING"),
    bigquery.SchemaField("status", "STRING"),
    bigquery.SchemaField("location", "STRING"),
    bigquery.SchemaField("alias_symbol", "STRING", mode="REPEATED"),
    bigquery.SchemaField("alias_name", "STRING", mode="REPEATED"),
    bigquery.SchemaField("prev_symbol", "STRING", mode="REPEATED"),
    bigquery.SchemaField("prev_name", "STRING", mode="REPEATED"),
    bigquery.SchemaField("gene_group", "STRING", mode="REPEATED"),
    bigquery.SchemaField("gene_group_id", "INTEGER", mode="REPEATED"),
    bigquery.SchemaField("date_approved_reserved", "DATE"),
    bigquery.SchemaField("date_symbol_changed", "DATE"),
    bigquery.SchemaField("date_name_changed", "DATE"),
    bigquery.SchemaField("date_modified", "DATE"),
    bigquery.SchemaField("entrez_id", "STRING"),
    bigquery.SchemaField("ensembl_gene_id", "STRING"),
    bigquery.SchemaField("vega_id", "STRING"),
    bigquery.SchemaField("ucsc_id", "STRING"),
    bigquery.SchemaField("refseq_accession", "STRING", mode="REPEATED"),
    bigquery.SchemaField("ccds_id", "STRING", mode="REPEATED"),
    bigquery.SchemaField("uniprot_ids", "STRING", mode="REPEATED"),
    bigquery.SchemaField("pubmed_id", "INTEGER", mode="REPEATED"),
    bigquery.SchemaField("omim_id", "STRING", mode="REPEATED"),
    bigquery.SchemaField("orphanet", "INTEGER"),
    bigquery.SchemaField("enzyme_id", "STRING", mode="REPEATED"),
    bigquery.SchemaField("mane_select", "STRING", mode="REPEATED"),
    bigquery.SchemaField("agr", "STRING"),
]

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


def fetch_organization_summary_from_ftp():
    """Fetch the latest organization_summary.txt directly from ClinVar FTP."""
    logging.info(f"Fetching organization_summary.txt from {CLINVAR_ORG_SUMMARY_URL}")
    try:
        with urllib.request.urlopen(CLINVAR_ORG_SUMMARY_URL, timeout=60) as response:
            content = response.read().decode("utf-8")
            logging.info(f"Successfully fetched {len(content)} bytes from ClinVar FTP")
            return content
    except Exception as e:
        logging.exception(f"Failed to fetch from ClinVar FTP: {e}")
        raise


def process_organization_summary_from_ftp():
    """Fetch organization_summary from ClinVar FTP and load into BigQuery."""
    config = TABLE_CONFIGS.get("submitter_organization")
    if not config:
        logging.error("Table 'submitter_organization' is not configured.")
        return "Table 'submitter_organization' is not configured."

    schema = config.get("schema")

    try:
        # Fetch latest data directly from ClinVar FTP
        tsv_data = fetch_organization_summary_from_ftp()

        df = process_tsv_data(tsv_data, config)
        return load_to_bigquery(df, "submitter_organization", schema=schema)

    except Exception as e:
        logging.exception("Failed to process organization_summary from FTP")
        return f"Error processing organization_summary from FTP: {str(e)}"


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


def extract_hgnc_genes(content):
    """Extract gene records from HGNC gene_with_protein_product.json."""
    data = json.loads(content)
    docs = data.get("response", {}).get("docs", [])
    results = []

    for doc in docs:
        record = {
            "hgnc_id": doc.get("hgnc_id"),
            "symbol": doc.get("symbol"),
            "name": doc.get("name"),
            "locus_group": doc.get("locus_group"),
            "locus_type": doc.get("locus_type"),
            "status": doc.get("status"),
            "location": doc.get("location"),
            "alias_symbol": doc.get("alias_symbol", []),
            "alias_name": doc.get("alias_name", []),
            "prev_symbol": doc.get("prev_symbol", []),
            "prev_name": doc.get("prev_name", []),
            "gene_group": doc.get("gene_group", []),
            "gene_group_id": doc.get("gene_group_id", []),
            "date_approved_reserved": doc.get("date_approved_reserved"),
            "date_symbol_changed": doc.get("date_symbol_changed"),
            "date_name_changed": doc.get("date_name_changed"),
            "date_modified": doc.get("date_modified"),
            "entrez_id": doc.get("entrez_id"),
            "ensembl_gene_id": doc.get("ensembl_gene_id"),
            "vega_id": doc.get("vega_id"),
            "ucsc_id": doc.get("ucsc_id"),
            "refseq_accession": doc.get("refseq_accession", []),
            "ccds_id": doc.get("ccds_id", []),
            "uniprot_ids": doc.get("uniprot_ids", []),
            "pubmed_id": doc.get("pubmed_id", []),
            "omim_id": doc.get("omim_id", []),
            "orphanet": doc.get("orphanet"),
            "enzyme_id": doc.get("enzyme_id", []),
            "mane_select": doc.get("mane_select", []),
            "agr": doc.get("agr"),
        }
        results.append(record)

    logging.info(f"Extracted {len(results)} HGNC gene records")
    return results


def process_hgnc_from_gcs(bucket_name, file_name):
    """Load HGNC gene data into BigQuery."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    file_content = blob.download_as_text()

    genes = extract_hgnc_genes(file_content)
    if not genes:
        return f"No gene data found in {file_name}"

    df = pd.DataFrame(genes)
    return load_to_bigquery(df, "hgnc_gene", schema=hgnc_gene_schema)


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
        elif file_name == "hgnc_gene.json":
            message = process_hgnc_from_gcs(bucket_name, file_name)
        elif file_name == "ncbi_gene.txt":
            message = process_tsv_from_gcs(bucket_name, file_name, "ncbi_gene")
        elif file_name == "organization_summary.txt":
            # Fetch latest from ClinVar FTP instead of using uploaded file
            message = process_organization_summary_from_ftp()
        else:
            logging.info(f"Ignored file: {file_name}")
            message = f"Ignored file: {file_name}"

        return jsonify({"status": "success", "message": message}), 200

    except Exception as e:
        logging.exception("Unexpected error")
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    app.run(debug=True)
