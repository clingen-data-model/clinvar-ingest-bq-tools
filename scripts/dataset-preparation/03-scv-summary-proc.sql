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

  -- deteremine if the final output is for clingen-stage (original XML) or not (new XML)
  SET scv_summary_output_sql = IF(
    project_id = 'clingen-stage',
    FORMAT("""
      SELECT
        cst.original_proposition_type as clinvar_stmt_type,
        cst.gks_proposition_type as cvc_stmt_type,
        IFNULL(map.cv_clinsig_type, '-') as classif_type,
        cst.significance,
        scv.*
      FROM scv
      JOIN `%s.clinical_assertion` ca
      ON
        ca.id = scv.id
      LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
      ON 
        map.scv_term = lower(IFNULL(ca.interpretation_description,'not provided'))
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst 
      ON 
        cst.code = map.cv_clinsig_type 
    """, schema_name),
    FORMAT("""
      SELECT
        ca.statement_type,
        cst.original_proposition_type,
        cst.gks_proposition_type,
        ca.clinical_impact_assertion_type,
        ca.clinical_impact_clinical_significance,
        IFNULL(map.cv_clinsig_type, '-') as classif_type,
        cst.significance,
        scv.*
      FROM scv
      JOIN `%s.clinical_assertion` ca
      ON
        ca.id = scv.id
      LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
      ON 
        map.scv_term = lower(IFNULL(ca.interpretation_description,'not provided'))
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst 
      ON 
        cst.code = map.cv_clinsig_type 
        AND
        cst.statement_type = ca.statement_type                          
    """, schema_name)
  );


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
    scv AS (
      SELECT 
        ca.release_date,
        ca.id, 
        ca.version, 
        ca.variation_id,
        ca.local_key,
        ca.interpretation_date_last_evaluated as last_evaluated, 
        cvs.rank,
        ca.review_status, 
        ca.interpretation_description as submitted_classification,
        `clinvar_ingest.parseComments`(ca.content) as comments,
        scc.text as classification_comment,
        ca.date_created,
        ca.date_last_updated,
        ca.clinical_assertion_observation_ids,
        ca.submitter_id,
        subm.submission_date, 
        obs.origin,
        obs.affected_status,
        obs.method_desc,
        obs.method_type,
        am.value as assertion_method,
        am.url as assertion_method_url
      FROM
        `%s.clinical_assertion` ca
      LEFT JOIN scv_classification_comment scc 
      ON
        scc.id = ca.id
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs
      ON
        cvs.label = ca.review_status
      LEFT JOIN obs
      ON
        obs.id = ca.id
      LEFT JOIN assertion_method am
      ON
        am.id = ca.id
      LEFT JOIN `%s.submission` subm 
      ON 
      subm.id = ca.submission_id
    )
    %s

  """, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, scv_summary_output_sql);
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