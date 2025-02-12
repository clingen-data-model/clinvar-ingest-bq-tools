CREATE OR REPLACE TABLE FUNCTION `clinvar_curator.cvc_submitter_annotations`(bool unreviewed_only) AS (
WITH x AS 
  (
    SELECT
      a.release_date,
      a.as_of_date,
      a.submitter_id,
      COUNTIF(
        (a.is_latest_annotation AND NOT a.is_deleted_scv) AND
        (a.action="flagging candidate" )
      ) AS flagging_candidate_count,
      COUNTIF(
        (a.is_latest_annotation AND NOT a.is_deleted_scv) AND
        (
          a.action="flagging candidate") AND 
        a.is_outdated_scv
      ) AS outdated_flagging_candidate_count,
      COUNTIF(
        (a.is_latest_annotation AND NOT a.is_deleted_scv) AND
        a.action="no change"
      ) AS nochange_count,
      COUNTIF(
        (a.is_latest_annotation AND NOT a.is_deleted_scv) AND
        a.action="no change" AND 
        a.is_outdated_scv
      ) AS outdated_nochange_count,
      COUNTIF(
        (a.is_latest_annotation AND NOT a.is_deleted_scv) AND
        (a.action="remove flagged submission" )
      ) AS remove_flagged_submission_count,
      COUNTIF(
        (a.is_latest_annotation AND NOT a.is_deleted_scv) AND
        (
          a.action="remove flagged submission") AND 
        a.is_outdated_scv
      ) AS outdated_remove_flagged_submission_count
    FROM `clinvar_curator.cvc_annotations`(unreviewed_only) a
    GROUP BY
      a.release_date,
      as_of_date,
      a.submitter_id )
  SELECT
    s.id,
    s.current_name,
    s.current_abbrev,
    s.cvc_abbrev,
    COUNT(scv.id) AS submission_count,
    COUNT(DISTINCT scv.variation_id) AS variation_count,
    x.flagging_candidate_count,
    x.outdated_flagging_candidate_count,
    x.nochange_count,
    x.outdated_nochange_count,
    x.remove_flagged_submission_count,
    x.outdated_remove_flagged_submission_count,
    MAX(scv.submission_date) as latest_submission_date,
    x.release_date,
    x.as_of_date
  FROM
    x
  JOIN
    `clinvar_ingest.clinvar_submitters` s
  ON
    s.id = x.submitter_id 
    AND
    x.release_date BETWEEN S.start_release_date AND S.end_release_date
  JOIN
    `clinvar_ingest.clinvar_scvs` scv
  ON
    scv.submitter_id = s.id 
    AND 
    x.release_date BETWEEN scv.start_release_date AND scv.end_release_date
  GROUP BY
    s.id,
    s.current_name,
    s.current_abbrev,
    s.cvc_abbrev,
    x.flagging_candidate_count,
    x.outdated_flagging_candidate_count,
    x.nochange_count,
    x.outdated_nochange_count,
    x.remove_flagged_submission_count,
    x.outdated_remove_flagged_submission_count,
    x.release_date,
    x.as_of_date
);