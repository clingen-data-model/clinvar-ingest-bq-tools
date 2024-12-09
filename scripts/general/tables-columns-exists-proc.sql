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