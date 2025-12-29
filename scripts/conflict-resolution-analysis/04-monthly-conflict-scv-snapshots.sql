-- ============================================================================
-- Script: 04-monthly-conflict-scv-snapshots.sql
--
-- GCS SYNC REMINDER:
--   This file is loaded by the Cloud Function from GCS. After making changes,
--   sync to GCS:  gsutil cp scripts/conflict-resolution-analysis/0*.sql \
--                           gs://clinvar-ingest/conflict-analytics-sql/
--
-- Description:
--   Creates a table of individual SCV (Submitted ClinVar) records that contribute
--   to VCV-level conflicts for each monthly snapshot. This enables detailed
--   tracking of how individual submissions change over time and contribute to
--   conflict resolution or escalation.
--
-- Output Table:
--   - clinvar_ingest.monthly_conflict_scv_snapshots
--
-- Source Tables:
--   - clinvar_ingest.clinvar_vcv_classifications - Authoritative VCV classification status
--   - clinvar_ingest.clinvar_sum_vsp_rank_group - VCV-level aggregations by rank
--   - clinvar_ingest.clinvar_scvs - Individual SCV records
--   - clinvar_ingest.all_schemas() table function - Release dates
--
-- Key Concepts:
--
--   Contributing SCVs:
--   - A VCV's classification is determined by SCVs at a specific rank tier
--   - VCV rank >= 1 (1-star or higher): 1-star SCVs contribute to aggregate
--   - VCV rank = 0: 0-star SCVs contribute to aggregate
--   - VCV rank >= 3: Expert panel SCVs determine classification (may mask conflicts)
--
--   Rank Tiers:
--   - 0-star: No assertion criteria provided
--   - 1-star: Assertion criteria provided (includes 2-star VCVs which use 1-star SCVs)
--   - 3/4-star: Expert panel or practice guideline (masks lower-rank conflicts)
--   - -3: Flagged submission (excluded from aggregation)
--
--   Filtering:
--   - Only SCVs with gks_proposition_type = 'path' (pathogenicity assertions)
--   - Only VCVs that are in conflict state OR tracked for potential conflict
--
-- Key Fields Returned:
--   Identification:
--   - snapshot_release_date: Monthly release date
--   - variation_id: VCV identifier
--   - scv_id: SCV identifier (clinvar_scvs.id)
--   - scv_version: SCV version number
--   - full_scv_id: Combined "id.version" format
--
--   VCV Context:
--   - vcv_rank: The VCV's aggregate rank for this snapshot
--   - vcv_agg_sig_type: VCV's conflict bitmask
--   - vcv_is_conflicting: TRUE if VCV is in conflict state
--
--   SCV Details:
--   - scv_rank: The SCV's own rank (0, 1, or -3 for flagged)
--   - clinsig_type: Classification category (0=BLB, 1=VUS, 2=PLP)
--   - submitted_classification: Original classification text
--   - submitter_id: Submitter identifier
--   - submitter_name: Submitter organization name
--   - last_evaluated: Date SCV was last evaluated
--   - submission_date: Date SCV was submitted
--   - review_status: Review status text (for flagged detection)
--
--   Contributing Status:
--   - is_contributing: TRUE if this SCV contributes to VCV's current aggregate
--   - contributing_rank_tier: '0-star', '1-star', '3-4-star', or NULL
--   - is_flagged: TRUE if review_status = 'flagged submission'
--
-- Usage:
--   Run after clinvar_scvs and clinvar_sum_vsp_rank_group tables are populated.
--   This table is the foundation for 05-monthly-conflict-scv-changes.sql.
-- ============================================================================

CREATE OR REPLACE TABLE `clinvar_ingest.monthly_conflict_scv_snapshots` AS

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

-- Get the previous month's release date for each monthly release
monthly_with_prev AS (
  SELECT
    release_date,
    LAG(release_date) OVER (ORDER BY release_date) AS prev_release_date
  FROM monthly_releases
),

-- Get variants that were conflicting in the PREVIOUS month
-- This allows us to track SCVs for VCVs that are being resolved in the current month
prev_month_conflicts AS (
  SELECT DISTINCT
    mwp.release_date AS snapshot_release_date,  -- Current month
    ac.variation_id
  FROM monthly_with_prev mwp
  INNER JOIN authoritative_conflicts ac
    ON ac.snapshot_release_date = mwp.prev_release_date  -- Was conflicting in prev month
  WHERE mwp.prev_release_date IS NOT NULL
    -- Exclude VCVs that are STILL conflicting in current month (already captured above)
    AND NOT EXISTS (
      SELECT 1 FROM authoritative_conflicts ac2
      WHERE ac2.variation_id = ac.variation_id
        AND ac2.snapshot_release_date = mwp.release_date
    )
),

