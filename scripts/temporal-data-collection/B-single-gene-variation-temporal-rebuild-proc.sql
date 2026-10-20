-- Rebuild the temporal data that comes from single_gene_variation, after past releases have been
-- re-run with clinvar_ingest.single_gene_variation_backfill. See docs/methods/single-gene-variation.md,
-- "Backfilling past releases".
--
--   CALL `clinvar_ingest.single_gene_variation_temporal_rebuild`(FALSE);  -- check only
--   CALL `clinvar_ingest.single_gene_variation_temporal_rebuild`(TRUE);   -- apply
--
-- Only two temporal tables depend on single_gene_variation:
--   clinvar_single_gene_variations  every column, including hgnc_id
--   clinvar_variations              gene_id, symbol and mane_select only
--
-- Every release it reads must have single_gene_variation's hgnc_id column; run
-- clinvar_ingest.single_gene_variation_identity_backfill first for releases built before it existed.
-- The procedure stops with an error giving the range of releases that lack it.
--
-- Both keep one row per variation per unbroken run of releases, with the values of the run's last
-- release, which is what clinvar_single_gene_variations() and clinvar_variations() produce one release
-- at a time. So the correct contents follow directly from the per-release tables, without replaying
-- the weekly temporal pipeline:
--   clinvar_single_gene_variations: one row per variation per run of consecutive releases that have a
--     single_gene_variation row; start/end = first/last release of the run; deleted = the next release
--     after the run (NULL when the run reaches the last processed release); values from the run's last
--     release
--   clinvar_variations: the row's date range is unchanged (it follows the variation table); gene_id and
--     mane_select come from single_gene_variation, and symbol from the gene table, of the row's
--     end_release_date
--
-- It always builds side tables (expiring after 7 days) and returns how they differ from the current
-- tables:
--   clinvar_ingest.clinvar_single_gene_variations_rebuild
--   clinvar_ingest.clinvar_variations_gene_rebuild
-- Run with apply_changes = FALSE before any release is backfilled: every count except "identical"
-- and "hgnc_id_differs" must be 0, which shows the rebuild reproduces the weekly pipeline.
-- hgnc_id_differs counts rows that match on every other column but not on hgnc_id, e.g. rows written
-- before the column existed. It is 0 after the rebuild is applied. With apply_changes = TRUE it first
-- keeps copies named *_before_backfill (created once), then replaces clinvar_single_gene_variations
-- and updates the three clinvar_variations columns in one transaction. Run it between weekly releases.

CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_temporal_rebuild`(
  apply_changes BOOL
)
BEGIN
  DECLARE first_processed DATE DEFAULT (SELECT MIN(start_release_date) FROM `clinvar_ingest.clinvar_single_gene_variations`);
  DECLARE last_processed DATE DEFAULT (SELECT MAX(end_release_date) FROM `clinvar_ingest.clinvar_single_gene_variations`);
  DECLARE sgv_union STRING;
  DECLARE gene_union STRING;
  DECLARE missing_identity STRUCT<releases INT64, from_date DATE, to_date DATE>;

  -- the releases the temporal tables have processed, in order
  CREATE TEMP TABLE _SESSION.rebuild_release
  AS
  SELECT
    schema_name,
    release_date,
    LEAD(release_date) OVER (ORDER BY release_date) as next_release_date,
    ROW_NUMBER() OVER (ORDER BY release_date) as idx
  FROM `clinvar_ingest.all_schemas`()
  WHERE
    release_date BETWEEN first_processed AND last_processed;

  -- every release must carry the gene identity columns (see single_gene_variation_identity_backfill)
  SET missing_identity = (
    SELECT AS STRUCT
      COUNT(*),
      MIN(r.release_date),
      MAX(r.release_date)
    FROM _SESSION.rebuild_release r
    LEFT JOIN `region-us.INFORMATION_SCHEMA.COLUMNS` c
    ON
      c.table_schema = r.schema_name
      AND
      c.table_name = 'single_gene_variation'
      AND
      c.column_name = 'hgnc_id'
    WHERE
      c.table_schema IS NULL
  );
  IF missing_identity.releases > 0 THEN
    RAISE USING MESSAGE = FORMAT(
      "single_gene_variation has no hgnc_id column in %d releases between %t and %t. Run CALL `clinvar_ingest.single_gene_variation_identity_backfill`(DATE '%t', DATE '%t') first.",
      missing_identity.releases, missing_identity.from_date, missing_identity.to_date,
      missing_identity.from_date, missing_identity.to_date
    );
  END IF;

  -- the comparison below reads hgnc_id, so the (empty) column is added even when apply_changes is FALSE
  ALTER TABLE `clinvar_ingest.clinvar_single_gene_variations`
    ADD COLUMN IF NOT EXISTS hgnc_id STRING;

  SET sgv_union = (
    SELECT
      STRING_AGG(
        FORMAT("""
          SELECT %T as release_date, variation_id, gene_id, relationship_type, source, mane_select, somatic, hgnc_id
          FROM `%s.single_gene_variation`
        """, release_date, schema_name),
        "UNION ALL" ORDER BY release_date
      )
    FROM _SESSION.rebuild_release
  );
  EXECUTE IMMEDIATE "CREATE TEMP TABLE _SESSION.rebuild_sgv AS " || sgv_union;

  SET gene_union = (
    SELECT
      STRING_AGG(
        FORMAT("""
          SELECT %T as release_date, id, ANY_VALUE(symbol) as symbol
          FROM `%s.gene`
          GROUP BY id
        """, release_date, schema_name),
        "UNION ALL" ORDER BY release_date
      )
    FROM _SESSION.rebuild_release
  );
  EXECUTE IMMEDIATE "CREATE TEMP TABLE _SESSION.rebuild_gene AS " || gene_union;

  CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_single_gene_variations_rebuild`
  OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY))
  AS
  WITH x AS (
    SELECT
      s.*,
      r.idx,
      r.next_release_date,
      -- consecutive releases of one variation share the same island value
      r.idx - ROW_NUMBER() OVER (PARTITION BY s.variation_id ORDER BY r.idx) as island
    FROM _SESSION.rebuild_sgv s
    JOIN _SESSION.rebuild_release r
    ON
      r.release_date = s.release_date
  ),
  runs AS (
    SELECT
      variation_id,
      MIN(release_date) as start_release_date,
      MAX(release_date) as end_release_date,
      ARRAY_AGG(
        STRUCT(gene_id, relationship_type, source, mane_select, somatic, hgnc_id, next_release_date)
        ORDER BY idx DESC
        LIMIT 1
      )[OFFSET(0)] as last
    FROM x
    GROUP BY
      variation_id,
      island
  )
  SELECT
    variation_id,
    last.gene_id,
    last.relationship_type,
    last.source,
    last.mane_select,
    last.somatic,
    start_release_date,
    end_release_date,
    last.next_release_date as deleted_release_date,
    last.hgnc_id
  FROM runs;

  CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_variations_gene_rebuild`
  OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY))
  AS
  SELECT
    cv.id,
    cv.start_release_date,
    s.gene_id,
    g.symbol,
    s.mane_select
  FROM `clinvar_ingest.clinvar_variations` cv
  LEFT JOIN _SESSION.rebuild_sgv s
  ON
    s.variation_id = cv.id
    AND
    s.release_date = cv.end_release_date
  LEFT JOIN _SESSION.rebuild_gene g
  ON
    g.release_date = cv.end_release_date
    AND
    g.id = s.gene_id;

  -- how the rebuilt data differs from the current tables
  CREATE TEMP TABLE _SESSION.rebuild_summary
  AS
  SELECT
    'clinvar_single_gene_variations' as table_name,
    COUNTIF(c.variation_id IS NOT NULL AND r.variation_id IS NOT NULL
      AND c.end_release_date = r.end_release_date
      AND c.deleted_release_date IS NOT DISTINCT FROM r.deleted_release_date
      AND c.gene_id = r.gene_id
      AND c.relationship_type IS NOT DISTINCT FROM r.relationship_type
      AND c.source IS NOT DISTINCT FROM r.source
      AND c.mane_select IS NOT DISTINCT FROM r.mane_select
      AND c.somatic IS NOT DISTINCT FROM r.somatic) as identical,
    COUNTIF(c.variation_id IS NULL) as rebuild_only,
    COUNTIF(r.variation_id IS NULL) as current_only,
    COUNTIF(c.variation_id IS NOT NULL AND r.variation_id IS NOT NULL
      AND (c.end_release_date != r.end_release_date
        OR c.deleted_release_date IS DISTINCT FROM r.deleted_release_date)) as dates_differ,
    COUNTIF(c.variation_id IS NOT NULL AND r.variation_id IS NOT NULL
      AND c.end_release_date = r.end_release_date
      AND c.deleted_release_date IS NOT DISTINCT FROM r.deleted_release_date
      AND (c.gene_id != r.gene_id
        OR c.relationship_type IS DISTINCT FROM r.relationship_type
        OR c.source IS DISTINCT FROM r.source
        OR c.mane_select IS DISTINCT FROM r.mane_select
        OR c.somatic IS DISTINCT FROM r.somatic)) as values_differ,
    COUNTIF(c.variation_id IS NOT NULL AND r.variation_id IS NOT NULL
      AND c.hgnc_id IS DISTINCT FROM r.hgnc_id) as hgnc_id_differs
  FROM `clinvar_ingest.clinvar_single_gene_variations_rebuild` r
  FULL JOIN `clinvar_ingest.clinvar_single_gene_variations` c
  ON
    c.variation_id = r.variation_id
    AND
    c.start_release_date = r.start_release_date
  UNION ALL
  SELECT
    'clinvar_variations (gene_id, symbol, mane_select)',
    COUNTIF(c.gene_id IS NOT DISTINCT FROM r.gene_id
      AND c.symbol IS NOT DISTINCT FROM r.symbol
      AND c.mane_select IS NOT DISTINCT FROM r.mane_select),
    0,
    0,
    0,
    COUNTIF(c.gene_id IS DISTINCT FROM r.gene_id
      OR c.symbol IS DISTINCT FROM r.symbol
      OR c.mane_select IS DISTINCT FROM r.mane_select),
    0
  FROM `clinvar_ingest.clinvar_variations_gene_rebuild` r
  JOIN `clinvar_ingest.clinvar_variations` c
  ON
    c.id = r.id
    AND
    c.start_release_date = r.start_release_date;

  IF apply_changes THEN
    CREATE TABLE IF NOT EXISTS `clinvar_ingest.clinvar_single_gene_variations_before_backfill`
    COPY `clinvar_ingest.clinvar_single_gene_variations`;
    CREATE TABLE IF NOT EXISTS `clinvar_ingest.clinvar_variations_before_backfill`
    COPY `clinvar_ingest.clinvar_variations`;

    BEGIN TRANSACTION;

    DELETE FROM `clinvar_ingest.clinvar_single_gene_variations` WHERE TRUE;

    INSERT INTO `clinvar_ingest.clinvar_single_gene_variations` (
      variation_id,
      gene_id,
      relationship_type,
      source,
      mane_select,
      somatic,
      start_release_date,
      end_release_date,
      deleted_release_date,
      hgnc_id
    )
    SELECT
      variation_id,
      gene_id,
      relationship_type,
      source,
      mane_select,
      somatic,
      start_release_date,
      end_release_date,
      deleted_release_date,
      hgnc_id
    FROM `clinvar_ingest.clinvar_single_gene_variations_rebuild`;

    UPDATE `clinvar_ingest.clinvar_variations` cv
    SET
      gene_id = r.gene_id,
      symbol = r.symbol,
      mane_select = r.mane_select
    FROM `clinvar_ingest.clinvar_variations_gene_rebuild` r
    WHERE
      r.id = cv.id
      AND
      r.start_release_date = cv.start_release_date
      AND (
        cv.gene_id IS DISTINCT FROM r.gene_id
        OR cv.symbol IS DISTINCT FROM r.symbol
        OR cv.mane_select IS DISTINCT FROM r.mane_select
      );

    COMMIT TRANSACTION;
  END IF;

  SELECT
    apply_changes as applied,
    first_processed,
    last_processed,
    (SELECT COUNT(*) FROM _SESSION.rebuild_release) as releases,
    s.*
  FROM _SESSION.rebuild_summary s;
END;
