CREATE OR REPLACE FUNCTION `clinvar_curator.determineMonthBasedOnRange`(startDate DATE, endDate DATE)
RETURNS STRUCT<yymm STRING, monyy STRING>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-gk-pilot/libraries/bq-utils.js'])
AS r"""
  return determineMonthBasedOnRange(startDate, endDate);
""";


select `clinvar_curator.determineMonthBasedOnRange`(DATE'2024-01-15', CURRENT_DATE());