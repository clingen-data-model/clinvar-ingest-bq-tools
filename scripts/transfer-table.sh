# Define variables
SOURCE_TABLE='clingen-stage:clinvar_2024_07_16_v1_6_62.variation_identity'
SOURCE_REGION='us'
DESTINATION_TABLE='clingen-dev:clinvar_2024_07_16_v1_0_0_beta1.variation_identity_from_stage'
DESTINATION_REGION='us-east1'
SCHEMA_FILE='schema.json'
FINAL_SCHEMA_FILE='final_schema.json'
GCS_PATH="'gs://clinvar-ingest/temp/stage-$SOURCE_TABLE-*.json'"

# Extract data to JSON file
bq --location="$SOURCE_REGION" extract --destination_format NEWLINE_DELIMITED_JSON \
   "$SOURCE_TABLE" "$GCS_PATH"

# Extract Schema Using bq show:
bq show --format=prettyjson "$SOURCE_TABLE" > "$SCHEMA_FILE"

# Extract and Format the Schema:
cat "$SCHEMA_FILE" | jq '.schema.fields' > "$FINAL_SCHEMA_FILE"

# Load data using the formatted schema
bq --location="$DESTINATION_REGION" load --source_format=NEWLINE_DELIMITED_JSON \
   --schema="$FINAL_SCHEMA_FILE" \
   "$DESTINATION_TABLE" "$GCS_PATH"
