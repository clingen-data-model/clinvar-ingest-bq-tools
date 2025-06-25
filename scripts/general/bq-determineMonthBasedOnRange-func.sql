CREATE OR REPLACE FUNCTION `clinvar_ingest.determineMonthBasedOnRange`(startDate DATE, endDate DATE)
RETURNS STRUCT<yymm STRING, monyy STRING>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/bq-utils.js'])
AS r"""
  return determineMonthBasedOnRange(startDate, endDate);
""";


select `clinvar_ingest.determineMonthBasedOnRange`(DATE'2024-01-15', CURRENT_DATE());
