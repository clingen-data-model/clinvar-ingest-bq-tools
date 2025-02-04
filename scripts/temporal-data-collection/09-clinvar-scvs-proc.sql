-- README! There are 250 cvc annotated SCV records that pre-date Jan.07.2023. The
--     scripts to load them can be found BELOW the PROCEDURE definition. 
--     This only needs to be performed if the clinvar_scvs table needs to be reinitialized.

CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_scvs`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date clinvar_scvs
  CALL `clinvar_ingest.validate_last_release`('clinvar_scvs', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deletes
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_scvs` cs
      SET 
        deleted_release_date = %T
    WHERE 
      cs.deleted_release_date is NULL 
      AND 
      NOT EXISTS (
        SELECT 
          scv.id 
        FROM `%s.scv_summary` scv
        WHERE 
          scv.variation_id = cs.variation_id 
          AND 
          scv.id = cs.id 
          AND 
          scv.version = cs.version 
          AND
          scv.statement_type IS NOT DISTINCT FROM cs.statement_type 
          AND
          scv.rank IS NOT DISTINCT FROM cs.rank 
          AND
          scv.gks_proposition_type IS NOT DISTINCT FROM cs.gks_proposition_type 
          AND
          scv.clinical_impact_assertion_type IS NOT DISTINCT FROM cs.clinical_impact_assertion_type 
          AND
          scv.clinical_impact_clinical_significance IS NOT DISTINCT FROM cs.clinical_impact_clinical_significance 
          AND
          scv.last_evaluated IS NOT DISTINCT FROM cs.last_evaluated 
          AND
          scv.significance IS NOT DISTINCT FROM cs.clinsig_type
          AND
          scv.rcv_accession_id IS NOT DISTINCT FROM cs.rcv_accession_id
          AND
          scv.trait_set_id IS NOT DISTINCT FROM cs.trait_set_id
      )
  """, release_date, schema_name);

  -- updated scv id+ver
  -- NOTE: Further investigation of handling cvc_actions is needed for collating the scv id+ver updates, 
  --       Simply overwriting the changes to last and pending cvc_actions appears to produce invalid outcomes
  --       The problem could be back in the building of the data in the scv_summary_proc?!
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_scvs` cs
    SET 
      cs.full_scv_id = scv.full_scv_id,
      cs.original_proposition_type = scv.original_proposition_type,
      cs.local_key = scv.local_key,
      cs.classif_type = scv.classif_type,
      cs.classification_label = scv.classification_label,
      cs.classification_abbrev = scv.classification_abbrev,
      cs.submitted_classification = scv.submitted_classification,
      cs.classification_comment = scv.classification_comment,
      cs.rcv_accession_id = scv.rcv_accession_id,
      cs.review_status = scv.review_status,
      cs.trait_set_id = scv.trait_set_id,
      cs.submitter_id = scv.submitter_id,
      cs.submitter_name = scv.submitter_name,
      cs.submitter_abbrev = scv.submitter_abbrev,
      cs.submission_date = scv.submission_date,
      cs.origin = scv.origin,
      cs.affected_status = scv.affected_status,
      cs.method_type = scv.method_type,
      cs.end_release_date = scv.release_date
    FROM `%s.scv_summary` scv
    WHERE 
      scv.variation_id = cs.variation_id 
      AND 
      scv.id = cs.id 
      AND 
      scv.version = cs.version 
      AND
      scv.statement_type IS NOT DISTINCT FROM cs.statement_type 
      AND
      scv.rank IS NOT DISTINCT FROM cs.rank 
      AND
      scv.gks_proposition_type IS NOT DISTINCT FROM cs.gks_proposition_type 
      AND
      scv.clinical_impact_assertion_type IS NOT DISTINCT FROM cs.clinical_impact_assertion_type 
      AND
      scv.clinical_impact_clinical_significance IS NOT DISTINCT FROM cs.clinical_impact_clinical_significance 
      AND
      scv.last_evaluated IS NOT DISTINCT FROM cs.last_evaluated 
      AND
      scv.significance IS NOT DISTINCT FROM cs.clinsig_type
      AND
      scv.rcv_accession_id IS NOT DISTINCT FROM cs.rcv_accession_id
      AND
      scv.trait_set_id IS NOT DISTINCT FROM cs.trait_set_id
      AND
      cs.deleted_release_date is NULL 
  """, schema_name);

  -- new scv variation+id+version
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_scvs` (
      variation_id, 
      id, 
      version, 
      full_scv_id,
      statement_type,
      original_proposition_type,
      gks_proposition_type,
      clinical_impact_assertion_type,
      clinical_impact_clinical_significance,
      rank, 
      review_status,
      last_evaluated, 
      local_key, 
      classif_type, 
      clinsig_type, 
      classification_label,
      classification_abbrev,
      submitted_classification, 
      classification_comment,
      rcv_accession_id,
      trait_set_id,
      submitter_id, 
      submitter_name,
      submitter_abbrev,
      submission_date, 
      origin, 
      affected_status, 
      method_type, 
      start_release_date, 
      end_release_date
    )
    SELECT 
      scv.variation_id,
      scv.id, 
      scv.version, 
      scv.full_scv_id,
      scv.statement_type,
      scv.original_proposition_type,
      scv.gks_proposition_type,
      scv.clinical_impact_assertion_type,
      scv.clinical_impact_clinical_significance,
      scv.rank, 
      scv.review_status,
      scv.last_evaluated,
      scv.local_key,
      scv.classif_type,
      scv.significance as clinsig_type,
      scv.classification_label,
      scv.classification_abbrev,
      scv.submitted_classification, 
      scv.classification_comment,
      scv.rcv_accession_id,
      scv.trait_set_id,
      scv.submitter_id,
      scv.submitter_name,
      scv.submitter_abbrev,
      scv.submission_date,
      scv.origin,
      scv.affected_status,
      scv.method_type,
      scv.release_date as start_release_date,
      scv.release_date as end_release_date
    FROM `%s.scv_summary` scv
    WHERE 
      NOT EXISTS (
        SELECT 
          cs.id 
        FROM `clinvar_ingest.clinvar_scvs` cs
        WHERE 
          scv.variation_id = cs.variation_id 
          AND 
          scv.id = cs.id 
          AND 
          scv.version = cs.version 
          AND
          scv.statement_type IS NOT DISTINCT FROM cs.statement_type 
          AND
          scv.rank IS NOT DISTINCT FROM cs.rank 
          AND
          scv.gks_proposition_type IS NOT DISTINCT FROM cs.gks_proposition_type 
          AND
          scv.clinical_impact_assertion_type IS NOT DISTINCT FROM cs.clinical_impact_assertion_type 
          AND
          scv.clinical_impact_clinical_significance IS NOT DISTINCT FROM cs.clinical_impact_clinical_significance 
          AND
          scv.last_evaluated IS NOT DISTINCT FROM cs.last_evaluated 
          AND
          scv.significance IS NOT DISTINCT FROM cs.clinsig_type
          AND
          scv.rcv_accession_id IS NOT DISTINCT FROM cs.rcv_accession_id
          AND
          scv.trait_set_id IS NOT DISTINCT FROM cs.trait_set_id
          AND
          cs.deleted_release_date is NULL 
      )
  """, schema_name);

  SET result_message = "clinvar_scvs processed successfully."; 

END;



---*** ONLY APPLY THE SCRIPTS BELOW IF RE-INITIALIZING THE clinvar_scvs TABLE ***---
-- README! There are 250 cvc annotated SCV records that pre-date Jan.07.2023 in the 
--  clinvar_ingest.clinvar_scvs_curated_before_2023 table. These records need to be included
--  in the clinvar_scvs table to support these older annotated scv records for the cvc project.

-- The CREATE TABLE script references the clingen-stage.clinvar_ingest.historic_clinvar_scvs table
-- IF that table is not availabe DO NOT replace the clinvar_scvs_curated_before_2023 table.
CREATE TABLE `clingen-dev.clinvar_ingest.clinvar_scvs_curated_before_2023`
AS
WITH x AS 
(
  SELECT
    SPLIT(a.scv_id,'.')[OFFSET(0)] AS scv_id,
  FROM `clinvar_curator.clinvar_annotations` a
  WHERE DATE(a.annotation_date) <= DATE'2023-01-07'
),
curated_scv_rcv_trait_set AS
(
  -- this is manually curated rcv and trait_set info for the 82 scv versioned records that were curated before Jan.07.2023 and changed thereafter
  -- it is needed to make the curated scvs work well with all downstream reporting and statistical analysis.
  SELECT
    [STRUCT<scv_id string, rcv_id string, trait_set_id string>("SCV000045445", "RCV000024154", "7628"),
      STRUCT("SCV000051898", "RCV000029252", "8763"),
      STRUCT("SCV000051901", "RCV003234919", "9590"),
      STRUCT("SCV000051911", "RCV003234920", "9590"),
      STRUCT("SCV000051916", "RCV003234921", "9590"),
      STRUCT("SCV000051938", "RCV001698944", "9590"),
      STRUCT("SCV000051940", "RCV000029294", "2675"),
      STRUCT("SCV000052424", "RCV003234924", "9590"),
      STRUCT("SCV000052505", "RCV003234925", "9590"),
      STRUCT("SCV000052685", "RCV000030030", "2533"),
      STRUCT("SCV000052783", "RCV003234927", "9590"),
      STRUCT("SCV000052789", "RCV000247593", "9590"),
      STRUCT("SCV000058845", "RCV000586485", "9590"),
      STRUCT("SCV000060009", "RCV003319174", "2366"),
      STRUCT("SCV000062666", "RCV004017327", "40993"),
      STRUCT("SCV000187066", "RCV000160732", "13598"),
      STRUCT("SCV000195161", "RCV000147705", "1863"),
      STRUCT("SCV000198337", "RCV000844708", "9590"),
      STRUCT("SCV000262901", "RCV000210653", "25797"),
      STRUCT("SCV000271290", "RCV000221320", "48389"),
      STRUCT("SCV000271304", "RCV001195102", "9590"),
      STRUCT("SCV000317739", "RCV000247505", "32616"),
      STRUCT("SCV000319256", "RCV003243004", "7840"),
      STRUCT("SCV000348823", "RCV000406731", "4000"),
      STRUCT("SCV000357989", "RCV000375211", "1092"),
      STRUCT("SCV000358212", "RCV000370400", "22773"),
      STRUCT("SCV000383044", "RCV000379337", "6574"),
      STRUCT("SCV000597319", "RCV000147705", "1863"),
      STRUCT("SCV000602552", "RCV000587234", "9460"),
      STRUCT("SCV000746931", "RCV000009409", "1517"),
      STRUCT("SCV000746953", "RCV000030077", "2440"),
      STRUCT("SCV000757745", "RCV000636306", "21987"),
      STRUCT("SCV000807281", "RCV000679884", "3382"),
      STRUCT("SCV000910365", "RCV000775886", "13598"),
      STRUCT("SCV000912262", "RCV000776642", "13598"),
      STRUCT("SCV000948007", "RCV000807927", "9403"),
      STRUCT("SCV001150435", "RCV000431687", "9460"),
      STRUCT("SCV001154674", "RCV000175607", "9460"),
      STRUCT("SCV001190875", "RCV001028092", "513"),
      STRUCT("SCV001335032", "RCV001172090", "9460"),
      STRUCT("SCV001344519", "RCV000563712", "13598"),
      STRUCT("SCV001370164", "RCV000001006", "250"),
      STRUCT("SCV001622882 ", "RCV001420570", "16994"),
      STRUCT("SCV001666677", "RCV001462752", "9460"),
      STRUCT("SCV001736607", "RCV001526294", "8589")] AS data
),
curated as (
  select 
    id.scv_id, 
    id.rcv_id, 
    id.trait_set_id
  from curated_scv_rcv_trait_set csrts, unnest(csrts.data) as id
)
-- get all pre-2023 historic_clinvar_scvs records for any scv ids that were annotated before 2023.
SELECT DISTINCT
  scv.*,
  curated.rcv_id,
  curated.trait_set_id 
FROM x
LEFT JOIN `clingen-stage.clinvar_ingest.historic_clinvar_scvs` scv
ON
  scv.id = x.scv_id
  AND
  scv.start_release_date < DATE'2023-01-07'
LEFT JOIN curated
ON
  curated.scv_id = scv.id
  AND
  scv.end_release_date < DATE'2023-01-07'
;

-- after the clinvar_scvs table is populated with the post Jan.07.2023 records, run the following to update
-- the historic clinvar_scvs for the scvs annotated before Jan.07.2023.
UPDATE `clinvar_ingest.clinvar_scvs` scv
SET
  scv.start_release_date = his.start_release_date
FROM `clinvar_ingest.clinvar_scvs_curated_before_2023` his
WHERE
  scv.id = his.id
  AND
  scv.version = his.version
  AND
  scv.statement_type is not distinct from 'GermlineClassification'
  AND
  scv.rank IS NOT DISTINCT from his.rank
  AND 
  scv.gks_proposition_type IS NOT DISTINCT FROM his.rpt_stmt_type
  AND
  scv.last_evaluated is not distinct from his.last_evaluated
  AND
  scv.clinsig_type is not distinct from his.clinsig_type
  AND
  scv.submitter_id is not distinct from his.submitter_id
  AND
  scv.variation_id = his.variation_id
  AND
  his.end_release_date between scv.start_release_date and scv.end_release_date

;

-- if the clinvar_scvs table needs to be reinitialized then the following INSERT statement should be run, once:
INSERT INTO `clinvar_ingest.clinvar_scvs` 
(
  variation_id, 
  id, 
  version, 
  full_scv_id,
  statement_type,
  original_proposition_type,
  gks_proposition_type,
  clinical_impact_assertion_type,
  clinical_impact_clinical_significance,
  rank, 
  review_status,
  last_evaluated, 
  local_key, 
  classif_type, 
  clinsig_type, 
  classification_label,
  classification_abbrev,
  submitted_classification, 
  classification_comment,
  rcv_accession_id,
  trait_set_id,
  submitter_id, 
  submitter_name,
  submitter_abbrev,
  submission_date, 
  origin, 
  affected_status, 
  method_type, 
  start_release_date, 
  end_release_date  
) 
SELECT 
  scv.variation_id,
  scv.id, 
  scv.version, 
  FORMAT('%s.%i', scv.id, scv.version) as full_scv_id,
  'GermlineClassification' as statement_type,
  scv.rpt_stmt_type as original_proposition_type,
  scv.rpt_stmt_type as gks_proposition_type,
  CAST(null AS STRING) as clinical_impact_assertion_type,
  CAST(null AS STRING) as clinical_impact_clinical_significance,
  scv.rank, 
  scv.review_status,
  scv.last_evaluated,
  scv.local_key,
  scv.classif_type,
  scv.clinsig_type,
  cst.classification_label,
  cst.classification_abbrev,
  scv.submitted_classification, 
  '!SYSTEM:pre-2023 not available' as classification_comment,
  scv.rcv_id as rcv_accession_id,
  scv.trait_set_id as trait_set_id,
  -- CAST(null AS STRING) as rcv_accession_id,
  -- CAST(null AS STRING) as trait_set_id,
  scv.submitter_id,
  subm.current_name as submitter_name,
  IFNULL(subm.current_abbrev, csa.current_abbrev) as submitter_abbrev,    
  scv.submission_date,
  scv.origin,
  scv.affected_status,
  scv.method_type,
  scv.start_release_date,
  scv.end_release_date
FROM  `clinvar_ingest.clinvar_scvs_curated_before_2023` scv
-- get submitter and classification info
JOIN `clingen-dev.clinvar_ingest.clinvar_submitters` subm
ON
  scv.submitter_id = subm.id
  AND
  DATE'2023-01-07' = subm.start_release_date
LEFT JOIN `clinvar_ingest.clinvar_submitter_abbrevs` csa 
ON 
  csa.submitter_id = subm.id  
LEFT JOIN (
  SELECT
    ca.id,
    ca.start_release_date,
    IFNULL(map.cv_clinsig_type, '-') as classif_type,
    cst.significance,
    FORMAT( '%s, %s, %t', 
        cst.label, 
        if(ca.rank > 0,format("%i%s", ca.rank, CHR(9733)), IF(ca.rank = 0, format("%i%s", ca.rank, CHR(9734)), "n/a")), 
        if(ca.last_evaluated is null, "<n/a>", format("%t", ca.last_evaluated))) as classification_label,
    FORMAT( '%s, %s, %t', 
        UPPER(map.cv_clinsig_type), 
        if(ca.rank > 0,format("%i%s", ca.rank, CHR(9733)), IF(ca.rank = 0, format("%i%s", ca.rank, CHR(9734)), "n/a")), 
        if(ca.last_evaluated is null, "<n/a>", format("%t", ca.last_evaluated))) as classification_abbrev
    FROM
      `clinvar_ingest.clinvar_scvs_curated_before_2023` ca
    LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
    ON 
      map.scv_term = lower(IFNULL(ca.submitted_classification,'not provided'))
    LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst 
    ON 
      cst.code = map.cv_clinsig_type 
      AND
      cst.statement_type = 'GermlineClassification'  
    WHERE ca.end_release_date < DATE'2023-01-07'
) cst
ON
  cst.id = scv.id  
  and
  cst.start_release_date = scv.start_release_date
WHERE
  scv.end_release_date < DATE'2023-01-07'
;