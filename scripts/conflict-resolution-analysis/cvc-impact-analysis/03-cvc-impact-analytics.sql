-- =============================================================================
-- CVC Impact Analytics
-- =============================================================================
--
-- Purpose:
--   Creates comprehensive analytics tables and views for understanding
--   the impact of CVC curation on conflict resolution over time.
--
-- Dependencies:
--   - clinvar_curator.cvc_submitted_variants (from 01-cvc-submitted-variants.sql)
--   - clinvar_curator.cvc_resolution_attribution (from 02-cvc-conflict-attribution.sql)
--   - clinvar_ingest.monthly_conflict_snapshots
--   - clinvar_ingest.conflict_vcv_change_detail
--
-- Output:
--   - clinvar_curator.cvc_impact_summary
--   - clinvar_curator.cvc_batch_effectiveness
--   - clinvar_curator.cvc_reason_effectiveness
--   - Various Google Sheets optimized views
--
-- =============================================================================

-- =============================================================================
-- Monthly Impact Summary Table
-- =============================================================================
-- Comprehensive monthly summary comparing CVC impact to overall resolution trends

CREATE OR REPLACE TABLE `clinvar_curator.cvc_impact_summary`
AS
WITH
-- Get overall conflict counts by month
monthly_conflicts AS (
  SELECT
    snapshot_release_date,
    COUNT(*) AS total_conflicts,
    COUNTIF(clinsig_conflict) AS clinsig_conflicts,
    COUNTIF(NOT clinsig_conflict) AS nonclinsig_conflicts,
    COUNTIF(has_outlier) AS conflicts_with_outlier
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date
),

-- Get resolution counts by month from change detail
monthly_resolutions AS (
  SELECT
    snapshot_release_date,
    COUNT(*) AS total_resolutions,
    COUNTIF(conflict_type = 'Clinsig') AS clinsig_resolutions,
    COUNTIF(conflict_type = 'Non-clinsig') AS nonclinsig_resolutions,
    COUNTIF(outlier_status = 'With Outlier') AS outlier_resolutions
  FROM `clinvar_ingest.conflict_vcv_change_detail`
  WHERE vcv_change_status = 'resolved'
  GROUP BY snapshot_release_date
),

-- Get CVC attribution by month
cvc_attribution AS (
  SELECT
    snapshot_release_date,
    COUNTIF(variant_attribution = 'cvc_attributed') AS cvc_attributed_resolutions,
    COUNTIF(primary_attribution = 'cvc_flagged') AS cvc_flagged_resolutions,
    COUNTIF(primary_attribution = 'cvc_prompted_deletion') AS cvc_prompted_deletion,
    COUNTIF(primary_attribution = 'cvc_prompted_reclassification') AS cvc_prompted_reclassification,
    COUNTIF(variant_attribution = 'organic') AS organic_resolutions,
    COUNTIF(variant_attribution = 'cvc_submitted_organic') AS cvc_submitted_organic
  FROM `clinvar_curator.cvc_resolution_attribution`
  GROUP BY snapshot_release_date
),

-- Get CVC submission activity by month
cvc_submissions AS (
  SELECT
    DATE_TRUNC(submission_date, MONTH) AS submission_month,
    COUNT(DISTINCT batch_id) AS batches_submitted,
    COUNT(*) AS scvs_submitted,
    COUNT(DISTINCT variation_id) AS variants_targeted,
    COUNTIF(outcome = 'flagged') AS scvs_flagged,
    COUNTIF(outcome = 'deleted') AS scvs_deleted,
    COUNTIF(outcome = 'resubmitted, reclassified') AS scvs_reclassified
  FROM `clinvar_curator.cvc_submitted_variants`
  WHERE valid_submission = TRUE
  GROUP BY DATE_TRUNC(submission_date, MONTH)
),

-- Get cumulative CVC statistics
cumulative_cvc AS (
  SELECT
    submission_month,
    SUM(scvs_submitted) OVER (ORDER BY submission_month) AS cumulative_scvs_submitted,
    SUM(variants_targeted) OVER (ORDER BY submission_month) AS cumulative_variants_targeted,
    SUM(scvs_flagged) OVER (ORDER BY submission_month) AS cumulative_scvs_flagged
  FROM cvc_submissions
)

