-- =============================================================================
-- CVC Batch Enriched View
-- =============================================================================
--
-- Purpose:
--   Creates a view that enriches cvc_clinvar_batches with:
--   - batch_accepted_date: When ClinVar processed/accepted the batch
--   - grace_period_end_date: 60 days after acceptance (when flags are applied)
--
-- Dependencies:
--   - clinvar_curator.cvc_clinvar_batches
--   - clinvar_curator.cvc_batch_accepted_dates
--
-- Output:
--   - clinvar_curator.cvc_batches_enriched
--
-- =============================================================================

CREATE OR REPLACE VIEW `clinvar_curator.cvc_batches_enriched`
AS
SELECT
  b.batch_id,
  b.finalized_datetime,
  b.batch_release_date,
  b.batch_start_date,
  b.batch_end_date,
  b.submission,
  a.batch_accepted_date,
  a.notes AS acceptance_notes,
  -- 60-day grace period ends on this date
  DATE_ADD(a.batch_accepted_date, INTERVAL 60 DAY) AS grace_period_end_date,
  -- The first ClinVar release after the grace period ends
  -- (this is when flags would be applied if submitter doesn't respond)
  (
    SELECT MIN(release_date)
    FROM `clinvar_ingest.clinvar_releases`
    WHERE release_date > DATE_ADD(a.batch_accepted_date, INTERVAL 60 DAY)
  ) AS first_release_after_grace_period
FROM `clinvar_curator.cvc_clinvar_batches` b
LEFT JOIN `clinvar_curator.cvc_batch_accepted_dates` a
  ON b.batch_id = a.batch_id
ORDER BY b.batch_id;
