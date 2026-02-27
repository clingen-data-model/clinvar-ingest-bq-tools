#!/usr/bin/env bash

# Download multiple HGNC JSON files, merge them, and upload to GCS
# This triggers the Cloud Function to process and load into BigQuery

set -e

# Add new HGNC URLs here as needed
HGNC_URLS=(
    "https://storage.googleapis.com/public-download-files/hgnc/json/json/locus_types/gene_with_protein_product.json"
    "https://storage.googleapis.com/public-download-files/hgnc/json/json/locus_groups/non-coding_RNA.json"
)

GCS_BUCKET="${GCS_BUCKET:-external-dataset-ingest}"
OUTPUT_FILE="hgnc_gene.json"

# Change to data directory
cd "$(dirname "$0")/../data" || { mkdir -p "$(dirname "$0")/../data" && cd "$(dirname "$0")/../data"; }

# Download and merge HGNC JSON files
if [ ! -f "$OUTPUT_FILE" ] || [ "$1" == "--force" ]; then
    echo "Downloading ${#HGNC_URLS[@]} HGNC JSON files..."

    TEMP_FILES=()
    for i in "${!HGNC_URLS[@]}"; do
        url="${HGNC_URLS[$i]}"
        temp_file="hgnc_temp_${i}.json"
        filename=$(basename "$url")
        echo "  Downloading $filename..."
        curl -sL -o "$temp_file" "$url"
        echo "    Downloaded $(wc -c < "$temp_file" | xargs) bytes"
        TEMP_FILES+=("$temp_file")
    done

    echo "Merging ${#TEMP_FILES[@]} files..."

    # Use Python to merge the response.docs arrays from all files
    python3 - "${TEMP_FILES[@]}" << 'EOF'
import json
import sys

all_docs = []
for temp_file in sys.argv[1:]:
    with open(temp_file) as f:
        data = json.load(f)
        docs = data.get("response", {}).get("docs", [])
        all_docs.extend(docs)
        print(f"  {temp_file}: {len(docs)} records")

# Create merged structure
merged = {
    "response": {
        "numFound": len(all_docs),
        "docs": all_docs
    }
}

with open("hgnc_gene.json", "w") as f:
    json.dump(merged, f)

print(f"Merged total: {len(all_docs)} records")
EOF

    # Clean up temp files
    rm -f "${TEMP_FILES[@]}"

    echo "Created $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | xargs) bytes)"
else
    echo "Using existing $OUTPUT_FILE (use --force to re-download)"
fi

# Upload to GCS if gsutil is available
if command -v gsutil &> /dev/null; then
    echo "Uploading to gs://${GCS_BUCKET}/${OUTPUT_FILE}..."
    gsutil cp "$OUTPUT_FILE" "gs://${GCS_BUCKET}/"
    echo "Upload complete. Cloud Function will be triggered automatically."
else
    echo "gsutil not found. File saved locally at: $(pwd)/$OUTPUT_FILE"
    echo "Manually upload to GCS bucket to trigger processing."
fi
