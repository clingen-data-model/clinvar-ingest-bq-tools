#!/bin/bash
# =============================================================================
# Load Batch Accepted Dates into BigQuery
# =============================================================================
#
# This script loads the batch-accepted-dates.tsv file into BigQuery.
# The batch_accepted_date determines when the 60-day grace period starts
# for flagging candidate submissions.
#
# Usage: ./load-batch-accepted-dates.sh
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TSV_FILE="${SCRIPT_DIR}/batch-accepted-dates.tsv"
TABLE="clinvar_curator.cvc_batch_accepted_dates"
TEMP_FILE=$(mktemp)

echo "Loading batch accepted dates from: ${TSV_FILE}"
echo "Target table: ${TABLE}"

# Strip comments and empty lines, remove trailing whitespace
grep -v "^#" "$TSV_FILE" | grep -v "^$" | sed 's/[[:space:]]*$//' > "$TEMP_FILE"

# Load the data
bq load \
  --replace \
  --source_format=CSV \
  --field_delimiter=tab \
  --skip_leading_rows=1 \
  --null_marker="" \
  "${TABLE}" \
  "$TEMP_FILE" \
  "batch_id:STRING,batch_accepted_date:DATE,notes:STRING"

rm "$TEMP_FILE"

echo ""
echo "Successfully loaded batch accepted dates."
echo ""

# Show summary
bq query --use_legacy_sql=false "
SELECT
  COUNT(*) as total_batches,
  MIN(batch_accepted_date) as earliest_date,
  MAX(batch_accepted_date) as latest_date
FROM \`${TABLE}\`
"
