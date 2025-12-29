-- ============================================================================
-- Script: 07-google-sheets-analytics.sql
--
-- GCS SYNC REMINDER:
--   This file is loaded by the Cloud Function from GCS. After making changes,
--   sync to GCS:  gsutil cp scripts/conflict-resolution-analysis/0*.sql \
--                           gs://clinvar-ingest/conflict-analytics-sql/
--
-- Description:
--   Creates optimized views for Google Sheets visualization with slicers.
--   Designed for charts that aggregate data dynamically based on user-selected
--   filters (conflict_type, outlier_status, snapshot_release_date range).
--
-- Output Views:
--   1. clinvar_ingest.sheets_conflict_summary
--      - Monthly totals and percentages for conflict trending
--      - One row per month per conflict_type per outlier_status
--      - Includes net change calculations
--
--   2. clinvar_ingest.sheets_conflict_changes
--      - Change status breakdown (new, resolved, modified, unchanged)
--      - One row per month per conflict_type per outlier_status per change_status
--      - For tracking resolution/new conflict rates
--
--   3. clinvar_ingest.sheets_change_reasons
--      - Primary reason breakdown for resolutions and modifications
--      - One row per month per conflict_type per outlier_status per reason
--      - For understanding WHY conflicts change
--
--   4. clinvar_ingest.sheets_multi_reason_detail
--      - Full reason array breakdown for complex changes
--      - Shows all reasons contributing to each change (not just primary)
--      - For deeper analysis of multi-factor changes
--
-- Slicer Dimensions (available in all views):
--   - snapshot_release_date: Filter by month/date range
--   - conflict_type: 'Clinsig' or 'Non-Clinsig'
--   - outlier_status: 'With Outlier' or 'No Outlier'
--
-- Key Metrics:
--   - conflict_count: Number of conflicts
--   - total_path_variants: Denominator for percentage calculations
--   - pct_of_path_variants: Conflicts as % of total pathogenicity variants
--   - net_change: New conflicts minus resolved conflicts
--   - variant_count: Count of variants in each category
--
-- Usage:
--   Connect Google Sheets to BigQuery via Data Connector.
--   Query the appropriate view and add slicers for the dimension columns.
--   Charts will aggregate based on selected slicer values.
-- ============================================================================


