CREATE OR REPLACE FUNCTION `clinvar_ingest.parseAttributeSet`(json STRING)
RETURNS 
  ARRAY<
    STRUCT<
      attribute STRUCT<type STRING, value STRING, integer_value INT64, date_value DATE>,
      citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >
  >
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseAttributeSet(json);
""";


-- test
WITH x as (
  SELECT
    """
    {
      "AttributeSet": [
        {
          "Attribute": {
            "$": "my test",
            "@Type": "TestName",
            "@integerValue": "10",
            "@dateValue": "2022-01-01"
          },
          "Citation": [
            {
              "ID": {
                "$": "12345678",
                "@Source": "PubMed"
              }
            }
          ],
          "XRef": [
            {
              "@DB": "PubMed",
              "@ID": "12345678",
              "@Type": "PMID"
            }
          ],
          "Comment": [
            {
              "$": "This is a comment."
            }
          ]
        },
        {
          "Attribute": {
            "$": "your test",
            "@Type": "TestName",
            "@integerValue": "20",
            "@dateValue": "2022-02-02"
          },
          "Citation": [
            {
              "ID": {
                "$": "87654321",
                "@Source": "PubMed"
              }

            },
            {"@Type":"general","CitationText":{"$":"LabCorp Variant Classification Summary - May 2015.docx"},"URL":{"$":"https://submit.ncbi.nlm.nih.gov/ft/byid/rtxspsnt/labcorp_variant_classification_method_-_may_2015.pdf"}}
          ],
          "XRef": [
            {
              "@DB": "PubMed",
              "@ID": "87654321",
              "@Type": "PMID"
            }
          ],
          "Comment": [
            {
              "$": "This is another comment."
            }
          ]
        }
      ]
    }
    """ as content
)
select `clinvar_ingest.parseAttributeSet`(x.content) as sx from x;
