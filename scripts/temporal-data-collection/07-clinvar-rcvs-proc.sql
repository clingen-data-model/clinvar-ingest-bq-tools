CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_rcvs`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_rcvs
  CALL `clinvar_ingest.validate_last_release`('clinvar_rcvs', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted rcvs (where it exists in clinvar_rcvs (for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_rcvs` crcv
      SET 
        deleted_release_date = %T,
        deleted_count = deleted_count + 1
    WHERE 
      crcv.deleted_release_date is NULL 
      AND
      NOT EXISTS (
        SELECT 
          rcv.id
        FROM `%s.rcv_accession` rcv
        WHERE  
          rcv.variation_id = crcv.variation_id 
          AND
          rcv.trait_set_id = crcv.trait_set_id
          AND 
          rcv.id = crcv.id 
          AND 
          rcv.version = crcv.version
      )
  """, release_date, schema_name);

  -- updated rcv
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_rcvs` crcv
      SET 
        end_release_date = rcv.release_date,
        deleted_release_date = NULL
    FROM `%s.rcv_accession` rcv
    WHERE 
      rcv.variation_id = crcv.variation_id 
      AND
      rcv.trait_set_id = crcv.trait_set_id
      AND 
      rcv.id = crcv.id 
      AND 
      rcv.version = crcv.version
  """, schema_name);

  -- new rcv_accession
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_rcvs` (
      variation_id,  
      trait_set_id,
      id, 
      version, 
      full_rcv_id,
      start_release_date, 
      end_release_date
    )
    SELECT 
      rcv.variation_id, 
      rcv.trait_set_id,
      rcv.id, 
      rcv.version,
      FORMAT('%%s.%%i', rcv.id, rcv.version) as full_rcv_id, 
      rcv.release_date as start_release_date, 
      rcv.release_date as end_release_date
    FROM `%s.rcv_accession` rcv
    WHERE 
      NOT EXISTS (
        SELECT 
          crcv.id 
        FROM `clinvar_ingest.clinvar_rcvs` crcv
        WHERE 
          rcv.variation_id = crcv.variation_id 
          AND
          rcv.trait_set_id = crcv.trait_set_id
          AND 
          rcv.id = crcv.id 
          AND 
          rcv.version = crcv.version
      )
  """, schema_name);

  SET result_message = 'clinvar_rcvs processed successfully.';

END;