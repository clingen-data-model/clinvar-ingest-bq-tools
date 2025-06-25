CREATE OR REPLACE FUNCTION `clinvar_ingest.formatNearestMonth`(arg DATE)
RETURNS STRING
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/bq-utils.js'])
AS r"""
  return formatNearestMonth(arg);
""";
