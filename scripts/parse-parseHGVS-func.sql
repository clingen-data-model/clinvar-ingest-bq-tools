CREATE OR REPLACE FUNCTION `clinvar_ingest.parseHGVS`(json STRING)
  RETURNS ARRAY<
    STRUCT<
      nucleotide_expression STRUCT<
        expression STRING,
        sequence_type STRING,
        sequence_accession_version STRING,
        sequence_accession STRING,
        sequence_version STRING,
        change STRING,
        assembly STRING,
        submitted STRING,
        mane_select BOOL,
        mane_plus_clinical BOOL
      >,
      protein_expression STRUCT<
        expression STRING,
        sequence_accession_version STRING,
        sequence_accession STRING,
        sequence_version STRING,
        change STRING
      >,
      molecular_consequence ARRAY<STRUCT<db STRING, id STRING, type STRING, status STRING, url STRING>>,
      assembly STRING,
      type STRING>>
LANGUAGE js 
  OPTIONS (library=["gs://clinvar-ingest/bq-tools/parse-utils.js"]) 
AS r"""
  return parseHGVS(json);
""";


-- test
WITH x AS (
  SELECT
    """
    {
      "HGVS": [{
        "NucleotideExpression": {
          "Expression": {
            "$": "NM_000059.3:c.1234A>G"
          },
          "@sequenceType": "DNA",
          "@sequenceAccessionVersion": "NM_000059.3",
          "@sequenceAccession": "NM_000059",
          "@sequenceVersion": "3",
          "@change": "1234A>G",
          "@Assembly": "GRCh38",
          "@Submitted": "2019-12-01",
          "@MANESelect": "true",
          "@MANEPlusClinical": "false"
        },
        "ProteinExpression": {
          "Expression": {
            "$": "NP_000050.2:p.Arg123Gly"
          },
          "@sequenceAccessionVersion": "NP_000050.2",
          "@sequenceAccession": "NP_000050",
          "@sequenceVersion": "2",
          "@change": "p.Arg123Gly"
        },
        "MolecularConsequence": [{
          "@DB": "SO",
          "@ID": "SO:0001627",
          "@Type": "intron variant",
          "@Status": "test_status",
          "@URL": "http://mytest.url"
        }],
        "@Type": "coding",
        "@Assembly": "GRCh38"
      }]
    }
    """ as content
)
select `clinvar_ingest.parseHGVS`(x.content) as hgvs from x;