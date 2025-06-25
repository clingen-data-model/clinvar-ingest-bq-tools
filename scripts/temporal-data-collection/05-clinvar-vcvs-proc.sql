CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_vcvs`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_vcvs
  CALL `clinvar_ingest.validate_last_release`('clinvar_vcvs', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted vcvs (where it exists in clinvar_vcvs (for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
      SET
        deleted_release_date = %T
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

  -- updated vcv
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
      SET
        end_release_date = vcv.release_date
    FROM `%s.variation_archive` vcv
    WHERE
      vcv.variation_id = cvcv.variation_id
      AND
      vcv.id = cvcv.id
      AND
      vcv.version = cvcv.version
      AND
      cvcv.deleted_release_date is NULL
  """, schema_name);

  -- new variation_archive
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_vcvs` (
      variation_id,
      id,
      version,
      full_vcv_id,
      start_release_date,
      end_release_date
    )
    SELECT
      vcv.variation_id,
      vcv.id,
      vcv.version,
      FORMAT('%%s.%%i', vcv.id, vcv.version) as full_vcv_id,
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
          AND
          cvcv.deleted_release_date is NULL
      )
  """, schema_name);

  SET result_message = 'clinvar_vcvs processed successfully.';

END;
