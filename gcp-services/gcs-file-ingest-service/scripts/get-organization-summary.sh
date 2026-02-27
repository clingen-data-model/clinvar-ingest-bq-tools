#!/usr/bin/env bash

# Download organization_summary.txt from ClinVar FTP and upload to GCS
# This triggers the Cloud Function to process and load into BigQuery

set -e

CLINVAR_FTP_URL="https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/organization_summary.txt"
GCS_BUCKET="${GCS_BUCKET:-external-dataset-ingest}"
OUTPUT_FILE="organization_summary.txt"

# Change to data directory
cd "$(dirname "$0")/../data" || mkdir -p "$(dirname "$0")/../data" && cd "$(dirname "$0")/../data"

echo "Downloading organization_summary.txt from ClinVar FTP..."
wget -O "$OUTPUT_FILE" "$CLINVAR_FTP_URL"

echo "Downloaded $(wc -l < "$OUTPUT_FILE") lines"

# Upload to GCS if gsutil is available and GCS_BUCKET is set
if command -v gsutil &> /dev/null; then
    echo "Uploading to gs://${GCS_BUCKET}/${OUTPUT_FILE}..."
    gsutil cp "$OUTPUT_FILE" "gs://${GCS_BUCKET}/"
    echo "Upload complete. Cloud Function will be triggered automatically."
else
    echo "gsutil not found. File saved locally at: $(pwd)/$OUTPUT_FILE"
    echo "Manually upload to GCS bucket to trigger processing."
fi
