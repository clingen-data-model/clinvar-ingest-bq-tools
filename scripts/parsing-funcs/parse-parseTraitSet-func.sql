CREATE OR REPLACE FUNCTION `clinvar_ingest.parseTraitSet`(json STRING)
RETURNS STRUCT<
  trait ARRAY<STRUCT<
    name ARRAY<STRUCT<
      element_value STRING,
      type STRING,
      citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >>,
    symbol ARRAY<STRUCT<
      element_value STRING,
      type STRING,
      citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
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
      citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >>,
    trait_relationship STRUCT<type STRING,id STRING>,
    citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
    xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
    comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>,
    type STRING,
    id STRING
  >>,
  type STRING,
  id STRING
>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseTraitSet(json);
""";

-- test
WITH x as (
  SELECT
  """
  {
    "@Type":"Disease",
    "@ID":"8827",
    "Trait":[
      {
      "@ID":"1053",
      "@Type":"Disease",
      "Name":{
        "ElementValue":{
          "@Type":"Preferred",
          "$":"Brachydactyly type B1"
        },
        "XRef":[{
          "@ID":"Brachydactyly+type+B1/7857","@DB":"Genetic Alliance"
        },{
          "@ID":"MONDO:0007220","@DB":"MONDO"
        }]
      },
      "Symbol":[{
        "ElementValue":{
          "@Type":"Preferred","$":"BDB1"
        },
        "XRef":{
          "@Type":"MIM","@ID":"113000","@DB":"OMIM"
        }
      },{
        "ElementValue":{
          "@Type":"Alternate","$":"BDB"
        },
        "XRef":{
          "@Type":"MIM","@ID":"113000","@DB":"OMIM"
        }
      }],
      "AttributeSet":[{
        "Attribute":{
          "@Type":"keyword","$":"ROR2-Related Disorders"
        }
      },{
        "Attribute":{
          "@Type":"GARD id","@integerValue":"18009"
        },
        "XRef":{"@ID":"18009","@DB":"Office of Rare Diseases"

        }
      }],
      "TraitRelationship":{
        "@Type":"co-occurring condition","@ID":"70"
      },
      "XRef":[{
        "@ID":"MONDO:0007220","@DB":"MONDO"
      },{
        "@ID":"C1862112","@DB":"MedGen"
      },{
        "@ID":"93383","@DB":"Orphanet"
      },{
        "@Type":"MIM","@ID":"113000","@DB":"OMIM"
      }]
    }]
  }
  """ as content  
),
traitSets as (
  select `clinvar_ingest.parseTraitSet`(FORMAT('{"TraitSet": %s}', x.content)) as traitSet from x
)
select ts.* from traitSets as ts
;