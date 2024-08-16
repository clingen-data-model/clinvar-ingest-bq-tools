CREATE OR REPLACE FUNCTION `clinvar_ingest.parseGeneLists`(json STRING)
RETURNS ARRAY<STRUCT<symbol STRING, relationship_type STRING, name STRING>>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseGeneLists(json);
""";

-- test
WITH x as (

  SELECT
    """
    {
      "AttributeSet": {
        "Attribute": {
          "$": "NC_000003.11:g.52441401C>A",
          "@Type": "HGVS"
        }
      },
      "GeneList": {
        "Gene": {
          "@Symbol": "BAP1"
        }
      }
    }
    """ as content
)
select `clinvar_ingest.parseGeneLists`(x.content) as interp from x;
