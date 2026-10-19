-- Re-run clinvar_ingest.single_gene_variation on past releases after the method changes, and log
-- what changed. See docs/methods/single-gene-variation.md, "Backfilling past releases".
--
--   CALL `clinvar_ingest.single_gene_variation_backfill`(DATE '2023-01-07', DATE '2023-01-07', FALSE);  -- one release
--   CALL `clinvar_ingest.single_gene_variation_backfill`(DATE '2023-01-07', DATE '2026-10-11', FALSE);  -- all of them
--   ... (..., TRUE)  -- also re-run gc_scv_obs for each release, which reads single_gene_variation
--
-- For each release dataset in the range (clinvar_ingest.all_schemas()) it:
--   1. keeps the release's original table as {release}.single_gene_variation_before_backfill
--      (created once, so re-running a release never overwrites the original)
--   2. re-runs clinvar_ingest.single_gene_variation
--   3. when rerun_gc_scv_obs is TRUE: keeps {release}.gc_scv_obs_before_backfill (once) and re-runs
--      clinvar_ingest.gc_scv_obs. A failure is logged and the backfill moves on; gc_scv_obs replaces
--      its table only in its last statement, so a failed run leaves the release's table as it was.
--   4. logs the comparisons with the originals to clinvar_ingest.single_gene_variation_backfill_log
--
-- The temporal tables are rebuilt separately, after all releases are done, by
-- clinvar_ingest.single_gene_variation_temporal_rebuild.

CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_backfill_release`(
  schema_name STRING,
  release_date DATE,
  rerun_gc_scv_obs BOOL
)
BEGIN
  DECLARE gc_exists BOOL DEFAULT FALSE;
  DECLARE gc_error STRING;
  DECLARE gc_stats STRUCT<rows_before INT64, rows_after INT64, rows_changed INT64, obs_gene_changed INT64>;

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

  ALTER TABLE `clinvar_ingest.single_gene_variation_backfill_log`
    ADD COLUMN IF NOT EXISTS gc_scv_obs_rerun BOOL OPTIONS (description = 'whether gc_scv_obs was re-run for the release'),
    ADD COLUMN IF NOT EXISTS gc_rows_before INT64,
    ADD COLUMN IF NOT EXISTS gc_rows_after INT64,
    ADD COLUMN IF NOT EXISTS gc_rows_changed INT64 OPTIONS (description = 'gc_scv_obs rows not found unchanged in the original'),
    ADD COLUMN IF NOT EXISTS gc_obs_gene_changed INT64 OPTIONS (description = 'observations (scv_obs_id) whose gene changed'),
    ADD COLUMN IF NOT EXISTS gc_scv_obs_error STRING OPTIONS (description = 'error message when gc_scv_obs failed for the release');

  EXECUTE IMMEDIATE FORMAT("""
    CREATE TABLE IF NOT EXISTS `%s.single_gene_variation_before_backfill`
    COPY `%s.single_gene_variation`
  """, schema_name, schema_name);

  CALL `clinvar_ingest.single_gene_variation`(schema_name, release_date);

  IF rerun_gc_scv_obs THEN
    CALL `clinvar_ingest.check_table_exists`(schema_name, 'gc_scv_obs', gc_exists);
    IF gc_exists THEN
      EXECUTE IMMEDIATE FORMAT("""
        CREATE TABLE IF NOT EXISTS `%s.gc_scv_obs_before_backfill`
        COPY `%s.gc_scv_obs`
      """, schema_name, schema_name);
    END IF;

    BEGIN
      CALL `clinvar_ingest.gc_scv_obs`(schema_name);
    EXCEPTION WHEN ERROR THEN
      SET gc_error = @@error.message;
    END;

    IF gc_error IS NULL AND gc_exists THEN
      EXECUTE IMMEDIATE FORMAT("""
        WITH
        b AS (SELECT * FROM `%s.gc_scv_obs_before_backfill`),
        a AS (SELECT * FROM `%s.gc_scv_obs`),
        b_gene AS (SELECT scv_obs_id, STRING_AGG(DISTINCT IFNULL(gene_id, '-') ORDER BY IFNULL(gene_id, '-')) as genes FROM b GROUP BY 1),
        a_gene AS (SELECT scv_obs_id, STRING_AGG(DISTINCT IFNULL(gene_id, '-') ORDER BY IFNULL(gene_id, '-')) as genes FROM a GROUP BY 1)
        SELECT STRUCT(
          (SELECT COUNT(*) FROM b) as rows_before,
          (SELECT COUNT(*) FROM a) as rows_after,
          (SELECT COUNT(*) FROM (SELECT TO_JSON_STRING(a) as r FROM a EXCEPT DISTINCT SELECT TO_JSON_STRING(b) FROM b)) as rows_changed,
          (SELECT COUNT(*) FROM a_gene JOIN b_gene USING (scv_obs_id) WHERE a_gene.genes != b_gene.genes) as obs_gene_changed
        )
      """, schema_name, schema_name) INTO gc_stats;
    END IF;
  END IF;

  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.single_gene_variation_backfill_log` (
      run_at, schema_name, release_date, rows_before, rows_after, identical, added, removed,
      gene_changed, other_fields_changed, duplicate_variation_rows,
      gc_scv_obs_rerun, gc_rows_before, gc_rows_after, gc_rows_changed, gc_obs_gene_changed, gc_scv_obs_error
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
      (SELECT COUNT(*) - COUNT(DISTINCT variation_id) FROM `%s.single_gene_variation`),
      CAST(%T AS BOOL),
      CAST(%T AS INT64),
      CAST(%T AS INT64),
      CAST(%T AS INT64),
      CAST(%T AS INT64),
      CAST(%T AS STRING)
    FROM j
  """,
    schema_name, schema_name, schema_name, release_date, schema_name,
    rerun_gc_scv_obs, gc_stats.rows_before, gc_stats.rows_after, gc_stats.rows_changed,
    gc_stats.obs_gene_changed, gc_error
  );
END;


CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_backfill`(
  from_release_date DATE,
  to_release_date DATE,
  rerun_gc_scv_obs BOOL
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
    CALL `clinvar_ingest.single_gene_variation_backfill_release`(rec.schema_name, rec.release_date, rerun_gc_scv_obs);
  END FOR;

  SELECT
    *
  FROM `clinvar_ingest.single_gene_variation_backfill_log`
  WHERE
    run_at >= started_at
  ORDER BY
    release_date;
END;
