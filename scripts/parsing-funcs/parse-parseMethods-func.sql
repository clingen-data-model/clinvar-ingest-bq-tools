CREATE OR REPLACE FUNCTION `clinvar_ingest.parseMethods`(json STRING)
RETURNS
  ARRAY<
    STRUCT<
      name_platform STRING,
      type_platform STRING,
      purpose STRING,
      result_type STRING,
      min_rerported INT64,
      max_reported INT64,
      reference_standard STRING,
      description STRING,
      source_type STRING,
      method_type STRING,
      citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      software ARRAY<STRUCT<name STRING, version STRING, purpose STRING>>,
      method_attribute
        ARRAY<STRUCT<attribute STRUCT<type STRING, value STRING, integer_value INT64, date_value DATE>>>,
      obs_method_attribute
        ARRAY<
          STRUCT<
            attribute STRUCT<type STRING, value STRING, integer_value INT64, date_value DATE>,
            comment STRUCT<text STRING, type STRING, source STRING>
          >
        >
    >
  >
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseMethods(json);
""";

-- test
WITH x as (

  SELECT
    """
    {
      "Method": [
        {
          "Description": {
            "$": "Microarray"
          },
          "MethodType": {
            "$": "clinical testing"
          },
          "NamePlatform": {
            "$": "Agilent ISCA 44K"
          },
          "Purpose": {
            "$": "Discovery"
          },
          "SourceType": {
            "$": "submitter-generated"
          },
          "TypePlatform": {
            "$": "Oligo aCGH"
          }
        },
        {
          "Description": {
            "$": "Fluorescence in situ hybridization"
          },
          "MethodType": {
            "$": "clinical testing"
          },
          "ObsMethodAttribute": {
            "Attribute": {
              "$": "Pass",
              "@Type": "MethodResult"
            }
          },
          "Purpose": {
            "$": "Validation"
          },
          "SourceType": {
            "$": "submitter-generated"
          },
          "TypePlatform": {
            "$": "FISH"
          }
        }
      ],
      "ObservedData": {
        "Attribute": {
          "@Type": "VariantAlleles",
          "@integerValue": "1"
        }
      },
      "Sample": {
        "AffectedStatus": {
          "$": "yes"
        },
        "Origin": {
          "$": "paternal"
        },
        "SampleDescription": {
          "Description": {
            "$": "Phenotype: fine motor delay, gross motor delay, speech delay, Asperger syndrome features, family history of mother with learning disability, maternal first cousin with cleft, absent corpus callosum in paternal aunt",
            "@Type": "public"
          }
        },
        "Species": {
          "$": "human",
          "@TaxonomyId": "9606"
        }
      },
      "XRef": {
        "@DB": "dbVar",
        "@ID": "nssv576370",
        "@Type": "dbVarVariantCallId"
      }
    }
    """ as content
)
select `clinvar_ingest.parseMethods`(x.content) as method from x;
