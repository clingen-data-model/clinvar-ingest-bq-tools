CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.all_schemas`()
AS (
  -- the state of al clinvar schemas available at the moment
  SELECT 
    r.schema_name,
    r.release_date,
    LAG(r.release_date, 1, DATE('0001-01-01')) OVER (ORDER BY r.release_date ASC) AS prev_release_date,
    LEAD(r.release_date, 1, DATE('9999-12-31')) OVER (ORDER BY r.release_date ASC) AS next_release_date
  FROM (
    SELECT
      "clinvar_2019_06_01_v0" as schema_name,
      v.release_date
    FROM `clinvar_2019_06_01_v0.variation` v
    GROUP BY v.release_date
    UNION ALL
    SELECT
      iss.schema_name,
      CAST(REGEXP_REPLACE(iss.schema_name, r'clinvar_(\d{4})_(\d{2})_(\d{2}).*', '\\1-\\2-\\3') as DATE) AS release_date
    FROM INFORMATION_SCHEMA.SCHEMATA iss
    WHERE 
      (
        (
          iss.catalog_name = 'clingen-stage'
          AND
          REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\d{4}_\d{2}_\d{2}.*')
        )
        OR
        (
          iss.catalog_name = 'clingen-dev'
          AND
          REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\d{4}_\d{2}_\d{2}_v\d+_\d+_\d+_beta\d+$') 
        )
      )
      AND
      iss.schema_name <> "clinvar_2019_06_01_v0"
  ) r
  ORDER BY 2
);  