#!/bin/bash
# Sync SQL scripts to GCS for use by the Cloud Function
#
# Usage: ./sync-sql-to-gcs.sh [--dry-run]
#
# This script uploads the SQL files (01-07) to GCS where the
# conflict-analytics-trigger Cloud Function loads them from.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GCS_BUCKET="gs://clinvar-ingest/conflict-analytics-sql"

# SQL files to sync (in execution order)
SQL_FILES=(
    "01-get-monthly-conflicts.sql"
    "02-monthly-conflict-changes.sql"
    "04-monthly-conflict-scv-snapshots.sql"
    "05-monthly-conflict-scv-changes.sql"
    "06-resolution-modification-analytics.sql"
    "07-google-sheets-analytics.sql"
)

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "DRY RUN - No files will be uploaded"
    echo ""
fi

echo "Syncing SQL files to GCS..."
echo "Source: $SCRIPT_DIR"
echo "Destination: $GCS_BUCKET"
echo ""

for sql_file in "${SQL_FILES[@]}"; do
    src_path="$SCRIPT_DIR/$sql_file"

    if [[ ! -f "$src_path" ]]; then
        echo "WARNING: File not found: $sql_file"
        continue
    fi

    if $DRY_RUN; then
        echo "[DRY RUN] Would upload: $sql_file"
    else
        echo "Uploading: $sql_file"
        gsutil cp "$src_path" "$GCS_BUCKET/"
    fi
done

echo ""
if $DRY_RUN; then
    echo "DRY RUN complete. Run without --dry-run to upload files."
else
    echo "Sync complete!"
    echo ""
    echo "To verify, run:"
    echo "  gsutil ls -l $GCS_BUCKET/"
fi