-- ============================================================================
-- View 1: Monthly Conflict Summary with Net Change
-- ============================================================================
-- This view provides the core trending data:
--   - Total conflicts per month (sliceable by type/outlier)
--   - Percentage of total path variants
--   - Net change from previous month
--
-- Use for:
--   - Line charts showing conflict count over time
--   - Stacked area charts by conflict_type or outlier_status
--   - KPI cards showing current conflict rate and trend

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_conflict_summary` AS

WITH monthly_totals AS (
  SELECT
    snapshot_release_date,
    CASE WHEN clinsig_conflict THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
    CASE WHEN has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
    COUNT(*) AS conflict_count,
    ANY_VALUE(total_path_variants) AS total_path_variants,
    ANY_VALUE(variants_with_conflict_potential) AS variants_with_conflict_potential
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date, clinsig_conflict, has_outlier
),

-- Get new and resolved counts per slice
change_counts AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    COUNTIF(change_status = 'new') AS new_conflicts,
    COUNTIF(change_status = 'resolved') AS resolved_conflicts,
    COUNTIF(change_status = 'modified') AS modified_conflicts,
    COUNTIF(change_status = 'unchanged') AS unchanged_conflicts
  FROM (
    SELECT
      snapshot_release_date,
      change_status,
      CASE WHEN COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
      CASE WHEN COALESCE(curr_has_outlier, prev_has_outlier) THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status
    FROM `clinvar_ingest.monthly_conflict_changes`
  )
  GROUP BY snapshot_release_date, conflict_type, outlier_status
)

SELECT
  t.snapshot_release_date,
  FORMAT_DATE('%Y-%m', t.snapshot_release_date) AS snapshot_month,
  t.conflict_type,
  t.outlier_status,
  t.conflict_count,
  t.total_path_variants,
  t.variants_with_conflict_potential,
  -- Percentage calculations
  ROUND(100.0 * t.conflict_count / NULLIF(t.total_path_variants, 0), 4) AS pct_of_path_variants,
  ROUND(100.0 * t.conflict_count / NULLIF(t.variants_with_conflict_potential, 0), 2) AS pct_of_conflict_potential,
  -- Change counts
  COALESCE(c.new_conflicts, 0) AS new_conflicts,
  COALESCE(c.resolved_conflicts, 0) AS resolved_conflicts,
  COALESCE(c.modified_conflicts, 0) AS modified_conflicts,
  COALESCE(c.unchanged_conflicts, 0) AS unchanged_conflicts,
  -- Net change (new minus resolved)
  COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0) AS net_change,
  -- Split net change for conditional bar coloring (one will be NULL per row)
  CASE WHEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0) > 0
       THEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0)
  END AS net_increase,
  CASE WHEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0) < 0
       THEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0)
  END AS net_decrease,
  -- Previous month comparison (via LAG)
  LAG(t.conflict_count) OVER (
    PARTITION BY t.conflict_type, t.outlier_status
    ORDER BY t.snapshot_release_date
  ) AS prev_month_conflict_count,
  -- Month-over-month change
  t.conflict_count - COALESCE(
    LAG(t.conflict_count) OVER (
      PARTITION BY t.conflict_type, t.outlier_status
      ORDER BY t.snapshot_release_date
    ), 0
  ) AS mom_change
FROM monthly_totals t
LEFT JOIN change_counts c
  ON c.snapshot_release_date = t.snapshot_release_date
  AND c.conflict_type = t.conflict_type
  AND c.outlier_status = t.outlier_status
ORDER BY t.snapshot_release_date, t.conflict_type, t.outlier_status;


-- ============================================================================
-- View 2: Change Status Breakdown
-- ============================================================================
-- This view shows the breakdown by change status:
--   - new: Conflicts that appeared this month
--   - resolved: Conflicts that disappeared this month
--   - modified: Conflicts that changed but still exist
--   - unchanged: Conflicts with no changes
--
-- Use for:
--   - Stacked bar charts showing change composition
--   - Pie charts of change distribution
--   - Resolution rate tracking

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_conflict_changes` AS

WITH change_data AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    conflict_type,
    outlier_status,
    change_status,
    COUNT(*) AS variant_count
  FROM (
    SELECT
      snapshot_release_date,
      prev_snapshot_release_date,
      change_status,
      CASE WHEN COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
      CASE WHEN COALESCE(curr_has_outlier, prev_has_outlier) THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status
    FROM `clinvar_ingest.monthly_conflict_changes`
  )
  GROUP BY
    snapshot_release_date,
    prev_snapshot_release_date,
    conflict_type,
    outlier_status,
    change_status
),

-- Get baseline totals from previous month for percentage calculations
baseline AS (
  SELECT
    snapshot_release_date,
    CASE WHEN clinsig_conflict THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
    CASE WHEN has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
    COUNT(*) AS total_conflicts,
    ANY_VALUE(total_path_variants) AS total_path_variants
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date, clinsig_conflict, has_outlier
)

SELECT
  c.snapshot_release_date,
  FORMAT_DATE('%Y-%m', c.snapshot_release_date) AS snapshot_month,
  c.prev_snapshot_release_date,
  c.conflict_type,
  c.outlier_status,
  c.change_status,
  c.variant_count,
  -- Baseline from previous month (for resolved/modified/unchanged)
  b.total_conflicts AS prev_month_total_conflicts,
  b.total_path_variants AS prev_month_total_path_variants,
  -- Percentage of previous month's conflicts
  ROUND(100.0 * c.variant_count / NULLIF(b.total_conflicts, 0), 2) AS pct_of_prev_conflicts,
  -- Percentage of path variants
  ROUND(100.0 * c.variant_count / NULLIF(b.total_path_variants, 0), 4) AS pct_of_path_variants
