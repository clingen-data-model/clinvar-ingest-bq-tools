-- ============================================================================
-- Script: 00-create-all-analytics.sql
--
-- Description:
--   Master orchestration script for the conflict resolution analytics pipeline.
--   This file documents the execution order and dependencies. The actual SQL
--   statements are maintained in the individual script files listed below.
--
-- IMPORTANT: Do not duplicate SQL here. The individual script files are the
-- source of truth for all table definitions and SQL statements.
--
-- Execution Order & Dependencies:
--   1. 01-get-monthly-conflicts.sql
--      Creates: monthly_conflict_snapshots
--      Depends on: clinvar_sum_vsp_rank_group, all_schemas() table function
--
--   2. 02-monthly-conflict-changes.sql
--      Creates: monthly_conflict_changes
--      Depends on: monthly_conflict_snapshots (from step 1)
--
--   3. 04-monthly-conflict-scv-snapshots.sql
--      Creates: monthly_conflict_scv_snapshots
--      Depends on: clinvar_sum_vsp_rank_group, clinvar_scvs, all_schemas() table function
--
--   4. 05-monthly-conflict-scv-changes.sql
--      Creates: monthly_conflict_scv_changes, monthly_conflict_vcv_scv_summary
--      Depends on: monthly_conflict_scv_snapshots (from step 3)
--
--   5. 06-resolution-modification-analytics.sql
--      Creates: conflict_resolution_analytics (table)
--               conflict_resolution_monthly_comparison (view)
--               conflict_resolution_reason_totals (view)
--               conflict_resolution_overall_trends (view)
--      Depends on: monthly_conflict_changes (from step 2)
--                  monthly_conflict_vcv_scv_summary (from step 4)
--                  monthly_conflict_snapshots (from step 1)
--
-- Excluded Scripts (Google Sheets query scripts - no tables created):
--   - 03-outlier-trends-long.sql (SELECT query for Data Connector)
--   - 03-outlier-trends-wide.sql (SELECT query for Data Connector)
--
-- Usage Options:
--   1. Manual: Run each script in order via BigQuery Console
--   2. Shell script: Use 00-run-all-analytics.sh (see below)
--   3. Scheduled: Set up scheduled query to call the shell script
--
-- Notes:
--   - Total runtime depends on data volume; expect several minutes for full rebuild
--   - Each script can be run independently if dependencies are already current
--   - Views in step 5 are automatically updated when underlying tables change
-- ============================================================================

-- ============================================================================
-- DIAGNOSTIC QUERY
-- Run this to check the current state of analytics tables
-- ============================================================================
SELECT
  'monthly_conflict_snapshots' AS table_name,
  MIN(snapshot_release_date) AS earliest_date,
  MAX(snapshot_release_date) AS latest_date,
  COUNT(DISTINCT snapshot_release_date) AS month_count
FROM `clinvar_ingest.monthly_conflict_snapshots`
UNION ALL
SELECT
  'monthly_conflict_changes',
  MIN(snapshot_release_date),
  MAX(snapshot_release_date),
  COUNT(DISTINCT snapshot_release_date)
FROM `clinvar_ingest.monthly_conflict_changes`
UNION ALL
SELECT
  'monthly_conflict_scv_snapshots',
  MIN(snapshot_release_date),
  MAX(snapshot_release_date),
  COUNT(DISTINCT snapshot_release_date)
FROM `clinvar_ingest.monthly_conflict_scv_snapshots`
UNION ALL
SELECT
  'monthly_conflict_scv_changes',
  MIN(snapshot_release_date),
  MAX(snapshot_release_date),
  COUNT(DISTINCT snapshot_release_date)
FROM `clinvar_ingest.monthly_conflict_scv_changes`
UNION ALL
SELECT
  'monthly_conflict_vcv_scv_summary',
  MIN(snapshot_release_date),
  MAX(snapshot_release_date),
  COUNT(DISTINCT snapshot_release_date)
FROM `clinvar_ingest.monthly_conflict_vcv_scv_summary`
UNION ALL
SELECT
  'conflict_resolution_analytics',
  MIN(snapshot_release_date),
  MAX(snapshot_release_date),
  COUNT(DISTINCT snapshot_release_date)
FROM `clinvar_ingest.conflict_resolution_analytics`
ORDER BY table_name;


-- ============================================================================
-- CHECK FOR NEW DATA
-- Run this to see if there are new monthly releases to process
-- ============================================================================
WITH latest_snapshot AS (
  SELECT MAX(snapshot_release_date) AS latest_snapshot_date
  FROM `clinvar_ingest.monthly_conflict_snapshots`
),
latest_release AS (
  SELECT MAX(release_date) AS latest_release_date
  FROM `clinvar_ingest.all_schemas`()
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
SELECT
  ls.latest_snapshot_date,
  lr.latest_release_date,
  nm.new_month_count,
  CASE
    WHEN nm.new_month_count > 0 THEN 'REBUILD NEEDED - New monthly data available'
    ELSE 'UP TO DATE - No new monthly data'
  END AS status
FROM latest_snapshot ls
CROSS JOIN latest_release lr
CROSS JOIN new_months nm;
