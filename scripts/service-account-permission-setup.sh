#!/bin/bash

PROJECT_ID="clingen-stage"
SERVICE_ACCOUNT_EMAIL="github-clinvar-bq-utils-upload@clingen-stage.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/storage.objectAdmin" \
  --role="roles/bigquery.dataEditor" \
  --role="roles/bigquery.jobUser" \
  --role="roles/bigquery.user" \
  --condition=None \
  --format=json

echo "Service account permissions setup completed."