FROM change_data c
LEFT JOIN baseline b
  ON b.snapshot_release_date = c.prev_snapshot_release_date
  AND b.conflict_type = c.conflict_type
  AND b.outlier_status = c.outlier_status
ORDER BY c.snapshot_release_date, c.conflict_type, c.outlier_status, c.change_status;


-- ============================================================================
-- View 3: Primary Reason Breakdown
-- ============================================================================
-- This view shows the primary reason for each change:
--   Resolution reasons: scv_flagged, scv_removed, scv_reclassified,
--                       expert_panel_added, single_submitter_withdrawn, consensus_reached
--   Modification reasons: scv_added, scv_removed, scv_flagged, scv_reclassified,
--                         vcv_rank_changed, outlier_status_changed, conflict_type_changed
--
-- Use for:
--   - Bar charts comparing reason frequencies
--   - Trend lines for specific reasons over time
--   - Understanding the primary drivers of resolution

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_change_reasons` AS

WITH reason_counts AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    vcv_change_status AS change_status,
    primary_reason,
    COUNT(*) AS variant_count
  FROM `clinvar_ingest.conflict_vcv_change_detail`
  WHERE vcv_change_status IN ('resolved', 'modified')
  GROUP BY snapshot_release_date, conflict_type, outlier_status, vcv_change_status, primary_reason
),

-- Get baseline from previous month
baseline AS (
  SELECT
    snapshot_release_date,
    CASE WHEN clinsig_conflict THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
    CASE WHEN has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
    COUNT(*) AS total_conflicts,
    ANY_VALUE(total_path_variants) AS total_path_variants
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date, clinsig_conflict, has_outlier
),

-- Map current month to previous month for baseline lookup
month_mapping AS (
  SELECT
    snapshot_release_date,
    LAG(snapshot_release_date) OVER (ORDER BY snapshot_release_date) AS prev_snapshot_release_date
  FROM (
    SELECT DISTINCT snapshot_release_date
    FROM `clinvar_ingest.monthly_conflict_snapshots`
  )
)

SELECT
  r.snapshot_release_date,
  FORMAT_DATE('%Y-%m', r.snapshot_release_date) AS snapshot_month,
  m.prev_snapshot_release_date,
  r.conflict_type,
  r.outlier_status,
  r.change_status,
  r.primary_reason,
  r.variant_count,
  -- Baseline from previous month
  b.total_conflicts AS prev_month_total_conflicts,
  b.total_path_variants AS prev_month_total_path_variants,
  -- Percentage of previous month's conflicts
  ROUND(100.0 * r.variant_count / NULLIF(b.total_conflicts, 0), 2) AS pct_of_prev_conflicts,
  -- Percentage of path variants
  ROUND(100.0 * r.variant_count / NULLIF(b.total_path_variants, 0), 4) AS pct_of_path_variants
FROM reason_counts r
LEFT JOIN month_mapping m ON m.snapshot_release_date = r.snapshot_release_date
LEFT JOIN baseline b
  ON b.snapshot_release_date = m.prev_snapshot_release_date
  AND b.conflict_type = r.conflict_type
  AND b.outlier_status = r.outlier_status
ORDER BY r.snapshot_release_date, r.conflict_type, r.outlier_status, r.change_status, r.primary_reason;


-- ============================================================================
-- View 4: Multi-Reason Detail (All Contributing Reasons)
-- ============================================================================
-- This view explodes the scv_reasons array to show ALL reasons contributing
-- to each change, not just the primary reason. A single VCV change may have
-- multiple SCV-level changes (e.g., one SCV flagged AND another reclassified).
--
-- Use for:
--   - Understanding the full picture of what drives changes
--   - Comparing primary vs contributing reason frequencies
--   - Identifying complex multi-factor resolutions

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_multi_reason_detail` AS

