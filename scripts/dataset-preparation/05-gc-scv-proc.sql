CREATE OR REPLACE PROCEDURE `clinvar_ingest.gc_scv`(
  schema_name STRING
)
BEGIN
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s.gc_scv`
    AS
     WITH gc_test_case AS (
      -- get the testing lab info for all gc samples that have some
      SELECT
        scv.variation_id,
        scv.submitter_id,
        scv.id,
        scv.version,
        scv.statement_type,
        scv.origin,
        m.description as method_desc,
        m.method_type,
        IF(
          oma.attribute.type = 'TestingLaboratory', 
          STRUCT(
            oma.attribute.type as type,
            oma.attribute.value as name,
            CAST(oma.attribute.integer_value AS STRING) as id,
            oma.attribute.date_value as date_reported,
            oma.comment.text as classification),
          null
        ) as lab,
        (
          SELECT 
            od.attribute.value
          FROM UNNEST(`clinvar_ingest.parseObservedData`(cao.content)) od 
          WHERE 
            od.attribute.type = 'SampleLocalID'
        ) as sample_id,
        (
          SELECT 
            od.attribute.value
          FROM UNNEST(`clinvar_ingest.parseObservedData`(cao.content)) od 
          WHERE 
            od.attribute.type = 'SampleVariantID'
        ) as sample_variant_id,
        cao.id as scv_obs_id,
        cao.clinical_assertion_trait_set_id as scv_obs_ts_id
      FROM `variation_tracker.report_submitter` rs
      JOIN `%s.scv_summary` scv
      ON
        rs.submitter_id = scv.submitter_id 
        AND
        rs.type = 'GC'
      CROSS JOIN UNNEST(scv.clinical_assertion_observation_ids) as cao_id
      JOIN `%s.clinical_assertion_observation` cao 
      ON 
        cao.id = cao_id
      LEFT JOIN UNNEST( `clinvar_ingest.parseMethods`(cao.content)) as m
      LEFT JOIN UNNEST( m.obs_method_attribute ) as oma
    )
    ,
    clinical_feature AS (
      SELECT DISTINCT
        gtc.id,
        IF(caot.content like '%XRef%', `clinvar_ingest.parseXRefs`(caot.content)[0].id, null) as xref_id,
        IFNULL(caot.name, hpo.lbl) as name,
        JSON_EXTRACT_SCALAR(caot.content, "$['@ClinicalFeaturesAffectedStatus']") as clinical_feature_affected_status
      FROM gc_test_case gtc
      JOIN `%s.clinical_assertion_trait_set` caots
      ON
        caots.id = gtc.scv_obs_ts_id
      CROSS JOIN UNNEST( caots.clinical_assertion_trait_ids) as obs_ts_trait_id
      JOIN `%s.clinical_assertion_trait` caot
      ON
        caot.id = obs_ts_trait_id
      LEFT JOIN `clinvar_ingest.hpo_terms` hpo
      ON
        hpo.id = `clinvar_ingest.parseXRefs`(caot.content)[0].id
      WHERE 
        caot.content like '%XRef%'
    ),
    gc_clinical_feature_set AS (
      select 
        cf.id,
        ARRAY_TO_STRING(ARRAY_AGG(cf.name ORDER BY cf.name), ',\n') as clinical_features
      from clinical_feature cf
      GROUP by cf.id
    )
    -- filter out any records that don't have at least one of the 
    -- following properties: lab_name, lab_id, lab_classification
    SELECT DISTINCT
      tc.variation_id, 
      tc.id, 
      tc.version,
      tc.submitter_id,
      tc.method_type,
      tc.method_desc,
      tc.lab.type as lab_type,
      tc.lab.id as lab_id,
      tc.lab.name as lab_name,
      tc.lab.classification as lab_classification,
      cct.code as lab_classif_type,
      tc.lab.date_reported as lab_date_reported,
      tc.sample_id,
      cfs.clinical_features
    FROM gc_test_case tc
    LEFT JOIN gc_clinical_feature_set cfs
    ON
      cfs.id = tc.id
    LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cct
    ON
      lower(cct.label) = lower(tc.lab.classification)
      AND
      cct.statement_type = tc.statement_type
    WHERE 
      IFNULL(tc.lab.name, IFNULL(tc.lab.id,tc.lab.classification)) IS NOT NULL
    """, schema_name, schema_name, schema_name, schema_name, schema_name);
END;