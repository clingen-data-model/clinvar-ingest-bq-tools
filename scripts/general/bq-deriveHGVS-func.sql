CREATE OR REPLACE FUNCTION `clinvar_ingest.deriveHGVS`(
  variationType STRING,
  seqLoc STRUCT<
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
    >
  )
RETURNS STRING
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return deriveHGVS(variationType, seqLoc);
""";

-- TESTs
WITH x as (
  SELECT
    'single nucleotide variant' as variation_type,
    -- establish the structure's data types since the null values are not directly mapped to the precise structure definition needed.
    STRUCT(
      CAST(null AS BOOL) as for_display,
      CAST(null AS STRING) as assembly,
      CAST(null AS STRING) as assembly_accession_version,
      CAST(null AS STRING) as assembly_status,
      'NC_012920.1' as accession,
      'MT' as chr,
      CAST(null AS INT64) as start,
      CAST(null AS INT64) as stop,
      CAST(null AS INT64) as innert_start,
      CAST(null AS INT64) as inner_stop,
      CAST(null AS INT64) as outer_start,
      CAST(null AS INT64) as outer_stop,
      CAST(null AS INT64) as variant_length,
      CAST(null AS INT64) as display_start,
      CAST(null AS INT64) as display_stop,
      100 as position_vcf,
      "A" as reference_allele_vcf,
      "G" as alternate_allele_vcf,
      CAST(null AS STRING) as strand,
      CAST(null AS STRING) as reference_allele,
      CAST(null AS STRING) as alternate_allele,
      CAST(null AS BOOL) as for_display_length
      ) as seq
  UNION ALL
  SELECT
    'copy number loss' as variation_type,
    STRUCT(null, null, null, null, 'NC_001.10', '1', 420, 430, null, null, null, null, null, null, null, null, null, null, null, null, null, null) as seq
  UNION ALL
  SELECT
    'copy number gain' as variation_type,
    STRUCT(null, null, null, null, 'NC_001.10', 'MT', null, null, 50, 70, null, null, null, null, null, null,null, null, null, null, null, null) as seq
  UNION ALL
  SELECT
    'Deletion' as variation_type,
    STRUCT(null, null, null, null, 'NC_001.10', '1', null, null, null, null, 900, 2001, null, null, null, null,null, null, null, null, null, null) as seq
  UNION ALL
  SELECT
    'Duplication' as variation_type,
    STRUCT(null, null, null, null, 'NC_001.10', '1', null, null, 50, 70, 900, 2001, null, null, null, null,null, null, null, null, null, null) as seq
)
SELECT
  `clinvar_ingest.deriveHGVS`( x.variation_type, x.seq),
  x.variation_type,
  x.seq
FROM x;