WITH unnested_reasons AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    vcv_change_status AS change_status,
    variation_id,
    primary_reason,
    reason AS contributing_reason,
    reason_count AS total_reasons_for_vcv
  FROM `clinvar_ingest.conflict_vcv_change_detail`
  CROSS JOIN UNNEST(scv_reasons) AS reason
  WHERE vcv_change_status IN ('resolved', 'modified')
    AND scv_reasons IS NOT NULL
    AND ARRAY_LENGTH(scv_reasons) > 0
),

reason_counts AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    change_status,
    contributing_reason,
    COUNT(DISTINCT variation_id) AS variant_count,
    -- Count how often this reason is the primary vs contributing
    COUNTIF(contributing_reason = primary_reason) AS as_primary_count,
    COUNTIF(contributing_reason != primary_reason) AS as_secondary_count
  FROM unnested_reasons
  GROUP BY snapshot_release_date, conflict_type, outlier_status, change_status, contributing_reason
),

-- Get baseline from previous month
baseline AS (
  SELECT
    snapshot_release_date,
    CASE WHEN clinsig_conflict THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
    CASE WHEN has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
    COUNT(*) AS total_conflicts,
    ANY_VALUE(total_path_variants) AS total_path_variants
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date, clinsig_conflict, has_outlier
),

month_mapping AS (
  SELECT
    snapshot_release_date,
    LAG(snapshot_release_date) OVER (ORDER BY snapshot_release_date) AS prev_snapshot_release_date
  FROM (
    SELECT DISTINCT snapshot_release_date
    FROM `clinvar_ingest.monthly_conflict_snapshots`
  )
)

SELECT
  r.snapshot_release_date,
  FORMAT_DATE('%Y-%m', r.snapshot_release_date) AS snapshot_month,
  m.prev_snapshot_release_date,
  r.conflict_type,
  r.outlier_status,
  r.change_status,
  r.contributing_reason AS reason,
  r.variant_count,
  r.as_primary_count,
  r.as_secondary_count,
  -- Baseline from previous month
  b.total_conflicts AS prev_month_total_conflicts,
  -- Percentage of previous month's conflicts
  ROUND(100.0 * r.variant_count / NULLIF(b.total_conflicts, 0), 2) AS pct_of_prev_conflicts
FROM reason_counts r
LEFT JOIN month_mapping m ON m.snapshot_release_date = r.snapshot_release_date
LEFT JOIN baseline b
  ON b.snapshot_release_date = m.prev_snapshot_release_date
  AND b.conflict_type = r.conflict_type
  AND b.outlier_status = r.outlier_status
ORDER BY r.snapshot_release_date, r.conflict_type, r.outlier_status, r.change_status, r.contributing_reason;


