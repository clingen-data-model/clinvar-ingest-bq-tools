// one off for UPENN clinvar manuscript

EXPORT DATA OPTIONS(
  uri='gs://clingen-public/upenn/clinvar_scvs_pre_2019_07_01/temp_shards/part_*.json.gz',
  format='JSON',
  compression='GZIP',
  overwrite=true
) AS
SELECT
  s.variation_id,
  s.id,
  s.version,
  CONCAT(s.id, '.', CAST(s.version AS STRING)) AS full_scv_id,
  s.cvc_stmt_type AS rpt_stmt_type,
  s.rank,
  s.last_evaluated,
  s.classif_type,
  s.submitted_classification,
  s.significance AS clinsig_type,
  CAST(NULL AS STRING) AS classification_label,
  CAST(NULL AS STRING) AS classification_abbrev,
  s.submitter_id,
  sub.current_name AS submitter_name,
  sub.current_abbrev AS submitter_abbrev,
  s.submission_date,
  s.origin,
  s.affected_status,
  s.method_type,
  s.release_date,
  CAST(NULL AS DATE) AS start_release_date,
  CAST(NULL AS DATE) AS end_release_date,
  CAST(NULL AS DATE) AS deleted_release_date,
  CAST(NULL AS INTEGER) AS deleted_count
FROM `clingen-stage.clinvar_2019_06_01_v0.scv_summary` s
LEFT JOIN `clingen-stage.clinvar_2019_06_01_v0.submitter` sub
  ON s.submitter_id = sub.id
  AND s.release_date = sub.release_date
order by variation_id, id, release_date;



EXPORT DATA OPTIONS(
  uri='gs://clingen-public/upenn/clinvar_scvs_2019_07_01/temp_shards/part_*.json.gz',
  format='JSON',
  compression='GZIP',
  overwrite=true
) AS
SELECT
  variation_id,
  id,
  version,
  full_scv_id,
  rpt_stmt_type,
  rank,
  last_evaluated,
  classif_type,
  submitted_classification,
  clinsig_type,
  classification_label,
  classification_abbrev,
  submitter_id,
  submitter_name,
  submitter_abbrev,
  submission_date,
  origin,
  affected_status,
  method_type,
  start_release_date,
  end_release_date,
  deleted_release_date,
  deleted_count
FROM `clingen-dev.clingen_stage.historic_voi_scv_copy` ;
