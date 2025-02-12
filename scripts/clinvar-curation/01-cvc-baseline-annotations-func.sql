-- We want to be able to bring back any unreviewed annotations or annotations in the process of being reviewed.
-- to know whether a given annotation is unreviewed would mean that we need to compare it to all presisted reviewed annotations 
-- We want to be able to bring back any unreviewed annotations or annotations in the process of being reviewed.
-- to know whether a given annotation is unreviewed would mean that we need to compare it to all presisted reviewed annotations 
CREATE OR REPLACE TABLE FUNCTION `clinvar_curator.cvc_baseline_annotations`(unreviewed_only BOOL) AS (
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
      av.review_status
    FROM `clinvar_curator.cvc_annotations_view` av
    LEFT JOIN `clinvar_curator.cvc_clinvar_reviews` rev
    ON 
      rev.annotation_id = av.annotation_id
    WHERE 
      IF(unreviewed_only, rev.annotation_id is NULL, TRUE)
  ),
  anno_reviews AS (
      
    -- based on the list of annotations we want all older reviewed annotations for the same scv ids, in order to show past activity on a given scv
    SELECT
      -- rev info
      rev.annotation_id,
      rev_anno.scv_id,
      rev_anno.scv_ver,
      rev_anno.annotated_date,
      rev_anno.annotation_label,
      rev.reviewer,
      rev.status,
      rev.notes,
      sbm.batch_id,
      FORMAT(
        '%s (%s) %s',
        IFNULL(rev.status, 'n/a'),
        IFNULL(rev.reviewer, 'n/a'),
        IFNULL(FORMAT('*%s*',sbm.batch_id), '')
      ) as review_label
    FROM `clinvar_curator.cvc_clinvar_reviews` rev
    LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` sbm 
    ON 
      sbm.annotation_id = rev.annotation_id


    JOIN `clinvar_curator.cvc_annotations_view` rev_anno
    ON
      a.scv_id = rev_anno.scv_id
    JOIN anno a
    ON
      rev_anno.annotation_id = rev.annotation_id
    
  ),
  anno_history AS (
    SELECT
      a.annotation_id,
      (COUNTIF(a.scv_id = prior_rev.scv_id) > 0) as has_prior_scv_id_annotation,
      (COUNTIF(a.scv_ver = prior_rev.scv_ver) > 0) as has_prior_scv_ver_annotation,
      (COUNTIF(prior_rev.batch_id is not null) > 0) as has_prior_finalized_submission_batch_id,
      STRING_AGG(
        FORMAT(
          'v%i %s %s',
          prior_rev.scv_ver,
          prior_rev.annotation_label, 
          if(prior_rev.review_label is not null, FORMAT('[ %s ]',prior_rev.review_label), '')
        ),
        '\n' 
        ORDER BY prior_rev.annotated_date DESC
      ) as prior_scv_annotations

    FROM anno as a
    LEFT JOIN related_anno_review as prior_rev
    ON
      prior_rev.annotation_id = a.annotation_id
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
    a.review_status,
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
    -- if annotation was reviewed then show the review info
    rev.annotation_id as rev_annotation_id,
    rev.reviewer as rev_reviewer,
    rev.status as rev_status,
    rev.notes as rev_notes,
    -- reviewed batch info
    rev.batch_id as rev_batch_id,
    rev.review_label as rev_label,
    -- anno history
    ah.has_prior_scv_id_annotation,
    ah.has_prior_scv_ver_annotation,
    ah.has_prior_submission_batch_id,
    ah.prior_scv_annotations
  FROM anno as a 
  JOIN `clinvar_ingest.schema_on`(CURRENT_DATE()) rel
  ON 
    TRUE
  LEFT JOIN related_anno_review rev 
  ON 
    -- this should never happen if the annotation is unreviewed
    rev.reviewed_annotation_id = a.annotation_id
  LEFT JOIN anno_history ah
  ON
    ah.annotation_id = a.annotation_id
);