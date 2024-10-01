#!/bin/bash

# Set the project id
PROJECT_ID='clingen-dev'

# get authorization
gcloud auth login --enable-gdrive-access

# set the project id
gcloud config set project $PROJECT_ID

# create the google sheet external table
# bq mk --external_table_definition=report_submitter.def clinvar_ingest.report_submitter

# Define the list of table names (assuming the file names match the table names)
table_names=(
  "clinvar_releases"
  "clinvar_submitter_abbrevs"
  "report" 
  "report_option"
  "report_submitter" 
  "report_gene" 
  "report_variant_list"
) 

# Loop over each table name to create the external tables
for table_name in "${table_names[@]}"; do
  # Construct the external table definition file and the corresponding table name
  definition_file="${table_name}.def"
  target_table="clinvar_ingest.${table_name}"
  
  # Create the google sheet external table
  bq mk --external_table_definition="$definition_file" "$target_table"
  
  echo "Created table $target_table using definition $definition_file"
done