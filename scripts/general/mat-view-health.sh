#!/bin/bash
# =============================================================================
# mat-view-health.sh
#
# Wrapper for mat-view-health-report.sql: reports whether BigQuery materialized
# views (and derived tables rebuilt by procedures / scheduled queries) are
# behind their base tables.
#
# Default mode is READ-ONLY (report only). Refreshing happens only with the
# explicit --refresh flag, and then only for real materialized views, in
# dependency order, after a confirmation prompt (skip it with --yes).
#
# Usage:
#   scripts/general/mat-view-health.sh [options]
#
# Options:
#   --project ID       GCP project (default: clingen-dev)
#   --region REGION    BigQuery region qualifier (default: us -> `region-us`)
#   --grace MINUTES    Minutes past refresh_interval before a stale MV is
#                      STALE_OVERDUE (default: 30)
#   --datasets A,B     Datasets checked for stale derived tables
#                      (default: clinvar_ingest,clinvar_curator)
#   --lookback DAYS    JOBS history used for derived-table lineage (default: 180)
#   --mv-only          Skip the derived-table section
#   --format FMT       text (default, readable summary) | json | prettyjson
#                      (json formats are the raw result sets from bq)
#   --refresh          After the report, run CALL BQ.REFRESH_MATERIALIZED_VIEW
#                      for every MV the report says needs it
#   --yes              With --refresh, do not prompt for confirmation
#   -h, --help         Show this help
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/mat-view-health-report.sql"

PROJECT="clingen-dev"
REGION="us"
GRACE=""
DATASETS=""
LOOKBACK=""
MV_ONLY=false
FORMAT="text"
DO_REFRESH=false
ASSUME_YES=false

usage() { sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)  PROJECT="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --grace)    GRACE="$2"; shift 2 ;;
    --datasets) DATASETS="$2"; shift 2 ;;
    --lookback) LOOKBACK="$2"; shift 2 ;;
    --mv-only)  MV_ONLY=true; shift ;;
    --format)   FORMAT="$2"; shift 2 ;;
    --refresh)  DO_REFRESH=true; shift ;;
    --yes)      ASSUME_YES=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Build the SQL with any overrides applied to the DECLARE defaults.
build_sql() {
  local mv_only="$1"
  local sql
  sql="$(cat "$SQL_FILE")"
  sql="${sql//\`region-us\`/\`region-${REGION}\`}"
  if [[ -n "$GRACE" ]]; then
    sql="$(sed -E "s/^(DECLARE grace_minutes INT64 DEFAULT )[0-9]+;/\1${GRACE};/" <<<"$sql")"
  fi
  if [[ -n "$LOOKBACK" ]]; then
    sql="$(sed -E "s/^(DECLARE derived_lookback_days INT64 DEFAULT )[0-9]+;/\1${LOOKBACK};/" <<<"$sql")"
  fi
  if [[ -n "$DATASETS" ]]; then
    local arr
    arr="$(awk -v s="$DATASETS" 'BEGIN{n=split(s,a,",");for(i=1;i<=n;i++){printf "%s'\''%s'\''", (i>1?", ":""), a[i]}}')"
    sql="$(sed -E "s/^(DECLARE derived_datasets ARRAY<STRING> DEFAULT )\[.*\];/\1[${arr}];/" <<<"$sql")"
  fi
  if [[ "$mv_only" == true ]]; then
    sql="$(sed -E "s/^(DECLARE include_derived BOOL DEFAULT )TRUE;/\1FALSE;/" <<<"$sql")"
  fi
  printf '%s\n' "$sql"
}

run_report() {
  local mv_only="$1"
  build_sql "$mv_only" | bq query --quiet --nouse_legacy_sql --project_id="$PROJECT" \
    --format=json --max_rows=10000
}

# Python helper: `text` renders the readable report, `refresh` prints the
# refresh statements from result set 1 (already in dependency order).
read -r -d '' PY_HELPER <<'PYEOF' || true
import json, sys

mode = sys.argv[1]
data = json.load(sys.stdin)
if data and isinstance(data[0], dict):
    data = [data]
# Scripts also emit status strings ("Created ...", "Number of affected rows")
# for the temp-table statements; keep only the SELECT result sets.
data = [x for x in data if isinstance(x, list)]
mvs = data[0] if data else []
derived = data[1] if len(data) > 1 else None

if mode == "refresh":
    for r in mvs:
        sql = r.get("refresh_sql") or ""
        if sql.startswith("CALL "):
            print(sql)
    sys.exit(0)

def short(fqn):
    parts = (fqn or "").split(".")
    return ".".join(parts[1:]) if len(parts) == 3 else (fqn or "")

def v(x):
    return "-" if x in (None, "", "NULL") else str(x)

print()
print(f"MATERIALIZED VIEWS ({len(mvs)})")
print("=" * 78)
if not mvs:
    print("  No materialized views found in this project/region.")
