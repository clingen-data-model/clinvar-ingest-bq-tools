CREATE OR REPLACE TABLE FUNCTION `clinvar_curator.cvc_annotations_as_of`(as_of_date DATE, include_finalized BOOL, only_latest BOOL) AS (
WITH anno AS
  (
    select 
      as_of_date,
      release_date,
      annotation_id, 
      -- variant and vcv
      variation_id,
      vcv_axn,
      vcv_id,
      vcv_ver,
      -- scv
      scv_id, 
      scv_ver, 
      review_status,
      -- annotation assessment record
      curator,
      annotated_on,
      annotated_date,
      annotated_time_utc,
      action,
      reason,
      notes,
      submitter_id,
      annotation_label, 
      is_latest,
      -- finalized rev info
      finalized_review_id,
      finalized_reviewer,
      finalized_review_status,
      finalized_review_notes,
      -- finalized submission batch info
      finalized_submission_batch_id,
      finalized_review_label,
      finalized_review_count,
      -- prior review data
      has_prior_scv_id_annotation,
      has_prior_scv_ver_annotation,
      has_prior_finalized_submission_batch_id,
      prior_scv_annotations
    from `clinvar_curator.cvc_baseline_annotations_as_of`(as_of_date, include_finalized, only_latest)
  ),
  scv_max_release_date AS (
    SELECT 
      id, 
      MAX(end_release_date) as max_end_release_date
    FROM anno as a
    JOIN `clinvar_ingest.clinvar_scvs` ON 
      id = a.scv_id
    WHERE 
      a.release_date >= start_release_date
    GROUP BY 
      id
  ),
  vs_last AS (
    SELECT 
      smrd.id,
      cs.version,      
      cs.variation_id,
      cs.start_release_date, 
      cs.end_release_date,
      cs.deleted_release_date,
      cs.classif_type,
      cs.rank
    FROM scv_max_release_date smrd
    JOIN `clinvar_ingest.clinvar_scvs` cs
    ON 
      smrd.id = cs.id 
      AND 
      smrd.max_end_release_date = cs.end_release_date
  ),
  vcv_max_release_date AS (
    SELECT 
      id, 
      MAX(end_release_date) as max_end_release_date
    FROM anno as a
    JOIN `clinvar_ingest.clinvar_vcvs` 
    ON 
      id = a.vcv_id
    where 
      a.release_date >= start_release_date
    GROUP BY 
      id
  ),
  vv_last AS (
    SELECT 
      vmrd.id,
      cv.version,      
      cv.variation_id,
      cv.start_release_date, 
      cv.end_release_date,
      cv.deleted_release_date,
      cv.agg_classification,
      cv.rank
    FROM vcv_max_release_date vmrd
    JOIN `clinvar_ingest.clinvar_vcvs` cv
    ON 
      vmrd.id = cv.id 
      AND 
      vmrd.max_end_release_date = cv.end_release_date
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
    -- originally annotated scv id+ver assertion data
    cs.rpt_stmt_type,
    cs.rank,
    cs.classif_type,
    cs.clinsig_type,
    -- submitter from original annotation (should never change)
    a.submitter_id,
    s.current_name as submitter_name,
    s.current_abbrev as submitter_abbrev,
    a.annotation_label, 
    a.finalized_review_label,

    a.has_prior_scv_id_annotation,
    a.has_prior_scv_ver_annotation,
    a.has_prior_finalized_submission_batch_id,
    a.prior_scv_annotations,

    -- is this the annotation the latest for this scv id (TRUE or Count=0 means no newer annotations currently exist for the exact scv id)
    a.is_latest AS is_latest_annotation,

    -- what is the latest scv version for this scv id, null if deleted
    vs_last.version AS latest_scv_ver,
    -- what is the latest scv released date, rank and classification?
    vs_last.start_release_date AS latest_scv_release_date,
    vs_last.rank as latest_scv_rank,
    vs_last.classif_type as latest_scv_classification,

    -- what is the latest vcv version for this vcv id, null if deleted
    vv_last.version AS latest_vcv_ver,
    -- what is the latest vcv release date?
    vv_last.start_release_date AS latest_vcv_release_date,

    -- is this annotation outdated for this scv id due to an update in the version number or moved to a different variation?
    (vs_last.version > a.scv_ver OR vs_last.variation_id <> a.variation_id) AS is_outdated_scv,

    -- is this annotation outdated for this vcv id due to an update in the version number
    (vv_last.version > a.vcv_ver) AS is_outdated_vcv,

    -- has this scv id been completely deleted from the latest release?
    (vs_last.deleted_release_date is not null AND vs_last.deleted_release_date <= a.release_date) AS is_deleted_scv,
    -- if the scv id record is deleted then this is the first release it was no longer available in.
    vs_last.deleted_release_date as deleted_scv_release_date,

    -- has this scv id been moved to another variation id in the most recent release?
    (vs_last.variation_id <> a.variation_id ) AS is_moved_scv

  FROM anno as a
  -- we could do an INNER JOIN but if there was an errant record in the annotations 
  -- sheet that didn't line up with a real scv then it would be inadvertantly hidden
  -- So,it is possible (not probable) that the cs.* fields could all be null when returned.
  -- same is true for the submitter fields
  LEFT JOIN `clinvar_ingest.clinvar_scvs` cs
  ON
    cs.variation_id = a.variation_id AND
    cs.id = a.scv_id AND
    cs.version = a.scv_ver AND
    a.release_date between cs.start_release_date and cs.end_release_date
  LEFT JOIN `clinvar_ingest.clinvar_submitters` s
  ON
    s.id = a.submitter_id AND
    a.release_date between s.start_release_date and s.end_release_date  
  LEFT JOIN vs_last
  ON
    vs_last.id = a.scv_id
  LEFT JOIN vv_last
  ON
    vv_last.id = a.vcv_id
);