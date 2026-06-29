#!/bin/bash
# Export spdi2vrs query result to GCS as a single gzipped CSV
# Usage: ./export-spdi2vrs-to-gcs.sh <query_or_table> [project] [bucket] [dest_path] [filename]
#
# Examples:
#   ./export-spdi2vrs-to-gcs.sh "SELECT * FROM \`clingen-dev.clinvar_2026_05_10_v2_5_0.spdi2vrs\`"
#   ./export-spdi2vrs-to-gcs.sh "clingen-dev.clinvar_2026_05_10_v2_5_0.spdi2vrs"

set -e

QUERY_OR_TABLE="${1:?Usage: $0 <query_or_table> [project] [bucket] [dest_path] [filename]}"
PROJECT="${2:-clingen-dev}"
BUCKET="${3:-clingen-public}"
DEST_PATH="${4:-clinvar-gks/clinvar-sv}"
FILENAME="${5:-clinvar_2026_05_10_spdi2vrs}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_TABLE="clinvar_ingest.temp_export_${TIMESTAMP}"
SHARD_URI="gs://${BUCKET}/${DEST_PATH}/_shards/${FILENAME}_${TIMESTAMP}_*.csv.gz"
FINAL_URI="gs://${BUCKET}/${DEST_PATH}/${FILENAME}.csv.gz"

echo "=== Export spdi2vrs to GCS ==="
echo "Project:     ${PROJECT}"
echo "Destination: ${FINAL_URI}"
echo ""

# Step 1: Materialize to temp table (needed for bq extract)
echo "--- Step 1: Materializing query to temp table ---"
if [[ "${QUERY_OR_TABLE}" == *"SELECT"* || "${QUERY_OR_TABLE}" == *"select"* ]]; then
    bq query \
        --project_id="${PROJECT}" \
        --use_legacy_sql=false \
        --destination_table="${TEMP_TABLE}" \
        --replace=true \
        --nouse_cache \
        "${QUERY_OR_TABLE}"
else
    # It's a table reference, create temp as SELECT *
    bq query \
        --project_id="${PROJECT}" \
        --use_legacy_sql=false \
        --destination_table="${TEMP_TABLE}" \
        --replace=true \
        --nouse_cache \
        "SELECT * FROM \`${QUERY_OR_TABLE}\`"
fi
echo "✓ Materialized to ${TEMP_TABLE}"

# Step 2: Export shards
echo "--- Step 2: Exporting shards ---"
bq extract \
    --project_id="${PROJECT}" \
    --destination_format=CSV \
    --compression=GZIP \
    --print_header=true \
    "${TEMP_TABLE}" \
    "${SHARD_URI}"
echo "✓ Shards exported"

# Step 3: Combine shards into single file
echo "--- Step 3: Combining shards ---"
SHARDS=($(gsutil ls "gs://${BUCKET}/${DEST_PATH}/_shards/${FILENAME}_${TIMESTAMP}_"*.csv.gz | sort))
NUM_SHARDS=${#SHARDS[@]}
echo "Found ${NUM_SHARDS} shards"

if [ ${NUM_SHARDS} -eq 1 ]; then
    gsutil mv "${SHARDS[0]}" "${FINAL_URI}"
elif [ ${NUM_SHARDS} -le 32 ]; then
    gsutil compose "${SHARDS[@]}" "${FINAL_URI}"
    gsutil rm "${SHARDS[@]}"
else
    echo "Multi-pass compose (${NUM_SHARDS} shards)..."
    TEMP_PREFIX="gs://${BUCKET}/${DEST_PATH}/_shards/_combined_"
    BATCH_SIZE=32
    BATCH_NUM=0
    TEMP_FILES=()

    for ((i=0; i<NUM_SHARDS; i+=BATCH_SIZE)); do
        BATCH=("${SHARDS[@]:i:BATCH_SIZE}")
        TEMP_FILE="${TEMP_PREFIX}batch_${BATCH_NUM}.csv.gz"
        gsutil compose "${BATCH[@]}" "${TEMP_FILE}"
        TEMP_FILES+=("${TEMP_FILE}")
        ((BATCH_NUM++))
    done

    gsutil compose "${TEMP_FILES[@]}" "${FINAL_URI}"
    gsutil rm "${TEMP_FILES[@]}"
    gsutil rm "${SHARDS[@]}"
fi

# Cleanup shard directory if empty
gsutil rm "gs://${BUCKET}/${DEST_PATH}/_shards/" 2>/dev/null || true

echo "✓ Combined into single file"

# Step 4: Cleanup temp table
echo "--- Step 4: Cleanup ---"
bq rm -f --project_id="${PROJECT}" "${TEMP_TABLE}"
echo "✓ Temp table removed"

# Summary
echo ""
echo "=== Export Complete ==="
gsutil ls -l "${FINAL_URI}"
