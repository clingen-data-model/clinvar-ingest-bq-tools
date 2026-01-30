-- ============================================================================
-- Script: 02-concordance-breakdown.sql
--
-- Description:
--   Produces a ClinVar Miner-style concordance breakdown showing the count
--   of variants by their submission agreement/conflict status. Categorizes
--   variants into conflicts, confidence differences, expert panel reviews,
--   concordant multi-submission, and single-submission groups.
--
-- Scope:
--   All GermlineClassification variants from the latest ClinVar release.
--   Uses max top_rank per variation_id, prioritizing 'path' over 'oth'
--   gks_proposition_type when both exist.
--
-- Source Tables:
--   - clinvar_ingest.clinvar_sum_vsp_top_rank_group_change
--     Identifies the top_rank per variation_id/proposition_type for each
--     release window. Used to select the determining rank group.
--   - clinvar_ingest.clinvar_sum_vsp_rank_group
--     SCV-level aggregation with agg_sig_type bitmask and agg_classif
--     (slash-separated classif_type codes). Joined at top_rank.
--   - clinvar_ingest.all_schemas() table function
--     Available release dates.
--
-- Categorization Logic (applied in priority order, first match wins):
--   1. Conflict (P/LP vs VUS/LB/B): agg_sig_type IN (5, 6, 7)
--   2. Conflict (VUS vs LB/B): agg_sig_type = 3
--   3. Confidence Difference (P vs LP or B vs LB):
--        agg_sig_type = 4 with both P-related AND LP-related terms in agg_classif
--        OR agg_sig_type = 1 with both B-related AND LB-related terms in agg_classif
--        P-related terms: 'p', 'p-lp', 'era'
--        LP-related terms: 'lp', 'lp-lp', 'lra'
--        B-related term: 'b'
--        LB-related term: 'lb'
--   4. Expert Panel: top_rank >= 3 for 'path' gks_proposition_type
--   5. >= 2 Concordant: agg_sig_type IN (1, 2, 4) AND submission_count >= 2
--      for 'path' gks_proposition_type
--   6. 1 Submission: top_rank IN (0, 1) for 'path' gks_proposition_type
--   7. not provided/other: all remaining
--
-- Output Columns:
--   concordance_status - Concordance category label
--   variants           - Count of distinct variants in that category
--   pct                - Percentage of total variants in this category
--   release_date       - ClinVar release date used for this snapshot
--
-- Output View:
--   clinvar_ingest.clinvar_miner_concordance_breakdown
-- ============================================================================

CREATE OR REPLACE VIEW `clinvar_ingest.clinvar_miner_concordance_breakdown` AS

WITH latest_release AS (
  SELECT MAX(release_date) AS release_date
  FROM `clinvar_ingest.all_schemas`()
),

-- All GermlineClassification top_rank records for the latest release.
-- For each variation_id, take the max top_rank. If multiple gks_proposition_types
-- exist at that max top_rank, prioritize 'path' over 'oth'.
top_rank AS (
  SELECT
    trg.variation_id,
    trg.gks_proposition_type,
    trg.top_rank,
    lr.release_date
  FROM latest_release lr
  JOIN `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` trg
    ON trg.statement_type = 'GermlineClassification'
    AND lr.release_date BETWEEN trg.start_release_date AND trg.end_release_date
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY trg.variation_id
    ORDER BY trg.top_rank DESC,
      CASE trg.gks_proposition_type WHEN 'path' THEN 0 ELSE 1 END
  ) = 1
),

-- Join to rank_group at the determining rank to get agg_sig_type and agg_classif
rank_group AS (
  SELECT
    tr.variation_id,
    tr.gks_proposition_type,
    tr.top_rank,
    tr.release_date,
    vrg.agg_sig_type,
    vrg.agg_classif,
    vrg.submission_count
  FROM top_rank tr
  JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
    ON vrg.variation_id = tr.variation_id
    AND vrg.rank = tr.top_rank
    AND vrg.gks_proposition_type = tr.gks_proposition_type
    AND tr.release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
),

-- Categorize each variant
categorized AS (
  SELECT
    rg.variation_id,
    rg.release_date,
    CASE
      -- 1. Clinically significant conflict
      WHEN rg.agg_sig_type IN (5, 6, 7)
        THEN 'Conflict (P/LP vs VUS/LB/B)'
      -- 2. Non-clinically significant conflict
      WHEN rg.agg_sig_type = 3
        THEN 'Conflict (VUS vs LB/B)'
      -- 3. Confidence difference: concordant tier but mixed confidence levels
      WHEN rg.agg_sig_type = 4
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('lp', 'lp-lp', 'lra'))
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('p', 'p-lp', 'era'))
        THEN 'Confidence Difference (P vs LP or B vs LB)'
      WHEN rg.agg_sig_type = 1
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'lb')
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'b')
        THEN 'Confidence Difference (P vs LP or B vs LB)'
      -- 4. Expert Panel: high-star path variants
      WHEN rg.gks_proposition_type = 'path' AND rg.top_rank >= 3
        THEN 'Expert Panel'
      -- 5. Concordant with 2+ submissions
      WHEN rg.gks_proposition_type = 'path' AND rg.agg_sig_type IN (1, 2, 4)
        AND rg.submission_count >= 2
        THEN '>= 2 Concordant'
      -- 6. Single submission
      WHEN rg.gks_proposition_type = 'path' AND rg.top_rank IN (0, 1)
        THEN '1 Submission'
      ELSE 'not provided/other'
    END AS concordance_status,
    CASE
      WHEN rg.agg_sig_type IN (5, 6, 7) THEN 1
      WHEN rg.agg_sig_type = 3 THEN 2
      WHEN rg.agg_sig_type = 4
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('lp', 'lp-lp', 'lra'))
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t IN ('p', 'p-lp', 'era'))
        THEN 3
      WHEN rg.agg_sig_type = 1
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'lb')
        AND EXISTS (SELECT 1 FROM UNNEST(SPLIT(rg.agg_classif, '/')) t WHERE t = 'b')
        THEN 3
      WHEN rg.gks_proposition_type = 'path' AND rg.top_rank >= 3 THEN 4
      WHEN rg.gks_proposition_type = 'path' AND rg.agg_sig_type IN (1, 2, 4)
        AND rg.submission_count >= 2 THEN 5
      WHEN rg.gks_proposition_type = 'path' AND rg.top_rank IN (0, 1) THEN 6
      ELSE 7
    END AS sort_order
  FROM rank_group rg
)

SELECT
  concordance_status,
  COUNT(DISTINCT variation_id) AS variants,
  ROUND(COUNT(DISTINCT variation_id) * 100.0 / SUM(COUNT(DISTINCT variation_id)) OVER (), 2) AS pct,
  release_date
FROM categorized
GROUP BY concordance_status, sort_order, release_date
ORDER BY sort_order;
