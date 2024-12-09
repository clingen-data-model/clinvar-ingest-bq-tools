CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.schemas_on_or_after_v2`(on_or_after_date DATE)
AS (
  -- the state of schemas available on or after a certain date
  -- if the date lands on a schema release date then that will be the first schema
  -- if the date is prior to the earliest release date then return all schemas
  -- otherwise the schema with the release date just prior to that date will be the first schema
  SELECT
    x.schema_name,
    x.release_date,
    x.prev_release_date,
    x.next_release_date
  FROM `clinvar_ingest.all_schemas_v2`() x
  WHERE (on_or_after_date > x.prev_release_date AND on_or_after_date < x.next_release_date) OR on_or_after_date <= x.release_date
  ORDER BY 2
);

-- select * from `clinvar_ingest.schemas_on_or_after_v2`(DATE('2020-06-01'));