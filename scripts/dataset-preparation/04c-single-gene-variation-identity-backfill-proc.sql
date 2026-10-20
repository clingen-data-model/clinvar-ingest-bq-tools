-- Add the gene identity columns (symbol, hgnc_id) to single_gene_variation tables built before they
-- existed, without re-running the method. See docs/methods/single-gene-variation.md, "Backfilling the
-- gene identity columns".
--
--   CALL `clinvar_ingest.single_gene_variation_identity_backfill`(DATE '2026-10-11', DATE '2026-10-11');  -- one release
--   CALL `clinvar_ingest.single_gene_variation_identity_backfill`(DATE '2023-01-07', DATE '2026-10-18');  -- all of them
--
-- For each release dataset in the range (clinvar_ingest.all_schemas()) it calls
-- clinvar_ingest.single_gene_variation_identity, which adds the two columns if they are missing and fills
-- them for every row, then logs the result to clinvar_ingest.single_gene_variation_identity_backfill_log.
-- No other column changes, and re-running a release gives the same result.
--
-- Afterwards, rebuild the temporal data with clinvar_ingest.single_gene_variation_temporal_rebuild, which
-- carries hgnc_id into clinvar_single_gene_variations.

CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_identity_backfill`(
  from_release_date DATE,
  to_release_date DATE
)
BEGIN
  DECLARE started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

  CREATE TABLE IF NOT EXISTS `clinvar_ingest.single_gene_variation_identity_backfill_log` (
    run_at TIMESTAMP NOT NULL,
    schema_name STRING NOT NULL,
    release_date DATE NOT NULL,
    rows_total INT64 OPTIONS (description = 'single_gene_variation rows'),
    with_symbol INT64 OPTIONS (description = 'rows with a symbol'),
    with_hgnc_id INT64 OPTIONS (description = 'rows with an HGNC id'),
    unlisted_gene INT64 OPTIONS (description = 'rows whose gene the release gene table does not list, so the identity came from entrez_gene')
  )
  OPTIONS (description = 'One row per release processed by single_gene_variation_identity_backfill');

  FOR rec IN (
    SELECT
      schema_name,
      release_date
    FROM `clinvar_ingest.all_schemas`()
    WHERE
      release_date BETWEEN from_release_date AND to_release_date
    ORDER BY
      release_date
  )
  DO
    CALL `clinvar_ingest.single_gene_variation_identity`(rec.schema_name);

    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.single_gene_variation_identity_backfill_log` (
        run_at, schema_name, release_date, rows_total, with_symbol, with_hgnc_id, unlisted_gene
      )
      SELECT
        CURRENT_TIMESTAMP(),
        %T,
        %T,
        COUNT(*),
        COUNTIF(sgv.symbol IS NOT NULL),
        COUNTIF(sgv.hgnc_id IS NOT NULL),
        COUNTIF(sgv.gene_id NOT IN (SELECT g.id FROM `%s.gene` g))
      FROM `%s.single_gene_variation` sgv
    """, rec.schema_name, rec.release_date, rec.schema_name, rec.schema_name);
  END FOR;

  SELECT
    *
  FROM `clinvar_ingest.single_gene_variation_identity_backfill_log`
  WHERE
    run_at >= started_at
  ORDER BY
    release_date;
END;
