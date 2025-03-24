from flask import Flask, request, jsonify
from google.cloud import storage, bigquery
import json
import pandas as pd
import os

app = Flask(__name__)

# Set environment variables
GCS_BUCKET = os.getenv("GCS_BUCKET")  # Cloud Storage bucket name
BQ_PROJECT = os.getenv("BQ_PROJECT")  # GCP project name
BQ_DATASET = os.getenv("BQ_DATASET")  # BigQuery dataset name
BQ_TABLE = "hpo_terms"  # BigQuery table name

def transform_id(id_path):
    """
    Extracts the last part of an ID path (after the last '/') and replaces '_' with ':'.
    Example: "http://purl.obolibrary.org/obo/HP_0000001" -> "HP:0000001"
    """
    last_part = id_path.rsplit("/", 1)[-1]  # Extracts last part after '/'
    return last_part.replace("_", ":")  # Replaces underscore with colon

def process_json_from_gcs(bucket_name, file_name):
    """
    Reads JSON from GCS, filters relevant data, and writes to BigQuery.
    """
    # Initialize GCS client
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)

    # Read the JSON file
    content = blob.download_as_text()
    data = json.loads(content)

    # Extract and filter nodes
    nodes = data["graphs"][0]["nodes"]
    filtered_nodes = [{"id": transform_id(node["id"]), "lbl": node["lbl"]}
                      for node in nodes if node.get("type") == "CLASS"]

    # Convert to DataFrame
    df = pd.DataFrame(filtered_nodes)

    # Load data into BigQuery
    bq_client = bigquery.Client()
    table_id = f"{BQ_PROJECT}.{BQ_DATASET}.{BQ_TABLE}"

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # Replace existing table
        autodetect=True
    )

    job = bq_client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Wait for completion

    return f"Loaded {len(df)} rows into {table_id}"

@app.route("/", methods=["POST"])
def handle_gcs_event():
    """
    Triggered by a Cloud Storage event.
    """
    request_json = request.get_json()
    
    if request_json and "name" in request_json:
        file_name = request_json["name"]
        bucket_name = request_json["bucket"]

        if file_name.endswith("hp.json"):  # Only process the target file
            result = process_json_from_gcs(bucket_name, file_name)
            return jsonify({"status": "success", "message": result}), 200

    return jsonify({"status": "error", "message": "Invalid event data"}), 400

if __name__ == "__main__":
    app.run(debug=True)
