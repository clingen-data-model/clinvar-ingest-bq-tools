-- ============================================================================
-- Script: 03-outlier-trends-wide.sql
--
-- Description:
--   Aggregates conflict trends in wide format for time-series visualization.
--   Provides counts and percentages split by conflict type (clinsig vs non-clinsig)
--   and outlier status, with all metrics as separate columns per row/date.
--
-- Source Tables:
--   - clinvar_ingest.monthly_conflict_changes (created by 02-monthly-conflict-changes.sql)
--   - clinvar_ingest.monthly_conflict_snapshots (created by 01-get-monthly-conflicts.sql)
--
-- Output Format:
--   One row per snapshot_release_date with columns for each metric combination.
--   Best for: Direct charting in Google Sheets, combo charts, side-by-side comparisons.
--
-- Key Fields Returned:
--   Baseline:
--   - snapshot_release_date: Monthly release date
--   - total_path_variants: Total variants with GermlineClassification
--   - variants_with_conflict_potential: Variants with 2+ SCVs at their contributing tier
--       (1-star SCVs for 1-star+ VCVs, 0-star SCVs for 0-star VCVs)
--       This is the meaningful denominator - only these could potentially have conflicts
--
--   Conflict Totals (active conflicts in that month's snapshot):
--   - total_clinsig_with_outlier: Clinsig conflicts where minority <= 33%
--   - total_clinsig_no_outlier: Clinsig conflicts with balanced submissions
--   - total_clinsig_conflicts: Sum of above two
--   - total_nonclinsig_with_outlier: Non-clinsig (B/LB vs VUS) with outlier
--   - total_nonclinsig_no_outlier: Non-clinsig without outlier
--   - total_nonclinsig_conflicts: Sum of above two
--   - total_all_conflicts: All conflicts combined
--
--   Percentages (of variants_with_conflict_potential, expressed as 0-100):
--   - pct_clinsig_conflicts: % of conflict-potential variants with clinsig conflict
--   - pct_nonclinsig_conflicts: % with non-clinsig conflict
--   - pct_clinsig_with_outlier, pct_clinsig_no_outlier: Breakdown by outlier
--   - pct_nonclinsig_with_outlier, pct_nonclinsig_no_outlier: Breakdown by outlier
--
--   Change Counts (month-over-month changes for each category):
--   Format: {action}_{conflict_type}_{outlier_status}
--   - new_*: Conflicts that appeared this month (not in previous)
--   - resolved_*: Conflicts that disappeared this month (were in previous)
--   - modified_*: Conflicts present in both but changed
--   - net_change_*: new minus resolved (positive = growing, negative = shrinking)
--
--   Categories:
--   - *_clinsig_with_outlier: Clinsig conflicts with outlier submitter
--   - *_clinsig_no_outlier: Clinsig conflicts without outlier
--   - *_nonclinsig_with_outlier: Non-clinsig conflicts with outlier
--   - *_nonclinsig_no_outlier: Non-clinsig conflicts without outlier
--
-- Conflict Type Definitions:
--   - Clinsig conflict (agg_sig_type 5,6,7): Pathogenic/LP vs Benign/LB disagreement
--   - Non-clinsig conflict (agg_sig_type 3): Benign/LB vs VUS disagreement only
--
-- Outlier Definition:
--   - has_outlier = TRUE when MIN(non-zero PERCENT in sig_type array) <= 0.333
--   - Indicates a minority opinion (one classification tier has <= 33% support)
--
-- Usage:
--   Run via BigQuery Data Connector in Google Sheets.
--   Extract data to sheet, then create charts selecting specific column groups.
--   Example: Line chart of pct_clinsig_conflicts over time.
--   Example: Combo chart with total_clinsig_conflicts (line) + net_change (bars).
-- ============================================================================

WITH change_counts AS (
  SELECT
    snapshot_release_date,
    -- Clinsig conflicts with outliers
    COUNTIF(change_status = 'new' AND COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND COALESCE(curr_has_outlier, prev_has_outlier)) AS new_clinsig_with_outlier,
    COUNTIF(change_status = 'resolved' AND COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND COALESCE(curr_has_outlier, prev_has_outlier)) AS resolved_clinsig_with_outlier,
    COUNTIF(change_status = 'modified' AND COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND COALESCE(curr_has_outlier, prev_has_outlier)) AS modified_clinsig_with_outlier,
    -- Clinsig conflicts without outliers
    COUNTIF(change_status = 'new' AND COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND NOT COALESCE(curr_has_outlier, prev_has_outlier)) AS new_clinsig_no_outlier,
    COUNTIF(change_status = 'resolved' AND COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND NOT COALESCE(curr_has_outlier, prev_has_outlier)) AS resolved_clinsig_no_outlier,
    COUNTIF(change_status = 'modified' AND COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND NOT COALESCE(curr_has_outlier, prev_has_outlier)) AS modified_clinsig_no_outlier,
    -- Non-clinsig conflicts with outliers
    COUNTIF(change_status = 'new' AND NOT COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND COALESCE(curr_has_outlier, prev_has_outlier)) AS new_nonclinsig_with_outlier,
    COUNTIF(change_status = 'resolved' AND NOT COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND COALESCE(curr_has_outlier, prev_has_outlier)) AS resolved_nonclinsig_with_outlier,
    COUNTIF(change_status = 'modified' AND NOT COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND COALESCE(curr_has_outlier, prev_has_outlier)) AS modified_nonclinsig_with_outlier,
    -- Non-clinsig conflicts without outliers
    COUNTIF(change_status = 'new' AND NOT COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND NOT COALESCE(curr_has_outlier, prev_has_outlier)) AS new_nonclinsig_no_outlier,
    COUNTIF(change_status = 'resolved' AND NOT COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND NOT COALESCE(curr_has_outlier, prev_has_outlier)) AS resolved_nonclinsig_no_outlier,
    COUNTIF(change_status = 'modified' AND NOT COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AND NOT COALESCE(curr_has_outlier, prev_has_outlier)) AS modified_nonclinsig_no_outlier
  FROM `clinvar_ingest.monthly_conflict_changes`
  GROUP BY snapshot_release_date
),
snapshot_totals AS (
  SELECT
    snapshot_release_date,
    ANY_VALUE(total_path_variants) AS total_path_variants,
    ANY_VALUE(variants_with_conflict_potential) AS variants_with_conflict_potential,
    -- Clinsig totals
    COUNTIF(clinsig_conflict AND has_outlier) AS total_clinsig_with_outlier,
    COUNTIF(clinsig_conflict AND NOT has_outlier) AS total_clinsig_no_outlier,
    -- Non-clinsig totals
    COUNTIF(NOT clinsig_conflict AND has_outlier) AS total_nonclinsig_with_outlier,
    COUNTIF(NOT clinsig_conflict AND NOT has_outlier) AS total_nonclinsig_no_outlier
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date
)
SELECT
  s.snapshot_release_date,
  -- Baseline counts
  s.total_path_variants,
  s.variants_with_conflict_potential,

  -- Clinsig conflict totals
  s.total_clinsig_with_outlier,
  s.total_clinsig_no_outlier,
  s.total_clinsig_with_outlier + s.total_clinsig_no_outlier AS total_clinsig_conflicts,

  -- Non-clinsig conflict totals
  s.total_nonclinsig_with_outlier,
  s.total_nonclinsig_no_outlier,
  s.total_nonclinsig_with_outlier + s.total_nonclinsig_no_outlier AS total_nonclinsig_conflicts,

  -- All conflicts
  s.total_clinsig_with_outlier + s.total_clinsig_no_outlier +
    s.total_nonclinsig_with_outlier + s.total_nonclinsig_no_outlier AS total_all_conflicts,

  -- Percentages (of variants with conflict potential - meaningful denominator)
  ROUND(100.0 * (s.total_clinsig_with_outlier + s.total_clinsig_no_outlier) / s.variants_with_conflict_potential, 3) AS pct_clinsig_conflicts,
  ROUND(100.0 * (s.total_nonclinsig_with_outlier + s.total_nonclinsig_no_outlier) / s.variants_with_conflict_potential, 3) AS pct_nonclinsig_conflicts,
  ROUND(100.0 * s.total_clinsig_with_outlier / s.variants_with_conflict_potential, 3) AS pct_clinsig_with_outlier,
  ROUND(100.0 * s.total_clinsig_no_outlier / s.variants_with_conflict_potential, 3) AS pct_clinsig_no_outlier,
  ROUND(100.0 * s.total_nonclinsig_with_outlier / s.variants_with_conflict_potential, 3) AS pct_nonclinsig_with_outlier,
  ROUND(100.0 * s.total_nonclinsig_no_outlier / s.variants_with_conflict_potential, 3) AS pct_nonclinsig_no_outlier,

  -- Clinsig with outlier changes
  COALESCE(c.new_clinsig_with_outlier, 0) AS new_clinsig_with_outlier,
  COALESCE(c.resolved_clinsig_with_outlier, 0) AS resolved_clinsig_with_outlier,
  COALESCE(c.modified_clinsig_with_outlier, 0) AS modified_clinsig_with_outlier,
  COALESCE(c.new_clinsig_with_outlier, 0) - COALESCE(c.resolved_clinsig_with_outlier, 0) AS net_change_clinsig_with_outlier,

  -- Clinsig without outlier changes
  COALESCE(c.new_clinsig_no_outlier, 0) AS new_clinsig_no_outlier,
  COALESCE(c.resolved_clinsig_no_outlier, 0) AS resolved_clinsig_no_outlier,
  COALESCE(c.modified_clinsig_no_outlier, 0) AS modified_clinsig_no_outlier,
  COALESCE(c.new_clinsig_no_outlier, 0) - COALESCE(c.resolved_clinsig_no_outlier, 0) AS net_change_clinsig_no_outlier,

  -- Non-clinsig with outlier changes
  COALESCE(c.new_nonclinsig_with_outlier, 0) AS new_nonclinsig_with_outlier,
  COALESCE(c.resolved_nonclinsig_with_outlier, 0) AS resolved_nonclinsig_with_outlier,
  COALESCE(c.modified_nonclinsig_with_outlier, 0) AS modified_nonclinsig_with_outlier,
  COALESCE(c.new_nonclinsig_with_outlier, 0) - COALESCE(c.resolved_nonclinsig_with_outlier, 0) AS net_change_nonclinsig_with_outlier,

  -- Non-clinsig without outlier changes
  COALESCE(c.new_nonclinsig_no_outlier, 0) AS new_nonclinsig_no_outlier,
  COALESCE(c.resolved_nonclinsig_no_outlier, 0) AS resolved_nonclinsig_no_outlier,
  COALESCE(c.modified_nonclinsig_no_outlier, 0) AS modified_nonclinsig_no_outlier,
  COALESCE(c.new_nonclinsig_no_outlier, 0) - COALESCE(c.resolved_nonclinsig_no_outlier, 0) AS net_change_nonclinsig_no_outlier

FROM snapshot_totals s
LEFT JOIN change_counts c USING (snapshot_release_date)
ORDER BY snapshot_release_date;
