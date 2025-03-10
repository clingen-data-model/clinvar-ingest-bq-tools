CREATE OR REPLACE TABLE FUNCTION `clinvar_curator.cvc_annotations`(
  scope STRING
) 
AS 
(
  WITH anno AS 
  (
    select 
      a.*,
      -- originally annotated scv id+ver assertion data
      cs.statement_type,
      cs.gks_proposition_type,
      cs.rank,
      cs.classif_type,
      cs.clinsig_type,
      -- submitter from original annotation (should never change)
      cs.submitter_name,
      cs.submitter_abbrev
    from `clinvar_curator.cvc_baseline_annotations`(scope) a
    LEFT JOIN `clinvar_ingest.clinvar_scvs` cs
    ON
      cs.id = a.scv_id 
      AND
      a.annotation_release_date between cs.start_release_date and cs.end_release_date
  ),
  scv_latest AS 
  (
    -- find the newest scv info that has a larger scv version # for the latest unreviewed annotation's scv version #
    select DISTINCT
      (
        LAST_VALUE(STRUCT(cs.id, cs.version, cs.variation_id, cs.classif_type, cs.rank, cs.start_release_date, cs.end_release_date, cs.deleted_release_date)) 
        OVER (
          PARTITION BY a.batch_id, a.scv_id 
          ORDER BY cs.end_release_date
          ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )
      ) as latest_scv
    from anno a
    JOIN `clinvar_ingest.clinvar_scvs` cs
    ON 
      a.scv_id = cs.id
      AND
      a.scv_ver < cs.version
    WHERE 
      (a.result_set_scope <> "REVIEWED")
      AND
      NOT a.is_reviewed 
      AND
      a.is_latest
  ),
  vcv_latest AS 
  (
    -- find the newest vcv info that has a larger vcv version # for the latest unreviewed annotation's vcv version #
    select DISTINCT
      (
        LAST_VALUE(STRUCT(vs.id, vs.version, vs.variation_id, vcs.agg_classification_description, vcs.rank, vcs.start_release_date, vcs.end_release_date, vcs.deleted_release_date)) 
        OVER (
          PARTITION BY a.batch_id, a.vcv_id 
          ORDER BY vcs.end_release_date
          ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )
      ) as latest_vcv
    from anno a
    JOIN `clinvar_ingest.clinvar_vcvs` vs
    ON 
      a.vcv_id = vs.id
      AND
      a.vcv_ver < vs.version
    JOIN `clinvar_ingest.clinvar_vcv_classifications` vcs
    ON
      a.vcv_id = vcs.vcv_id
      AND
      a.statement_type = vcs.statement_type

    WHERE 
      (a.result_set_scope <> "REVIEWED")
      AND
      NOT a.is_reviewed 
      AND
      a.is_latest
  )
  SELECT 
    a.as_of_date,
    a.annotation_release_date,
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
    a.action,
    a.reason,
    a.notes,
    -- originally annotated scv id+ver assertion data
    a.statement_type,
    a.gks_proposition_type,
    a.rank,
    a.classif_type,
    a.clinsig_type,
    -- submitter from original annotation (should never change)
    a.submitter_id,
    a.submitter_name,
    a.submitter_abbrev,

    a.annotation_label, 

    a.has_prior_scv_id_annotation,
    a.has_prior_scv_ver_annotation,
    a.has_prior_submission_batch_id,
    a.prior_scv_annotations,

    -- review info
    a.reviewer,
    a.review_status,
    a.review_notes,
    a.review_label,
    a.batch_id,
    a.batch_date,
    a.batch_release_date,

    -- is this the annotation the latest for this scv id (TRUE or Count=0 means no newer annotations currently exist for the exact scv id)
    a.is_latest AS is_latest_annotation,
    a.is_submitted AS is_submitted_annotation,
    a.is_reviewed AS is_reviewed_annotation,

    -- what is the latest scv version for this scv id, null if not the latest, unreviewed annotation with a scv_version older than the latest
    s.latest_scv.version AS latest_scv_ver,

    -- what is the latest scv released date, rank and classification?
    s.latest_scv.start_release_date AS latest_scv_release_date,

    s.latest_scv.rank as latest_scv_rank,
    s.latest_scv.classif_type as latest_scv_classification,

    -- what is the latest vcv version for this vcv id, null if not the latest, unreviewed annotation with a vcv_version older than the latest
    v.latest_vcv.version AS latest_vcv_ver,
    -- what is the latest vcv start release date?
    v.latest_vcv.start_release_date AS latest_vcv_release_date,

    -- is this annotation outdated for this scv id due to an update in the version number or moved to a different variation?
    (s.latest_scv.version > a.scv_ver OR s.latest_scv.variation_id <> a.variation_id) AS is_outdated_scv,

    -- is this annotation outdated for this vcv id due to an update in the version number
    (v.latest_vcv.version > a.vcv_ver) AS is_outdated_vcv,

    -- has this scv id been completely deleted from the latest release?
    (s.latest_scv.deleted_release_date is not null AND s.latest_scv.deleted_release_date <= a.annotation_release_date) AS is_deleted_scv,
    -- if the scv id record is deleted then this is the first release it was no longer available in.
    s.latest_scv.deleted_release_date as deleted_scv_release_date,

    -- has this scv id been moved to another variation id in the most recent release?
    (s.latest_scv.variation_id <> a.variation_id ) AS is_moved_scv

  FROM anno as a
  LEFT JOIN scv_latest s
  ON
    s.latest_scv.id = a.scv_id
    AND
    s.latest_scv.version > a.scv_ver

  LEFT JOIN vcv_latest v
  ON
    v.latest_vcv.id = a.vcv_id
    AND
    v.latest_vcv.version > a.vcv_ver
);
