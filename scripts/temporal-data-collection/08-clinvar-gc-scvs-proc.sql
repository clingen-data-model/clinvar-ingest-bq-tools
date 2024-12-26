CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_gc_scvs`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date clinvar_gc_scvs
  CALL `clinvar_ingest.validate_last_release`('clinvar_gc_scvs', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = "Skipping clinvar_gc_scvs processing. " + validation_message;
    RETURN;
  END IF;

  -- deletes
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_gc_scvs` cgs
      SET 
        deleted_release_date = %T,
        deleted_count = deleted_count + 1
    WHERE 
      cgs.deleted_release_date is NULL 
      AND 
      NOT EXISTS (
        SELECT 
          gscv.id 
        FROM `%s.gc_scv` gscv
        WHERE 
          gscv.variation_id = cgs.variation_id 
          AND
          gscv.id = cgs.id 
          AND 
          gscv.version = cgs.version 
          AND
          gscv.lab_date_reported IS NOT DISTINCT FROM cgs.lab_date_reported 
          AND
          gscv.lab_id IS NOT DISTINCT FROM cgs.lab_id 
          AND
          gscv.sample_id IS NOT DISTINCT FROM cgs.sample_id
      )
  """, release_date, schema_name);

  -- updated gscv id+ver
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_gc_scvs` cgs
    SET 
      cgs.variation_id = gscv.variation_id,
      cgs.submitter_id = gscv.submitter_id,
      cgs.method_desc = gscv.method_desc,
      cgs.method_type = gscv.method_type,
      cgs.lab_classification = gscv.lab_classification,
      cgs.lab_classif_type = gscv.lab_classif_type,
      cgs.lab_type = gscv.lab_type,
      cgs.end_release_date = %T,
      cgs.deleted_release_date = NULL
    FROM `%s.gc_scv` gscv
    WHERE 
      gscv.variation_id = cgs.variation_id 
      AND
      gscv.id = cgs.id 
      AND 
      gscv.version = cgs.version 
      AND
      gscv.lab_date_reported IS NOT DISTINCT FROM cgs.lab_date_reported 
      AND
      gscv.lab_id IS NOT DISTINCT FROM cgs.lab_id 
      AND
      gscv.sample_id IS NOT DISTINCT FROM cgs.sample_id
  """, release_date, schema_name);

  -- new gscv variation+id+version
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_gc_scvs` (
      variation_id, 
      id, 
      version, 
      submitter_id, 
      method_desc,
      method_type,
      lab_name,
      lab_date_reported,
      lab_id,
      lab_classification,
      lab_classif_type,
      lab_type,
      sample_id,
      start_release_date, 
      end_release_date
    )
    SELECT 
      gscv.variation_id,
      gscv.id, 
      gscv.version, 
      gscv.submitter_id, 
      gscv.method_desc,
      gscv.method_type,
      gscv.lab_name,
      gscv.lab_date_reported,
      gscv.lab_id,
      gscv.lab_classification,
      gscv.lab_classif_type,
      gscv.lab_type,
      gscv.sample_id,
      %T as start_release_date,
      %T as end_release_date
    FROM `%s.gc_scv` gscv
    WHERE 
      NOT EXISTS (
        SELECT 
          cgs.id 
        FROM `clinvar_ingest.clinvar_gc_scvs` cgs
        WHERE 
          gscv.variation_id = cgs.variation_id 
          AND
          gscv.id = cgs.id 
          AND 
          gscv.version = cgs.version 
          AND
          gscv.lab_date_reported IS NOT DISTINCT FROM cgs.lab_date_reported 
          AND
          gscv.lab_id IS NOT DISTINCT FROM cgs.lab_id 
          AND
          gscv.sample_id IS NOT DISTINCT FROM cgs.sample_id
      )
  """, release_date, release_date, schema_name);

  SET result_message = "clinvar_gc_scvs processed successfully."; 

END;