SELECT
  mc.snapshot_release_date,
  -- Overall conflict status
  mc.total_conflicts,
  mc.clinsig_conflicts,
  mc.nonclinsig_conflicts,
  mc.conflicts_with_outlier,
  -- Resolution counts
  COALESCE(mr.total_resolutions, 0) AS total_resolutions,
  COALESCE(mr.clinsig_resolutions, 0) AS clinsig_resolutions,
  COALESCE(mr.nonclinsig_resolutions, 0) AS nonclinsig_resolutions,
  COALESCE(mr.outlier_resolutions, 0) AS outlier_resolutions,
  -- CVC attribution
  COALESCE(ca.cvc_attributed_resolutions, 0) AS cvc_attributed_resolutions,
  COALESCE(ca.cvc_flagged_resolutions, 0) AS cvc_flagged_resolutions,
  COALESCE(ca.cvc_prompted_deletion, 0) AS cvc_prompted_deletion,
  COALESCE(ca.cvc_prompted_reclassification, 0) AS cvc_prompted_reclassification,
  COALESCE(ca.organic_resolutions, 0) AS organic_resolutions,
  COALESCE(ca.cvc_submitted_organic, 0) AS cvc_submitted_organic,
  -- CVC submission activity (for the month the snapshot represents)
  COALESCE(cs.batches_submitted, 0) AS batches_submitted_this_month,
  COALESCE(cs.scvs_submitted, 0) AS scvs_submitted_this_month,
  COALESCE(cs.variants_targeted, 0) AS variants_targeted_this_month,
  -- Cumulative CVC statistics
  COALESCE(cc.cumulative_scvs_submitted, 0) AS cumulative_scvs_submitted,
  COALESCE(cc.cumulative_variants_targeted, 0) AS cumulative_variants_targeted,
  COALESCE(cc.cumulative_scvs_flagged, 0) AS cumulative_scvs_flagged,
  -- Attribution rates
  CASE
    WHEN mr.total_resolutions > 0
    THEN ROUND(100.0 * COALESCE(ca.cvc_attributed_resolutions, 0) / mr.total_resolutions, 1)
    ELSE 0
  END AS cvc_attribution_rate_pct,
  CASE
    WHEN mr.total_resolutions > 0
    THEN ROUND(100.0 * COALESCE(ca.organic_resolutions, 0) / mr.total_resolutions, 1)
    ELSE 0
  END AS organic_rate_pct,
  -- Resolution rate (resolutions as % of conflicts)
  CASE
    WHEN mc.total_conflicts > 0
    THEN ROUND(100.0 * COALESCE(mr.total_resolutions, 0) / mc.total_conflicts, 2)
    ELSE 0
  END AS resolution_rate_pct
FROM monthly_conflicts mc
LEFT JOIN monthly_resolutions mr ON mr.snapshot_release_date = mc.snapshot_release_date
LEFT JOIN cvc_attribution ca ON ca.snapshot_release_date = mc.snapshot_release_date
LEFT JOIN cvc_submissions cs ON cs.submission_month = DATE_TRUNC(mc.snapshot_release_date, MONTH)
LEFT JOIN cumulative_cvc cc ON cc.submission_month = DATE_TRUNC(mc.snapshot_release_date, MONTH)
WHERE mc.snapshot_release_date >= '2023-09-01'  -- Start from first CVC batch
ORDER BY mc.snapshot_release_date
;


-- =============================================================================
-- Batch Effectiveness Analysis
-- =============================================================================
-- Track how effective each CVC batch has been at driving resolutions

CREATE OR REPLACE TABLE `clinvar_curator.cvc_batch_effectiveness`
AS
WITH
batch_submissions AS (
  SELECT
    batch_id,
    submission_date,
    submission_month_year,
    COUNT(*) AS scvs_submitted,
    COUNT(DISTINCT variation_id) AS variants_targeted,
    COUNTIF(outcome = 'flagged') AS scvs_flagged,
    COUNTIF(outcome = 'deleted') AS scvs_deleted,
    COUNTIF(outcome = 'resubmitted, reclassified') AS scvs_reclassified,
    COUNTIF(is_resolution_candidate) AS resolution_candidates
  FROM `clinvar_curator.cvc_submitted_variants`
  WHERE valid_submission = TRUE
  GROUP BY batch_id, submission_date, submission_month_year
),

-- Count how many resolutions each batch has contributed to
batch_resolutions AS (
  SELECT
    batch_id,
    COUNT(DISTINCT variation_id) AS variants_resolved
  FROM `clinvar_curator.cvc_resolution_attribution`,
  UNNEST(cvc_batch_ids) AS batch_id
  WHERE variant_attribution = 'cvc_attributed'
  GROUP BY batch_id
)

SELECT
  bs.batch_id,
  bs.submission_date,
  bs.submission_month_year,
  bs.scvs_submitted,
  bs.variants_targeted,
  bs.scvs_flagged,
  bs.scvs_deleted,
  bs.scvs_reclassified,
  bs.resolution_candidates,
  COALESCE(br.variants_resolved, 0) AS variants_resolved,
  -- Effectiveness metrics
  CASE
    WHEN bs.variants_targeted > 0
    THEN ROUND(100.0 * COALESCE(br.variants_resolved, 0) / bs.variants_targeted, 1)
    ELSE 0
  END AS resolution_rate_pct,
  CASE
    WHEN bs.scvs_submitted > 0
    THEN ROUND(100.0 * bs.scvs_flagged / bs.scvs_submitted, 1)
    ELSE 0
  END AS flag_rate_pct,
  -- Days since submission (for maturity tracking)
  DATE_DIFF(CURRENT_DATE(), bs.submission_date, DAY) AS days_since_submission
FROM batch_submissions bs
LEFT JOIN batch_resolutions br ON br.batch_id = bs.batch_id
ORDER BY bs.batch_id
;


-- =============================================================================
-- Curation Reason Effectiveness
-- =============================================================================
-- Analyze which curation reasons are most effective at driving resolutions