-- ============================================================================
-- View 5: Overall Monthly Summary (Single Row Per Month)
-- ============================================================================
-- This view provides a single-row-per-month summary that's easy to chart.
-- All conflict_type and outlier_status combinations are in separate columns.
--
-- Use for:
--   - Simple trend line charts
--   - Dashboard KPIs
--   - Quick overview without slicers

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_monthly_overview` AS

WITH monthly_base AS (
  SELECT
    snapshot_release_date,
    ANY_VALUE(total_path_variants) AS total_path_variants,
    ANY_VALUE(variants_with_conflict_potential) AS variants_with_conflict_potential,
    COUNT(*) AS total_conflicts,
    COUNTIF(clinsig_conflict) AS clinsig_conflicts,
    COUNTIF(NOT clinsig_conflict) AS non_clinsig_conflicts,
    COUNTIF(has_outlier) AS conflicts_with_outlier,
    COUNTIF(NOT has_outlier) AS conflicts_no_outlier,
    -- Combined categories
    COUNTIF(clinsig_conflict AND has_outlier) AS clinsig_with_outlier,
    COUNTIF(clinsig_conflict AND NOT has_outlier) AS clinsig_no_outlier,
    COUNTIF(NOT clinsig_conflict AND has_outlier) AS non_clinsig_with_outlier,
    COUNTIF(NOT clinsig_conflict AND NOT has_outlier) AS non_clinsig_no_outlier
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date
),

change_summary AS (
  SELECT
    snapshot_release_date,
    COUNTIF(change_status = 'new') AS new_conflicts,
    COUNTIF(change_status = 'resolved') AS resolved_conflicts,
    COUNTIF(change_status = 'modified') AS modified_conflicts,
    COUNTIF(change_status = 'unchanged') AS unchanged_conflicts
  FROM `clinvar_ingest.monthly_conflict_changes`
  GROUP BY snapshot_release_date
)

SELECT
  b.snapshot_release_date,
  FORMAT_DATE('%Y-%m', b.snapshot_release_date) AS snapshot_month,
  b.total_path_variants,
  b.variants_with_conflict_potential,
  b.total_conflicts,
  -- By conflict type
  b.clinsig_conflicts,
  b.non_clinsig_conflicts,
  -- By outlier status
  b.conflicts_with_outlier,
  b.conflicts_no_outlier,
  -- Combined categories
  b.clinsig_with_outlier,
  b.clinsig_no_outlier,
  b.non_clinsig_with_outlier,
  b.non_clinsig_no_outlier,
  -- Percentages
  ROUND(100.0 * b.total_conflicts / NULLIF(b.total_path_variants, 0), 4) AS pct_total_conflicts,
  ROUND(100.0 * b.clinsig_conflicts / NULLIF(b.total_path_variants, 0), 4) AS pct_clinsig_conflicts,
  ROUND(100.0 * b.non_clinsig_conflicts / NULLIF(b.total_path_variants, 0), 4) AS pct_non_clinsig_conflicts,
  -- Change counts
  COALESCE(c.new_conflicts, 0) AS new_conflicts,
  COALESCE(c.resolved_conflicts, 0) AS resolved_conflicts,
  COALESCE(c.modified_conflicts, 0) AS modified_conflicts,
  COALESCE(c.unchanged_conflicts, 0) AS unchanged_conflicts,
  -- Net change
  COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0) AS net_change,
  -- Split net change for conditional bar coloring (one will be NULL per row)
  CASE WHEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0) > 0
       THEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0)
  END AS net_increase,
  CASE WHEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0) < 0
       THEN COALESCE(c.new_conflicts, 0) - COALESCE(c.resolved_conflicts, 0)
  END AS net_decrease,
  -- Previous month for comparison
  LAG(b.total_conflicts) OVER (ORDER BY b.snapshot_release_date) AS prev_month_total,
  b.total_conflicts - COALESCE(LAG(b.total_conflicts) OVER (ORDER BY b.snapshot_release_date), 0) AS mom_change
FROM monthly_base b
LEFT JOIN change_summary c ON c.snapshot_release_date = b.snapshot_release_date
ORDER BY b.snapshot_release_date;


-- ============================================================================
-- View 6: Change Status Wide Format (for Stacked Charts with Slicers)
-- ============================================================================
-- This view pivots change_status into columns while keeping conflict_type and
-- outlier_status as slicer dimensions. This enables stacked bar charts in
-- Google Sheets where each change_status is a separate series.
--
-- Use for:
--   - Stacked bar charts of change status breakdown
--   - Filtering by conflict_type and/or outlier_status via slicers
--   - Charts showing new/resolved/modified/unchanged as separate colored bars

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_change_status_wide` AS

SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  SUM(CASE WHEN change_status = 'new' THEN variant_count ELSE 0 END) AS new_conflicts,
  SUM(CASE WHEN change_status = 'resolved' THEN variant_count ELSE 0 END) AS resolved_conflicts,
  SUM(CASE WHEN change_status = 'modified' THEN variant_count ELSE 0 END) AS modified_conflicts,
  SUM(CASE WHEN change_status = 'unchanged' THEN variant_count ELSE 0 END) AS unchanged_conflicts,
  -- Net change for convenience
  SUM(CASE WHEN change_status = 'new' THEN variant_count ELSE 0 END) -
  SUM(CASE WHEN change_status = 'resolved' THEN variant_count ELSE 0 END) AS net_change
FROM `clinvar_ingest.sheets_conflict_changes`
GROUP BY snapshot_release_date, conflict_type, outlier_status
ORDER BY snapshot_release_date, conflict_type, outlier_status;


-- ============================================================================
-- View 7: Change Reasons Wide Format (for Stacked Charts with Slicers)
-- ============================================================================
-- This view pivots primary_reason into columns while keeping conflict_type and
-- outlier_status as slicer dimensions. Useful for charts comparing resolution
-- reasons side-by-side.
--
-- Use for:
--   - Stacked bar charts of resolution reasons
--   - Comparing reason frequencies across conflict types

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_change_reasons_wide` AS

SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  change_status,
  -- Contributing tier reasons (high priority)
  SUM(CASE WHEN primary_reason = 'scv_flagged' THEN variant_count ELSE 0 END) AS scv_flagged,
  SUM(CASE WHEN primary_reason = 'scv_removed' THEN variant_count ELSE 0 END) AS scv_removed,
  SUM(CASE WHEN primary_reason = 'scv_reclassified' THEN variant_count ELSE 0 END) AS scv_reclassified,
  SUM(CASE WHEN primary_reason = 'scv_added' THEN variant_count ELSE 0 END) AS scv_added,
  SUM(CASE WHEN primary_reason = 'scv_rank_downgraded' THEN variant_count ELSE 0 END) AS scv_rank_downgraded,
  -- VCV-level reasons
  SUM(CASE WHEN primary_reason = 'expert_panel_added' THEN variant_count ELSE 0 END) AS expert_panel_added,
  SUM(CASE WHEN primary_reason = 'higher_rank_scv_added' THEN variant_count ELSE 0 END) AS higher_rank_scv_added,
  SUM(CASE WHEN primary_reason = 'vcv_rank_changed' THEN variant_count ELSE 0 END) AS vcv_rank_changed,
  SUM(CASE WHEN primary_reason = 'outlier_reclassified' THEN variant_count ELSE 0 END) AS outlier_reclassified,
  SUM(CASE WHEN primary_reason = 'outlier_status_changed' THEN variant_count ELSE 0 END) AS outlier_status_changed,
  SUM(CASE WHEN primary_reason = 'conflict_type_changed' THEN variant_count ELSE 0 END) AS conflict_type_changed,
  SUM(CASE WHEN primary_reason = 'single_submitter_withdrawn' THEN variant_count ELSE 0 END) AS single_submitter_withdrawn,
  -- Fallback
  SUM(CASE WHEN primary_reason = 'unknown' THEN variant_count ELSE 0 END) AS unknown
FROM `clinvar_ingest.sheets_change_reasons`
GROUP BY snapshot_release_date, conflict_type, outlier_status, change_status
ORDER BY snapshot_release_date, conflict_type, outlier_status, change_status;


-- ============================================================================
-- View 8: SCV Reasons Over Time
-- ============================================================================
-- This view tracks the SCV-level reasons that drive conflict resolutions and
-- modifications. Each reason row includes both single-reason and multi-reason
-- variant counts.
--
-- SCV REASONS (what caused the change):
--   Resolution reasons: reclassified, flagged, removed, rank_downgraded,
--                       expert_panel, higher_rank
--   Modification reasons: all above + added
--
-- VCV OUTCOMES (effects, not causes - tracked separately):
--   outlier_status_changed, conflict_type_changed, vcv_rank_changed
--   These are NOT included in reason categorization as they are effects,
--   not causes of the resolution/modification.
--
-- OUTPUT FORMAT:
--   One row per reason with:
--   - single_reason_count: Variants where this was the ONLY SCV reason
--   - multi_reason_count: Variants where this was primary but other reasons exist
--   - total_variant_count: Sum of single + multi
--
-- NOTES:
--   - single_submitter_withdrawn is NOT a separate reason - it's a context
--     where the underlying SCV reason (flagged/removed/reclassified) was
--     sufficient because only one submitter existed on one side
--   - For expert_panel and higher_rank, the "added" is implicit in the reason
--
-- Use for:
--   - Trend charts showing reason distribution over time
--   - Comparing single vs multi-reason patterns per reason type
--   - Aggregations by reason across time periods

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_reason_combinations` AS

