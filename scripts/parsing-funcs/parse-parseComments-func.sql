CREATE OR REPLACE FUNCTION `clinvar_ingest.parseComments`(json STRING)
RETURNS ARRAY<STRUCT<text STRING, type STRING, source STRING>>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseComments(json);
""";

CREATE OR REPLACE FUNCTION `clinvar_ingest.parseCommentItems`(json_comments ARRAY<STRING>)
RETURNS ARRAY<STRUCT<db STRING, id STRING, type STRING, status STRING, url STRING>>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseCommentItems(json_xrefs);
""";

-- test
WITH x as (

  SELECT
    """
    {
      "AttributeSet": {
        "Attribute": {
          "$": "Mendelics Assertion Criteria 2017",
          "@Type": "AssertionMethod"
        },
        "Citation": {
          "URL": {
            "$": "https://submit.ncbi.nlm.nih.gov/ft/byid/chhjzatu/mendelics_assertion_criteria_2017.pdf"
          }
        }
      },
      "ClinVarAccession": {
        "@DateCreated": "2020-01-09",
        "@DateUpdated": "2020-01-09"
      },
      "Comment": [
        {
          "$": "Notes: None",
          "@DataSource": "ClinGen",
          "@Type": "FlaggedComment"
        },
        {
          "$": "Reason: Claim with insufficient supporting evidence",
          "@DataSource": "ClinGen",
          "@Type": "FlaggedComment"
        }
      ]
    }
    """ as content
)
select JSON_EXTRACT(x.content,r'$'), `clinvar_ingest.parseComments`(JSON_EXTRACT(x.content,r'$')) as comment from x;
