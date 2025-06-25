#!/bin/bash

# Set the project id
PROJECT_ID='clingen-dev'

# Date of release
RELEASE_DATE='2025-03-23'

# Set the dataset id
DATASET_ID='clinvar_2025_03_23_v2_3_1'

# Set the table id
TABLE_ID='gk_pilot_vrs'

# Set the Google Cloud Storage path
# GCS_JSON_PATH='gs://clinvar-gk-pilot/2024-04-07/dev/2024-04-07_dev_output-vi2.ndjson'
GCS_JSON_PATH="gs://clinvar-gk-pilot/${RELEASE_DATE}/dev/processed-vi.json.gz"

# Set the BigQuery schema
SCHEMA_FILE_PATH='vrs_output_2_0.schema.json'

# Load the data from the GCS JSON file into the BigQuery table
bq --project_id=$PROJECT_ID load \
   --source_format=NEWLINE_DELIMITED_JSON \
   --schema=$SCHEMA_FILE_PATH\
   --max_bad_records=2 \
   --ignore_unknown_values \
   $DATASET_ID.$TABLE_ID \
   $GCS_JSON_PATH

# Check if the load job succeeded or failed
if [ $? -eq 0 ]; then
  echo "Data load succeeded."
else
  echo "Data load failed."
fi
