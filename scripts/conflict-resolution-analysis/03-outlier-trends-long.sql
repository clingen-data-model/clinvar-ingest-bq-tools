-- ============================================================================
-- Script: 03-outlier-trends-long.sql
--
-- Description:
--   Aggregates conflict trends in long/normalized format for flexible visualization.
--   Each row represents one combination of snapshot_release_date + conflict_type +
--   outlier_status, enabling easy filtering and pivoting in Google Sheets.
--
-- Source Tables:
--   - clinvar_ingest.monthly_conflict_changes (created by 02-monthly-conflict-changes.sql)
--   - clinvar_ingest.monthly_conflict_snapshots (created by 01-get-monthly-conflicts.sql)
--
-- Output Format:
--   Four rows per snapshot_release_date (one for each conflict_type/outlier_status combo).
--   Best for: Pivot tables, slicers, grouped/stacked bar charts, filtering.
--
-- Key Fields Returned:
--   Dimensions:
--   - snapshot_release_date: Monthly release date
--   - conflict_type: 'Clinsig' or 'Non-Clinsig'
--       Clinsig: P/LP vs B/LB disagreement (agg_sig_type 5,6,7)
--       Non-Clinsig: B/LB vs VUS only (agg_sig_type 3)
--   - outlier_status: 'With Outlier' or 'No Outlier'
--       With Outlier: MIN(non-zero sig_type.PERCENT) <= 0.333 (minority opinion)
--       No Outlier: All classification tiers have > 33% representation
--
--   Baseline:
--   - total_path_variants: Total variants with GermlineClassification
--   - variants_with_conflict_potential: Variants with 2+ SCVs at their contributing tier
--       (1-star SCVs for 1-star+ VCVs, 0-star SCVs for 0-star VCVs)
--       This is the meaningful denominator - only these could potentially have conflicts
--
--   Metrics:
--   - total_active: Number of active conflicts for this category in this month
--   - pct_of_conflict_potential: Percentage of conflict-potential variants in this category
--       Formula: 100.0 * total_active / variants_with_conflict_potential
--       Rounded to 3 decimal places
--
--   Change Counts (month-over-month for this category):
--   - new_conflicts: Conflicts that appeared this month (not in previous)
--   - resolved_conflicts: Conflicts that disappeared (were in previous, not now)
--   - modified_conflicts: Conflicts present in both months but changed
--   - net_change: new_conflicts - resolved_conflicts
--       Positive = category growing, Negative = category shrinking
--
-- Row Examples (for one snapshot date):
--   | snapshot_release_date | conflict_type | outlier_status | total_active | ... |
--   |-----------------------|---------------|----------------|--------------|-----|
--   | 2023-01-08            | Clinsig       | No Outlier     | 1500         | ... |
--   | 2023-01-08            | Clinsig       | With Outlier   | 800          | ... |
--   | 2023-01-08            | Non-Clinsig   | No Outlier     | 2000         | ... |
--   | 2023-01-08            | Non-Clinsig   | With Outlier   | 600          | ... |
--
-- Usage:
--   Run via BigQuery Data Connector in Google Sheets.
--   Extract data, then:
--   1. Add slicers for conflict_type and outlier_status to filter interactively
--   2. Create pivot tables grouping by dimensions
--   3. Build stacked bar charts showing composition over time
--
-- Google Sheets Tips:
--   - Data > Add a slicer > Column: conflict_type (toggle Clinsig vs Non-Clinsig)
--   - Data > Add a slicer > Column: outlier_status (toggle outlier filtering)
--   - Insert > Pivot table > Rows: snapshot_release_date, Columns: conflict_type
-- ============================================================================

WITH base_data AS (
  SELECT
    snapshot_release_date,
    change_status,
    COALESCE(curr_clinsig_conflict, prev_clinsig_conflict) AS is_clinsig,
    COALESCE(curr_has_outlier, prev_has_outlier) AS has_outlier
  FROM `clinvar_ingest.monthly_conflict_changes`
),
snapshot_totals AS (
  SELECT
    snapshot_release_date,
    clinsig_conflict AS is_clinsig,
    has_outlier,
    ANY_VALUE(total_path_variants) AS total_path_variants,
    ANY_VALUE(variants_with_conflict_potential) AS variants_with_conflict_potential,
    COUNT(*) AS total_active
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date, clinsig_conflict, has_outlier
)
SELECT
  s.snapshot_release_date,
  CASE WHEN s.is_clinsig THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
  CASE WHEN s.has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
  s.total_path_variants,
  s.variants_with_conflict_potential,
  s.total_active,
  ROUND(100.0 * s.total_active / s.variants_with_conflict_potential, 3) AS pct_of_conflict_potential,
  COUNTIF(b.change_status = 'new') AS new_conflicts,
  COUNTIF(b.change_status = 'resolved') AS resolved_conflicts,
  COUNTIF(b.change_status = 'modified') AS modified_conflicts,
  COUNTIF(b.change_status = 'new') - COUNTIF(b.change_status = 'resolved') AS net_change
FROM snapshot_totals s
LEFT JOIN base_data b
  ON b.snapshot_release_date = s.snapshot_release_date
  AND b.is_clinsig = s.is_clinsig
  AND b.has_outlier = s.has_outlier
GROUP BY s.snapshot_release_date, s.is_clinsig, s.has_outlier, s.total_path_variants, s.variants_with_conflict_potential, s.total_active
ORDER BY s.snapshot_release_date, conflict_type, outlier_status;
