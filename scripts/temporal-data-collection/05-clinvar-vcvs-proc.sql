CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_vcvs`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE project_id STRING;
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  SET project_id = 
  (
    SELECT 
      catalog_name as paroject_id
    FROM `INFORMATION_SCHEMA.SCHEMATA`
    WHERE 
      schema_name = 'clinvar_ingest'
  );

  -- validate the last release date for clinvar_vcvs
  CALL `clinvar_ingest.validate_last_release`('clinvar_vcvs', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  IF (project_id = 'clingen-stage') THEN

    -- deleted vcvs (where it exists in clinvar_vcvs (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cvcv.deleted_release_date is NULL 
        AND
        NOT EXISTS (
          SELECT 
            vcv.id
          FROM `%s.variation_archive` vcv
          LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
          ON 
            cvs1.label = vcv.review_status
          WHERE  
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version 
            AND
            cvs1.rank IS NOT DISTINCT FROM cvcv.rank 
            AND
            vcv.interp_description IS NOT DISTINCT FROM cvcv.agg_classification 
            AND
            vcv.interp_date_last_evaluated IS NOT DISTINCT FROM cvcv.last_evaluated
        )
    """, release_date, schema_name);

    -- updated variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          end_release_date = vcv.release_date,
          deleted_release_date = NULL
      FROM `%s.variation_archive` vcv
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
      ON 
        cvs1.label = vcv.review_status
      WHERE 
        vcv.variation_id = cvcv.variation_id 
        AND 
        vcv.id = cvcv.id 
        AND 
        vcv.version = cvcv.version 
        AND
        cvs1.rank IS NOT DISTINCT FROM cvcv.rank 
        AND
        vcv.interp_description IS NOT DISTINCT FROM cvcv.agg_classification 
        AND
        vcv.interp_date_last_evaluated IS NOT DISTINCT FROM cvcv.last_evaluated
    """, schema_name);

    -- new variation_archive
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_vcvs` (
        variation_id,  
        id, 
        version, 
        rank, 
        last_evaluated, 
        agg_classification, 
        start_release_date, 
        end_release_date
      )
      SELECT 
        vcv.variation_id, 
        vcv.id, 
        vcv.version, 
        cvs1.rank, 
        vcv.interp_date_last_evaluated as last_evaluated,
        vcv.interp_description as agg_classification,
        vcv.release_date as start_release_date, 
        vcv.release_date as end_release_date
      FROM `%s.variation_archive` vcv
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
      ON 
        cvs1.label = vcv.review_status
      WHERE 
        NOT EXISTS (
          SELECT 
            cvcv.id 
          FROM `clinvar_ingest.clinvar_vcvs` cvcv
          WHERE 
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version 
            AND
            cvs1.rank IS NOT DISTINCT FROM cvcv.rank 
            AND
            vcv.interp_description IS NOT DISTINCT FROM cvcv.agg_classification 
            AND
            vcv.interp_date_last_evaluated IS NOT DISTINCT FROM cvcv.last_evaluated
        )
    """, schema_name);

  ELSE

    -- deleted vcvs (where it exists in clinvar_vcvs (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cvcv.deleted_release_date is NULL 
        AND
        NOT EXISTS (
          SELECT 
            vcv.id
          FROM `%s.variation_archive` vcv
          WHERE  
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version
        )
    """, release_date, schema_name);

    -- updated variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          end_release_date = vcv.release_date,
          deleted_release_date = NULL
      FROM `%s.variation_archive` vcv
      WHERE 
        vcv.variation_id = cvcv.variation_id 
        AND 
        vcv.id = cvcv.id 
        AND 
        vcv.version = cvcv.version
    """, schema_name);

    -- new variation_archive
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_vcvs` (
        variation_id,  
        id, 
        version, 
        start_release_date, 
        end_release_date
      )
      SELECT 
        vcv.variation_id, 
        vcv.id, 
        vcv.version, 
        vcv.release_date as start_release_date, 
        vcv.release_date as end_release_date
      FROM `%s.variation_archive` vcv
      WHERE 
        NOT EXISTS (
          SELECT 
            cvcv.id 
          FROM `clinvar_ingest.clinvar_vcvs` cvcv
          WHERE 
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version
        )
    """, schema_name);

  END IF;

  SET result_message = 'clinvar_vcvs processed successfully.';

END;