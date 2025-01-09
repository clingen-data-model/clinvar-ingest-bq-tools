CREATE OR REPLACE PROCEDURE `clinvar_ingest.check_required_fields`(
  schema_name STRING,
  table_fields ARRAY<STRUCT<table_name STRING, field_name STRING>>,
  OUT validation_errors ARRAY<STRING>
)
BEGIN
  DECLARE required_nulls INT64;

  SET validation_errors = [];

  FOR field IN (
    SELECT
      field.table_name,
      field.field_name
    FROM UNNEST(table_fields) AS field
  ) 
  DO
    EXECUTE IMMEDIATE FORMAT("""
      SELECT
        COUNT(*)
      FROM `%s.%s` t
      WHERE 
        t.%s IS NULL
    """, schema_name, field.table_name, field.field_name) INTO required_nulls; 

    IF required_nulls > 0 THEN
      SET validation_errors = ARRAY_CONCAT(validation_errors, [CONCAT('Required field ', schema_name, '.', field.table_name, '.', field.field_name, 
                                  ' has ', required_nulls, ' NULL records.')]);                     
    END IF;

  END FOR;

END;