CREATE OR REPLACE FUNCTION `clinvar_curator.formatNearestMonth`(arg DATE)
RETURNS STRING
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-gk-pilot/libraries/bq-utils.js'])
AS r"""
  return formatNearestMonth(arg);
""";
