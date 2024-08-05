CREATE OR REPLACE FUNCTION `clinvar_ingest.parseSequenceLocations`(json STRING)
RETURNS ARRAY<STRUCT<
  for_display BOOL,
  assembly STRING, 
  assembly_accession_version STRING, 
  assembly_status STRING, 
  accession STRING, 
  chr STRING, 
  start INT64, 
  stop INT64, 
  inner_start INT64, 
  inner_stop INT64, 
  outer_start INT64, 
  outer_stop INT64, 
  variant_length INT64, 
  display_start INT64, 
  display_stop INT64,
  position_vcf INT64,
  reference_allele_vcf STRING,
  alternate_allele_vcf STRING,
  strand STRING,
  reference_allele STRING,
  alternate_allele STRING,
  for_display_length BOOL
>>
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseSequenceLocations(json);
""";

-- test
WITH x as (

  SELECT
    """
    {
      "HGVSlist":{
        "HGVS":[
          {"@Type":"coding","NucleotideExpression":{"@change":"c.-297_-291delCACACACinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"LRG_333t1","@sequenceAccessionVersion":"LRG_333t1","Expression":{"$":"LRG_333t1:c.-297_-291delCACACACinsGAGAGAGAGAGAGAGAG"}}},
          {"@Type":"genomic","NucleotideExpression":{"@change":"g.5018_5024delinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"LRG_333","@sequenceAccessionVersion":"LRG_333","Expression":{"$":"LRG_333:g.5018_5024delinsGAGAGAGAGAGAGAGAG"}}},
          {"@Type":"genomic","NucleotideExpression":{"@change":"g.5018_5024delinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"NG_023406","@sequenceAccessionVersion":"NG_023406.2","@sequenceVersion":"2","Expression":{"$":"NG_023406.2:g.5018_5024delinsGAGAGAGAGAGAGAGAG"}}},
          {"@Assembly":"GRCh38","@Type":"genomic, top-level","NucleotideExpression":{"@Assembly":"GRCh38","@change":"g.128891435_128891441delinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"NC_000011","@sequenceAccessionVersion":"NC_000011.10","@sequenceVersion":"10","Expression":{"$":"NC_000011.10:g.128891435_128891441delinsGAGAGAGAGAGAGAGAG"}}},
          {"@Assembly":"GRCh37","@Type":"genomic, top-level","NucleotideExpression":{"@Assembly":"GRCh37","@change":"g.128761330_128761336delinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"NC_000011","@sequenceAccessionVersion":"NC_000011.9","@sequenceVersion":"9","Expression":{"$":"NC_000011.9:g.128761330_128761336delinsGAGAGAGAGAGAGAGAG"}}},
          {"@Type":"coding","MolecularConsequence":{"@DB":"SO","@ID":"SO:0001623","@Type":"5 prime UTR variant"},"NucleotideExpression":{"@MANESelect":"true","@change":"c.-297_-291delinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"NM_000890","@sequenceAccessionVersion":"NM_000890.5","@sequenceVersion":"5","Expression":{"$":"NM_000890.5:c.-297_-291delinsGAGAGAGAGAGAGAGAG"}}},
          {"@Type":"coding","MolecularConsequence":{"@DB":"SO","@ID":"SO:0001623","@Type":"5 prime UTR variant"},"NucleotideExpression":{"@change":"c.-386_-380delinsGAGAGAGAGAGAGAGAG","@sequenceAccession":"NM_001354169","@sequenceAccessionVersion":"NM_001354169.2","@sequenceVersion":"2","Expression":{"$":"NM_001354169.2:c.-386_-380delinsGAGAGAGAGAGAGAGAG"}}}
        ]
      },
      "Location":{
        "CytogeneticLocation":{"$":"11q24.3"},
        "SequenceLocation":[
          {"@Accession":"NC_000011.9","@Assembly":"GRCh37","@AssemblyAccessionVersion":"GCF_000001405.25","@AssemblyStatus":"previous","@Chr":"11","@alternateAlleleVCF":"GAGAGAGAGAGAGAGAG","@display_start":"128761330","@display_stop":"128761336","@positionVCF":"128761330","@referenceAlleleVCF":"CACACAC","@start":"128761330","@stop":"128761336","@variantLength":"17"},
          {"@Accession":"NC_000011.10","@Assembly":"GRCh38","@AssemblyAccessionVersion":"GCF_000001405.38","@AssemblyStatus":"current","@Chr":"11","@alternateAlleleVCF":"GAGAGAGAGAGAGAGAG","@display_start":"128891435","@display_stop":"128891441","@forDisplay":"true","@positionVCF":"128891435","@referenceAlleleVCF":"CACACAC","@start":"128891435","@stop":"128891441","@variantLength":"17"}
        ]
      },
      "XRefList":{"XRef":[{"@DB":"ClinGen","@ID":"CA10637852"},{"@DB":"dbSNP","@ID":"886047993","@Type":"rs"}]}
    }
    """ as content
)
select 
  x.content,
  `clinvar_ingest.parseSequenceLocations`(JSON_EXTRACT(x.content, r'$.Location')) as seq 
from x;