for r in mvs:
    print(f"[{r['status']}] {r['materialized_view']}")
    auto = f"on, every {float(r['refresh_interval_minutes']):g} min" if r.get("auto_refresh") == "true" else "OFF"
    print(f"  last refresh      : {v(r.get('last_refresh_time'))}   (watermark {v(r.get('refresh_watermark'))})")
    print(f"  newest base change: {v(r.get('newest_base_change'))}")
    if r.get("stale_since"):
        print(f"  stale since       : {r['stale_since']}  ({r['minutes_stale']} min, {r['changed_base_count']} base table(s) changed)")
    print(f"  auto-refresh      : {auto}" + (f"; max_staleness {r['max_staleness']}" if r.get("max_staleness") else ""))
    print(f"  refresh jobs      : {v(r.get('refresh_jobs_in_window'))} in window, {v(r.get('failed_refresh_jobs_in_window'))} failed")
    if r.get("refresh_error"):
        print(f"  refresh error     : {r['refresh_error']}")
    if r.get("stale_upstream_mvs"):
        print(f"  waits on MV(s)    : {', '.join(r['stale_upstream_mvs'])}")
    print(f"  base tables ({v(r.get('lineage_source'))}; * = changed since last refresh, ! = missing):")
    for b in r.get("base_tables") or []:
        flag = "!" if b.get("base_missing") == "true" else ("*" if b.get("changed_since_refresh") == "true" else " ")
        print(f"    {flag} {v(b.get('base_last_modified')):19}  {b['base_table']}")
    if r.get("refresh_sql"):
        print(f"  fix               : {r['refresh_sql']}")
    print()

plan = [r for r in mvs if (r.get("refresh_sql") or "").startswith("CALL ")]
print("MV REFRESH PLAN (dependency order)")
print("-" * 78)
if plan:
    for r in plan:
        print(f"  {r['refresh_sql']}")
else:
    print("  Nothing to refresh - all materialized views are current.")

if derived is not None:
    print()
    print(f"STALE DERIVED TABLES ({len(derived)})  - rebuilt by procedures/scheduled queries, not BQ MVs")
    print("=" * 78)
    if not derived:
        print("  None - every derived table was written after its sources last changed.")
    for r in derived:
        print(f"[order {r['rebuild_order']}] {r['derived_table']}")
        print(f"  last built {r['last_built']}; newest source change {r['newest_source_change']} ({r['hours_behind']} h later)")
        srcs = ", ".join(f"{short(c['source_table'])} ({c['source_last_modified']})" for c in r.get("changed_sources") or [])
        print(f"  changed sources: {srcs}")
        print(f"  last built by  : {r['last_built_by']}")
        print()
    if derived:
        # One procedure usually rebuilds several tables: group by builder.
        plan = {}
        for r in derived:
            p = plan.setdefault(r["last_built_by"], {"order": int(r["rebuild_order"]), "tables": []})
            p["order"] = min(p["order"], int(r["rebuild_order"]))
            p["tables"].append(short(r["derived_table"]))
        print("DERIVED REBUILD PLAN (grouped by what last built them; lower order first)")
        print("-" * 78)
        for builder, p in sorted(plan.items(), key=lambda kv: (kv[1]["order"], kv[0])):
            print(f"  [order {p['order']}] {builder}")
            print(f"      -> {', '.join(sorted(p['tables']))}")
PYEOF

echo "# Materialized view health report: project=${PROJECT} region=${REGION} ($(date -u '+%Y-%m-%d %H:%M:%S UTC'))" >&2
REPORT_JSON="$(run_report "$MV_ONLY")"

case "$FORMAT" in
  text)       python3 -c "$PY_HELPER" text <<<"$REPORT_JSON" ;;
  json)       printf '%s\n' "$REPORT_JSON" ;;
  prettyjson) python3 -m json.tool <<<"$REPORT_JSON" ;;
  *) echo "Unknown --format: $FORMAT (use text, json or prettyjson)" >&2; exit 1 ;;
esac

if [[ "$DO_REFRESH" != true ]]; then
  exit 0
fi

# --- explicit refresh mode -------------------------------------------------
# Only real materialized views are refreshed; derived tables must be rebuilt
# with the procedure/script shown in the report.
REFRESH_SQL=()
while IFS= read -r line; do
  [[ -n "$line" ]] && REFRESH_SQL+=("$line")
done < <(python3 -c "$PY_HELPER" refresh <<<"$REPORT_JSON")

if [[ ${#REFRESH_SQL[@]} -eq 0 ]]; then
  echo "No materialized views need a refresh." >&2
  exit 0
fi

echo "" >&2
echo "About to run ${#REFRESH_SQL[@]} refresh statement(s), in dependency order:" >&2
printf '  %s\n' "${REFRESH_SQL[@]}" >&2

if [[ "$ASSUME_YES" != true ]]; then
  read -r -p "Run these refreshes now? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted; nothing refreshed." >&2; exit 0; }
fi

for stmt in "${REFRESH_SQL[@]}"; do
  echo "Running: $stmt" >&2
  bq query --quiet --nouse_legacy_sql --project_id="$PROJECT" "$stmt"
done
echo "Done. Re-run without --refresh to confirm everything reports OK." >&2
