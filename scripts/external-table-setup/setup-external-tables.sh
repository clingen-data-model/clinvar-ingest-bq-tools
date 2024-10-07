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
  "cvc_clinvar_reviews_sheet,clinvar_curator"
  "cvc_clinvar_submissions_sheet,clinvar_curator"
  "cvc_clinvar_batches_sheet,clinvar_curator"
  "clinvar_releases,clinvar_ingest"
  "clinvar_submitter_abbrevs,clinvar_ingest"
  "report,variation_tracker"
  "report_option,variation_tracker"
  "report_submitter,variation_tracker"
  "report_gene,variation_tracker"
  "report_variant_list,variation_tracker"
)

# Loop over each tuple to create the external tables
for table_def in "${table_definitions[@]}"; do
  # Split the tuple into table name and dataset
  IFS=',' read -r table_name dataset <<< "$table_def"
  
  # Construct the external table definition file and the corresponding table name
  definition_file="${table_name}.def"
  target_table="${dataset}.${table_name}"
  
  # Create the google sheet external table
  bq mk --external_table_definition="$definition_file" "$target_table"
  
  echo "Created table $target_table using definition $definition_file"
done