CREATE OR REPLACE TABLE `clinvar_curator.cvc_reason_effectiveness`
AS
WITH
-- Count submissions by reason
reason_submissions AS (
  SELECT
    reason AS curation_reason,
    COUNT(*) AS times_used,
    COUNT(DISTINCT variation_id) AS variants_targeted,
    COUNTIF(outcome = 'flagged') AS scvs_flagged,
    COUNTIF(outcome = 'deleted') AS scvs_deleted,
    COUNTIF(outcome = 'resubmitted, reclassified') AS scvs_reclassified
  FROM `clinvar_curator.cvc_submitted_variants`
  WHERE valid_submission = TRUE
    AND reason IS NOT NULL
  GROUP BY reason
),

-- Count resolutions by reason
reason_resolutions AS (
  SELECT
    curation_reason,
    COUNT(DISTINCT variation_id) AS variants_resolved
  FROM `clinvar_curator.cvc_resolution_attribution`,
  UNNEST(cvc_curation_reasons) AS curation_reason
  WHERE variant_attribution = 'cvc_attributed'
  GROUP BY curation_reason
)

SELECT
  rs.curation_reason,
  rs.times_used,
  rs.variants_targeted,
  rs.scvs_flagged,
  rs.scvs_deleted,
  rs.scvs_reclassified,
  COALESCE(rr.variants_resolved, 0) AS variants_resolved,
  -- Effectiveness metrics
  CASE
    WHEN rs.variants_targeted > 0
    THEN ROUND(100.0 * COALESCE(rr.variants_resolved, 0) / rs.variants_targeted, 1)
    ELSE 0
  END AS resolution_rate_pct,
  CASE
    WHEN rs.times_used > 0
    THEN ROUND(100.0 * rs.scvs_flagged / rs.times_used, 1)
    ELSE 0
  END AS flag_rate_pct
FROM reason_submissions rs
LEFT JOIN reason_resolutions rr ON rr.curation_reason = rs.curation_reason
ORDER BY rs.times_used DESC
;


-- =============================================================================
-- Google Sheets Optimized Views
-- =============================================================================

-- Monthly summary for dashboard
CREATE OR REPLACE VIEW `clinvar_curator.sheets_cvc_impact_monthly`
AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%b %Y', snapshot_release_date) AS month_label,
  total_conflicts,
  total_resolutions,
  cvc_attributed_resolutions,
  organic_resolutions,
  cvc_attribution_rate_pct,
  organic_rate_pct,
  cumulative_scvs_submitted,
  cumulative_scvs_flagged
FROM `clinvar_curator.cvc_impact_summary`
ORDER BY snapshot_release_date
;

-- Attribution breakdown for stacked charts
CREATE OR REPLACE VIEW `clinvar_curator.sheets_cvc_attribution_breakdown`
AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%b %Y', snapshot_release_date) AS month_label,
  cvc_flagged_resolutions AS "CVC Flagged",
  cvc_prompted_deletion AS "Submitter Deleted (CVC Prompted)",
  cvc_prompted_reclassification AS "Submitter Reclassified (CVC Prompted)",
  organic_resolutions AS "Organic",
  cvc_submitted_organic AS "CVC Submitted (Organic Outcome)"
FROM `clinvar_curator.cvc_impact_summary`
ORDER BY snapshot_release_date
;

-- Batch effectiveness for comparison charts
CREATE OR REPLACE VIEW `clinvar_curator.sheets_cvc_batch_effectiveness`
AS
SELECT
  batch_id,
  submission_month_year AS batch_month,
  scvs_submitted,
  variants_targeted,
  variants_resolved,
  resolution_rate_pct,
  flag_rate_pct,
  days_since_submission
FROM `clinvar_curator.cvc_batch_effectiveness`
ORDER BY batch_id
;

-- Curation reason effectiveness for comparison
CREATE OR REPLACE VIEW `clinvar_curator.sheets_cvc_reason_effectiveness`
AS
SELECT
  curation_reason,
  times_used,
  variants_targeted,
  variants_resolved,
  resolution_rate_pct,
  flag_rate_pct
FROM `clinvar_curator.cvc_reason_effectiveness`
ORDER BY times_used DESC
;

-- Cumulative impact over time
CREATE OR REPLACE VIEW `clinvar_curator.sheets_cvc_cumulative_impact`
AS
SELECT
  snapshot_release_date,
  FORMAT_DATE('%b %Y', snapshot_release_date) AS month_label,
  cumulative_scvs_submitted,
  cumulative_variants_targeted,
  cumulative_scvs_flagged,
  SUM(cvc_attributed_resolutions) OVER (ORDER BY snapshot_release_date) AS cumulative_cvc_resolutions,
  SUM(organic_resolutions) OVER (ORDER BY snapshot_release_date) AS cumulative_organic_resolutions,
  SUM(total_resolutions) OVER (ORDER BY snapshot_release_date) AS cumulative_total_resolutions
FROM `clinvar_curator.cvc_impact_summary`
ORDER BY snapshot_release_date
;
