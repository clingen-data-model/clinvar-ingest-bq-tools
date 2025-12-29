"""
Cloud Function to trigger the Conflict Resolution Analytics pipeline.

This function executes the SQL scripts from 07-google-sheets-analytics.sql
and related files to update the BigQuery views used by Google Sheets dashboards.

Deployment:
    gcloud functions deploy conflict-analytics-trigger \
        --runtime python311 \
        --trigger-http \
        --allow-unauthenticated \
        --entry-point run_analytics_pipeline \
        --timeout 540s \
        --memory 512MB \
        --region us-central1 \
        --project clingen-dev

For authenticated access (recommended for production):
    Remove --allow-unauthenticated and configure IAM:
    gcloud functions add-iam-policy-binding conflict-analytics-trigger \
        --member="serviceAccount:YOUR_SERVICE_ACCOUNT" \
        --role="roles/cloudfunctions.invoker"
"""

import functions_framework
from google.cloud import bigquery
from flask import jsonify
import traceback
from datetime import datetime

# SQL files in execution order (relative paths from this module)
SQL_SCRIPTS = [
    ("01-get-monthly-conflicts.sql", "Creating monthly_conflict_snapshots"),
    ("02-monthly-conflict-changes.sql", "Creating monthly_conflict_changes"),
    ("04-monthly-conflict-scv-snapshots.sql", "Creating monthly_conflict_scv_snapshots"),
    ("05-monthly-conflict-scv-changes.sql", "Creating monthly_conflict_scv_changes"),
    ("06-resolution-modification-analytics.sql", "Creating conflict_resolution_analytics"),
    ("07-google-sheets-analytics.sql", "Creating Google Sheets views"),
]

# Default project
DEFAULT_PROJECT = "clingen-dev"


def check_new_data(client: bigquery.Client) -> int:
    """Check if there are new monthly releases to process."""
    query = """
    WITH latest_snapshot AS (
      SELECT MAX(snapshot_release_date) AS latest_snapshot_date
      FROM `clinvar_ingest.monthly_conflict_snapshots`
    ),
    new_months AS (
      SELECT COUNT(DISTINCT DATE_TRUNC(release_date, MONTH)) AS new_month_count
      FROM `clinvar_ingest.all_schemas`()
      WHERE release_date >= DATE'2023-01-01'
        AND DATE_TRUNC(release_date, MONTH) > (
          SELECT COALESCE(DATE_TRUNC(latest_snapshot_date, MONTH), DATE'2022-12-01')
          FROM latest_snapshot
        )
    )
    SELECT new_month_count FROM new_months
    """
    result = client.query(query).result()
    for row in result:
        return row.new_month_count
    return 0


def run_sql_script(client: bigquery.Client, sql_content: str, description: str) -> dict:
    """Execute a SQL script and return timing info."""
    start_time = datetime.now()

    # Split by semicolons to handle multiple statements, but be careful with
    # statements that contain semicolons in strings
    # For CREATE OR REPLACE VIEW statements, we run the whole file as one query
    job = client.query(sql_content)
    job.result()  # Wait for completion

    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()

    return {
        "description": description,
        "duration_seconds": duration,
        "status": "success"
    }


