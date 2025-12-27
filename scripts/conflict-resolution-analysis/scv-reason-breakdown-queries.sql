-- ============================================================================
-- SCV Reason Breakdown Queries
-- ============================================================================
-- These queries show resolved variants with their reasons and the SCVs
-- associated with each reason.
--
-- RESOLUTION-FOCUSED: These queries only include SCVs that are causally
-- relevant to the resolution. Lower-tier SCVs (e.g., 0-star SCVs on a 1-star
-- conflict) are excluded because they don't determine the VCV's classification.
--
-- VCV-LEVEL REASONS (tier supersession):
-- - higher_rank_scv_added: Use scvs_added_higher_rank (new 1-star SCVs supersede 0-star conflict)
-- - vcv_rank_changed: Use scvs_rank_upgraded (existing SCV upgraded to 1-star)
-- - expert_panel_added: Use scvs_added_higher_rank (3/4-star SCVs added)
--
-- CONTRIBUTING TIER REASONS (for resolutions and modifications):
-- - scv_removed: scvs_removed_contributing (contributing SCVs withdrawn)
-- - scv_flagged: scvs_flagged_contributing (contributing SCVs flagged)
-- - scv_reclassified: scvs_reclassified_contributing (contributing SCVs changed classification)
-- - scv_rank_downgraded: scvs_rank_downgraded (SCVs demoted from contributing tier, excludes flagged)
--
-- MODIFICATION-ONLY REASONS (never apply to resolutions):
-- - scv_added: scvs_added_contributing (new SCVs at contributing tier)
-- - outlier_status_changed: Gained or lost outlier status
-- - conflict_type_changed: Changed between clinsig and non-clinsig
--
-- NOTE: scv_added only appears for modifications because when SCVs are added and
-- a conflict resolves, a higher-priority reason (like expert_panel_added or
-- higher_rank_scv_added) always takes precedence.
--
-- CONTEXT-BASED REASONS (no specific SCV array):
-- - single_submitter_withdrawn: Only had one submitter who withdrew
-- - outlier_reclassified: Outlier submitter changed classification
-- - unknown: No identifiable reason (fallback)
--
-- Use prev_vcv_rank and curr_vcv_rank to understand tier transitions.
--
-- NOTE: higher_rank_scv_added and vcv_rank_changed only apply to 0-star conflicts
-- being superseded by 1-star SCVs. For 1-star conflicts, only expert_panel_added
-- can supersede (no 2-star SCVs exist in ClinVar).
-- ============================================================================

-- Query 1: Resolved variants with reasons and associated SCVs
-- Replace the date in the WHERE clause with your target snapshot date

WITH resolved_variants AS (
  SELECT
    d.variation_id,
    d.conflict_type,
    d.outlier_status,
    d.primary_reason,
    d.scv_reasons,
    d.scv_reasons_with_counts,
    -- VCV-level reason arrays (for higher_rank_scv_added and vcv_rank_changed)
    s.scvs_added_higher_rank,
    s.scvs_rank_upgraded,
    -- Contributing tier arrays
    s.scvs_added_contributing,
    s.scvs_removed_contributing,
    s.scvs_flagged_contributing,
    s.scvs_reclassified_contributing,
    s.scvs_rank_downgraded,
    s.prev_vcv_rank,
    s.curr_vcv_rank
  FROM `clinvar_ingest.conflict_vcv_change_detail` d
  LEFT JOIN `clinvar_ingest.monthly_conflict_vcv_scv_summary` s
    ON s.variation_id = d.variation_id
    AND s.snapshot_release_date = d.snapshot_release_date
  WHERE d.snapshot_release_date = DATE '2024-10-09'  -- <-- Change this date
    AND d.vcv_change_status = 'resolved'
)

SELECT
  variation_id,
  conflict_type,
  outlier_status,
  primary_reason,
  scv_reasons_with_counts,
  -- Build a struct for each reason with its associated SCVs
  STRUCT(
    -- VCV-level reasons (tier supersession)
    CASE WHEN ARRAY_LENGTH(scvs_added_higher_rank) > 0
         THEN STRUCT('higher_rank_scv_added' AS reason, scvs_added_higher_rank AS scv_ids)
    END AS higher_rank_added,
    CASE WHEN ARRAY_LENGTH(scvs_rank_upgraded) > 0
         THEN STRUCT('vcv_rank_changed' AS reason, scvs_rank_upgraded AS scv_ids)
    END AS rank_upgraded,
    -- Contributing tier reasons (high priority)
    CASE WHEN ARRAY_LENGTH(scvs_added_contributing) > 0
         THEN STRUCT('scv_added' AS reason, scvs_added_contributing AS scv_ids)
    END AS added_contributing,
    CASE WHEN ARRAY_LENGTH(scvs_removed_contributing) > 0
         THEN STRUCT('scv_removed' AS reason, scvs_removed_contributing AS scv_ids)
    END AS removed_contributing,
    CASE WHEN ARRAY_LENGTH(scvs_flagged_contributing) > 0
         THEN STRUCT('scv_flagged' AS reason, scvs_flagged_contributing AS scv_ids)
    END AS flagged_contributing,
    CASE WHEN ARRAY_LENGTH(scvs_reclassified_contributing) > 0
         THEN STRUCT('scv_reclassified' AS reason, scvs_reclassified_contributing AS scv_ids)
    END AS reclassified_contributing,
    CASE WHEN ARRAY_LENGTH(scvs_rank_downgraded) > 0
         THEN STRUCT('scv_rank_downgraded' AS reason, scvs_rank_downgraded AS scv_ids)
    END AS rank_downgraded
  ) AS scvs_by_reason,
  prev_vcv_rank,
  curr_vcv_rank
