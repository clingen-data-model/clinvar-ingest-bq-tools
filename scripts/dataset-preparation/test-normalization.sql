-- =============================================================
-- Test script for proposition type normalization refactor
--
-- Usage:
--   1. Run Part 1 BEFORE applying translation table changes
--   2. Apply the new 00-setup-translation-tables.sql
--   3. Run the scv_summary proc on the release dataset
--   4. Run Part 2 to compare output
--   5. Run Part 3 to clean up backups
--
-- Set @release_schema to your target release dataset name
-- =============================================================

DECLARE release_schema STRING DEFAULT 'clinvar_2026_05_10_v2_5_0';

-- =============================================================
-- Part 1: Create backups (run BEFORE changes)
-- =============================================================

-- Backup translation tables
CREATE OR REPLACE TABLE `clinvar_ingest._bak_clinvar_clinsig_types`
AS SELECT * FROM `clinvar_ingest.clinvar_clinsig_types`;

CREATE OR REPLACE TABLE `clinvar_ingest._bak_clinvar_proposition_types`
AS SELECT * FROM `clinvar_ingest.clinvar_proposition_types`;

-- Backup scv_summary output
EXECUTE IMMEDIATE FORMAT("""
  CREATE OR REPLACE TABLE `clinvar_2026_05_10_v2_5_0._bak_scv_summary`
  AS SELECT * FROM `%s.scv_summary`
""", release_schema);


-- =============================================================
-- Part 2: Compare output (run AFTER changes + proc re-run)
-- =============================================================

-- 2a: Row count comparison
EXECUTE IMMEDIATE FORMAT("""
  SELECT
    'row_counts' as check_name,
    (SELECT COUNT(*) FROM `clinvar_2026_05_10_v2_5_0._bak_scv_summary`) as before_count,
    (SELECT COUNT(*) FROM `%s.scv_summary`) as after_count,
    (SELECT COUNT(*) FROM `clinvar_2026_05_10_v2_5_0._bak_scv_summary`) =
    (SELECT COUNT(*) FROM `%s.scv_summary`) as counts_match
""", release_schema, release_schema);

-- 2b: Join on PK (id, version), compare all other columns
--     Reports any row where a column value changed
EXECUTE IMMEDIATE FORMAT("""
  SELECT
    old.id,
    old.version,
    CASE
      WHEN old.proposition_type IS DISTINCT FROM cur.proposition_type THEN 'proposition_type'
      WHEN old.statement_type IS DISTINCT FROM cur.statement_type THEN 'statement_type'
      WHEN old.clinical_impact_assertion_type IS DISTINCT FROM cur.clinical_impact_assertion_type THEN 'clinical_impact_assertion_type'
      WHEN old.clinical_impact_clinical_significance IS DISTINCT FROM cur.clinical_impact_clinical_significance THEN 'clinical_impact_clinical_significance'
      WHEN old.rank IS DISTINCT FROM cur.rank THEN 'rank'
      WHEN old.review_status IS DISTINCT FROM cur.review_status THEN 'review_status'
      WHEN old.classif_type IS DISTINCT FROM cur.classif_type THEN 'classif_type'
      WHEN old.significance IS DISTINCT FROM cur.significance THEN 'significance'
      WHEN old.classification_label IS DISTINCT FROM cur.classification_label THEN 'classification_label'
      WHEN old.classification_abbrev IS DISTINCT FROM cur.classification_abbrev THEN 'classification_abbrev'
      WHEN old.submitted_classification IS DISTINCT FROM cur.submitted_classification THEN 'submitted_classification'
      WHEN old.submitter_id IS DISTINCT FROM cur.submitter_id THEN 'submitter_id'
      WHEN old.variation_id IS DISTINCT FROM cur.variation_id THEN 'variation_id'
    END as first_diff_column,
    old.proposition_type as old_proposition_type,
    cur.proposition_type as new_proposition_type,
    old.rank as old_rank,
    cur.rank as new_rank,
    old.classif_type as old_classif_type,
    cur.classif_type as new_classif_type
  FROM `clinvar_2026_05_10_v2_5_0._bak_scv_summary` old
  JOIN `%s.scv_summary` cur
  ON old.id = cur.id AND old.version = cur.version
  WHERE
    old.proposition_type IS DISTINCT FROM cur.proposition_type
    OR old.statement_type IS DISTINCT FROM cur.statement_type
    OR old.rank IS DISTINCT FROM cur.rank
    OR old.classif_type IS DISTINCT FROM cur.classif_type
    OR old.significance IS DISTINCT FROM cur.significance
    OR old.classification_label IS DISTINCT FROM cur.classification_label
    OR old.classification_abbrev IS DISTINCT FROM cur.classification_abbrev
    OR old.submitted_classification IS DISTINCT FROM cur.submitted_classification
    OR old.submitter_id IS DISTINCT FROM cur.submitter_id
    OR old.review_status IS DISTINCT FROM cur.review_status
    OR old.clinical_impact_assertion_type IS DISTINCT FROM cur.clinical_impact_assertion_type
    OR old.clinical_impact_clinical_significance IS DISTINCT FROM cur.clinical_impact_clinical_significance
    OR old.variation_id IS DISTINCT FROM cur.variation_id
  LIMIT 100
""", release_schema);

-- 2c: Row count comparison (rows in old but not new, and vice versa)
EXECUTE IMMEDIATE FORMAT("""
  SELECT
    'old_only' as direction, COUNT(*) as cnt
  FROM `clinvar_2026_05_10_v2_5_0._bak_scv_summary` old
  LEFT JOIN `%s.scv_summary` cur ON old.id = cur.id AND old.version = cur.version
  WHERE cur.id IS NULL
  UNION ALL
  SELECT
    'new_only' as direction, COUNT(*) as cnt
  FROM `%s.scv_summary` cur
  LEFT JOIN `clinvar_2026_05_10_v2_5_0._bak_scv_summary` old ON old.id = cur.id AND old.version = cur.version
  WHERE old.id IS NULL
""", release_schema, release_schema);

-- 2d: Quick sanity check — verify proposition_type was always
--     equal to proposition_type for non-"oth" grouped types,
--     and show the gks remapping cases that existed before
SELECT
  'gks_vs_original_diff' as check_name,
  proposition_type,
  proposition_type,
  COUNT(*) as row_count
FROM `clinvar_2026_05_10_v2_5_0._bak_scv_summary`
WHERE proposition_type != proposition_type
   OR (proposition_type IS NULL) != (proposition_type IS NULL)
GROUP BY proposition_type, proposition_type
ORDER BY row_count DESC;


-- =============================================================
-- Part 3: Cleanup backups (run when done)
-- =============================================================

-- DROP TABLE IF EXISTS `clinvar_ingest._bak_clinvar_clinsig_types`;
-- DROP TABLE IF EXISTS `clinvar_ingest._bak_clinvar_proposition_types`;
-- DROP TABLE IF EXISTS `clinvar_2026_05_10_v2_5_0._bak_scv_summary`;