@functions_framework.http
def run_analytics_pipeline(request):
    """
    HTTP Cloud Function to run the conflict resolution analytics pipeline.

    Query Parameters:
        force (bool): Force rebuild even if no new data (default: false)
        skip_check (bool): Skip the new data check (default: false)
        check_only (bool): Only check if rebuild is needed (default: false)
        project (str): GCP project ID (default: clingen-dev)
        views_only (bool): Only run the views script (07-google-sheets-analytics.sql)

    Returns:
        JSON response with execution status and timing
    """
    try:
        # Parse parameters
        force = request.args.get("force", "false").lower() == "true"
        skip_check = request.args.get("skip_check", "false").lower() == "true"
        check_only = request.args.get("check_only", "false").lower() == "true"
        views_only = request.args.get("views_only", "false").lower() == "true"
        project_id = request.args.get("project", DEFAULT_PROJECT)

        # Initialize BigQuery client
        client = bigquery.Client(project=project_id)

        results = {
            "project": project_id,
            "started_at": datetime.now().isoformat(),
            "steps": [],
            "status": "success"
        }

        # Check for new data unless skipped or forced
        if not skip_check and not force and not views_only:
            new_months = check_new_data(client)
            results["new_months_found"] = new_months

            if new_months == 0:
                results["status"] = "skipped"
                results["message"] = "No new monthly releases to process"
                if check_only:
                    results["rebuild_needed"] = False
                return jsonify(results)
            else:
                if check_only:
                    results["rebuild_needed"] = True
                    results["message"] = f"Found {new_months} new month(s) to process"
                    return jsonify(results)

        if check_only:
            return jsonify(results)

        # Determine which scripts to run
        if views_only:
            scripts_to_run = [
                ("07-google-sheets-analytics.sql", "Creating Google Sheets views")
            ]
        else:
            scripts_to_run = SQL_SCRIPTS

        # Read and execute SQL scripts
        # Note: In Cloud Functions, we embed the SQL or fetch from GCS
        # For this implementation, we'll use inline SQL for the views
        for script_name, description in scripts_to_run:
            try:
                # Get SQL content (embedded or from GCS)
                sql_content = get_sql_content(script_name)
                step_result = run_sql_script(client, sql_content, description)
                results["steps"].append(step_result)
            except Exception as e:
                results["steps"].append({
                    "description": description,
                    "status": "error",
                    "error": str(e)
                })
                results["status"] = "partial_failure"

        results["completed_at"] = datetime.now().isoformat()

        # Calculate total duration
        if results["steps"]:
            total_duration = sum(
                s.get("duration_seconds", 0)
                for s in results["steps"]
                if s.get("status") == "success"
            )
            results["total_duration_seconds"] = total_duration

        return jsonify(results)

    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e),
            "traceback": traceback.format_exc()
        }), 500


def get_sql_content(script_name: str) -> str:
    """
    Get SQL content for a script.

    In production, this would fetch from GCS or have embedded SQL.
    For now, we'll embed the critical views SQL directly.
    """
    # For the Cloud Function, we embed the SQL directly
    # This avoids needing to deploy SQL files separately

    if script_name == "07-google-sheets-analytics.sql":
        return get_google_sheets_views_sql()

    # For other scripts, raise an error - they should be run via
    # the shell script or have their SQL embedded here
    raise ValueError(
        f"SQL script {script_name} not embedded. "
        "Use views_only=true or run full pipeline via shell script."
    )


