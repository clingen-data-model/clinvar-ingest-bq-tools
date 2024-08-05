#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

PROJECT_IDS=("clingen-dev" "clingen-stage")
SERVICE_ACCOUNT_EMAIL="github-clinvar-bq-utils-upload@clingen-stage.iam.gserviceaccount.com"


for PROJECT_ID in "${PROJECT_IDS[@]}"
do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.objectAdmin" \
    --condition=None \
    --quiet > /dev/null || { echo "Failed to assign storage.objectAdmin role"; exit 1; }

  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.objectViewer" \
    --condition=None \
    --quiet > /dev/null || { echo "Failed to assign storage.objectViewer role"; exit 1; }

  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.dataEditor" \
    --condition=None \
    --quiet > /dev/null || { echo "Failed to assign bigquery.dataEditor role"; exit 1; }

  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.jobUser" \
    --condition=None \
    --quiet > /dev/null || { echo "Failed to assign bigquery.jobUser role"; exit 1; }

  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.user" \
    --condition=None \
    --quiet > /dev/null || { echo "Failed to assign bigquery.user role"; exit 1; }
done

echo "All roles assigned successfully."

echo "Service account permissions setup completed."
