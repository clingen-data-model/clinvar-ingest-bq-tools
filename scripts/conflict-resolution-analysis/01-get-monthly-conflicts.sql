-- ============================================================================
-- Script: 01-get-monthly-conflicts.sql
--
-- Description:
--   Creates a table of monthly conflict snapshots for all variants starting
--   from January 2023. For each month, captures all variants in a conflict
--   state as of the first release of that month. This serves as the foundation
--   for tracking conflict resolution over time and measuring curation impact.
--
-- Output Table:
--   - clinvar_ingest.monthly_conflict_snapshots
--
-- Source Tables:
--   - clinvar_ingest.clinvar_vcv_classifications
--     The authoritative source for VCV aggregate classification status.
--     Variants are only included if agg_classification_description LIKE 'Conflicting%'
--   - clinvar_ingest.clinvar_sum_vsp_rank_group
--     Pre-computed aggregations of SCVs grouped by variation_id, statement_type,
--     gks_proposition_type, and rank (star rating). Used for conflict details.
--   - clinvar_ingest.all_schemas() table function
--     Returns all available release dates with schema_name, release_date,
--     prev_release_date, and next_release_date.
--
-- Conflict Detection:
--   A variant is considered "in conflict" if and only if:
--   1. The VCV's agg_classification_description starts with 'Conflicting'
--      (from clinvar_vcv_classifications - the authoritative source)
--   2. AND it has conflicting SCVs at the determining rank tier
--
--   This ensures alignment with ClinVar's official classification. Conflicts
--   at lower-tier ranks that are "masked" by agreement at higher tiers are
--   NOT counted as conflicts (matching ClinVar's behavior).
--
-- agg_sig_type Bitmask (from clinvar_sum_vsp_rank_group):
--   agg_sig_type is a bitmask combining three classification tiers:
--     bit 1 (value 1) = non-clinsig (Benign, Likely benign)
--     bit 2 (value 2) = uncertain (VUS, Uncertain significance)
--     bit 4 (value 4) = clinsig (Pathogenic, Likely pathogenic, risk alleles)
--
--   Conflict values (when multiple tiers are present):
--     3 (1+2) = non-clinsig + uncertain       = NON-CLINSIG CONFLICT (B/LB vs VUS)
--     5 (1+4) = non-clinsig + clinsig         = CLINSIG CONFLICT (B/LB vs P/LP)
--     6 (2+4) = uncertain + clinsig           = CLINSIG CONFLICT (VUS vs P/LP)
--     7 (1+2+4) = all three tiers             = CLINSIG CONFLICT (all conflicting)
--
--   Non-conflict values:
--     1 = only non-clinsig (concordant B/LB)
--     2 = only uncertain (concordant VUS)
--     4 = only clinsig (concordant P/LP)
--
-- Key Fields Returned:
--   - variation_id: The variant identifier
--   - rank: Star ranking (0-4, max rank of SCVs in this group)
--   - agg_sig_type: Bitmask indicating which classification tiers are present
--   - clinsig_conflict: TRUE if agg_sig_type in (5,6,7), FALSE if 3 (non-clinsig)
--   - has_outlier: TRUE if any significance tier represents <= 33% of submissions
--   - agg_classif: Slash-separated list of classifications
--   - agg_classif_w_count: Classifications with counts (e.g., "Benign(2)/Pathogenic(3)")
--   - submitter_count: Number of distinct submitters contributing to conflict
--   - submission_count: Number of SCVs contributing to conflict
--   - snapshot_release_date: The monthly release date for this snapshot
--   - total_path_variants: Total distinct variants with gks_proposition_type='path'
--                          (pathogenicity assertions) for this release
--   - variants_with_conflict_potential: Count of variants with 2+ SCVs at their
--                          contributing tier. For 1-star or 2-star VCVs, counts variants
--                          with 2+ 1-star SCVs. For 0-star VCVs, counts variants with
--                          2+ 0-star SCVs. This is the meaningful denominator for
--                          conflict rate calculation since only these variants could
--                          potentially have a conflict.
--
-- Deduplication Logic:
--   When a variant has multiple conflicting groups (by statement_type,
--   gks_proposition_type, or rank), we keep only the highest-priority record
--   using: ORDER BY rank DESC, agg_sig_type DESC
--   This prioritizes higher star rankings and clinsig conflicts over non-clinsig.
--
-- Usage:
--   Run this script to create/refresh the monthly_conflict_snapshots table.
--   Use for month-to-month comparison to identify new conflicts, resolved
--   conflicts, and continuing conflicts over time.
-- ============================================================================

CREATE OR REPLACE TABLE `clinvar_ingest.monthly_conflict_snapshots` AS

-- Define the monthly release dates (first release of each month starting Jan 2023)
WITH monthly_releases AS (
  SELECT release_date
  FROM `clinvar_ingest.all_schemas`()
  WHERE release_date >= DATE'2023-01-01'
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY DATE_TRUNC(release_date, MONTH)
    ORDER BY release_date ASC
  ) = 1
),

