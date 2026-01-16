#!/bin/bash
# Export large BigQuery tables to GCS as gzipped CSV
# Usage: ./export-variation-to-gcs.sh <export_name> [destination_bucket] [destination_path]
#
# Export names:
#   all         - Export all tables
#   variation   - Export variation table
#   scv_summary - Export scv_summary (with specific columns, ordered)
#   submitter   - Export submitter table
#
# Examples:
#   ./export-variation-to-gcs.sh all
#   ./export-variation-to-gcs.sh variation
#   ./export-variation-to-gcs.sh scv_summary my-bucket my/path

set -e

# Check for export name argument
if [ -z "$1" ]; then
    echo "Usage: $0 <export_name> [destination_bucket] [destination_path]"
    echo ""
    echo "Export names: all, variation, scv_summary, submitter"
    exit 1
fi

EXPORT_NAME="$1"

# Configuration
PROJECT="clingen-stage"
DATASET="clinvar_2019_06_01_v0"
BUCKET="${2:-${PROJECT}-bq-exports}"
DEST_PATH="${3:-exports/${DATASET}}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== BigQuery Export to GCS ==="
echo "Export:      ${EXPORT_NAME}"
echo "Project:     ${PROJECT}"
echo "Dataset:     ${DATASET}"
echo "Destination: gs://${BUCKET}/${DEST_PATH}/"
echo ""

# Function to export a table to GCS
export_table() {
    local TABLE_NAME="$1"
    local OUTPUT_NAME="$2"
    local GCS_URI="gs://${BUCKET}/${DEST_PATH}/${OUTPUT_NAME}_${TIMESTAMP}.csv.gz"
    local SHARD_PREFIX="gs://${BUCKET}/${DEST_PATH}/shards/${OUTPUT_NAME}_${TIMESTAMP}_"

    echo "--- Exporting ${TABLE_NAME} ---"
    echo "Destination: ${GCS_URI}"

    # Try single file export first
    if bq extract \
        --project_id="${PROJECT}" \
        --destination_format=CSV \
        --compression=GZIP \
        --print_header=true \
        "${DATASET}.${TABLE_NAME}" \
        "${GCS_URI}" 2>/dev/null; then

        echo "✓ Export completed to single file"
    else
        # If single file fails (too large), use sharded export then combine
        echo "Using sharded approach for large table..."

        bq extract \
            --project_id="${PROJECT}" \
            --destination_format=CSV \
            --compression=GZIP \
            --print_header=true \
            "${DATASET}.${TABLE_NAME}" \
            "${SHARD_PREFIX}*.csv.gz"

        echo "✓ Sharded export complete, combining..."

        # Combine shards
        combine_shards "${SHARD_PREFIX}" "${GCS_URI}"
    fi

    echo "✓ ${OUTPUT_NAME}: ${GCS_URI}"
    echo ""
}

# Function to export a query result to GCS
export_query() {
    local QUERY="$1"
    local OUTPUT_NAME="$2"
    local TEMP_TABLE="${DATASET}.temp_export_${OUTPUT_NAME}_${TIMESTAMP}"
    local GCS_URI="gs://${BUCKET}/${DEST_PATH}/${OUTPUT_NAME}_${TIMESTAMP}.csv.gz"
    local SHARD_PREFIX="gs://${BUCKET}/${DEST_PATH}/shards/${OUTPUT_NAME}_${TIMESTAMP}_"

    echo "--- Exporting ${OUTPUT_NAME} (from query) ---"
    echo "Destination: ${GCS_URI}"

    # Materialize query to temp table
    echo "Materializing query to temp table..."
    bq query \
        --project_id="${PROJECT}" \
        --use_legacy_sql=false \
        --destination_table="${TEMP_TABLE}" \
        --replace=true \
        "${QUERY}"

    # Export temp table
    if bq extract \
        --project_id="${PROJECT}" \
        --destination_format=CSV \
        --compression=GZIP \
        --print_header=true \
        "${TEMP_TABLE}" \
        "${GCS_URI}" 2>/dev/null; then

        echo "✓ Export completed to single file"
    else
        # Sharded export
        echo "Using sharded approach for large result..."

        bq extract \
            --project_id="${PROJECT}" \
            --destination_format=CSV \
            --compression=GZIP \
            --print_header=true \
            "${TEMP_TABLE}" \
            "${SHARD_PREFIX}*.csv.gz"

        echo "✓ Sharded export complete, combining..."

        # Combine shards
        combine_shards "${SHARD_PREFIX}" "${GCS_URI}"
    fi

    # Cleanup temp table
    echo "Cleaning up temp table..."
    bq rm -f --project_id="${PROJECT}" "${TEMP_TABLE}"

    echo "✓ ${OUTPUT_NAME}: ${GCS_URI}"
    echo ""
}

# Function to combine sharded files into single file
combine_shards() {
    local SHARD_PREFIX="$1"
    local GCS_URI="$2"

    SHARDS=($(gsutil ls "${SHARD_PREFIX}"*.csv.gz | sort))
    NUM_SHARDS=${#SHARDS[@]}

    if [ ${NUM_SHARDS} -le 32 ]; then
        gsutil compose "${SHARDS[@]}" "${GCS_URI}"
    else
        echo "Large number of shards (${NUM_SHARDS}), using multi-pass compose..."

        TEMP_PREFIX="${SHARD_PREFIX}combined_"
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

        if [ ${#TEMP_FILES[@]} -le 32 ]; then
            gsutil compose "${TEMP_FILES[@]}" "${GCS_URI}"
        else
            echo "ERROR: Too many intermediate files for single compose"
            exit 1
        fi

        gsutil rm "${TEMP_PREFIX}"*.csv.gz 2>/dev/null || true
    fi

    # Cleanup shards
    gsutil rm "${SHARD_PREFIX}"*.csv.gz
    echo "✓ Combined into single file"
}

# =============================================================================
# EXPORTS
# =============================================================================

run_variation() {
    export_table "variation" "variation"
}

run_scv_summary() {
    export_query "
SELECT
  release_date, id, version, variation_id, local_key, last_evaluated,
  rank, review_status, clinvar_stmt_type, cvc_stmt_type,
  submitted_classification, classif_type, significance,
  submitter_id, submission_date
FROM \`${PROJECT}.${DATASET}.scv_summary\`
ORDER BY 1, 2
" "scv_summary"
}

run_submitter() {
    export_query "
SELECT
  release_date, id, current_name, current_abbrev, org_category
FROM \`${PROJECT}.${DATASET}.submitter\`
" "submitter"
}

case "${EXPORT_NAME}" in
    all)
        run_variation
        run_scv_summary
        run_submitter
        ;;
    variation)
        run_variation
        ;;
    scv_summary)
        run_scv_summary
        ;;
    submitter)
        run_submitter
        ;;
    *)
        echo "ERROR: Unknown export name '${EXPORT_NAME}'"
        echo "Valid options: all, variation, scv_summary, submitter"
        exit 1
        ;;
esac

# =============================================================================
# SUMMARY
# =============================================================================

echo "=== All Exports Complete ==="
echo ""
echo "Files exported to gs://${BUCKET}/${DEST_PATH}/:"
gsutil ls -l "gs://${BUCKET}/${DEST_PATH}/*_${TIMESTAMP}.csv.gz"
echo ""
echo "To download all: gsutil cp 'gs://${BUCKET}/${DEST_PATH}/*_${TIMESTAMP}.csv.gz' ."
