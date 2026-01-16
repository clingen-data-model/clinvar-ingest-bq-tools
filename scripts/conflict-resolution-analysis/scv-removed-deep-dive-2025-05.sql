-- ============================================================================
-- Deep Dive: scv_removed spike in May 2025
-- ============================================================================
-- This file contains queries to investigate the large number of scv_removed
-- submissions in the 2025-05 release.
-- ============================================================================

-- Query 1: Overview - How many scv_removed events in 2025-05 vs other months?
-- ----------------------------------------------------------------------------
SELECT
  FORMAT_DATE('%Y-%m', snapshot_release_date) AS snapshot_month,
  COUNT(*) AS total_scv_removed,
  COUNT(DISTINCT variation_id) AS unique_variants_affected,
  COUNT(DISTINCT prev_submitter_id) AS unique_submitters
FROM `clinvar_ingest.monthly_conflict_scv_changes`
WHERE scv_change_status = 'removed'
GROUP BY snapshot_release_date
ORDER BY snapshot_release_date DESC
LIMIT 12;


-- Query 2: Which submitters had the most SCVs removed in 2025-05?
-- ----------------------------------------------------------------------------
-- NOTE: scv_change_status='removed' includes BOTH:
--   1. True removals: SCV withdrawn from ClinVar
--   2. Conflict exits: SCV left conflict tracking because variant resolved
-- This query now separates these cases.

WITH removed_scvs AS (
  SELECT
    sc.scv_id,
    sc.variation_id,
    sc.prev_submitter_id,
    sc.prev_submitter_name,
    sc.prev_is_contributing,
    -- Determine if this is a "true removal" vs "conflict exit"
    -- True removal: variant is still conflicting but this SCV is gone
    -- Conflict exit: variant resolved, so all SCVs left tracking
    CASE
      WHEN sc.curr_vcv_is_conflicting = TRUE THEN 'true_removal'
      WHEN sc.prev_is_contributing = TRUE THEN 'caused_resolution'
      ELSE 'conflict_exit'
    END AS removal_type
  FROM `clinvar_ingest.monthly_conflict_scv_changes` sc
  WHERE sc.scv_change_status = 'removed'
    AND sc.snapshot_release_date = '2025-05-04'
)

SELECT
  prev_submitter_id AS submitter_id,
  prev_submitter_name AS submitter_name,
  COUNT(*) AS total_scvs_removed,
  -- Break down by removal type
  COUNTIF(removal_type = 'true_removal') AS true_removals,
  COUNTIF(removal_type = 'caused_resolution') AS caused_resolution,
  COUNTIF(removal_type = 'conflict_exit') AS conflict_exits,
  COUNT(DISTINCT variation_id) AS variants_affected,
  -- Sample of true removals for THIS submitter
  ARRAY_AGG(scv_id ORDER BY scv_id LIMIT 5) AS sample_scv_ids,
  -- Sample of true removals (most interesting) for THIS submitter
  ARRAY_AGG(CASE WHEN removal_type = 'true_removal' THEN scv_id END IGNORE NULLS ORDER BY scv_id LIMIT 5) AS sample_true_removal_scvs,
  -- Sample of SCVs that caused resolutions for THIS submitter
  ARRAY_AGG(CASE WHEN removal_type = 'caused_resolution' THEN scv_id END IGNORE NULLS ORDER BY scv_id LIMIT 5) AS sample_resolution_scvs
FROM removed_scvs
GROUP BY prev_submitter_id, prev_submitter_name
ORDER BY total_scvs_removed DESC
LIMIT 20;


-- Query 3: Breakdown by conflict_type and outlier_status for 2025-05
-- ----------------------------------------------------------------------------
SELECT
  conflict_type,
  outlier_status,
  change_status,
  SUM(scv_removed) AS scv_removed_count
FROM `clinvar_ingest.sheets_change_reasons_wide`
WHERE snapshot_month = '2025-05'
GROUP BY conflict_type, outlier_status, change_status
ORDER BY scv_removed_count DESC;


-- Query 4: What was the previous classification of removed SCVs?
-- ----------------------------------------------------------------------------
SELECT
  prev_clinsig_type,
  COUNT(*) AS count,
  COUNT(DISTINCT variation_id) AS unique_variants
FROM `clinvar_ingest.monthly_conflict_scv_changes`
WHERE scv_change_status = 'removed'
  AND snapshot_release_date = '2025-05-04'  -- Adjust date if needed
GROUP BY prev_clinsig_type
ORDER BY count DESC;


-- Query 5: Were the removed SCVs contributing to the conflict?
-- ----------------------------------------------------------------------------
-- Fixed: Count distinct SCVs, verify they were in a conflict, sample multi-removal variants
WITH removed_scvs_in_conflicts AS (
  SELECT
    sc.variation_id,
    sc.scv_id,
    sc.prev_is_contributing
  FROM `clinvar_ingest.monthly_conflict_scv_changes` sc
  WHERE sc.snapshot_release_date = '2025-05-04'  -- Adjust date if needed
    AND sc.scv_change_status = 'removed'
    AND sc.prev_vcv_is_conflicting = TRUE  -- Only SCVs that were in a conflict
),