-- Combine: VCVs currently in conflict + VCVs that were in conflict last month (now resolved)
all_tracked_conflicts AS (
  SELECT variation_id, snapshot_release_date, TRUE AS is_currently_conflicting
  FROM authoritative_conflicts
  UNION ALL
  SELECT variation_id, snapshot_release_date, FALSE AS is_currently_conflicting
  FROM prev_month_conflicts
),

-- Get VCV-level aggregations for pathogenicity assertions
-- For currently conflicting VCVs: require agg_sig_type IN (3,5,6,7)
-- For previously conflicting (now resolved) VCVs: get current state regardless of conflict status
vcv_snapshots AS (
  SELECT
    atc.snapshot_release_date,
    atc.variation_id,
    atc.is_currently_conflicting,
    vrg.rank AS vcv_rank,
    vrg.agg_sig_type AS vcv_agg_sig_type,
    vrg.unique_clinsig_type_count,
    -- VCV is conflicting based on authoritative source
    atc.is_currently_conflicting AS vcv_is_conflicting,
    -- Determine which rank tier's SCVs contribute to this VCV
    CASE
      WHEN vrg.rank >= 3 THEN '3-4-star'
      WHEN vrg.rank >= 1 THEN '1-star'
      ELSE '0-star'
    END AS contributing_scv_tier,
    -- The SCV rank that contributes (for joining)
    CASE
      WHEN vrg.rank >= 3 THEN vrg.rank  -- Expert panel: exact rank match
      WHEN vrg.rank >= 1 THEN 1         -- 1-star or 2-star VCV: 1-star SCVs contribute
      ELSE 0                            -- 0-star VCV: 0-star SCVs contribute
    END AS contributing_scv_rank
  FROM all_tracked_conflicts atc
  INNER JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` vrg
    ON vrg.variation_id = atc.variation_id
    AND vrg.gks_proposition_type = 'path'
    AND atc.snapshot_release_date BETWEEN vrg.start_release_date AND vrg.end_release_date
    -- For currently conflicting: must have conflicting SCVs
    -- For resolved: accept any state (we need to see what the SCVs look like now)
    AND (atc.is_currently_conflicting = FALSE OR vrg.agg_sig_type IN (3, 5, 6, 7))
  -- Deduplicate: keep only the highest-priority record per variant per month
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY atc.snapshot_release_date, atc.variation_id
    ORDER BY vrg.rank DESC, vrg.agg_sig_type DESC
  ) = 1
),

-- Get individual SCVs for pathogenicity assertions
scv_details AS (
  SELECT
    r.release_date AS snapshot_release_date,
    scv.variation_id,
    scv.id AS scv_id,
    scv.version AS scv_version,
    scv.full_scv_id,
    scv.rank AS scv_rank,
    scv.clinsig_type,
    scv.submitted_classification,
    scv.submitter_id,
    scv.submitter_name,
    scv.last_evaluated,
    scv.submission_date,
    scv.review_status,
    -- Flagged detection
    (scv.review_status = 'flagged submission' OR scv.rank = -3) AS is_flagged
  FROM `clinvar_ingest.clinvar_scvs` scv
  CROSS JOIN monthly_releases r
  WHERE
    scv.gks_proposition_type = 'path'
    AND r.release_date BETWEEN scv.start_release_date AND scv.end_release_date
)

-- Join VCVs with their contributing SCVs
SELECT
  v.snapshot_release_date,
  v.variation_id,

  -- VCV context
  v.vcv_rank,
  v.vcv_agg_sig_type,
  v.vcv_is_conflicting,
  v.contributing_scv_tier,

  -- SCV identification
  s.scv_id,
  s.scv_version,
  s.full_scv_id,

  -- SCV details
  s.scv_rank,
  s.clinsig_type,
  s.submitted_classification,
  s.submitter_id,
  s.submitter_name,
  s.last_evaluated,
  s.submission_date,
  s.review_status,
  s.is_flagged,

  -- Contributing status
  -- An SCV contributes if its rank matches the VCV's contributing tier
  -- (and it's not flagged)
  CASE
    WHEN s.is_flagged THEN FALSE
    WHEN v.contributing_scv_tier = '3-4-star' AND s.scv_rank >= 3 THEN TRUE
    WHEN v.contributing_scv_tier = '1-star' AND s.scv_rank = 1 THEN TRUE
    WHEN v.contributing_scv_tier = '0-star' AND s.scv_rank = 0 THEN TRUE
    ELSE FALSE
  END AS is_contributing,

  -- What tier does this SCV belong to (regardless of VCV's current tier)
  CASE
    WHEN s.is_flagged THEN 'flagged'
    WHEN s.scv_rank >= 3 THEN '3-4-star'
    WHEN s.scv_rank = 1 THEN '1-star'
    WHEN s.scv_rank = 0 THEN '0-star'
    ELSE 'other'
  END AS scv_rank_tier

FROM vcv_snapshots v
INNER JOIN scv_details s
  ON s.snapshot_release_date = v.snapshot_release_date
  AND s.variation_id = v.variation_id

ORDER BY snapshot_release_date, variation_id, scv_id;
