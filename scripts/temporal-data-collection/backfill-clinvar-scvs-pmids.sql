-- =============================================================================
-- Backfill clinvar_scvs.pmids from Historic Releases
-- =============================================================================
--
-- Purpose:
--   Re-runs scv_summary on all historic release schemas to ensure the pmids
--   column is populated, then backfills clinvar_scvs.pmids from those rebuilt
--   scv_summary tables.
--
--   This is a one-time migration proc needed because pmids was added to
--   clinvar_scvs after the table was already populated with historical data.
--
-- How it works:
--   1. Adds the pmids column to clinvar_scvs if it doesn't already exist
--   2. Loops through every schema (chronologically) that has a scv_summary
--   3. Rebuilds scv_summary for each schema (ensures pmids is present)
--   4. Updates clinvar_scvs rows with pmids from the rebuilt scv_summary,
--      matching on (id, version) for rows whose temporal range includes
--      that schema's release date
--
-- Parameters:
--   start_from_date - Optional: skip schemas before this date to resume
--                     a partially completed run. Pass NULL to process all.
--
-- Usage:
--   -- Full backfill (all schemas):
--   CALL `clinvar_ingest.backfill_clinvar_scvs_pmids`(NULL);
--
--   -- Resume from a specific date:
--   CALL `clinvar_ingest.backfill_clinvar_scvs_pmids`('2025-01-01');
--
-- Notes:
--   - This proc is idempotent; re-running it will overwrite pmids with
--     the latest values from each schema's scv_summary.
--   - For a given (id, version), pmids should be stable across releases.
--     Processing in chronological order ensures the latest value wins.
--   - Expect this to take a while — there are 100+ schemas to rebuild.
--
-- =============================================================================

CREATE OR REPLACE PROCEDURE `clinvar_ingest.backfill_clinvar_scvs_pmids`(
  start_from_date DATE
)
BEGIN
  DECLARE schemas_processed INT64 DEFAULT 0;
  DECLARE rows_updated INT64 DEFAULT 0;
  DECLARE current_schema STRING;
  DECLARE current_release DATE;

  -- Step 1: Add pmids column if it doesn't exist yet
  -- (BigQuery doesn't have IF NOT EXISTS for ALTER TABLE ADD COLUMN,
  --  so we use an exception handler)
  BEGIN
    EXECUTE IMMEDIATE """
      ALTER TABLE `clinvar_ingest.clinvar_scvs`
      ADD COLUMN IF NOT EXISTS pmids STRING
    """;
  EXCEPTION WHEN ERROR THEN
    -- Column already exists, continue
    SELECT 1;
  END;

  -- Step 2: Loop through all schemas in chronological order
  FOR schema_rec IN (
    SELECT schema_name, release_date
    FROM `clinvar_ingest.all_schemas`()
    WHERE start_from_date IS NULL OR release_date >= start_from_date
    ORDER BY release_date
  )
  DO
    SET current_schema = schema_rec.schema_name;
    SET current_release = schema_rec.release_date;

    -- Step 2a: Rebuild scv_summary for this schema (ensures pmids column exists)
    CALL `clinvar_ingest.scv_summary`(current_schema);

    -- Step 2b: Update clinvar_scvs.pmids from the rebuilt scv_summary
    -- Match on (id, version) where the release falls within the row's temporal range
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_scvs` cs
      SET cs.pmids = scv.pmids
      FROM `%s.scv_summary` scv
      WHERE scv.id = cs.id
        AND scv.version = cs.version
        AND %T BETWEEN cs.start_release_date AND cs.end_release_date
    """, current_schema, current_release);

    SET schemas_processed = schemas_processed + 1;
  END FOR;

  -- Report results
  SELECT
    schemas_processed AS total_schemas_processed,
    (SELECT COUNTIF(pmids IS NOT NULL) FROM `clinvar_ingest.clinvar_scvs`) AS rows_with_pmids,
    (SELECT COUNTIF(pmids IS NULL) FROM `clinvar_ingest.clinvar_scvs`) AS rows_without_pmids;

END;