WITH reason_combos AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    vcv_change_status AS change_status,
    primary_reason,
    scv_reasons,
    -- Count only true SCV reasons (exclude VCV-level outcomes)
    (SELECT COUNT(*) FROM UNNEST(scv_reasons) r
     WHERE r IN ('scv_reclassified', 'scv_flagged', 'scv_removed', 'scv_added', 'scv_rank_downgraded')
    ) AS scv_reason_count,
    -- Determine the simplified reason category (without _multi suffix)
    -- Priority: Use explicit SCV reason from primary_reason first, then fall back to scv_reasons array
    CASE
      -- Expert panel supersession (3/4-star SCV added)
      WHEN primary_reason = 'expert_panel_added' THEN 'expert_panel'
      -- Higher rank supersession (1-star SCV supersedes 0-star conflict)
      WHEN primary_reason = 'higher_rank_scv_added' THEN 'higher_rank'
      -- Standard SCV reasons (when primary_reason is already an SCV reason)
      WHEN primary_reason = 'scv_reclassified' THEN 'reclassified'
      WHEN primary_reason = 'scv_flagged' THEN 'flagged'
      WHEN primary_reason = 'scv_removed' THEN 'removed'
      WHEN primary_reason = 'scv_added' THEN 'added'
      WHEN primary_reason = 'scv_rank_downgraded' THEN 'rank_downgraded'
      -- For VCV outcomes and context-based reasons, use the underlying SCV reason from scv_reasons array
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
    -- Exclude new_conflict and no_change since they're not SCV-level reasons
    AND primary_reason NOT IN ('new_conflict', 'no_change')
)

SELECT
  snapshot_release_date,
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  conflict_type,
  outlier_status,
  change_status,
  scv_reason,
  -- Single-reason count (this was the only SCV reason)
  COUNTIF(scv_reason_count = 1) AS single_reason_count,
  -- Multi-reason count (this was primary but other SCV reasons exist)
  COUNTIF(scv_reason_count > 1) AS multi_reason_count,
  -- Total variant count
  COUNT(*) AS total_variant_count
FROM reason_combos
GROUP BY
  snapshot_release_date,
  conflict_type,
  outlier_status,
  change_status,
  scv_reason
ORDER BY snapshot_release_date, change_status, total_variant_count DESC;


-- ============================================================================
-- View 9: SCV Reasons Wide Format (for Stacked Charts)
-- ============================================================================
-- This view pivots SCV reasons into columns for stacked bar charts.
-- Each reason has two columns: {reason}_single and {reason}_multi
--
-- SCV REASONS (what caused the change):
--   Resolution reasons: reclassified, flagged, removed, rank_downgraded,
--                       expert_panel, higher_rank
--   Modification reasons: all above + added
--
-- COLUMN FORMAT:
--   {reason}_single: Variants where this was the ONLY SCV reason
--   {reason}_multi: Variants where this was primary but other reasons exist
--
-- Use for:
--   - Stacked bar charts showing reason breakdown over time
--   - Side-by-side comparison of single vs multi-reason changes per reason

