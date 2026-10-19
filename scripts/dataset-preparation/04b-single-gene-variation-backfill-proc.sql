-- Re-run clinvar_ingest.single_gene_variation on past releases after the method changes, and log
-- what changed. See docs/methods/single-gene-variation.md, "Backfilling past releases".
--
--   CALL `clinvar_ingest.single_gene_variation_backfill`(DATE '2023-01-07', DATE '2023-01-07');  -- one release
--   CALL `clinvar_ingest.single_gene_variation_backfill`(DATE '2023-01-07', DATE '2026-10-11');  -- all of them
--
-- For each release dataset in the range (clinvar_ingest.all_schemas()) it:
--   1. keeps the release's original table as {release}.single_gene_variation_before_backfill
--      (created once, so re-running a release never overwrites the original)
--   2. re-runs clinvar_ingest.single_gene_variation
--   3. logs the comparison with the original to clinvar_ingest.single_gene_variation_backfill_log
--
-- The temporal tables are rebuilt separately, after all releases are done, by
-- clinvar_ingest.single_gene_variation_temporal_rebuild.

CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_backfill_release`(
  schema_name STRING,
  release_date DATE
)
BEGIN
  CREATE TABLE IF NOT EXISTS `clinvar_ingest.single_gene_variation_backfill_log` (
    run_at TIMESTAMP NOT NULL,
    schema_name STRING NOT NULL,
    release_date DATE NOT NULL,
    rows_before INT64,
    rows_after INT64,
    identical INT64,
    added INT64,
    removed INT64,
    gene_changed INT64,
    other_fields_changed INT64,
    duplicate_variation_rows INT64
  )
  OPTIONS (description = 'One row per release re-run by single_gene_variation_backfill, comparing with the original output');

  EXECUTE IMMEDIATE FORMAT("""
    CREATE TABLE IF NOT EXISTS `%s.single_gene_variation_before_backfill`
    COPY `%s.single_gene_variation`
  """, schema_name, schema_name);

  CALL `clinvar_ingest.single_gene_variation`(schema_name, release_date);

  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.single_gene_variation_backfill_log` (
      run_at, schema_name, release_date, rows_before, rows_after, identical, added, removed,
      gene_changed, other_fields_changed, duplicate_variation_rows
    )
    WITH j AS (
      SELECT
        b.variation_id IS NOT NULL AS in_before,
        a.variation_id IS NOT NULL AS in_after,
        a.gene_id = b.gene_id AS same_gene,
        (
          a.relationship_type IS NOT DISTINCT FROM b.relationship_type
          AND a.source IS NOT DISTINCT FROM b.source
          AND a.mane_select IS NOT DISTINCT FROM b.mane_select
          AND a.somatic IS NOT DISTINCT FROM b.somatic
        ) AS same_fields
      FROM `%s.single_gene_variation` a
      FULL JOIN `%s.single_gene_variation_before_backfill` b
      ON
        a.variation_id = b.variation_id
    )
    SELECT
      CURRENT_TIMESTAMP(),
      %T,
      %T,
      COUNTIF(in_before),
      COUNTIF(in_after),
      COUNTIF(in_before AND in_after AND same_gene AND same_fields),
      COUNTIF(in_after AND NOT in_before),
      COUNTIF(in_before AND NOT in_after),
      COUNTIF(in_before AND in_after AND NOT same_gene),
      COUNTIF(in_before AND in_after AND same_gene AND NOT same_fields),
      (SELECT COUNT(*) - COUNT(DISTINCT variation_id) FROM `%s.single_gene_variation`)
    FROM j
  """, schema_name, schema_name, schema_name, release_date, schema_name);
END;


CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_backfill`(
  from_release_date DATE,
  to_release_date DATE
)
BEGIN
  DECLARE started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

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
    CALL `clinvar_ingest.single_gene_variation_backfill_release`(rec.schema_name, rec.release_date);
  END FOR;

  SELECT
    *
  FROM `clinvar_ingest.single_gene_variation_backfill_log`
  WHERE
    run_at >= started_at
  ORDER BY
    release_date;
END;
