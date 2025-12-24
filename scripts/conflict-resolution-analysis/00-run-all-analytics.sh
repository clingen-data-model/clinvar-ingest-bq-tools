#!/bin/bash
# ============================================================================
# Script: 00-run-all-analytics.sh
#
# Description:
#   Executes all conflict resolution analytics SQL scripts in the correct
#   dependency order. Each SQL file is the source of truth for its table
#   definitions.
#
# Usage:
#   ./00-run-all-analytics.sh [OPTIONS]
#
# Options:
#   --project PROJECT_ID    GCP project ID (default: clingen-dev)
#   --check-only            Only check if rebuild is needed, don't execute
#   --force                 Force rebuild even if no new data detected
#   --skip-check            Skip the new data check and rebuild immediately
#   --dry-run               Show commands without executing
#   --no-gcloud-update      Skip gcloud components update check
#   --help                  Show this help message
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - bq command-line tool available
#   - Access to the clinvar_ingest dataset
#
# Execution Order:
#   1. 01-get-monthly-conflicts.sql
#   2. 02-monthly-conflict-changes.sql
#   3. 04-monthly-conflict-scv-snapshots.sql
#   4. 05-monthly-conflict-scv-changes.sql
#   5. 06-resolution-modification-analytics.sql
#   6. 07-google-sheets-analytics.sql
#
# Scheduling:
#   To set up as a cron job (monthly on the 1st at 6 AM):
#   0 6 1 * * /path/to/00-run-all-analytics.sh --project your-project-id
#
#   Or use Cloud Scheduler with Cloud Functions/Cloud Run for serverless execution.
# ============================================================================

set -e  # Exit on error

# Disable gcloud interactive prompts and auto-update checks
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1

# Default values
PROJECT_ID="clingen-dev"
CHECK_ONLY=false
FORCE=false
SKIP_CHECK=false
DRY_RUN=false
AUTO_UPDATE_GCLOUD=true

# Script directory (where the SQL files are located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --skip-check)
      SKIP_CHECK=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-gcloud-update)
      AUTO_UPDATE_GCLOUD=false
      shift
      ;;
    --help)
      head -50 "$0" | grep -E "^#" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Function to log with timestamp
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to update gcloud components
update_gcloud() {
  if [[ "$AUTO_UPDATE_GCLOUD" != "true" ]]; then
    return 0
  fi

  log "${BLUE}Updating gcloud SDK components...${NC}"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "${YELLOW}  [DRY RUN] Would execute: gcloud components update --quiet${NC}"
  else
    gcloud components update --quiet
    log "${GREEN}gcloud components updated.${NC}"
  fi
}

# Function to run a SQL file
run_sql() {
  local sql_file="$1"
  local description="$2"

  if [[ ! -f "$sql_file" ]]; then
    log "${RED}ERROR: SQL file not found: $sql_file${NC}"
    exit 1
  fi

  log "${BLUE}Running: $description${NC}"
  log "  File: $sql_file"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "${YELLOW}  [DRY RUN] Would execute: bq query --project_id=$PROJECT_ID --use_legacy_sql=false < $sql_file${NC}"
  else
    local start_time
    local end_time
    local duration
    start_time=$(date +%s)

    bq query \
      --project_id="$PROJECT_ID" \
      --use_legacy_sql=false \
      --max_rows=0 \
      < "$sql_file"

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log "${GREEN}  Completed in ${duration}s${NC}"
  fi
}

