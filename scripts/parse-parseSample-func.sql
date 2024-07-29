CREATE OR REPLACE FUNCTION `clinvar_curator.parseSample`(json STRING)
RETURNS STRUCT<
  sample_description STRUCT<
    description STRUCT<
      element_value STRING,
      type STRING,
      citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >,
    citation STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>
  >,
  origin STRING,
  ethnicity STRING,
  geographic_origin STRING,
  tissue STRING,
  cell_line STRING,
  species STRING,
  taxonomy_id STRING,
  age ARRAY<STRUCT<value INT64, type STRING,age_unit STRING>>,
  strain STRING,
  affected_status STRING,
  number_tested INT64,
  number_males INT64,
  number_females INT64,
  number_chr_tested INT64,
  gender STRING,
  family_data STRUCT<
    family_history STRING,
    num_families INT64,
    num_families_with_variant INT64,
    num_families_with_segregation_observed INT64,
    pedigree_id STRING,
    segregation_observed STRING>,
  proband STRING,
  indication STRUCT<
    trait ARRAY<STRUCT<
      name ARRAY<STRUCT<
        element_value STRING,
        type STRING,
        citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
        xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
        comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
      >>,
      symbol ARRAY<STRUCT<
        element_value STRING,
        type STRING,
        citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
        xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
        comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
      >>,
      attribute_set ARRAY<STRUCT<
        attribute STRUCT<
          type STRING,
          value STRING,
          integer_value INT64,
          date_value DATE
        >,
        citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
        xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
        comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
      >>,
      trait_relationship ARRAY<STRUCT<
        name ARRAY<STRUCT<
          element_value STRING,
          type STRING,
          citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
          xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
          comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
        >>,
        symbol ARRAY<STRUCT<
          element_value STRING,
          type STRING,
          citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
          xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
          comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
        >>,
        attribute_set ARRAY<STRUCT<
          attribute STRUCT<
            type STRING,
            value STRING,
            integer_value INT64,
            date_value DATE
          >,
          citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
          xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
          comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
        >>,
        citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
        xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
        source ARRAY<STRING>,
        type STRING
      >>,
      citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>,
      type STRING,
      clinical_features_affected_status STRING,
      id STRING
    >>,
    name ARRAY<STRUCT<
      element_value STRING,
      type STRING,
      citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >>,
    symbol ARRAY<STRUCT<
      element_value STRING,
      type STRING,
      citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >>,
    attribute_set ARRAY<STRUCT<
      attribute STRUCT<
        type STRING,
        value STRING,
        integer_value INT64,
        date_value DATE
      >,
      citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >>,
    citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
    xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
    comment STRUCT<text STRING, type STRING, source STRING>,
    type STRING,
    id STRING
  >,
  citation ARRAY<STRUCT<id STRING, source STRING, url STRING, type STRING, abbrev STRING, text STRING, curie STRING>>,
  xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
  comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>,
  source_type STRING>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-gk-pilot/libraries/parse-utils.js'])
AS r"""
  return parseSample(json);
""";

-- test
WITH x as (

  SELECT
    """
    {
      "Method":{"Description":{"$":"Sanger Sequencing"},"MethodType":{"$":"phenotyping only"},"ObsMethodAttribute":{"Attribute":{"$":"GeneDx","@Type":"TestingLaboratory","@dateValue":"2018-11-09","@integerValue":"26957"},"Comment":{"$":"Uncertain significance"}},"Purpose":{"$":"validation"},"TypePlatform":{"$":"Exome Sequencing"}},
      "ObservedData":{"Attribute":{"$":"not provided","@Type":"Description"}},
      "Sample":{
        "AffectedStatus":{"$":"unknown"},
        "Age":[{"$":"0","@Type":"minimum","@age_unit":"years"},{"$":"9","@Type":"maximum","@age_unit":"years"}],
        "Gender":{"$":"female"},
        "Indication":{
          "@Type":"Indication",
          "Trait":{"@Type":"Finding","Name":{"ElementValue":{"$":"Diagnostic","@Type":"Preferred"}}}
        },
        "Origin":{"$":"maternal"},
        "Species":{"$":"human","@TaxonomyId":"9606"}
      }
    }
    """ as content
),
samples as (
select 
  `clinvar_curator.parseSample`(x.content) as sample
from x
)
select
  s.sample.indication.trait as indication_trait
from samples as s
;
