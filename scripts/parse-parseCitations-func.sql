CREATE OR REPLACE FUNCTION `clinvar_curator.parseCitations`(json STRING)
RETURNS ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, curie STRING>>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-gk-pilot/libraries/parse-utils.js'])
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
select `clinvar_curator.parseCitations`(JSON_EXTRACT(x.content,r'$.Interpretation')) as interp from x;