# Function to check if new data is available
check_new_data() {
  log "${BLUE}Checking for new monthly releases...${NC}"

  local result
  result=$(bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    --format=csv \
    --quiet \
    "WITH latest_snapshot AS (
      SELECT MAX(snapshot_release_date) AS latest_snapshot_date
      FROM \`clinvar_ingest.monthly_conflict_snapshots\`
    ),
    new_months AS (
      SELECT COUNT(DISTINCT DATE_TRUNC(release_date, MONTH)) AS new_month_count
      FROM \`clinvar_ingest.all_schemas\`()
      WHERE release_date >= DATE'2023-01-01'
        AND DATE_TRUNC(release_date, MONTH) > (
          SELECT COALESCE(DATE_TRUNC(latest_snapshot_date, MONTH), DATE'2022-12-01')
          FROM latest_snapshot
        )
    )
    SELECT new_month_count FROM new_months;" 2>/dev/null | tail -1)

  echo "$result"
}

# Main execution
log "${GREEN}============================================${NC}"
log "${GREEN}Conflict Resolution Analytics Pipeline${NC}"
log "${GREEN}============================================${NC}"
log "Project: $PROJECT_ID"
log "Script directory: $SCRIPT_DIR"

# Update gcloud if enabled
update_gcloud

# Check for new data unless skipped or forced
if [[ "$SKIP_CHECK" == "false" && "$FORCE" == "false" ]]; then
  new_months=$(check_new_data)

  if [[ "$new_months" == "0" ]]; then
    log "${YELLOW}No new monthly releases to process.${NC}"
    if [[ "$CHECK_ONLY" == "true" ]]; then
      log "Status: UP TO DATE"
      exit 0
    fi
    log "Use --force to rebuild anyway, or --skip-check to skip this check."
    exit 0
  else
    log "${GREEN}Found $new_months new month(s) to process.${NC}"
    if [[ "$CHECK_ONLY" == "true" ]]; then
      log "Status: REBUILD NEEDED"
      exit 0
    fi
  fi
elif [[ "$FORCE" == "true" ]]; then
  log "${YELLOW}Force rebuild requested - skipping new data check${NC}"
elif [[ "$SKIP_CHECK" == "true" ]]; then
  log "${YELLOW}Skipping new data check${NC}"
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
  exit 0
fi

# Record start time
PIPELINE_START=$(date +%s)

log ""
log "${GREEN}Starting pipeline execution...${NC}"
log ""

# Step 1: Create monthly_conflict_snapshots
run_sql "$SCRIPT_DIR/01-get-monthly-conflicts.sql" \
  "Step 1/6: Creating monthly_conflict_snapshots"

# Step 2: Create monthly_conflict_changes
run_sql "$SCRIPT_DIR/02-monthly-conflict-changes.sql" \
  "Step 2/6: Creating monthly_conflict_changes"

# Step 3: Create monthly_conflict_scv_snapshots
run_sql "$SCRIPT_DIR/04-monthly-conflict-scv-snapshots.sql" \
  "Step 3/6: Creating monthly_conflict_scv_snapshots"

# Step 4: Create monthly_conflict_scv_changes and monthly_conflict_vcv_scv_summary
run_sql "$SCRIPT_DIR/05-monthly-conflict-scv-changes.sql" \
  "Step 4/6: Creating monthly_conflict_scv_changes & monthly_conflict_vcv_scv_summary"

# Step 5: Create conflict_resolution_analytics and views
run_sql "$SCRIPT_DIR/06-resolution-modification-analytics.sql" \
  "Step 5/6: Creating conflict_resolution_analytics & views"

# Step 6: Create Google Sheets optimized views
run_sql "$SCRIPT_DIR/07-google-sheets-analytics.sql" \
  "Step 6/6: Creating Google Sheets analytics views"

# Calculate total duration
PIPELINE_END=$(date +%s)
TOTAL_DURATION=$((PIPELINE_END - PIPELINE_START))

log ""
log "${GREEN}============================================${NC}"
log "${GREEN}Pipeline completed successfully!${NC}"
log "${GREEN}Total duration: ${TOTAL_DURATION}s${NC}"
log "${GREEN}============================================${NC}"

# Show final status
if [[ "$DRY_RUN" == "false" ]]; then
  log ""
  log "Final table status:"
  bq query \
    --project_id="$PROJECT_ID" \
    --use_legacy_sql=false \
    "SELECT
      'monthly_conflict_snapshots' AS table_name,
      MAX(snapshot_release_date) AS latest_date,
      COUNT(DISTINCT snapshot_release_date) AS month_count
    FROM \`clinvar_ingest.monthly_conflict_snapshots\`
    UNION ALL
    SELECT 'conflict_resolution_analytics',
      MAX(snapshot_release_date),
      COUNT(DISTINCT snapshot_release_date)
    FROM \`clinvar_ingest.conflict_resolution_analytics\`
    ORDER BY table_name;"
fi