def get_google_sheets_views_sql() -> str:
    """Return the Google Sheets analytics views SQL."""
    # This is the critical SQL that creates the views used by Google Sheets
    # It's embedded here so we can quickly refresh views without running
    # the full pipeline
    return """
-- ============================================================================
-- Google Sheets Analytics Views
-- ============================================================================
-- These views are optimized for Google Sheets Connected Sheets functionality.
-- They provide pre-aggregated data in formats suitable for charts and slicers.
--
-- Run this after 06-resolution-modification-analytics.sql
-- ============================================================================

-- View 1: Monthly conflict summary with net change
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_conflict_summary` AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  conflict_count,
  prev_month_conflict_count,
  (conflict_count - COALESCE(prev_month_conflict_count, 0)) AS net_change,
  CASE
    WHEN conflict_count > COALESCE(prev_month_conflict_count, 0)
    THEN conflict_count - prev_month_conflict_count
    ELSE NULL
  END AS net_increase,
  CASE
    WHEN conflict_count < COALESCE(prev_month_conflict_count, 0)
    THEN conflict_count - prev_month_conflict_count
    ELSE NULL
  END AS net_decrease,
  total_path_variants,
  SAFE_DIVIDE(conflict_count, total_path_variants) * 100 AS pct_of_path_variants,
  variants_with_conflict_potential,
  SAFE_DIVIDE(conflict_count, variants_with_conflict_potential) * 100 AS pct_of_conflict_potential
FROM `clinvar_ingest.conflict_resolution_analytics`
ORDER BY snapshot_release_date, conflict_type, outlier_status;


-- View 2: Change status breakdown (long format for pivot tables)
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_conflict_changes` AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  change_status,
  variant_count,
  prev_month_total_conflicts,
  SAFE_DIVIDE(variant_count, prev_month_total_conflicts) * 100 AS pct_of_prev_conflicts
FROM `clinvar_ingest.conflict_resolution_analytics`
CROSS JOIN UNNEST([
  STRUCT('new' AS change_status, new_conflicts AS variant_count),
  STRUCT('resolved', resolved_conflicts),
  STRUCT('modified', modified_conflicts),
  STRUCT('unchanged', unchanged_conflicts)
]) AS changes
WHERE variant_count > 0
ORDER BY snapshot_release_date, conflict_type, outlier_status, change_status;


-- View 3: Primary reason breakdown (long format)
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_change_reasons` AS
SELECT
  d.snapshot_release_date,
  FORMAT_DATE('%Y-%m', d.snapshot_release_date) AS snapshot_month,
  d.conflict_type,
  d.outlier_status,
  d.vcv_change_status AS change_status,
  d.primary_reason,
  COUNT(*) AS variant_count
FROM `clinvar_ingest.conflict_vcv_change_detail` d
WHERE d.vcv_change_status IN ('resolved', 'modified')
GROUP BY
  d.snapshot_release_date,
  d.conflict_type,
  d.outlier_status,
  d.vcv_change_status,
  d.primary_reason
ORDER BY snapshot_release_date, conflict_type, outlier_status, change_status, variant_count DESC;


-- View 4: Multi-reason detail (for deep-dive analysis)
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_multi_reason_detail` AS
SELECT
  d.snapshot_release_date,
  FORMAT_DATE('%Y-%m', d.snapshot_release_date) AS snapshot_month,
  d.conflict_type,
  d.outlier_status,
  d.vcv_change_status AS change_status,
  d.primary_reason,
  d.change_category,
  ARRAY_LENGTH(d.scv_reasons) AS reason_count,
  ARRAY_TO_STRING(d.scv_reasons, ', ') AS all_reasons,
  COUNT(*) AS variant_count
FROM `clinvar_ingest.conflict_vcv_change_detail` d
WHERE ARRAY_LENGTH(d.scv_reasons) >= 2
GROUP BY
  d.snapshot_release_date,
  d.conflict_type,
  d.outlier_status,
  d.vcv_change_status,
  d.primary_reason,
  d.change_category,
  d.scv_reasons
ORDER BY snapshot_release_date, variant_count DESC;


-- View 5: Monthly overview (single row per month, pre-aggregated)
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_monthly_overview` AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  SUM(conflict_count) AS total_conflicts,
  SUM(new_conflicts) AS total_new,
  SUM(resolved_conflicts) AS total_resolved,
  SUM(modified_conflicts) AS total_modified,
  SUM(unchanged_conflicts) AS total_unchanged,
  SUM(conflict_count) - SUM(COALESCE(prev_month_conflict_count, 0)) AS total_net_change,
  SUM(total_path_variants) AS total_path_variants,
  SAFE_DIVIDE(SUM(conflict_count), SUM(total_path_variants)) * 100 AS overall_pct
FROM `clinvar_ingest.conflict_resolution_analytics`
GROUP BY snapshot_release_date
ORDER BY snapshot_release_date;


-- View 6: Change status wide format (for stacked bar charts)
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_change_status_wide` AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  new_conflicts,
  resolved_conflicts,
  modified_conflicts,
  unchanged_conflicts,
  conflict_count AS total_conflicts
FROM `clinvar_ingest.conflict_resolution_analytics`
ORDER BY snapshot_release_date, conflict_type, outlier_status;


-- View 7: Change reasons wide format (for stacked bar charts)
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_change_reasons_wide` AS
WITH reason_counts AS (
  SELECT
    d.snapshot_release_date,
    d.conflict_type,
    d.outlier_status,
    d.vcv_change_status AS change_status,
    d.primary_reason,
    COUNT(*) AS cnt
  FROM `clinvar_ingest.conflict_vcv_change_detail` d
  WHERE d.vcv_change_status IN ('resolved', 'modified')
  GROUP BY 1, 2, 3, 4, 5
)
SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  change_status,
  SUM(CASE WHEN primary_reason = 'scv_flagged' THEN cnt ELSE 0 END) AS scv_flagged,
  SUM(CASE WHEN primary_reason = 'scv_removed' THEN cnt ELSE 0 END) AS scv_removed,
  SUM(CASE WHEN primary_reason = 'scv_reclassified' THEN cnt ELSE 0 END) AS scv_reclassified,
  SUM(CASE WHEN primary_reason = 'scv_added' THEN cnt ELSE 0 END) AS scv_added,
  SUM(CASE WHEN primary_reason = 'scv_rank_downgraded' THEN cnt ELSE 0 END) AS scv_rank_downgraded,
  SUM(CASE WHEN primary_reason = 'expert_panel_added' THEN cnt ELSE 0 END) AS expert_panel_added,
  SUM(CASE WHEN primary_reason = 'higher_rank_scv_added' THEN cnt ELSE 0 END) AS higher_rank_scv_added,
  SUM(CASE WHEN primary_reason = 'vcv_rank_changed' THEN cnt ELSE 0 END) AS vcv_rank_changed,
  SUM(CASE WHEN primary_reason = 'outlier_status_changed' THEN cnt ELSE 0 END) AS outlier_status_changed,
  SUM(CASE WHEN primary_reason = 'conflict_type_changed' THEN cnt ELSE 0 END) AS conflict_type_changed,
  SUM(CASE WHEN primary_reason = 'single_submitter_withdrawn' THEN cnt ELSE 0 END) AS single_submitter_withdrawn,
  SUM(CASE WHEN primary_reason = 'outlier_reclassified' THEN cnt ELSE 0 END) AS outlier_reclassified,
  SUM(CASE WHEN primary_reason = 'unknown' THEN cnt ELSE 0 END) AS unknown,
  SUM(cnt) AS total_changes
FROM reason_counts
GROUP BY snapshot_release_date, conflict_type, outlier_status, change_status
ORDER BY snapshot_release_date, conflict_type, outlier_status, change_status;


-- ============================================================================
-- View 8: SCV Reasons Over Time
-- ============================================================================
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_reason_combinations` AS

WITH reason_combos AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    vcv_change_status AS change_status,
    primary_reason,
    scv_reasons,
    (SELECT COUNT(*) FROM UNNEST(scv_reasons) r
     WHERE r IN ('scv_reclassified', 'scv_flagged', 'scv_removed', 'scv_added', 'scv_rank_downgraded')
    ) AS scv_reason_count,
    CASE
      WHEN primary_reason = 'expert_panel_added' THEN 'expert_panel'
      WHEN primary_reason = 'higher_rank_scv_added' THEN 'higher_rank'
      WHEN primary_reason = 'scv_reclassified' THEN 'reclassified'
      WHEN primary_reason = 'scv_flagged' THEN 'flagged'
      WHEN primary_reason = 'scv_removed' THEN 'removed'
      WHEN primary_reason = 'scv_added' THEN 'added'
      WHEN primary_reason = 'scv_rank_downgraded' THEN 'rank_downgraded'
      WHEN primary_reason IN ('single_submitter_withdrawn', 'vcv_rank_changed',
                              'outlier_status_changed', 'conflict_type_changed',
                              'outlier_reclassified', 'unknown') THEN
        CASE
          WHEN 'scv_flagged' IN UNNEST(scv_reasons) THEN 'flagged'
          WHEN 'scv_removed' IN UNNEST(scv_reasons) THEN 'removed'
          WHEN 'scv_reclassified' IN UNNEST(scv_reasons) THEN 'reclassified'
          WHEN 'scv_rank_downgraded' IN UNNEST(scv_reasons) THEN 'rank_downgraded'
          WHEN 'scv_added' IN UNNEST(scv_reasons) THEN 'added'
          ELSE 'unknown'
        END
      ELSE 'unknown'
    END AS scv_reason
  FROM `clinvar_ingest.conflict_vcv_change_detail`
  WHERE scv_reasons IS NOT NULL
    AND ARRAY_LENGTH(scv_reasons) > 0
    AND primary_reason NOT IN ('new_conflict', 'no_change')
)

SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  change_status,
  scv_reason,
  COUNTIF(scv_reason_count = 1) AS single_reason_count,
  COUNTIF(scv_reason_count > 1) AS multi_reason_count,
  COUNT(*) AS total_variant_count
FROM reason_combos
GROUP BY
  snapshot_release_date,
  conflict_type,
  outlier_status,
  change_status,
  scv_reason
ORDER BY snapshot_release_date, conflict_type, outlier_status, change_status, total_variant_count DESC;


-- ============================================================================
-- View 9: SCV Reasons Wide Format
-- ============================================================================
CREATE OR REPLACE VIEW `clinvar_ingest.sheets_reason_combinations_wide` AS

WITH reason_combos AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    vcv_change_status AS change_status,
    primary_reason,
    scv_reasons,
    (SELECT COUNT(*) FROM UNNEST(scv_reasons) r
     WHERE r IN ('scv_reclassified', 'scv_flagged', 'scv_removed', 'scv_added', 'scv_rank_downgraded')
    ) AS scv_reason_count,
    CASE
      WHEN primary_reason = 'expert_panel_added' THEN 'expert_panel'
      WHEN primary_reason = 'higher_rank_scv_added' THEN 'higher_rank'
      WHEN primary_reason = 'scv_reclassified' THEN 'reclassified'
      WHEN primary_reason = 'scv_flagged' THEN 'flagged'
      WHEN primary_reason = 'scv_removed' THEN 'removed'
      WHEN primary_reason = 'scv_added' THEN 'added'
      WHEN primary_reason = 'scv_rank_downgraded' THEN 'rank_downgraded'
      WHEN primary_reason IN ('single_submitter_withdrawn', 'vcv_rank_changed',
                              'outlier_status_changed', 'conflict_type_changed',
                              'outlier_reclassified', 'unknown') THEN
        CASE
          WHEN 'scv_flagged' IN UNNEST(scv_reasons) THEN 'flagged'
          WHEN 'scv_removed' IN UNNEST(scv_reasons) THEN 'removed'
          WHEN 'scv_reclassified' IN UNNEST(scv_reasons) THEN 'reclassified'
          WHEN 'scv_rank_downgraded' IN UNNEST(scv_reasons) THEN 'rank_downgraded'
          WHEN 'scv_added' IN UNNEST(scv_reasons) THEN 'added'
          ELSE 'unknown'
        END
      ELSE 'unknown'
    END AS scv_reason
  FROM `clinvar_ingest.conflict_vcv_change_detail`
  WHERE scv_reasons IS NOT NULL
    AND ARRAY_LENGTH(scv_reasons) > 0
    AND primary_reason NOT IN ('new_conflict', 'no_change')
),

month_mapping AS (
  SELECT DISTINCT
    snapshot_release_date,
    FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month
  FROM reason_combos
)

SELECT
  m.snapshot_release_date,
  m.snapshot_month,
  r.conflict_type,
  r.outlier_status,
  r.change_status,
  COUNTIF(r.scv_reason = 'reclassified' AND r.scv_reason_count = 1) AS reclassified_single,
  COUNTIF(r.scv_reason = 'reclassified' AND r.scv_reason_count > 1) AS reclassified_multi,
  COUNTIF(r.scv_reason = 'flagged' AND r.scv_reason_count = 1) AS flagged_single,
  COUNTIF(r.scv_reason = 'flagged' AND r.scv_reason_count > 1) AS flagged_multi,
  COUNTIF(r.scv_reason = 'removed' AND r.scv_reason_count = 1) AS removed_single,
  COUNTIF(r.scv_reason = 'removed' AND r.scv_reason_count > 1) AS removed_multi,
  COUNTIF(r.scv_reason = 'added' AND r.scv_reason_count = 1) AS added_single,
  COUNTIF(r.scv_reason = 'added' AND r.scv_reason_count > 1) AS added_multi,
  COUNTIF(r.scv_reason = 'rank_downgraded' AND r.scv_reason_count = 1) AS rank_downgraded_single,
  COUNTIF(r.scv_reason = 'rank_downgraded' AND r.scv_reason_count > 1) AS rank_downgraded_multi,
  COUNTIF(r.scv_reason = 'expert_panel' AND r.scv_reason_count = 1) AS expert_panel_single,
  COUNTIF(r.scv_reason = 'expert_panel' AND r.scv_reason_count > 1) AS expert_panel_multi,
  COUNTIF(r.scv_reason = 'higher_rank' AND r.scv_reason_count = 1) AS higher_rank_single,
  COUNTIF(r.scv_reason = 'higher_rank' AND r.scv_reason_count > 1) AS higher_rank_multi,
  COUNTIF(r.scv_reason = 'unknown' AND r.scv_reason_count = 1) AS unknown_single,
  COUNTIF(r.scv_reason = 'unknown' AND r.scv_reason_count > 1) AS unknown_multi,
  COUNTIF(r.scv_reason_count = 1) AS single_reason_total,
  COUNTIF(r.scv_reason_count > 1) AS multi_reason_total,
  COUNT(*) AS total_variants
FROM month_mapping m
JOIN reason_combos r ON m.snapshot_release_date = r.snapshot_release_date
GROUP BY
  m.snapshot_release_date,
  m.snapshot_month,
  r.conflict_type,
  r.outlier_status,
  r.change_status
ORDER BY m.snapshot_release_date, r.conflict_type, r.outlier_status, r.change_status;
"""
