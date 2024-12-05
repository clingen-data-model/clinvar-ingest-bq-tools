CREATE OR REPLACE FUNCTION `clinvar_ingest.parseAggDescription`(json STRING)
RETURNS STRUCT<
  description ARRAY<STRUCT<
    clinical_impact_assertion_type STRING,
    clinical_impact_clinical_significance STRING,
    date_last_evaluated DATE,
    num_submissions INT64,
    interp_description STRING
  >>
>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseAggDescription(json);
""";

-- test
WITH x as (
  SELECT
  """
  {
    "Description": [
    {
      "@ClinicalImpactAssertionType": "diagnostic", 
      "@ClinicalImpactClinicalSignificance": "supports diagnosis", 
      "@DateLastEvaluated": "2024-01-24", 
      "@SubmissionCount": "1", 
      "$": "Tier I - Strong"
    }, 
    {
      "@ClinicalImpactAssertionType": "prognostic", 
      "@ClinicalImpactClinicalSignificance": "better outcome", 
      "@DateLastEvaluated": "2024-01-23", 
      "@SubmissionCount": "1", 
      "$": "Tier I - Strong"
    }
  ]}
  """ as content  
),
aggDescriptions as (
  select `clinvar_ingest.parseAggDescription`(x.content) as aggDescription from x
)
select ad.* from aggDescriptions as ad
;