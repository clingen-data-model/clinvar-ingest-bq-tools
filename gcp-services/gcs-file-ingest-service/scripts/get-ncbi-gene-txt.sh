#!/usr/bin/env bash

# Download gene_info.gz from NCBI, extract human genes, and upload to GCS
# This triggers the Cloud Function to process and load into BigQuery

set -e

NCBI_FTP_URL="https://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz"
GCS_BUCKET="${GCS_BUCKET:-external-dataset-ingest}"
OUTPUT_FILE="ncbi_gene.txt"

# Change to data directory
cd "$(dirname "$0")/../data" || { mkdir -p "$(dirname "$0")/../data" && cd "$(dirname "$0")/../data"; }

# Download gene_info.gz if not present or if --force flag is passed
if [ ! -f "gene_info.gz" ] || [ "$1" == "--force" ]; then
    echo "Downloading gene_info.gz from NCBI FTP (~1.5GB)..."
    wget -O gene_info.gz "$NCBI_FTP_URL"
else
    echo "Using existing gene_info.gz (use --force to re-download)"
fi

echo "Processing gene_info.gz to extract human genes..."

# Count total lines for progress
total=$(gunzip -c gene_info.gz | wc -l)

# Stream, filter, extract + progress → ncbi_gene.txt
gunzip -c gene_info.gz \
  | awk -F'\t' -v total="$total" '
    BEGIN {
      OFS = "\t"
      print "GeneID","Symbol","Description","GeneType","NomenclatureID","Synonyms","OMIM_ID"
    }
    NR > 1 {
      # every 200k lines, update progress on same stderr line
      if (NR % 200000 == 0) {
        printf("\r[%.2f%%] processed", NR/total*100) \
          > "/dev/stderr"
        fflush("/dev/stderr")
      }
      # only Homo sapiens and skip biological-region
      if ($1 == "9606" && $10 != "biological-region") {
        omim = ""
        n = split($6, refs, "|")
        for (i = 1; i <= n; i++) {
          if (refs[i] ~ /^MIM:/) {
            split(refs[i], m, ":")
            omim = (omim ? omim "|" m[2] : m[2])
          }
        }
        print $2, $3, $9, $10, $11, $5, omim
      }
    }
    END {
      # finish the progress line
      printf("\r[100%%] processed!\n") > "/dev/stderr"
    }
  ' \
  > "$OUTPUT_FILE"

echo "Extracted $(wc -l < "$OUTPUT_FILE") human genes"

# Upload to GCS if gsutil is available
if command -v gsutil &> /dev/null; then
    echo "Uploading to gs://${GCS_BUCKET}/${OUTPUT_FILE}..."
    gsutil cp "$OUTPUT_FILE" "gs://${GCS_BUCKET}/"
    echo "Upload complete. Cloud Function will be triggered automatically."
else
    echo "gsutil not found. File saved locally at: $(pwd)/$OUTPUT_FILE"
    echo "Manually upload to GCS bucket to trigger processing."
fi
