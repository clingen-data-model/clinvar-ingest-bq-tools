-- ============================================================================
-- Script: 01-pathogenicity-breakdown.sql
--
-- Description:
--   Produces a ClinVar Miner-style pathogenicity breakdown showing the count
--   of variants by their aggregate Germline Classification significance
--   category. Conflicts are split into clinically significant conflicts
--   (P/LP vs VUS/LB/B) and non-clinically significant conflicts (VUS vs LB/B)
--   using the agg_sig_type bitmask from clinvar_sum_vsp_rank_group.
--
-- Scope:
--   All Germline Classification variants with proposition_type in
--   ('path', 'oth') for each ClinVar release date supplied in the
--   release_dates argument. Each release date is snapshotted independently
--   and returned in a single result set (distinguished by release_date).
--   Pass a single date (e.g. the latest release) for a single snapshot.
--
-- Arguments:
--   release_dates ARRAY<DATE> - One or more ClinVar release dates to produce
--     the breakdown for. Each must fall within an available release window.
--
-- Source Tables:
--   - clinvar_ingest.clinvar_sum_vsp_top_rank_group_change
--     Identifies the top_rank per variation_id/proposition_type for each
--     release window. Used to select the determining rank group.
--   - clinvar_ingest.clinvar_sum_vsp_rank_group
--     SCV-level aggregation with agg_sig_type bitmask and agg_classif
--     (slash-separated classif_type codes). Joined at top_rank.
--
-- Categorization Logic (applied in priority order, first match wins):
--   1. Conflict (P/LP vs VUS/LB/B): agg_sig_type IN (5, 6, 7)
--   2. Conflict (VUS vs LB/B): agg_sig_type = 3
--   3. For remaining (agg_sig_type NOT IN 3, 5, 6, 7), split agg_classif on
--      '/' to get individual terms. First group containing a matching term wins:
--        Likely pathogenic: any term IN ('lp', 'lp-lp', 'lra')
--        Pathogenic:        any term IN ('p', 'p-lp', 'era')
--        VUS:               any term IN ('vus', 'ura')
--        Likely benign:     any term IN ('lb')
--        Benign:            any term IN ('b')
--        not provided/other: no terms matched any group
--
-- Output Columns:
--   submission_significance - Classification category label
--   variants               - Count of distinct variants in that category
--   pct                    - Percentage of total variants in this category
--                            (within the same release_date)
--   release_date           - ClinVar release date used for this snapshot
--
-- Output Procedure:
--   clinvar_ingest.clinvar_miner_pathogenicity_breakdown(release_dates ARRAY<DATE>)
--
-- Example:
--   CALL `clinvar_ingest.clinvar_miner_pathogenicity_breakdown`(
--     [DATE'2024-01-07', DATE'2024-02-01']);
-- ============================================================================

CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_miner_pathogenicity_breakdown`(
  release_dates ARRAY<DATE>
)
BEGIN

  WITH
  -- The set of release dates to produce the breakdown for.
  releases AS (
    SELECT release_date
    FROM UNNEST(release_dates) AS release_date
  ),

  -- All GermlineClassification top_rank records for each requested release.
  -- For each release_date/variation_id, take the max top_rank. If multiple
  -- proposition_types exist at that max top_rank, prioritize 'path' over 'oth'.
  top_rank AS (
    SELECT
      trg.variation_id,
      trg.proposition_type,
      trg.top_rank,
      r.release_date
    FROM releases r
    JOIN `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` trg
      ON trg.statement_type = 'GermlineClassification'
      AND r.release_date BETWEEN trg.start_release_date AND trg.end_release_date
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY r.release_date, trg.variation_id
      ORDER BY trg.top_rank DESC,
        CASE trg.proposition_type WHEN 'path' THEN 0 ELSE 1 END
    ) = 1
  ),

  -- Join to rank_group at the determining rank to get agg_sig_type and agg_classif
  rank_group AS (
    SELECT
      tr.variation_id,
      tr.release_date,
      vrg.agg_sig_type,
      vrg.agg_classif
    FROM top_rank tr
    JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
      ON vrg.variation_id = tr.variation_id
      AND vrg.rank = tr.top_rank
      AND vrg.proposition_type = tr.proposition_type
      AND tr.release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
  ),

  -- Categorize each variant
  categorized AS (
    SELECT
      rg.variation_id,
      rg.release_date,
      CASE
        WHEN rg.agg_sig_type IN (5, 6, 7)
          THEN 'Conflict (P/LP vs VUS/LB/B)'
        WHEN rg.agg_sig_type = 3
          THEN 'Conflict (VUS vs LB/B)'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('lp', 'lp-lp', 'lra'))
          THEN 'Likely pathogenic'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('p', 'p-lp', 'era'))
          THEN 'Pathogenic'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('vus', 'ura'))
          THEN 'VUS'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'lb')
          THEN 'Likely benign'
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'b')
          THEN 'Benign'
        ELSE 'not provided/other'
      END AS submission_significance,
      CASE
        WHEN rg.agg_sig_type IN (5, 6, 7) THEN 3
        WHEN rg.agg_sig_type = 3 THEN 5
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('lp', 'lp-lp', 'lra')) THEN 1
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('p', 'p-lp', 'era')) THEN 2
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('vus', 'ura')) THEN 4
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'lb') THEN 6
        WHEN EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'b') THEN 7
        ELSE 8
      END AS sort_order
    FROM rank_group rg
  )

  SELECT
    submission_significance,
    COUNT(DISTINCT variation_id) AS variants,
    ROUND(COUNT(DISTINCT variation_id) * 100.0 / SUM(COUNT(DISTINCT variation_id)) OVER (PARTITION BY release_date), 2) AS pct,
    release_date
  FROM categorized
  GROUP BY submission_significance, sort_order, release_date
  ORDER BY release_date, sort_order;

END;

-- ============================================================================
-- Supplemental: Breakdown of "not provided/other" agg_classif values
--
-- Shows the individual agg_classif values that fall into the
-- "not provided/other" bucket, with variant counts sorted descending.
-- ============================================================================
--
-- WITH releases AS (
--   SELECT release_date FROM UNNEST([DATE'2024-01-07']) AS release_date
-- ),
-- top_rank AS (
--   SELECT trg.variation_id, trg.proposition_type, trg.top_rank, r.release_date
--   FROM releases r
--   JOIN `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` trg
--     ON trg.statement_type = 'GermlineClassification'
--     AND r.release_date BETWEEN trg.start_release_date AND trg.end_release_date
--   QUALIFY ROW_NUMBER() OVER (
--     PARTITION BY r.release_date, trg.variation_id
--     ORDER BY trg.top_rank DESC,
--       CASE trg.proposition_type WHEN 'path' THEN 0 ELSE 1 END
--   ) = 1
-- )
-- SELECT
--   tr.release_date,
--   vrg.agg_classif,
--   COUNT(DISTINCT tr.variation_id) AS variants
-- FROM top_rank tr
-- JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
--   ON vrg.variation_id = tr.variation_id
--   AND vrg.rank = tr.top_rank
--   AND vrg.proposition_type = tr.proposition_type
--   AND tr.release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
-- WHERE vrg.agg_sig_type NOT IN (3, 5, 6, 7)
--   AND NOT EXISTS (SELECT 1 FROM UNNEST(SPLIT(vrg.agg_classif, '/')) t
--     WHERE t IN ('p', 'p-lp', 'era', 'lp', 'lp-lp', 'lra', 'vus', 'ura', 'lb', 'b'))
-- GROUP BY tr.release_date, vrg.agg_classif
-- ORDER BY tr.release_date, variants DESC;
