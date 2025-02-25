-- We want to be able to bring back any unreviewed annotations or annotations in the process of being reviewed.
-- to know whether a given annotation is unreviewed would mean that we need to compare it to all presisted reviewed annotations 
-- We want to be able to bring back any unreviewed annotations or annotations in the process of being reviewed.
-- to know whether a given annotation is unreviewed would mean that we need to compare it to all presisted reviewed annotations 
CREATE OR REPLACE TABLE FUNCTION `clingen-dev.clinvar_curator.cvc_baseline_annotations`(unreviewed BOOL) AS (
WITH 
  anno AS (
    SELECT
      av.annotation_id,
      av.vcv_axn,
      av.scv_id,
      av.scv_ver,
      av.variation_id,
      av.submitter_id,
      av.action,
      av.curator,
      av.annotated_on,
      av.annotated_date,
      av.annotated_time_utc,
      av.reason,
      av.notes,
      av.vcv_id,
      av.vcv_ver,
      av.is_latest,
      av.annotation_label,
      av.review_status as clinvar_review_status,
      rev.reviewer,
      rev.status as review_status,
      rev.notes as review_notes,
      sbm.batch_id as submission_batch_id,
      DATE(sub_b.finalized_datetime) as submission_batch_date,
      rev.batch_id as review_batch_id,
      DATE(rev_b.finalized_datetime) as review_batch_date,
      IF(rev.annotation_id is null, 
        NULL, 
        FORMAT(
          '%s (%s) %s',
          IFNULL(rev.status, 'n/a'),
          IFNULL(rev.reviewer, 'n/a'),
          IFNULL(FORMAT('*%s*',sbm.batch_id), '')
        )
      ) as review_label
    FROM `clinvar_curator.cvc_annotations_view` av
    LEFT JOIN `clinvar_curator.cvc_clinvar_reviews` rev
    ON 
      rev.annotation_id = av.annotation_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` sbm 
    ON 
      sbm.annotation_id = rev.annotation_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_batches` sub_b
    ON
      sub_b.batch_id = sbm.batch_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_batches` rev_b
    ON
      rev_b.batch_id = rev.batch_id 
    WHERE 
      IF(unreviewed, rev.annotation_id is NULL, rev.annotation_id is not NULL)
  ),
  anno_history AS (
    SELECT
      a.annotation_id,
      (COUNTIF(a.scv_id = prior_a.scv_id) > 0) as has_prior_scv_id_annotation,
      (COUNTIF(a.scv_ver = prior_a.scv_ver) > 0) as has_prior_scv_ver_annotation,
      (COUNTIF(prior_a.submission_batch_id is not null) > 0) as has_prior_submission_batch_id,
      STRING_AGG(
        FORMAT(
          'v%i %s %s',
          prior_a.scv_ver,
          prior_a.annotation_label, 
          if(prior_a.review_label is not null, FORMAT('[ %s ]',prior_a.review_label), '')
        ),
        '\n' 
        ORDER BY prior_a.annotated_date DESC
      ) as prior_scv_annotations

    FROM anno as a
    JOIN anno as prior_a
    ON
      prior_a.scv_id = a.scv_id
      AND
      prior_a.annotation_id < a.annotation_id
    GROUP BY
      a.annotation_id 
  )
  SELECT 
    CURRENT_DATE() as as_of_date,
    rel.release_date,
    a.annotation_id,
    -- variant and vcv
    a.variation_id,
    a.vcv_axn,
    a.vcv_id,
    a.vcv_ver,
    -- scv
    a.scv_id,
    a.scv_ver,
    a.clinvar_review_status,
    -- annotation assessment record
    a.curator,
    a.annotated_on,
    a.annotated_date,
    a.annotated_time_utc,
    a.action,
    a.reason,
    a.notes,
    a.submitter_id,
    a.annotation_label,
    a.is_latest,
    a.reviewer,
    a.review_status,
    a.review_notes,
    a.review_label,
    a.review_batch_id,
    a.review_batch_date,
    -- batch submission
    a.submission_batch_id,
    a.submission_batch_date,
    -- anno history
    ah.has_prior_scv_id_annotation,
    ah.has_prior_scv_ver_annotation,
    ah.has_prior_submission_batch_id,
    ah.prior_scv_annotations
  FROM anno as a 
  JOIN `clinvar_ingest.schema_on`(CURRENT_DATE()) rel
  ON 
    TRUE
  LEFT JOIN anno_history ah
  ON
    ah.annotation_id = a.annotation_id
);