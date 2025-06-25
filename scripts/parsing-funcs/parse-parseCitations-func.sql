CREATE OR REPLACE FUNCTION `clinvar_ingest.parseCitations`(json STRING)
RETURNS ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseCitations(json);
""";

-- test
WITH x as (

  SELECT
    """
    {
      "AttributeSet":{
        "Attribute":{"$":"LabCorp Variant Classification Summary - May 2015","@Type":"AssertionMethod"},
        "Citation":{"@Type":"general","CitationText":{"$":"LabCorp Variant Classification Summary - May 2015.docx"},"URL":{"$":"https://submit.ncbi.nlm.nih.gov/ft/byid/rtxspsnt/labcorp_variant_classification_method_-_may_2015.pdf"}}
      },
      "ClinVarAccession":{"@DateCreated":"2017-12-26","@DateUpdated":"2017-12-26"},
      "Interpretation": {"Citation":[{"ID":{"$":"8094613","@Source":"PubMed"}},{"ID":{"$":"21889385","@Source":"PubMed"}}]}
    }

    """ as content
)
select `clinvar_ingest.parseCitations`(JSON_EXTRACT(x.content,r'$.Interpretation')) as interp from x;
