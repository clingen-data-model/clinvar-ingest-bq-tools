CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.schema_on_v2`(on_date DATE)
AS (
  -- the state of schemas available on a certain date
  -- if the date lands on a schema release date then that will be the schema
  -- otherwise the schema with the release date just prior to that date will be the schema
  SELECT
    x.schema_name,
    x.release_date,
    x.prev_release_date,
    x.next_release_date
  FROM `clinvar_ingest.all_schemas_v2`() x
  WHERE on_date >= x.release_date
  ORDER BY 2 DESC
  LIMIT 1
);