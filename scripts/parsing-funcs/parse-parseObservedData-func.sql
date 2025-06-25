CREATE OR REPLACE FUNCTION `clinvar_ingest.parseObservedData`(json STRING)
RETURNS
  ARRAY<
    STRUCT<
      attribute STRUCT<type STRING, value STRING, integer_value INT64, date_value DATE>,
      severity STRING,
      citation ARRAY<STRUCT<id ARRAY<STRUCT<id STRING,source STRING, curie STRING>>,url STRING,type STRING,abbrev STRING, text STRING>>,
      xref ARRAY<STRUCT<db STRING, id STRING, url STRING, type STRING, status STRING>>,
      comment ARRAY<STRUCT<text STRING, type STRING, source STRING>>
    >
  >
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseObservedData(json);
""";

-- test
WITH x as (
  SELECT
  """
    {
      "ObservedData":
      [
        {"Attribute":{"$":"Autosomal dominant inheritance","@Type":"ModeOfInheritance"}},
        {"Attribute":{"$":"ACMG Guidelines, 2015","@Type":"AssertionMethod"},
          "Citation":{"@Abbrev":"ACMG, 2015","@Type":"practice guideline","ID":{"$":"25741868"}}},
        {"Attribute": {"@Type": "VariantAlleles","@integerValue": "2"},
          "Severity": "mild",
          "Citation": [{"ID": {"$": "25741868", "@Source": "PubMed"}}],
          "XRef": [{"@DB": "PubMed","@ID": "25741868","@Type": "PMID"}],
          "Comment": [{"$": "This is a comment."}]
        }
      ],
      "ClinVarAccession":{"@DateCreated":"2014-11-23","@DateUpdated":"2014-11-23"},
      "Comment":{"$":"Likely benign based on allele frequency in 1000 Genomes Project or ESP global frequency and its presence in a patient with a rare or unrelated disease phenotype. NOT Sanger confirmed"}
    }
  """ as content
  UNION ALL
  SELECT
  """
  {
    "Method":{
      "MethodType":{"$":"literature only"}},
      "ObservedData":[
        {
          "Attribute":{"$":"In complementation experiments involving the effect of various XRCC4 mutations on double-strand break repair, Guo et al. (2015) observed that the W43R mutant showed little complementation when expressed with the c.760delG mutant (194363.0009). They concluded that the W43R mutation impairs XRCC4 function.","@Type":"Description"},
          "Citation":{"ID":{"$":"26255102","@Source":"PubMed"}}
        },{
          "Attribute":{"$":"In a 4-year-old Saudi Arabian girl with severe short stature and microcephaly (SSMED; 616541), Shaheen et al. (2014) identified homozygosity for a c.127T-C transition (c.127T-C, NM_003401.3) in the XRCC4 gene, resulting in a trp43-to-arg (W43R) substitution at a highly conserved residue. Functional analysis in XRCC4-deficient fibroblasts demonstrated significant impairment to DNA damage repair following ionizing radiation.","@Type":"Description"},
          "Citation":{"ID":{"$":"24389050","@Source":"PubMed"}},
          "XRef":{"@DB":"OMIM","@ID":"616541","@Type":"MIM"}
        },{
          "Attribute":{"$":"In a Saudi Arabian boy with short stature, extreme microcephaly, and lymphopenia, Murray et al. (2015) identified homozygosity for the W43R mutation, located within the head domain of the XRCC4 gene. The mutation, which segregated with disease in the family, was reported to have an allele frequency of 3.3 x 10(-5) in control populations, with no homozygotes detected in the ExAC database. Expression and purification of recombinant XRCC4 in E. coli cells showed that the W43R substitution greatly reduces protein solubility compared to wildtype, and that the XRCC4 mutant is more prone to degradation. Analysis of circular dichroism spectra indicated that although the mutant protein is folded, it differs from wildtype. However, because in vitro ligation assays did not reveal any significant reduction in ligation efficiency with the mutant compared to wildtype, Murray et al. (2015) concluded that the W43R substitution more likely affects protein stability than directly affecting XRCC4 function. Immunoblotting of patient fibroblasts demonstrated strongly reduced levels of XRCC4 as well as of XLF (NHEJ1; 611290) and LIG4 (601837), indicating that the reduction in XRCC4 affects stability of the entire complex.","@Type":"Description"},
          "Citation":{"ID":{"$":"25728776","@Source":"PubMed"}},
          "XRef":[{"@DB":"OMIM","@ID":"611290","@Type":"MIM"},{"@DB":"OMIM","@ID":"601837","@Type":"MIM"}]
        }
      ],
      "Sample":{"AffectedStatus":{"$":"not provided"},"Origin":{"$":"germline"},"Species":{"$":"human"}}
    }
  """ as content
)
select `clinvar_ingest.parseObservedData`(x.content) as od from x;
