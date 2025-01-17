CREATE OR REPLACE PROCEDURE `clinvar_ingest.scv_summary`(
  schema_name STRING
)
BEGIN

  DECLARE scv_summary_output_sql STRING;
  DECLARE project_id STRING;

  SET project_id = (
    SELECT 
      catalog_name as paroject_id
    FROM `INFORMATION_SCHEMA.SCHEMATA`
    WHERE 
      schema_name = 'clinvar_ingest'
  );

  -- NOTE: This will no longer work on clingen-stage based on recent changes to support clingen-dev.

  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s.scv_summary` 
    AS
    WITH obs_sample AS (
      SELECT
        REGEXP_EXTRACT(id, r'^SCV[0-9]+') as id, 
        `clinvar_ingest.parseSample`(obs.content) as s
      FROM 
        `%s.clinical_assertion_observation` obs
    ),
    obs_method AS (
      SELECT
        REGEXP_EXTRACT(id, r'^SCV[0-9]+') as id, 
        m.description as method_desc,
        m.method_type
      FROM 
        `%s.clinical_assertion_observation` obs,
        UNNEST(`clinvar_ingest.parseMethods`(obs.content)) as m
    ),
    assertion_method AS (
      SELECT 
        ca.id, 
        a.attribute.type,
        a.attribute.value,
        STRING_AGG(DISTINCT c.url,';') as url 
      FROM `%s.clinical_assertion` ca,
      UNNEST(`clinvar_ingest.parseAttributeSet`(ca.content)) as a,
      UNNEST(a.citation) as c
      WHERE 
        a.attribute.type = "AssertionMethod" 
        and 
        c.url is not null
      GROUP BY 
        ca.id, 
        a.attribute.type, 
        a.attribute.value
    ),
    obs AS (
      SELECT 
        ca.id,
        STRING_AGG(DISTINCT os.s.origin, ", " ORDER BY os.s.origin) as origin,
        STRING_AGG(DISTINCT os.s.affected_status, ", " ORDER BY os.s.affected_status) as affected_status,
        STRING_AGG(DISTINCT om.method_desc, ", " ORDER BY om.method_desc) as method_desc,
        STRING_AGG(DISTINCT om.method_type, ", " ORDER BY om.method_type) as method_type
      FROM 
        `%s.clinical_assertion` ca
      LEFT JOIN obs_sample os 
      ON 
        os.id = ca.id
      LEFT JOIN obs_method om 
      ON 
        om.id = ca.id
      GROUP BY
        ca.id
    ),
    scv_classification_comment AS (
      SELECT
        id,
        STRING_AGG(JSON_EXTRACT_SCALAR(c, r'$.text'), '\\n') as text
      FROM
        `%s.clinical_assertion` ca
      LEFT JOIN UNNEST(ca.interpretation_comments) as c
      WHERE 
        ARRAY_LENGTH(ca.interpretation_comments) > 0
      GROUP BY
        id
    ),
    clinsig AS (
      SELECT
        ca.id,
        cst.original_proposition_type,
        cst.gks_proposition_type,
        cvs.rank,
        IFNULL(map.cv_clinsig_type, '-') as classif_type,
        cst.significance,
        FORMAT( '%%s, %%s, %%t', 
            cst.label, 
            if(cvs.rank > 0,format("%%i%%s", cvs.rank, CHR(9733)), IF(cvs.rank = 0, format("%%i%%s", cvs.rank, CHR(9734)), "n/a")), 
            if(ca.interpretation_date_last_evaluated is null, "<n/a>", format("%%t", ca.interpretation_date_last_evaluated))) as classification_label,
        FORMAT( '%%s, %%s, %%t', 
            UPPER(map.cv_clinsig_type), 
            if(cvs.rank > 0,format("%%i%%s", cvs.rank, CHR(9733)), IF(cvs.rank = 0, format("%%i%%s", cvs.rank, CHR(9734)), "n/a")), 
            if(ca.interpretation_date_last_evaluated is null, "<n/a>", format("%%t", ca.interpretation_date_last_evaluated))) as classification_abbrev
      FROM
        `%s.clinical_assertion` ca
      LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
      ON 
        map.scv_term = lower(IFNULL(ca.interpretation_description,'not provided'))
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst 
      ON 
        cst.code = map.cv_clinsig_type 
        AND
        cst.statement_type = ca.statement_type  
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs
      ON
        cvs.label = ca.review_status
    )
    SELECT 
      ca.release_date,
      ca.id, 
      ca.version, 
      FORMAT('%%s.%%i', ca.id, ca.version) as full_scv_id,
      ca.variation_id,
      ca.local_key,
      ca.interpretation_date_last_evaluated as last_evaluated, 
      ca.statement_type,
      cst.original_proposition_type,
      cst.gks_proposition_type,
      ca.clinical_impact_assertion_type,
      ca.clinical_impact_clinical_significance,
      cst.rank,
      ca.review_status, 
      cst.classif_type,
      cst.significance,
      cst.classification_label,
      cst.classification_abbrev,
      ca.interpretation_description as submitted_classification,
      `clinvar_ingest.parseComments`(ca.content) as comments,
      scc.text as classification_comment,
      ca.rcv_accession_id,
      rcv.trait_set_id,
      ca.date_created,
      ca.date_last_updated,
      ca.clinical_assertion_observation_ids,
      ca.submitter_id,
      subr.current_name as submitter_name,
      IFNULL(subr.current_abbrev, csa.current_abbrev) as submitter_abbrev,
      subm.submission_date, 
      obs.origin,
      obs.affected_status,
      obs.method_desc,
      obs.method_type,
      am.value as assertion_method,
      am.url as assertion_method_url
    FROM
      `%s.clinical_assertion` ca
    LEFT JOIN clinsig cst
    ON
      cst.id = ca.id
    LEFT JOIN scv_classification_comment scc 
    ON
      scc.id = ca.id
    LEFT JOIN obs
    ON
      obs.id = ca.id
    LEFT JOIN assertion_method am
    ON
      am.id = ca.id
    LEFT JOIN `%s.submitter` subr
    ON 
      subr.id = ca.submitter_id
    LEFT JOIN `clinvar_ingest.clinvar_submitter_abbrevs` csa 
    ON 
      csa.submitter_id = subr.id
    LEFT JOIN `%s.submission` subm 
    ON 
      subm.id = ca.submission_id
    LEFT JOIN `%s.rcv_accession` rcv
    ON
      rcv.id = ca.rcv_accession_id
  """, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);
END;


-- repair any null review_status values
--  set any NULL review_status either 'no assertion provided' (if interp_desc is null or not provided) or 'no assertion criteria provided' (otherwise)
--
-- UPDATE `%s.clinical_assertion` ca
-- SET 
--   ca.review_status = 
--     IF( 
--       ca.interpretation_description is null OR 
--       ca.interpretation_description = 'not provided', 
--       'no assertion provided', 
--       'no assertion criteria provided'
--     )
-- WHERE ca.review_status IS NULL
-- ;