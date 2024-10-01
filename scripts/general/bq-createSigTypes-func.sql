CREATE OR REPLACE FUNCTION `clinvar_ingest.createSigTypes`(nosig_count INTEGER, unc_count INTEGER, sig_count INTEGER)
RETURNS ARRAY<STRUCT<count INTEGER, percent NUMERIC>>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/bq-utils.js'])
AS r"""
  return createSigTypes(nosig_count, unc_count, sig_count);
""";