CREATE OR REPLACE VIEW `clinvar_ingest.sheets_reason_combinations_wide` AS

WITH reason_combos AS (
  SELECT
    snapshot_release_date,
    conflict_type,
    outlier_status,
    vcv_change_status AS change_status,
    primary_reason,
    scv_reasons,
    -- Count only true SCV reasons (exclude VCV-level outcomes)
    (SELECT COUNT(*) FROM UNNEST(scv_reasons) r
     WHERE r IN ('scv_reclassified', 'scv_flagged', 'scv_removed', 'scv_added', 'scv_rank_downgraded')
    ) AS scv_reason_count,
    -- Determine the simplified reason category (without _multi suffix)
    -- Priority: Use explicit SCV reason from primary_reason first, then fall back to scv_reasons array
    CASE
      -- Expert panel supersession (3/4-star SCV added)
      WHEN primary_reason = 'expert_panel_added' THEN 'expert_panel'
      -- Higher rank supersession (1-star SCV supersedes 0-star conflict)
      WHEN primary_reason = 'higher_rank_scv_added' THEN 'higher_rank'
      -- Standard SCV reasons (when primary_reason is already an SCV reason)
      WHEN primary_reason = 'scv_reclassified' THEN 'reclassified'
      WHEN primary_reason = 'scv_flagged' THEN 'flagged'
      WHEN primary_reason = 'scv_removed' THEN 'removed'
      WHEN primary_reason = 'scv_added' THEN 'added'
      WHEN primary_reason = 'scv_rank_downgraded' THEN 'rank_downgraded'
      -- For VCV outcomes and context-based reasons, use the underlying SCV reason from scv_reasons array
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
  -- Reclassified
  SUM(CASE WHEN scv_reason = 'reclassified' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS reclassified_single,
  SUM(CASE WHEN scv_reason = 'reclassified' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS reclassified_multi,
  -- Flagged
  SUM(CASE WHEN scv_reason = 'flagged' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS flagged_single,
  SUM(CASE WHEN scv_reason = 'flagged' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS flagged_multi,
  -- Removed
  SUM(CASE WHEN scv_reason = 'removed' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS removed_single,
  SUM(CASE WHEN scv_reason = 'removed' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS removed_multi,
  -- Added (modification only)
  SUM(CASE WHEN scv_reason = 'added' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS added_single,
  SUM(CASE WHEN scv_reason = 'added' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS added_multi,
  -- Rank downgraded
  SUM(CASE WHEN scv_reason = 'rank_downgraded' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS rank_downgraded_single,
  SUM(CASE WHEN scv_reason = 'rank_downgraded' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS rank_downgraded_multi,
  -- Expert panel
  SUM(CASE WHEN scv_reason = 'expert_panel' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS expert_panel_single,
  SUM(CASE WHEN scv_reason = 'expert_panel' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS expert_panel_multi,
  -- Higher rank
  SUM(CASE WHEN scv_reason = 'higher_rank' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS higher_rank_single,
  SUM(CASE WHEN scv_reason = 'higher_rank' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS higher_rank_multi,
  -- Unknown (VCV-level outcomes or unidentified)
  SUM(CASE WHEN scv_reason = 'unknown' AND scv_reason_count = 1 THEN 1 ELSE 0 END) AS unknown_single,
  SUM(CASE WHEN scv_reason = 'unknown' AND scv_reason_count > 1 THEN 1 ELSE 0 END) AS unknown_multi,
  -- Summary totals
  SUM(CASE WHEN scv_reason_count = 1 THEN 1 ELSE 0 END) AS single_reason_total,
  SUM(CASE WHEN scv_reason_count > 1 THEN 1 ELSE 0 END) AS multi_reason_total,
  COUNT(*) AS total_variants
FROM reason_combos
GROUP BY snapshot_release_date, conflict_type, outlier_status, change_status
ORDER BY snapshot_release_date, conflict_type, outlier_status, change_status;
