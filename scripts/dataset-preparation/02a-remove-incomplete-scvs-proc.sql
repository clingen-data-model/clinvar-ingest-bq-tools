-- ============================================================================
-- clinvar_ingest.remove_incomplete_scvs
-- ============================================================================
-- Archives and removes clinical_assertion (SCV) records that have no RCV
-- accession mapping (clinical_assertion.rcv_accession_id IS NULL after
-- normalize_dataset), together with:
--   (a) their SCV-level dependent rows, and
--   (b) any aggregate records that become ORPHANED as a result (a cascade).
--
-- Nothing is hard-deleted: every removed row is first copied into a
-- `<schema>.removed_<table>` archive of identical structure PLUS a
-- `removal_reason` column, then deleted from the live table. A one-row-per-SCV
-- summary is also written to `clinvar_ingest.validation_issues_log`.
--
-- Called by clinvar_ingest.validate_dataset (which applies a safety cap on the
-- number of SCVs before calling this). Safe to run directly for ad-hoc cleanup.
--
-- WHY these SCVs exist: rcv_mapping is produced upstream by the ingest. When the
-- newest RCVs are absent from a release's rcv_mapping, normalize_dataset cannot
-- set clinical_assertion.rcv_accession_id and leaves it NULL. Such records are
-- treated as incomplete; the next release's fresh ingest is expected to carry
-- them correctly.
--
-- ORPHAN RULE (the cascade's safety guarantee): an aggregate record is removed
-- ONLY if no REMAINING record references it. Shared dictionaries
-- (gene, submitter, submission, trait, trait_set) are therefore never removed.
--
-- Removal tiers (processed bottom-up so orphan status is evaluated correctly):
--   TIER 1 (SCV-level): clinical_assertion_variation, clinical_assertion_trait_set,
--                       clinical_assertion_observation, clinical_assertion_trait,
--                       trait_mapping, clinical_assertion (parent last)
--   TIER 2 (VCV/RCV)  : variation_archive_classification, variation_archive,
--                       rcv_accession_classification, rcv_mapping, rcv_accession
--   TIER 3 (variation): gene_association, variation
-- ============================================================================
CREATE OR REPLACE PROCEDURE `clinvar_ingest.remove_incomplete_scvs`(
  schema_name STRING
)
BEGIN
  DECLARE reason_scv STRING DEFAULT
    'SCV has no RCV accession mapping (absent from source rcv_mapping for this release); removed as incomplete.';
  DECLARE reason_dep STRING DEFAULT
    'Dependent record of an SCV that has no RCV accession mapping; removed with its parent SCV.';
  DECLARE reason_orphan STRING DEFAULT
    'Orphaned by removal of incomplete SCV(s) with no RCV accession mapping; no remaining record references it.';
  DECLARE targets ARRAY<STRUCT<tbl STRING, predicate STRING, reason STRING>>;
  DECLARE seed_count INT64;

  -- Persistent, cross-release issues log.
  CREATE TABLE IF NOT EXISTS `clinvar_ingest.validation_issues_log` (
    logged_at TIMESTAMP,
    schema_name STRING,
    release_date DATE,
    issue_type STRING,     -- e.g. 'MISSING_RCV_ACCESSION'
    table_name STRING,     -- table the record relates to / was removed from
    record_id STRING,      -- the affected record id (e.g. the SCV accession)
    reason STRING,         -- human-readable explanation
    action_taken STRING,   -- e.g. 'REMOVED'
    details STRING         -- optional JSON with extra context
  );

  -- --------------------------------------------------------------------------
  -- Capture the seed set (SCVs with no RCV mapping) and the variation / VCV ids
  -- they reference, BEFORE any deletion removes the linkage.
  -- --------------------------------------------------------------------------
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _seed_scv AS
    SELECT
      ca.id                   AS scv_id,
      ca.variation_id         AS variation_id,
      ca.variation_archive_id AS vcv_id,
      ca.release_date         AS release_date,
      ca.submitter_id         AS submitter_id,
      ca.statement_type       AS statement_type
    FROM `%s.clinical_assertion` ca
    WHERE ca.rcv_accession_id IS NULL
  """, schema_name);

  SET seed_count = (SELECT COUNT(*) FROM _seed_scv);
  IF seed_count = 0 THEN
    DROP TABLE _seed_scv;
    RETURN;
  END IF;

  -- Summary: one row per removed SCV.
  INSERT INTO `clinvar_ingest.validation_issues_log`
    (logged_at, schema_name, release_date, issue_type, table_name,
     record_id, reason, action_taken, details)
  SELECT
    CURRENT_TIMESTAMP(), schema_name, s.release_date, 'MISSING_RCV_ACCESSION',
    'clinical_assertion', s.scv_id, reason_scv, 'REMOVED',
    TO_JSON_STRING(STRUCT(
      s.variation_id AS variation_id,
      s.vcv_id AS vcv_id,
      s.submitter_id AS submitter_id,
      s.statement_type AS statement_type))
  FROM _seed_scv s;

  -- ==========================================================================
  -- TIER 1 - SCV-level rows (children first, parent clinical_assertion last)
  -- ==========================================================================
  SET targets = [
    STRUCT('clinical_assertion_variation' AS tbl,
           'clinical_assertion_id IN (SELECT scv_id FROM _seed_scv)' AS predicate,
           reason_dep AS reason),
    STRUCT('clinical_assertion_trait_set',
           'id IN (SELECT scv_id FROM _seed_scv)', reason_dep),
    STRUCT('clinical_assertion_observation',
           "SPLIT(id, '.')[OFFSET(0)] IN (SELECT scv_id FROM _seed_scv)", reason_dep),
    STRUCT('clinical_assertion_trait',
           "SPLIT(id, '.')[OFFSET(0)] IN (SELECT scv_id FROM _seed_scv)", reason_dep),
    STRUCT('trait_mapping',
           'clinical_assertion_id IN (SELECT scv_id FROM _seed_scv)', reason_dep),
    STRUCT('clinical_assertion',
           'id IN (SELECT scv_id FROM _seed_scv)', reason_scv)
  ];
  FOR t IN (SELECT tbl, predicate, reason FROM UNNEST(targets) WITH OFFSET o ORDER BY o)
  DO
    EXECUTE IMMEDIATE FORMAT(
      "CREATE TABLE IF NOT EXISTS `%s.removed_%s` LIKE `%s.%s`",
      schema_name, t.tbl, schema_name, t.tbl);
    EXECUTE IMMEDIATE FORMAT(
      "ALTER TABLE `%s.removed_%s` ADD COLUMN IF NOT EXISTS removal_reason STRING",
      schema_name, t.tbl);
    EXECUTE IMMEDIATE FORMAT(
      "INSERT INTO `%s.removed_%s` SELECT x.*, %T AS removal_reason FROM `%s.%s` x WHERE %s",
      schema_name, t.tbl, t.reason, schema_name, t.tbl, t.predicate);
    EXECUTE IMMEDIATE FORMAT(
      "DELETE FROM `%s.%s` WHERE %s",
      schema_name, t.tbl, t.predicate);
  END FOR;

  -- ==========================================================================
  -- TIER 2 - aggregate VCV / RCV rows orphaned by the SCV removals
  -- (evaluated now that TIER 1 has removed the SCVs)
  -- ==========================================================================
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _orphan_vcv AS
    SELECT DISTINCT s.vcv_id AS vcv
    FROM _seed_scv s
    WHERE s.vcv_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM `%s.clinical_assertion` ca
        WHERE ca.variation_archive_id = s.vcv_id)
  """, schema_name);

  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _orphan_rcv AS
    SELECT DISTINCT ra.id AS rcv
    FROM `%s.rcv_accession` ra
    WHERE ra.variation_archive_id IN (SELECT vcv FROM _orphan_vcv)
  """, schema_name);

  SET targets = [
    STRUCT('variation_archive_classification' AS tbl,
           'vcv_id IN (SELECT vcv FROM _orphan_vcv)' AS predicate,
           reason_orphan AS reason),
    STRUCT('variation_archive',
           'id IN (SELECT vcv FROM _orphan_vcv)', reason_orphan),
    STRUCT('rcv_accession_classification',
           'rcv_id IN (SELECT rcv FROM _orphan_rcv)', reason_orphan),
    STRUCT('rcv_mapping',
           'rcv_accession IN (SELECT rcv FROM _orphan_rcv)', reason_orphan),
    STRUCT('rcv_accession',
           'id IN (SELECT rcv FROM _orphan_rcv)', reason_orphan)
  ];
  FOR t IN (SELECT tbl, predicate, reason FROM UNNEST(targets) WITH OFFSET o ORDER BY o)
  DO
    EXECUTE IMMEDIATE FORMAT(
      "CREATE TABLE IF NOT EXISTS `%s.removed_%s` LIKE `%s.%s`",
      schema_name, t.tbl, schema_name, t.tbl);
    EXECUTE IMMEDIATE FORMAT(
      "ALTER TABLE `%s.removed_%s` ADD COLUMN IF NOT EXISTS removal_reason STRING",
      schema_name, t.tbl);
    EXECUTE IMMEDIATE FORMAT(
      "INSERT INTO `%s.removed_%s` SELECT x.*, %T AS removal_reason FROM `%s.%s` x WHERE %s",
      schema_name, t.tbl, t.reason, schema_name, t.tbl, t.predicate);
    EXECUTE IMMEDIATE FORMAT(
      "DELETE FROM `%s.%s` WHERE %s",
      schema_name, t.tbl, t.predicate);
  END FOR;

  -- ==========================================================================
  -- TIER 3 - variation rows orphaned once their SCV / VCV / RCV are gone
  -- (evaluated now that TIER 2 has removed the aggregates)
  -- ==========================================================================
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _orphan_var AS
    SELECT DISTINCT s.variation_id AS var
    FROM _seed_scv s
    WHERE s.variation_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM `%s.clinical_assertion` ca WHERE ca.variation_id = s.variation_id)
      AND NOT EXISTS (SELECT 1 FROM `%s.variation_archive` va WHERE va.variation_id = s.variation_id)
      AND NOT EXISTS (SELECT 1 FROM `%s.rcv_accession` ra WHERE ra.variation_id = s.variation_id)
  """, schema_name, schema_name, schema_name);

  SET targets = [
    STRUCT('gene_association' AS tbl,
           'variation_id IN (SELECT var FROM _orphan_var)' AS predicate,
           reason_orphan AS reason),
    STRUCT('variation',
           'id IN (SELECT var FROM _orphan_var)', reason_orphan)
  ];
  FOR t IN (SELECT tbl, predicate, reason FROM UNNEST(targets) WITH OFFSET o ORDER BY o)
  DO
    EXECUTE IMMEDIATE FORMAT(
      "CREATE TABLE IF NOT EXISTS `%s.removed_%s` LIKE `%s.%s`",
      schema_name, t.tbl, schema_name, t.tbl);
    EXECUTE IMMEDIATE FORMAT(
      "ALTER TABLE `%s.removed_%s` ADD COLUMN IF NOT EXISTS removal_reason STRING",
      schema_name, t.tbl);
    EXECUTE IMMEDIATE FORMAT(
      "INSERT INTO `%s.removed_%s` SELECT x.*, %T AS removal_reason FROM `%s.%s` x WHERE %s",
      schema_name, t.tbl, t.reason, schema_name, t.tbl, t.predicate);
    EXECUTE IMMEDIATE FORMAT(
      "DELETE FROM `%s.%s` WHERE %s",
      schema_name, t.tbl, t.predicate);
  END FOR;

  DROP TABLE _seed_scv;
  DROP TABLE _orphan_vcv;
  DROP TABLE _orphan_rcv;
  DROP TABLE _orphan_var;
END;
