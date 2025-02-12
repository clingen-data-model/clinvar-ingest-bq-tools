CREATE OR REPLACE TABLE FUNCTION `clinvar_curator.cvc_baseline_annotations`() AS (
WITH 
  anno AS (
    SELECT
      rel.release_date,
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
    FROM `clinvar_curator.cvc_annotations_view` av,
      `clinvar_ingest.schema_on`(CURRENT_DATE()) rel
  ),
  related_anno_review AS (
    -- based on the list of annotations we want all reviewed annotations for the same scv ids, in order to show past activity on a given scv
    SELECT
      a.annotation_id,  -- the parent annotation
      -- rev info
      rev.annotation_id as reviewed_annotation_id,
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
    FROM anno a
    JOIN `clinvar_curator.cvc_annotations_view` rev_anno
    ON
      a.scv_id = rev_anno.scv_id
    JOIN `clinvar_curator.cvc_clinvar_reviews` rev 
    ON
      rev_anno.annotation_id = rev.annotation_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` sbm 
    ON 
      sbm.annotation_id = rev.annotation_id
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


  -- reviewed_anno AS (
  --   SELECT
  --     -- rev info
  --     rev.annotation_id,
  --     count(*) as annotation_review_count,
  --     a.scv_id,
  --     a.scv_ver,
  --     a.annotated_date,
  --     rev.reviewer,
  --     rev.status,
  --     rev.notes,
  --     sbm.batch_id,
  --     FORMAT(
  --       '%s (%s) %s%s',
  --       IFNULL(rev.status, 'n/a'),
  --       IF(rev.annotation_id IS NULL, NULL, IFNULL(rev.reviewer, 'n/a')),
  --       IFNULL(FORMAT('*%s*',sbm.batch_id), ''),
  --       IF(COUNT(*)>1, FORMAT('-%ix?',COUNT(*)), '')
  --     ) as review_label
  --   FROM `clinvar_curator.cvc_clinvar_reviews` rev 
  --   JOIN anno a ON a.annotation_id = rev.annotation_id
  --   LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` sbm 
  --   ON 
  --     sbm.annotation_id = rev.annotation_id
  --   group by 
  --     rev.annotation_id,
  --     a.scv_id,
  --     a.scv_ver,
  --     a.annotated_date,
  --     rev.reviewer,
  --     rev.status,
  --     rev.notes,
  --     sbm.batch_id
  ),
  ra_priors AS (
    SELECT
      a.annotation_id,
      (COUNTIF(a.scv_id = prior_a.scv_id) > 0) as has_prior_scv_id_annotation,
      (COUNTIF(a.scv_ver = prior_a.scv_ver) > 0) as has_prior_scv_ver_annotation,
      (COUNTIF(prior_ra.batch_id is not null) > 0) as has_prior_finalized_submission_batch_id,
      STRING_AGG(
        FORMAT(
          'v%i %s %s',
          prior_a.scv_ver,
          prior_a.annotation_label, 
          if(prior_ra.review_label is not null, FORMAT('[ %s ]',prior_ra.review_label), '')
        ),
        '\n' 
        ORDER BY prior_a.annotated_date DESC
      ) as prior_scv_annotations

    FROM anno as a
    LEFT JOIN reviewed_anno as ra
    ON
      ra.annotation_id = a.annotation_id
    JOIN anno as prior_a
    ON 
      prior_a.scv_id = a.scv_id 
      and 
      prior_a.annotation_id < a.annotation_id
    LEFT JOIN reviewed_anno as prior_ra
    ON
      prior_ra.annotation_id = prior_a.annotation_id
    GROUP BY
      a.annotation_id 
  )
  SELECT 
    as_of_date,
    a.release_date,
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
    -- finalized rev info
    ra.annotation_id as finalized_review_id,
    ra.reviewer as finalized_reviewer,
    ra.status as finalized_review_status,
    ra.notes as finalized_review_notes,
    -- finalized submission batch info
    ra.batch_id as finalized_submission_batch_id,
    ra.review_label as finalized_review_label,
    ra.annotation_review_count as finalized_review_count,
    -- prior review data
    ra_priors.has_prior_scv_id_annotation,
    ra_priors.has_prior_scv_ver_annotation,
    ra_priors.has_prior_finalized_submission_batch_id,
    ra_priors.prior_scv_annotations
  FROM anno as a 
  LEFT JOIN reviewed_anno ra 
  ON 
    ra.annotation_id = a.annotation_id
  LEFT JOIN ra_priors
  ON
    ra_priors.annotation_id = a.annotation_id
;