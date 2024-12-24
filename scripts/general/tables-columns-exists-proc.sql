CREATE OR REPLACE PROCEDURE `clinvar_ingest.check_table_exists`(
    schema_name STRING,
    table_name STRING,
    OUT table_exists BOOL
)
BEGIN
  EXECUTE IMMEDIATE FORMAT("""
    SELECT EXISTS(
      SELECT 1 
      FROM `%s.INFORMATION_SCHEMA.TABLES`
      WHERE table_name = '%s'
    )
  """, schema_name, table_name) INTO table_exists;
END;

CREATE OR REPLACE PROCEDURE `clinvar_ingest.check_column_exists`(
    schema_name STRING,
    table_name STRING,
    column_name STRING,
    OUT column_exists BOOL
)
BEGIN
  EXECUTE IMMEDIATE FORMAT("""
    SELECT EXISTS(
      SELECT 1
      FROM `%s.INFORMATION_SCHEMA.COLUMNS`
      WHERE table_name = '%s' AND column_name = '%s'
    )
  """, schema_name, table_name, column_name) INTO column_exists;
END;

CREATE OR REPLACE PROCEDURE `clinvar_ingest.validate_last_release`(
    table_name STRING,
    previous_release_date DATE
)
BEGIN
  DECLARE last_processed_release_date DATE;

  EXECUTE IMMEDIATE FORMAT("""
    SELECT 
      MAX(end_release_date) 
    FROM `clinvar_ingest.%s`
  """, table_name) INTO last_processed_release_date;

  -- validate that the max end_release_date is the previous release date otherwise throw an error
  IF last_processed_release_date != previous_release_date THEN
    BEGIN
      DECLARE error_message STRING;
      SET error_message = FORMAT("""
        The last processed release date (%t) in clinvar_genes
        is not equal to the expected previous release date (%t).
        Processing of clinvar_genes will not continue.
      """, last_processed_release_date, previous_release_date);
      RAISE USING message = error_message;
    END;
  END IF;
  
END;
