CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.schemas_on_or_after`(on_or_after_date DATE)
AS (
  -- the state of schemas available on or after a certain date
  -- if the date lands on a schema release date then that will be the first schema
  -- if the date is prior to the earliest release date then return all schemas
  -- otherwise the schema with the release date just prior to that date will be the first schema
  WITH x AS (
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
  )
  SELECT
    x.schema_name,
    x.release_date,
    x.prev_release_date,
    x.next_release_date
  FROM x
  WHERE (on_or_after_date > x.prev_release_date AND on_or_after_date < x.next_release_date) OR on_or_after_date <= x.release_date
  ORDER BY 2
);

-- select * from `clinvar_ingest.schemas_on_or_after`(DATE('2020-06-01'));