#!/bin/bash

# Set the project id
PROJECT_ID='clingen-dev'

# get authorization
gcloud auth login --enable-gdrive-access

# set the project id
gcloud config set project $PROJECT_ID

# Define the list of table and dataset pairs
# Each entry is a tuple where the first element is the table name and the second element is the dataset name
table_definitions=(
  "clinvar_annotations,clinvar_curator"
  "cvc_clinvar_outlier_tracking,clinvar_curator"
  "cvc_clinvar_reviews_sheet,clinvar_curator"
  "cvc_clinvar_submissions_sheet,clinvar_curator"
  "cvc_clinvar_batches_sheet,clinvar_curator"
  "cvc_clinvar_clinsig_outlier_tracker,clinvar_curator"
  "clinvar_releases_ext,clinvar_ingest"
  "clinvar_submitter_abbrevs_ext,clinvar_ingest"
  "report_ext,variation_tracker"
  "report_option_ext,variation_tracker"
  "report_submitter_ext,variation_tracker"
  "report_gene_ext,variation_tracker"
  "report_variant_list_ext,variation_tracker"
)

# Loop over each tuple to create the external tables
for table_def in "${table_definitions[@]}"; do
  # Split the tuple into table name and dataset
  IFS=',' read -r table_name dataset <<< "$table_def"

  # Construct the external table definition file and the corresponding table name
  definition_file="${table_name}.def"
  target_table="${dataset}.${table_name}"

  # Check if the table exists (suppress stderr since "Not found" error is expected)
  if bq show --format=none "$target_table" 2>/dev/null; then
      echo "Table $target_table exists. Replacing..."

      # Delete the existing table
      bq rm -f -t "$target_table"

      # Ensure deletion was successful
      if bq show --format=none "$target_table" 2>/dev/null; then
          echo "Error: Failed to delete table $target_table"
          exit 1
      fi
  else
      echo "Table $target_table does not exist. Creating a new table..."
  fi

  # Create the google sheet external table
  bq mk --external_table_definition="$definition_file" "$target_table"

  echo "Created table $target_table using definition $definition_file"
done

# re-run the createOrReplaceTables.sql script to re-create the internal tables that reference the external tables
echo "Replacing internal tables that reference the external tables..."
bq query --use_legacy_sql=false --project_id="$PROJECT_ID" "CALL \`clinvar_ingest.refresh_external_table_copies\`()"


# after running the external table setup scripts, assure that the 2 schedule jobs that create the
# tables with the data from the all_releases() table function and the clinvar_annotations google sheet external table
# these two sources are used in many downstream queries and having them in native tables will speed up
# query performance significantly.

# Function to create or update a scheduled query transfer config
create_or_update_transfer_config() {
  local display_name="$1"
  local target_dataset="$2"
  local query="$3"
  local dest_table="$4"
  local schedule="$5"

  # Check if transfer config already exists by display name
  local config_id
  config_id=$(bq ls --transfer_config --transfer_location=us --project_id="$PROJECT_ID" --format=json 2>/dev/null | \
    python3 -c "import sys, json; configs = json.load(sys.stdin); print(next((c['name'] for c in configs if c.get('displayName') == '$display_name'), ''))" 2>/dev/null)

  local params="{
    \"query\":\"$query\",
    \"destination_table_name_template\":\"$dest_table\",
    \"write_disposition\":\"WRITE_TRUNCATE\"
  }"

  if [ -n "$config_id" ]; then
    echo "Transfer config '$display_name' exists. Updating..."
    bq update --transfer_config \
      --params="$params" \
      --schedule="$schedule" \
      "$config_id"
    echo "Updated transfer config: $display_name"
  else
    echo "Transfer config '$display_name' does not exist. Creating..."
    bq mk --transfer_config \
      --project_id="$PROJECT_ID" \
      --target_dataset="$target_dataset" \
      --display_name="$display_name" \
      --params="$params" \
      --data_source=scheduled_query \
      --schedule="$schedule"
    echo "Created transfer config: $display_name"
  fi
}

# all_releases_native
create_or_update_transfer_config \
  "Hourly: all_releases() Table Function to Native Table" \
  "clinvar_ingest" \
  "SELECT * FROM \`$PROJECT_ID.clinvar_ingest.all_releases\`()" \
  "all_releases_native" \
  "every 1 hours"

# clinvar_annotations_native
create_or_update_transfer_config \
  "Hourly : clinvar_annotations GSheet to Native Table" \
  "clinvar_curator" \
  "SELECT * FROM \`$PROJECT_ID.clinvar_curator.clinvar_annotations\`" \
  "clinvar_annotations_native" \
  "every 1 hours"
