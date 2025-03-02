-- TABLES to support the clinvar curation dashboard, reporting and downstream processing

CREATE TABLE `clinvar_curator.cvc_clinvar_reviews`
(
  annotation_id STRING,
  date_added TIMESTAMP,
  status STRING,
  reviewer STRING,
  notes STRING,
  date_last_updated TIMESTAMP,
  batch_id STRING
)
;

CREATE TABLE `clinvar_curator.cvc_clinvar_submissions`
(
  annotation_id STRING,
  scv_id STRING,
  scv_ver STRING,
  batch_id STRING
)
;

CREATE TABLE `clinvar_curator.cvc_clinvar_batches`
(
  batch_id STRING,
  finalized_datetime TIMESTAMP
)
;

-- VIEWS to support the clinvar curation dashboard, reporting and downstream processing

-- This script creates or replaces a view named `cvc_batch_window_view` in the `clinvar_curator` schema.
-- The view calculates the `from_datetime` and `to_datetime` window for each batch such that they do not 
-- overlap based on the `finalized_datetime` of the batches in the `cvc_clinvar_batches` table.
-- It also embellishes the batch window data with additional information such as the submission date in 
-- (YYYY-MM-DD date), subm_date.monyy (MON'YY string), sbum_date.yymm (YY-MM string) and the release date 
-- of the batch.
-- The main SELECT statement of the view includes:
-- - `batch_id`: The ID of the batch.
-- - `from_datetime`: The start datetime of the batch window.
-- - `to_datetime`: The end datetime of the batch window.
-- - `submission_date`: The date part of the `to_datetime`.
-- - `subm_date.monyy `: the MON'YY representation of the submission_date.
-- - `subm_date.yymm `: the YY-MM representation of the submission_date.
-- - `batch_release_date`: The release date of the batch, determined by a custom function `schema_on`.
CREATE OR REPLACE VIEW clinvar_curator.cvc_batch_window_view
AS
  WITH batch_window AS (
    SELECT 
      ccb.batch_id, 
      LAG(DATETIME(ccb.finalized_datetime), 1, DATETIME('0001-01-01')) OVER (ORDER BY ccb.finalized_datetime ASC) AS from_datetime,
      DATETIME(ccb.finalized_datetime) AS to_datetime
    FROM clinvar_curator.cvc_clinvar_batches ccb
  )
  SELECT
    bw.batch_id,
    bw.from_datetime,
    bw.to_datetime,
    DATE(bw.to_datetime) as submission_date,
    `clinvar_ingest.determineMonthBasedOnRange`(DATE(bw.from_datetime), DATE(bw.to_datetime)) as subm_date,
    rel.release_date as batch_release_date
  FROM batch_window bw
  JOIN `clinvar_ingest.all_releases`() rel
  ON
    DATE(bw.from_datetime) between rel.release_date and rel.next_release_date
;

-- This script creates or replaces a view named `cvc_annotations_view` in the `clinvar_curator` schema.
-- The view is constructed from all the `clinvar_annotations` data and includes the following transformations and fields:
-- 
-- - `annotation_id`: A string representation of the annotation date in UNIX milliseconds.
-- - `vcv_axn`: The `vcv_id` field from the source table.
-- - `scv_id`: The first part of the `scv_id` field, split by a dot.
-- - `scv_ver`: The second part of the `scv_id` field, cast to an INT64.
-- - `variation_id`: The `variation_id` field, cast to a string.
-- - `submitter_id`: The `submitter_id` field, cast to a string.
-- - `action`: The `action` field, converted to lowercase.
-- - `curator`: The first part of the `curator_email` field, split by the '@' symbol.
-- - `annotated_on`: The original `annotation_date` field.
-- - `annotated_date`: The date part of the `annotation_date` field.
-- - `annotated_time_utc`: The time part of the `annotation_date` field in UTC.
-- - `reason`: The `reason` field from the source table.
-- - `notes`: The `notes` field from the source table.
-- - `vcv_id`: The first part of the `vcv_id` field, split by a dot.
-- - `vcv_ver`: The second part of the `vcv_id` field, cast to an INT64.
-- - `is_latest`: A boolean indicating if the annotation is the latest for the given `scv_id`.
-- - `annotation_label`: A formatted string combining the annotation date, curator, action, and a truncated reason.
-- - `review_status`: The `review_status` field from the source table.
-- 
-- The view is designed to facilitate querying and analysis of ClinVar annotations with additional metadata and transformations.
CREATE OR REPLACE VIEW clinvar_curator.cvc_annotations_view
AS
  WITH anno AS 
  (
    SELECT
      CAST(UNIX_MILLIS(annotation_date) AS STRING) as annotation_id,
      a.vcv_id as vcv_axn,
      SPLIT(a.scv_id,'.')[OFFSET(0)] AS scv_id,
      CAST(SPLIT(a.scv_id,'.')[OFFSET(1)] AS INT64) AS scv_ver,
      CAST(a.variation_id AS String) AS variation_id,
      CAST(a.submitter_id AS String) AS submitter_id,
      LOWER(a.action) AS action,
      SPLIT(a.curator_email,'@')[OFFSET(0)] AS curator,
      a.annotation_date AS annotated_on,
      DATE(a.annotation_date) AS annotated_date,
      a.reason,
      a.notes,
      SPLIT(a.vcv_id,'.')[OFFSET(0)] AS vcv_id,
      CAST(SPLIT(a.vcv_id,'.')[OFFSET(1)] AS INT64) AS vcv_ver,
      CASE LOWER(a.action)
      WHEN 'flagging candidate' THEN
        'flag'
      WHEN 'no change' THEN
        'no chg'
      WHEN 'remove flagged submission' THEN
        'rem flg sub'
      ELSE
        'unk'
      END as action_abbrev,
      LEFT(a.reason, 25)||IF(LENGTH(a.reason) > 25,'...','') as reason_abbrev,
      a.review_status as clinvar_review_status
    FROM `clinvar_curator.clinvar_annotations` a
  ),
  anno_review AS 
  (
    SELECT 
      a.*,
      rev.reviewer,
      rev.status as review_status,
      rev.notes as review_notes,
      IF(rev.annotation_id is null, 
        NULL, 
        FORMAT(
          '%s (%s) %s',
          IFNULL(rev.status, 'n/a'),
          IFNULL(rev.reviewer, 'n/a'),
          IFNULL(FORMAT('*%s*',sub.batch_id), '')
        )
      ) as review_label,
      rev.batch_id,
      DATE(b_rev.finalized_datetime) as batch_date,
      (sub.annotation_id is not null) as is_submitted
    FROM anno a
    LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` sub
    ON
      sub.annotation_id = a.annotation_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_reviews` rev
    ON
      rev.annotation_id = a.annotation_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_batches` b_rev
    ON
      b_rev.batch_id = rev.batch_id
  )
  select 
    ar.*,
    FORMAT(
      '%t (%s) %s: %s',
      ar.annotated_date, 
      IFNULL(ar.curator,'n/a'),
      ar.action_abbrev, 
      IFNULL(ar.reason_abbrev,'n/a')
    ) as annotation_label,
    -- if there are no other scv_id annotations after when orderd by annotation date then it is the latest
    (
      COUNT(ar.annotated_date) 
      OVER (
        PARTITION BY ar.batch_id, ar.scv_id 
        ORDER BY ar.annotation_id 
        ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
      ) = 0
    ) AS is_latest,
    (ar.batch_id is not null) AS is_reviewed
  from anno_review as ar
  ;

-- This script creates a view named `cvc_batch_scv_max_annotation_view` in the `clinvar_curator` schema.
-- The view aggregates data from the `cvc_clinvar_reviews` with their corresponding`cvc_annotations_view` data.
-- It selects the batch ID, SCV ID, and the maximum annotation ID for each SCV ID within each batch.
-- The view is useful for identifying the latest annotation for each SCV ID in a given batch.
CREATE OR REPLACE VIEW clinvar_curator.cvc_batch_scv_max_annotation_view
AS
  SELECT 
    ccr.batch_id, 
    av.scv_id, 
    max(av.annotation_id) annotation_id 
  FROM `clinvar_curator.cvc_clinvar_reviews` ccr
  JOIN `clinvar_curator.cvc_annotations_view` av
  ON
    av.annotation_id = ccr.annotation_id
  GROUP BY 
    av.scv_id,
    ccr.batch_id
  ;

-- This script creates or replaces the view `clinvar_curator.cvc_submitted_annotations_view`.
-- The view provides a comprehensive overview of submitted annotations, including their validity status,
-- reasons for invalid submissions, and various metadata related to the submission and annotation process.
-- 
-- The view includes the following columns:
-- - valid_submission: A boolean indicating if the submission was valid for NCBI's receipt.
-- - invalid_submission_reason: A string describing the reason why NCBI rejected the submission.
-- - batch_id: The batch identifier from the `cvc_clinvar_submissions` table.
-- - batch_release_date: The release date of the batch from the `cvc_batch_window_view` table.
-- - submission_date: The date of submission from the `cvc_batch_window_view` table.
-- - submission_month_year: The month and year of submission in 'MON'YY' format.
-- - submission_yy_mm: The year and month of submission in 'YY-MM' format.
-- - variation_id: The variation identifier from the `cvc_annotations_view` table.
-- - vcv_axn: The VCV action from the `cvc_annotations_view` table.
-- - vcv_id: The VCV identifier from the `cvc_annotations_view` table.
-- - vcv_ver: The VCV version from the `cvc_annotations_view` table.
-- - scv_id: The SCV identifier from the `cvc_annotations_view` table.
-- - scv_ver: The SCV version from the `cvc_annotations_view` table.
-- - submitter_id: The submitter identifier from the `cvc_annotations_view` table.
-- - action: The action taken from the `cvc_annotations_view` table.
-- - reason: The reason for the action from the `cvc_annotations_view` table.
-- - notes: Additional notes from the `cvc_annotations_view` table.
-- - curator: The curator responsible from the `cvc_annotations_view` table.
-- - annotation_id: The annotation identifier from the `cvc_annotations_view` table.
-- - annotated_date: The date the annotation was made from the `cvc_annotations_view` table.
-- 
-- The view joins data from the following tables:
-- - `clinvar_curator.cvc_clinvar_submissions`: Provides submission data.
-- - `clinvar_curator.cvc_batch_window_view`: Provides batch window data.
-- - `clinvar_curator.cvc_annotations_view`: Provides annotation data.
-- - `clinvar_ingest.clinvar_scvs`: Provides SCV data for validating submissions.
-- - `clinvar_curator.cvc_clinvar_submissions`: Provides prior submission data for comparison.
CREATE OR REPLACE VIEW clinvar_curator.cvc_submitted_annotations_view
AS
  SELECT
    IF(vs.id is null OR vs.version != av.scv_ver OR ccs_prior.annotation_id is not null, FALSE, TRUE) as valid_submission,
    CASE
    WHEN (vs.id is NULL) THEN
      'deleted prior to submission'
    WHEN (vs.version != av.scv_ver) THEN
      'updated prior to submission'
    WHEN (ccs_prior.annotation_id is not null) THEN
      'submitted in prior batch'
    END as invalid_submission_reason,
    ccs.batch_id,
    br.batch_release_date,
    br.submission_date,
    br.subm_date.monyy as submission_month_year,
    br.subm_date.yymm as submission_yy_mm,
    av.variation_id,
    av.vcv_axn,
    av.vcv_id,
    av.vcv_ver,
    av.scv_id,
    av.scv_ver,
    av.submitter_id,
    av.action,
    av.reason,
    av.notes,
    av.curator,
    av.annotation_id,
    av.annotated_date,
    av.review_status
  FROM `clinvar_curator.cvc_clinvar_submissions` ccs
  JOIN `clinvar_curator.cvc_batch_window_view` br
  ON
    br.batch_id = ccs.batch_id
  JOIN `clinvar_curator.cvc_annotations_view` av
  ON
    av.annotation_id = ccs.annotation_id
  LEFT JOIN `clinvar_ingest.clinvar_scvs` vs
  ON
    vs.id = ccs.scv_id
    AND
    br.batch_release_date BETWEEN vs.start_release_date AND vs.end_release_date
  LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` ccs_prior
  ON
    ccs_prior.batch_id < ccs.batch_id
    AND
    ccs_prior.scv_id = ccs.scv_id
    AND
    ccs_prior.scv_ver = ccs.scv_ver
;

-- This script creates or replaces the view `clinvar_curator.cvc_submitted_outcomes_view`.
-- The view provides a summary of the outcomes of submitted annotations based on the latest release date.
-- 
-- The view is constructed using a Common Table Expression (CTE) `latest_release` to fetch the most recent release date.
-- 
-- The main SELECT statement joins the `cvc_submitted_annotations_view` with the `latest_release` CTE and two instances of the `clinvar_scvs` table.
-- 
-- The `outcome` field is determined using a CASE statement that evaluates various conditions:
--   - "invalid submission" if the submission is not valid.
--   - "deleted" if the submission has been deleted.
--   - "flagged" if the submission has been flagged.
--   - "resubmitted, reclassified" or "resubmitted, same classification" if the submission has been resubmitted with or without reclassification.
--   - "pending (or rejected)" for other cases.
-- 
-- The view also includes additional fields from the `cvc_submitted_annotations_view` such as:
--   - `invalid_submission_reason`
--   - `batch_id`
--   - `batch_release_date`
--   - `submission_date`
--   - `submission_month_year`
--   - `submission_yy_mm`
--   - `variation_id`
--   - `vcv_axn`
--   - `vcv_id`
--   - `vcv_ver`
--   - `scv_id`
--   - `scv_ver`
--   - `submitter_id`
--   - `action`
--   - `reason`
--   - `notes`
--   - `curator`
--   - `annotation_id`
--   - `annotated_date`
--   - `review_status`
CREATE OR REPLACE VIEW clinvar_curator.cvc_submitted_outcomes_view
AS
  SELECT
    latest_release.release_date as report_release_date,
    CASE 
      WHEN (NOT sa.valid_submission) THEN
        "invalid submission"
      WHEN (cur_vs.id is null) THEN
        "deleted"
      WHEN (cur_vs.rank = -3) THEN
        "flagged"
      WHEN (cur_vs.version > sa.scv_ver) THEN
        IF(cur_vs.classif_type <> anno_vs.classif_type, "resubmitted, reclassified", "resubmitted, same classification")
      ELSE
        "pending (or rejected)"
    END as outcome,
    sa.invalid_submission_reason,
    sa.batch_id,
    sa.batch_release_date,
    sa.submission_date,
    sa.submission_month_year,
    sa.submission_yy_mm,
    sa.variation_id,  
    sa.vcv_axn,
    sa.vcv_id,
    sa.vcv_ver,
    sa.scv_id,
    sa.scv_ver,
    sa.submitter_id,
    sa.action,
    sa.reason,
    sa.notes,
    sa.curator,
    sa.annotation_id,
    sa.annotated_date,
    sa.review_status
  FROM `clinvar_curator.cvc_submitted_annotations_view` sa
  JOIN `clinvar_ingest.schema_on`(CURRENT_DATE()) latest_release ON TRUE
  LEFT JOIN `clinvar_ingest.clinvar_scvs` cur_vs
  ON
    cur_vs.id = sa.scv_id
    AND
    latest_release.release_date between cur_vs.start_release_date and cur_vs.end_release_date
  LEFT JOIN `clinvar_ingest.clinvar_scvs` anno_vs
  ON
    anno_vs.id = sa.scv_id
    AND
    sa.annotated_date between anno_vs.start_release_date and anno_vs.end_release_date
  ;