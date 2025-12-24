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

  # Check if the table exists
  if bq show --format=none "$target_table"; then
      echo "Table $target_table exists. Replacing..."

      # Delete the existing table
      bq rm -f -t "$target_table"

      # Ensure deletion was successful
      if bq show --format=none "$target_table"; then
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

# all_releases_native
bq mk --update --transfer_config \
--project_id="$PROJECT_ID" \
--target_dataset="clinvar_ingest" \
--display_name="Hourly: all_releases() Table Function to Native Table" \
--params="{
  \"query\":\"SELECT * FROM \`$PROJECT_ID.clinvar_ingest.all_releases\`()\",
  \"destination_table_name_template\":\"all_releases_native\",
  \"write_disposition\":\"WRITE_TRUNCATE\"
}" \
--data_source=scheduled_query \
--schedule='0 * * * *'

echo "Scheduled job for all_releases_native has been successfully created or updated in project $PROJECT_ID."

# clinvar_annotations_native
bq mk --update --transfer_config \
--project_id="$PROJECT_ID" \
--target_dataset="clinvar_curator" \
--display_name="Hourly : clinvar_annotations GSheet to Native Table" \
--params="{
  \"query\":\"SELECT * FROM \`$PROJECT_ID.clinvar_curator.clinvar_annotations\`\",
  \"destination_table_name_template\":\"clinvar_annotations_native\",
  \"write_disposition\":\"WRITE_TRUNCATE\"
}" \
--data_source=scheduled_query \
--schedule='1 * * * *'

echo "Scheduled job for clinvar_annotations_native has been successfully created or updated in project $PROJECT_ID."