FROM resolved_variants
ORDER BY primary_reason, variation_id;

-- Or if you prefer a flatter format with one row per reason per variant:
-- Flattened view: one row per reason per resolved variant
-- Replace the date in the WHERE clause with your target snapshot date

WITH resolved_variants AS (
  SELECT
    d.variation_id,
    d.conflict_type,
    d.outlier_status,
    d.primary_reason,
    -- VCV-level reason arrays (tier supersession)
    s.scvs_added_higher_rank,
    s.scvs_rank_upgraded,
    -- Contributing tier arrays
    s.scvs_added_contributing,
    s.scvs_removed_contributing,
    s.scvs_flagged_contributing,
    s.scvs_reclassified_contributing,
    s.scvs_rank_downgraded
  FROM `clinvar_ingest.conflict_vcv_change_detail` d
  LEFT JOIN `clinvar_ingest.monthly_conflict_vcv_scv_summary` s
    ON s.variation_id = d.variation_id
    AND s.snapshot_release_date = d.snapshot_release_date
  WHERE d.snapshot_release_date = DATE '2024-10-09'  -- <-- Change this date
    AND d.vcv_change_status = 'resolved'
),

reason_scv_pairs AS (
  -- VCV-level reasons (tier supersession)
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'higher_rank_scv_added' AS reason, 'vcv' AS tier, scvs_added_higher_rank AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_added_higher_rank) > 0
  UNION ALL
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'vcv_rank_changed' AS reason, 'vcv' AS tier, scvs_rank_upgraded AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_rank_upgraded) > 0
  UNION ALL
  -- Contributing tier reasons (high priority)
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'scv_added' AS reason, 'contributing' AS tier, scvs_added_contributing AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_added_contributing) > 0
  UNION ALL
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'scv_removed' AS reason, 'contributing' AS tier, scvs_removed_contributing AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_removed_contributing) > 0
  UNION ALL
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'scv_flagged' AS reason, 'contributing' AS tier, scvs_flagged_contributing AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_flagged_contributing) > 0
  UNION ALL
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'scv_reclassified' AS reason, 'contributing' AS tier, scvs_reclassified_contributing AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_reclassified_contributing) > 0
  UNION ALL
  SELECT variation_id, conflict_type, outlier_status, primary_reason,
         'scv_rank_downgraded' AS reason, 'contributing' AS tier, scvs_rank_downgraded AS scv_ids
  FROM resolved_variants WHERE ARRAY_LENGTH(scvs_rank_downgraded) > 0
)

SELECT
  variation_id,
  conflict_type,
  outlier_status,
  primary_reason,
  reason,
  tier,
  ARRAY_TO_STRING(scv_ids, ', ') AS scv_ids_list,
  ARRAY_LENGTH(scv_ids) AS scv_count
FROM reason_scv_pairs
ORDER BY variation_id, tier, reason;


-- Or a simple summary view:
-- Simple summary of resolved variants with all reasons and SCVs in one row
-- Replace the date in the WHERE clause with your target snapshot date

SELECT
  d.variation_id,
  d.conflict_type,
  d.outlier_status,
  d.primary_reason,
  d.scv_reasons_with_counts,
  s.prev_vcv_rank,
  s.curr_vcv_rank,
  -- VCV-level reason SCVs (tier supersession)
  ARRAY_TO_STRING(s.scvs_added_higher_rank, ', ') AS scvs_added_higher_rank,
  ARRAY_TO_STRING(s.scvs_rank_upgraded, ', ') AS scvs_rank_upgraded,
  -- Contributing tier SCVs
  ARRAY_TO_STRING(s.scvs_added_contributing, ', ') AS scvs_added_contributing,
  ARRAY_TO_STRING(s.scvs_removed_contributing, ', ') AS scvs_removed_contributing,
  ARRAY_TO_STRING(s.scvs_flagged_contributing, ', ') AS scvs_flagged_contributing,
  ARRAY_TO_STRING(s.scvs_reclassified_contributing, ', ') AS scvs_reclassified_contributing,
  ARRAY_TO_STRING(s.scvs_rank_downgraded, ', ') AS scvs_rank_downgraded
FROM `clinvar_ingest.conflict_vcv_change_detail` d
LEFT JOIN `clinvar_ingest.monthly_conflict_vcv_scv_summary` s
  ON s.variation_id = d.variation_id
  AND s.snapshot_release_date = d.snapshot_release_date
WHERE d.snapshot_release_date = DATE '2024-10-09'  -- <-- Change this date
  AND d.vcv_change_status = 'resolved'
ORDER BY d.primary_reason, d.variation_id;
