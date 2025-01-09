CREATE OR REPLACE PROCEDURE `clinvar_ingest.check_release_dates`(
  schema_name STRING,
  table_names ARRAY<STRING>,
  OUT validation_errors ARRAY<STRING>
)
BEGIN
  DECLARE release_date_mismatch INT64;
  DECLARE release_date DATE;
  
  SET validation_errors = [];
  SET release_date = DATE(REGEXP_REPLACE(schema_name, r'clinvar_(\d{4})_(\d{2})_(\d{2}).*', '\\1-\\2-\\3'));

  FOR table IN (
    SELECT
      name
    FROM UNNEST(table_names) AS name
  ) 
  DO
   
    -- make sure the release date for each table matches the date in the schema name
    EXECUTE IMMEDIATE FORMAT("""
      SELECT
        COUNT(*)
      FROM `%s.%s` t
      WHERE 
        t.release_date IS DISTINCT FROM DATE'%t'
    """, schema_name, table.name, release_date) INTO release_date_mismatch; 

    IF release_date_mismatch > 0 THEN
      SET validation_errors = ARRAY_CONCAT(validation_errors, [CONCAT('Release date values in ', schema_name, '.', table.name,  
                                  ' has ', release_date_mismatch, ' records that do not match the dataset name\'s release date.')]); 
    END IF;

  END FOR;

END;