-- Count total pathogenicity variants per monthly release (baseline denominator)
-- Using gks_proposition_type = 'path' for consistency with SCV-level tracking
monthly_path_totals AS (
  SELECT
    r.release_date AS snapshot_release_date,
    COUNT(DISTINCT vrg.variation_id) AS total_path_variants
  FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
  CROSS JOIN monthly_releases r
  WHERE
    vrg.gks_proposition_type = 'path'
    AND r.release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
  GROUP BY r.release_date
),

-- Count variants with conflict potential: 2+ SCVs at their contributing tier
-- A variant has conflict potential only if there are 2+ SCVs at the tier that
-- determines its classification:
--   - For 1-star or 2-star VCVs: need 2+ 1-star SCVs
--   - For 0-star VCVs: need 2+ 0-star SCVs
-- We first identify each VCV's determining rank, then check if that rank has 2+ SCVs
variants_with_potential AS (
  SELECT
    r.release_date AS snapshot_release_date,
    vrg.variation_id,
    -- VCV rank is the highest rank with SCVs for this variant
    MAX(vrg.rank) AS vcv_rank,
    -- Check if there are 2+ SCVs at rank 1 (contributing tier for 1-star+ VCVs)
    MAX(CASE WHEN vrg.rank = 1 AND vrg.submission_count >= 2 THEN 1 ELSE 0 END) AS has_1star_potential,
    -- Check if there are 2+ SCVs at rank 0 (contributing tier for 0-star VCVs)
    MAX(CASE WHEN vrg.rank = 0 AND vrg.submission_count >= 2 THEN 1 ELSE 0 END) AS has_0star_potential
  FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
  CROSS JOIN monthly_releases r
  WHERE
    vrg.gks_proposition_type = 'path'
    AND vrg.rank IN (0, 1, 2)  -- Only consider ranks that can have conflicts (not 3-4 star expert panels)
    AND r.release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
  GROUP BY r.release_date, vrg.variation_id
),

-- Aggregate conflict potential counts per month
monthly_conflict_potential AS (
  SELECT
    snapshot_release_date,
    -- A variant has conflict potential if:
    --   - VCV rank >= 1 AND has 2+ 1-star SCVs, OR
    --   - VCV rank = 0 AND has 2+ 0-star SCVs
    COUNT(DISTINCT CASE
      WHEN (vcv_rank >= 1 AND has_1star_potential = 1)
        OR (vcv_rank = 0 AND has_0star_potential = 1)
      THEN variation_id
    END) AS variants_with_conflict_potential
  FROM variants_with_potential
  GROUP BY snapshot_release_date
),

-- Get variants that are officially in conflict state per ClinVar's VCV classification
-- This is the authoritative source - only variants where agg_classification_description
-- starts with 'Conflicting' are truly in conflict
authoritative_conflicts AS (
  SELECT
    vcv.variation_id,
    r.release_date AS snapshot_release_date
  FROM `clinvar_ingest.clinvar_vcv_classifications` vcv
  CROSS JOIN monthly_releases r
  WHERE
    vcv.agg_classification_description LIKE 'Conflicting%'
    AND r.release_date BETWEEN vcv.start_release_date AND vcv.end_release_date
),

-- Get conflict snapshots for each monthly release
-- IMPORTANT: Require BOTH conditions to be true:
--   1. VCV classification says "Conflicting%" (authoritative source)
--   2. AND the rank group actually shows a conflict (agg_sig_type IN 3,5,6,7)
-- This excludes edge cases where VCV classification is stale (SCVs removed/flagged
-- but VCV not yet updated) - those are false positives we want to exclude.
monthly_conflicts AS (
  SELECT
    ac.variation_id,
    ac.snapshot_release_date,
    vrg.rank,
    vrg.agg_sig_type,
    vrg.agg_classif,
    vrg.agg_classif_w_count,
    vrg.submitter_count,
    vrg.submission_count,
    vrg.start_release_date,
    vrg.end_release_date,
    (vrg.agg_sig_type IN (5, 6, 7)) AS clinsig_conflict,
    COALESCE(
      (
        SELECT MIN(st.PERCENT) <= 0.333
        FROM UNNEST(vrg.sig_type) AS st
        WHERE st.PERCENT > 0
      ),
      FALSE
    ) AS has_outlier
  FROM authoritative_conflicts ac
  INNER JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
    ON vrg.variation_id = ac.variation_id
    AND vrg.gks_proposition_type = 'path'
    AND vrg.agg_sig_type IN (3, 5, 6, 7)  -- Must actually have conflicting SCVs
    AND ac.snapshot_release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
  -- Keep only the highest-priority conflicting record per variant per month
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ac.snapshot_release_date, ac.variation_id
    ORDER BY vrg.rank DESC, vrg.agg_sig_type DESC
  ) = 1
)

SELECT
  mc.*,
  pt.total_path_variants,
  cp.variants_with_conflict_potential
FROM monthly_conflicts mc
JOIN monthly_path_totals pt USING (snapshot_release_date)
JOIN monthly_conflict_potential cp USING (snapshot_release_date)
ORDER BY snapshot_release_date, variation_id