-- Find variants with multiple SCVs removed
multi_removal_variants AS (
  SELECT
    variation_id,
    COUNT(DISTINCT scv_id) AS scv_count
  FROM removed_scvs_in_conflicts
  GROUP BY variation_id
  HAVING COUNT(DISTINCT scv_id) > 1
)

SELECT
  CASE
    WHEN r.prev_is_contributing THEN 'Contributing (affected conflict)'
    ELSE 'Non-contributing (lower tier)'
  END AS contribution_status,
  COUNT(DISTINCT r.scv_id) AS scvs_removed,
  COUNT(DISTINCT r.variation_id) AS variants_affected,
  -- Sample of 5 variants with multiple SCVs removed
  ARRAY_AGG(DISTINCT CASE WHEN m.variation_id IS NOT NULL THEN r.variation_id END IGNORE NULLS LIMIT 5) AS sample_multi_removal_variants
FROM removed_scvs_in_conflicts r
LEFT JOIN multi_removal_variants m
  ON m.variation_id = r.variation_id
GROUP BY r.prev_is_contributing
ORDER BY scvs_removed DESC;


-- Query 6: Did the removal resolve or just modify the conflicts?
-- ----------------------------------------------------------------------------
SELECT
  vcv_change_status,
  COUNT(*) AS variant_count,
  SUM(contributing_scvs_removed_count) AS contributing_scvs_removed,
  SUM(lower_tier_scvs_removed_count) AS lower_tier_scvs_removed
FROM `clinvar_ingest.monthly_conflict_vcv_scv_summary`
WHERE snapshot_release_date = '2025-05-04'  -- Adjust date if needed
  AND scvs_removed_count > 0
GROUP BY vcv_change_status
ORDER BY variant_count DESC;


-- Query 7: Sample of specific variants with scv_removed in 2025-05
-- ----------------------------------------------------------------------------
SELECT
  v.variation_id,
  v.vcv_change_status,
  v.prev_vcv_is_conflicting,
  v.curr_vcv_is_conflicting,
  v.scvs_removed_count,
  v.scvs_removed,
  v.contributing_scvs_removed_count,
  v.scvs_removed_contributing,
  v.scv_reasons_with_counts
FROM `clinvar_ingest.monthly_conflict_vcv_scv_summary` v
WHERE v.snapshot_release_date = '2025-05-04'  -- Adjust date if needed
  AND v.scvs_removed_count > 0
ORDER BY v.contributing_scvs_removed_count DESC, v.scvs_removed_count DESC
LIMIT 50;


-- Query 8: Compare 2025-05 to previous months - is this an anomaly?
-- ----------------------------------------------------------------------------
WITH monthly_stats AS (
  SELECT
    FORMAT_DATE('%Y-%m', snapshot_release_date) AS month,
    COUNT(*) AS total_removed,
    COUNT(DISTINCT prev_submitter_id) AS unique_submitters,
    COUNT(DISTINCT variation_id) AS unique_variants
  FROM `clinvar_ingest.monthly_conflict_scv_changes`
  WHERE scv_change_status = 'removed'
  GROUP BY snapshot_release_date
)
SELECT
  month,
  total_removed,
  unique_submitters,
  unique_variants,
  -- Calculate z-score relative to historical average
  ROUND((total_removed - AVG(total_removed) OVER()) / NULLIF(STDDEV(total_removed) OVER(), 0), 2) AS z_score
FROM monthly_stats
ORDER BY month DESC;


-- Query 9: Investigate a specific SCV's history across releases
-- ----------------------------------------------------------------------------
-- Use this to verify if an SCV was truly removed or just left conflict tracking
-- Replace 2405717 with the SCV ID you want to investigate

-- 9a: Check all snapshots where this SCV appears (in conflict tracking)
SELECT
  snapshot_release_date,
  variation_id,
  scv_id,
  scv_version,
  full_scv_id,
  submitter_name,
  clinsig_type,
  submitted_classification,
  is_flagged,
  is_contributing,
  scv_rank
FROM `clinvar_ingest.monthly_conflict_scv_snapshots`
WHERE scv_id = 2405717  -- Replace with SCV ID to investigate
ORDER BY snapshot_release_date;

-- 9b: Check all change events for this SCV
SELECT
  snapshot_release_date,
  prev_snapshot_release_date,
  variation_id,
  scv_id,
  scv_change_status,
  prev_scv_version,
  curr_scv_version,
  prev_clinsig_type,
  curr_clinsig_type,
  prev_submitter_name,
  curr_submitter_name,
  prev_vcv_is_conflicting,
  curr_vcv_is_conflicting
FROM `clinvar_ingest.monthly_conflict_scv_changes`
WHERE scv_id = 2405717  -- Replace with SCV ID to investigate
ORDER BY snapshot_release_date;

-- 9c: Check if the SCV exists in the current ClinVar data (outside conflict tracking)
-- This checks the raw scv_summary table to see if the SCV still exists
SELECT
  id,
  version,
  variation_id,
  submitter_id,
  classification_abbrev,
  submitted_classification,
  last_evaluated,
  review_status,
  rank
FROM `clinvar_ingest.clinvar_scvs`
WHERE id = 'SCV002405717'  -- Use string format with SCV prefix
ORDER BY version DESC
LIMIT 5;
