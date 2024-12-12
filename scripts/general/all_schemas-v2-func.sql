CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.all_schemas_v2`()
AS (
  -- the state of al clinvar schemas available at the moment
  SELECT 
    r.schema_name,
    r.release_date,
    LAG(r.release_date, 1, DATE('0001-01-01')) OVER (ORDER BY r.release_date ASC) AS prev_release_date,
    LEAD(r.release_date, 1, DATE('9999-12-31')) OVER (ORDER BY r.release_date ASC) AS next_release_date
  FROM (

    SELECT
      iss.schema_name,
      CAST(REGEXP_REPLACE(iss.schema_name, r'clinvar_(\d{4})_(\d{2})_(\d{2}).*', '\\1-\\2-\\3') as DATE) AS release_date
    FROM INFORMATION_SCHEMA.SCHEMATA iss
    WHERE 
      (
        REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\d{4}_\d{2}_\d{2}_v\d_\d+_\d+$')
      OR
        REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\d{4}_\d{2}_\d{2}_v\d_\d+_\d+_alpha\d*$') 
      )
  ) r
  ORDER BY 2
);  