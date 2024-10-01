CREATE OR REPLACE PROCEDURE
  `clinvar_ingest.gc_scv_proc`(start_with DATE)
BEGIN
  FOR rec IN (SELECT s.schema_name, s.release_date, s.prev_release_date, s.next_release_date FROM clinvar_ingest.schemas_on_or_after(start_with) AS s)
  DO
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
            WHERE od.attribute.type = 'SampleLocalID'
          ) as sample_id,
          (
            SELECT 
              od.attribute.value
            FROM UNNEST(`clinvar_ingest.parseObservedData`(cao.content)) od 
            WHERE od.attribute.type = 'SampleVariantID'
          ) as sample_variant_id,
          cao.id as scv_obs_id
        FROM `clinvar_ingest.report_submitter` rs
        JOIN `%s.scv_summary` scv
        ON
          rs.submitter_id = scv.submitter_id 
          and
          rs.type = 'GC'
        CROSS JOIN UNNEST(scv.clinical_assertion_observation_ids) as cao_id
        JOIN `%s.clinical_assertion_observation` cao 
        ON 
          cao.id = cao_id
        LEFT JOIN UNNEST( `clinvar_ingest.parseMethods`(cao.content)) as m
        LEFT JOIN UNNEST( m.obs_method_attribute ) as oma
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
        tc.sample_id
      FROM gc_test_case tc
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cct
      ON
        lower(cct.label) = lower(tc.lab.classification)
      WHERE 
        IFNULL(tc.lab.name, IFNULL(tc.lab.id,tc.lab.classification)) IS NOT NULL
      """, rec.schema_name, rec.schema_name, rec.schema_name);
  END FOR;
END;