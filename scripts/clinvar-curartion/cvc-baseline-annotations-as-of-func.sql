CREATE OR REPLACE TABLE FUNCTION `clinvar_curator.cvc_baseline_annotations_as_of`(as_of_date DATE, incl_finalized BOOL, only_latest BOOL) AS (
WITH anno AS 
    (
      SELECT
        rel.release_date,
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
        TIME(a.annotation_date) AS annotated_time_utc,
        a.reason,
        a.notes,
        SPLIT(a.vcv_id,'.')[OFFSET(0)] AS vcv_id,
        CAST(SPLIT(a.vcv_id,'.')[OFFSET(1)] AS INT64) AS vcv_ver,
        -- if there are no other scv_id annotations after when orderd by annotation date then it is the latest
        (
          COUNT(a.annotation_date) 
          OVER (
            PARTITION BY SPLIT(a.scv_id,'.')[OFFSET(0)] 
            ORDER BY a.annotation_date 
            ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
          ) = 0
        ) AS is_latest

      FROM `clinvar_curator.clinvar_annotations` a,
        `clinvar_ingest.schema_on`(as_of_date) rel
      WHERE 
        DATE(a.annotation_date) <= as_of_date
  ),
  reviewed_anno AS (
    SELECT
      -- rev info
      rev.annotation_id,
      count(*) as annotation_review_count,
      a.scv_id,
      a.scv_ver,
      a.annotated_date,
      rev.reviewer,
      rev.status,
      rev.notes,
      sbm.batch_id,
      FORMAT(
        '%s (%s) %s%s',
        IFNULL(rev.status, 'n/a'),
        IF(rev.annotation_id IS NULL, NULL, IFNULL(rev.reviewer, 'n/a')),
        IFNULL(FORMAT('*%s*',sbm.batch_id), ''),
        IF(COUNT(*)>1, FORMAT('-%ix?',COUNT(*)), '')
      ) as review_label
    FROM `clinvar_curator.cvc_clinvar_reviews` rev 
    JOIN anno a ON a.annotation_id = rev.annotation_id
    LEFT JOIN `clinvar_curator.cvc_clinvar_submissions` sbm 
    ON 
      sbm.annotation_id = rev.annotation_id
    group by 
      rev.annotation_id,
      a.scv_id,
      a.scv_ver,
      a.annotated_date,
      rev.reviewer,
      rev.status,
      rev.notes,
      sbm.batch_id
  ),
  anno_label as (
    SELECT 
      a.annotation_id,
      FORMAT(
        '%t (%s) %s: %s',
        a.annotated_date, 
        IFNULL(a.curator,'n/a'), 
        IF(a.action ='flagging candidate','flag',IF(a.action = 'no change', 'no chg', 'n/a or unk' )), 
        LEFT(IFNULL(a.reason,'n/a'), 20)||IF(LENGTH(a.reason) > 20,'...','')
      ) as annotation_label
    FROM anno a
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
          prior_a_label.annotation_label, 
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
      prior_a.scv_id = a.scv_id and 
      prior_a.annotation_id < a.annotation_id
    JOIN anno_label prior_a_label
    ON
      prior_a.annotation_id = prior_a_label.annotation_id
    
    LEFT JOIN reviewed_anno as prior_ra
    ON
      prior_ra.annotation_id = prior_a.annotation_id
    WHERE 
      IF(only_latest, a.is_latest, true) 
      AND 
      IF(incl_finalized, true, ra.annotation_id is NULL)
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
    -- annotation assessment record
    a.curator,
    a.annotated_on,
    a.annotated_date,
    a.annotated_time_utc,
    a.action,
    a.reason,
    a.notes,
    a.submitter_id,
    FORMAT(
      '%t (%s) %s: %s',
      a.annotated_date, 
      IFNULL(a.curator,'n/a'), 
      IF(a.action ='flagging candidate','flag',IF(a.action = 'no change', 'no chg', 'n/a or unk' )), 
      LEFT(IFNULL(a.reason,'n/a'), 20)||IF(LENGTH(a.reason) > 20,'...','')
    ) as annotation_label,
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
  WHERE 
    IF(only_latest, a.is_latest, true) 
    AND 
    IF(incl_finalized, true, ra.annotation_id is NULL)
);