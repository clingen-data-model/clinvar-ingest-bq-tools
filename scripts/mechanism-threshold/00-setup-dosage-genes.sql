-- ============================================================================
-- Mechanism Threshold Analysis: Dosage Genes Table Setup
-- ============================================================================
-- This script creates the dosage_genes table in the clinvar_ingest dataset
-- from the Dosage Sensitivity Curation gene list.
--
-- Prerequisites:
-- 1. Upload the CSV file to GCS:
--    gsutil cp "Dosage genes 2.6.26.csv" gs://clinvar-ingest/mechanism-threshold/dosage_genes_2.6.26.csv
--
-- 2. Create the external table using the definition file:
--    bq mk --external_table_definition=dosage_genes_ext.def \
--       clingen-dev:clinvar_ingest.dosage_genes_ext
--
-- Alternatively, run this script directly to create the table from
-- a pre-loaded external table.
-- ============================================================================

-- Create or replace the dosage_genes table from the external table
CREATE OR REPLACE TABLE `clinvar_ingest.dosage_genes`
AS
SELECT
  gene_symbol,
  -- Extract HGNC ID number from the full HGNC/Dosage ID string
  REGEXP_EXTRACT(hgnc_id, r'HGNC:(\d+)') AS hgnc_id_num,
  hgnc_id AS hgnc_dosage_id,
  grch37_coords,
  grch38_coords,
  hi_score,
  ts_score,
  SAFE.PARSE_DATE('%m/%d/%Y', last_evaluated_date) AS last_evaluated_date
FROM `clinvar_ingest.dosage_genes_ext`;

-- Verify the table was created successfully
SELECT
  COUNT(*) AS total_genes,
  COUNTIF(hi_score = 'SufficientEvidence') AS hi_sufficient,
  COUNTIF(ts_score = 'SufficientEvidence') AS ts_sufficient,
  COUNTIF(hi_score = 'SufficientEvidence' AND ts_score = 'SufficientEvidence') AS both_sufficient
FROM `clinvar_ingest.dosage_genes`;
