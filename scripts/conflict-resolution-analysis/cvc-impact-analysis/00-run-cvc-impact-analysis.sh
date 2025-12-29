#!/bin/bash
# =============================================================================
# CVC Impact Analysis Pipeline Runner
# =============================================================================
#
# Usage:
#   ./00-run-cvc-impact-analysis.sh [OPTIONS]
#
# Options:
#   --dry-run     Show commands without executing
#   --force       Force rebuild even if no new data
#   --check-only  Check if rebuild is needed without running
#   --help        Show this help message
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="clingen-dev"
DRY_RUN=false
FORCE=false
CHECK_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --help)
            head -20 "$0" | grep -E "^#" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_query() {
    local sql_file="$1"
    local description="$2"

    if [ ! -f "$sql_file" ]; then
        log_error "SQL file not found: $sql_file"
        return 1
    fi

    log_info "Running: $description"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] bq query --use_legacy_sql=false --project_id=$PROJECT < $sql_file"
    else
        bq query \
            --use_legacy_sql=false \
            --project_id="$PROJECT" \
            < "$sql_file"

        if [ $? -eq 0 ]; then
            log_info "  Completed: $description"
        else
            log_error "  Failed: $description"
            return 1
        fi
    fi
}

check_rebuild_needed() {
    log_info "Checking if rebuild is needed..."

    # Check if cvc_submitted_variants table exists
    local table_exists=$(bq query --use_legacy_sql=false --format=csv --quiet \
        "SELECT COUNT(*) FROM \`$PROJECT.clinvar_curator.INFORMATION_SCHEMA.TABLES\`
         WHERE table_name = 'cvc_submitted_variants'" 2>/dev/null | tail -1)

    if [ "$table_exists" = "0" ]; then
        log_info "Table cvc_submitted_variants does not exist. Rebuild needed."
        return 0
    fi

    # Check if there are new batches since last run
    local new_batches=$(bq query --use_legacy_sql=false --format=csv --quiet "
        SELECT COUNT(*) as new_batches
        FROM \`$PROJECT.clinvar_curator.cvc_clinvar_batches\` b
        WHERE NOT EXISTS (
            SELECT 1 FROM \`$PROJECT.clinvar_curator.cvc_submitted_variants\` sv
            WHERE sv.batch_id = b.batch_id
        )
    " 2>/dev/null | tail -1)

    if [ "$new_batches" != "0" ] && [ -n "$new_batches" ]; then
        log_info "Found $new_batches new batches. Rebuild needed."
        return 0
    fi

    # Check if there's new conflict resolution data
    local new_data=$(bq query --use_legacy_sql=false --format=csv --quiet "
        SELECT COUNT(*) as new_months
        FROM \`$PROJECT.clinvar_ingest.monthly_conflict_snapshots\` mcs
        WHERE mcs.snapshot_release_date >= '2023-09-01'
          AND NOT EXISTS (
            SELECT 1 FROM \`$PROJECT.clinvar_curator.cvc_impact_summary\` cis
            WHERE cis.snapshot_release_date = mcs.snapshot_release_date
          )
    " 2>/dev/null | tail -1)

    if [ "$new_data" != "0" ] && [ -n "$new_data" ]; then
        log_info "Found $new_data new monthly snapshots. Rebuild needed."
        return 0
    fi

    log_info "No new data detected. Rebuild not needed."
    return 1
}

main() {
    log_info "CVC Impact Analysis Pipeline"
    log_info "Project: $PROJECT"
    log_info "Script directory: $SCRIPT_DIR"
    echo ""

    # Check if rebuild is needed
    if [ "$CHECK_ONLY" = true ]; then
        if check_rebuild_needed; then
            exit 0
        else
            exit 1
        fi
    fi

    if [ "$FORCE" = false ]; then
        if ! check_rebuild_needed; then
            log_info "Use --force to rebuild anyway."
            exit 0
        fi
    else
        log_warn "Force rebuild requested."
    fi

    echo ""
    log_info "Starting pipeline execution..."
    echo ""

    # Step 1: Create CVC submitted variants table
    run_query "$SCRIPT_DIR/01-cvc-submitted-variants.sql" \
        "Step 1: Building CVC submitted variants table"
    echo ""

    # Step 2: Create conflict attribution tables
    run_query "$SCRIPT_DIR/02-cvc-conflict-attribution.sql" \
        "Step 2: Building conflict attribution tables"
    echo ""

    # Step 3: Create impact analytics and views
    run_query "$SCRIPT_DIR/03-cvc-impact-analytics.sql" \
        "Step 3: Building impact analytics and views"
    echo ""

    log_info "Pipeline completed successfully!"
    echo ""

    # Show summary statistics
    if [ "$DRY_RUN" = false ]; then
        log_info "Summary Statistics:"
        bq query --use_legacy_sql=false --format=pretty "
            SELECT
                (SELECT COUNT(*) FROM \`$PROJECT.clinvar_curator.cvc_submitted_variants\`) AS total_cvc_submissions,
                (SELECT COUNT(DISTINCT variation_id) FROM \`$PROJECT.clinvar_curator.cvc_submitted_variants\`) AS unique_variants,
                (SELECT COUNT(*) FROM \`$PROJECT.clinvar_curator.cvc_resolution_attribution\`) AS total_resolutions_analyzed,
                (SELECT COUNT(*) FROM \`$PROJECT.clinvar_curator.cvc_resolution_attribution\` WHERE variant_attribution = 'cvc_attributed') AS cvc_attributed_resolutions
        "
    fi
}

main
