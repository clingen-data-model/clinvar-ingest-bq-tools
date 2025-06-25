#!/bin/bash

# Set variables
PROJECT_ID="clingen-dev"
DATASET_ID="clinvar_2025_03_23_v2_3_1"
BUCKET_NAME="clinvar-gk-pilot"  # Replace with your bucket name
EXPORT_PATH="2025-03-23/dev"
TABLES=(
  "temp_catvar_final"
  # "gk_pilot_statement_scv"
)
FORMATS=(
  "NEWLINE_DELIMITED_JSON"
  "CSV"
)
TYPES=(
  "json"
  "csv"
)

# Loop over each table and export to JSON with GZIP compression
for TABLE in "${TABLES[@]}"; do
  # Extract the last part after the last underscore
  LAST_PART="${TABLE##*_}"

  # Loop over each format
  for i in "${!FORMATS[@]}"; do
    FORMAT="${FORMATS[$i]}"
    TYPE="${TYPES[$i]}"
    EXPORT_URI="gs://${BUCKET_NAME}/${EXPORT_PATH}/${LAST_PART}_out/${TYPE}/${LAST_PART}-*.${TYPE}.gz"

    bq extract \
      --destination_format="${FORMAT}" \
      --compression=GZIP \
      "${PROJECT_ID}:${DATASET_ID}.${TABLE}" \
      "${EXPORT_URI}"

    if [ $? -eq 0 ]; then
      echo "Exported ${TABLE} to ${EXPORT_URI} in format ${FORMAT}"
    else
      echo "Failed to export ${TABLE} to ${EXPORT_URI} in format ${FORMAT}"
    fi
  done
done

echo "All exports completed."

# # Categorical Variant Output to GCS
# bq extract --compression GZIP \
#   --destination_format NEWLINE_DELIMITED_JSON \
#   'clingen-stage:clinvar_2024_09_08_v1_6_62.gk_pilot_catvar' \
#   'gs://clinvar-gk-pilot/2024-09-08/stage/catvar_output_v2/ndjson/catvars-*.ndjson.gz'

# bq extract --compression GZIP \
#   --destination_format CSV \
#   'clingen-stage:clinvar_2024_09_08_v1_6_62.gk_pilot_catvar' \
#   'gs://clinvar-gk-pilot/2024-09-08/stage/catvar_output_v2/csv/catvars-*.csv.gz'

# # SCV Statement Output to GCS
# bq extract --compression GZIP \
#   --destination_format NEWLINE_DELIMITED_JSON \
#   'clingen-stage:clinvar_2024_09_08_v1_6_62.gk_pilot_statement' \
#   'gs://clinvar-gk-pilot/2024-09-08/stage/scv_output_v2/ndjson/scvs-*.ndjson.gz'

# bq extract --compression GZIP \
#   --destination_format CSV \
#   'clingen-stage:clinvar_2024_09_08_v1_6_62.gk_pilot_statement' \
#   'gs://clinvar-gk-pilot/2024-09-08/stage/scv_output_v2/csv/scvs-*.csv.gz'
