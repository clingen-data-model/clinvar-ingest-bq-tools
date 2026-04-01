CREATE TABLE IF NOT EXISTS `clinvar_ingest.rollback_log` (
  execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_release_date DATE,
  prev_release_date DATE,
  table_name STRING,
  backup_created STRING,
  rows_restored_deleted INT64,
  rows_restored_ended INT64,
  rows_deleted INT64,
  executed_by STRING
);

-- example call
-- CALL `clinvar_ingest.rollback_temporal_release`(
--   DATE'2026-03-08',
--   DATE'2026-03-02',
--   FALSE
-- );

CREATE OR REPLACE PROCEDURE `clinvar_ingest.rollback_temporal_release`(
  last_release_date DATE,
  prev_release_date DATE,
  dry_run BOOL
)
BEGIN
  DECLARE target_tables ARRAY<STRING> DEFAULT [
    'clinvar_ingest.clinvar_scvs',
    'clinvar_ingest.clinvar_rcv_classifications',
    'clinvar_ingest.clinvar_rcvs',
    'clinvar_ingest.clinvar_vcv_classifications',
    'clinvar_ingest.clinvar_vcvs',
    'clinvar_ingest.clinvar_variations',
    'clinvar_ingest.clinvar_submitters',
    'clinvar_ingest.clinvar_single_gene_variations',
    'clinvar_ingest.clinvar_genes'
  ];

  DECLARE i INT64 DEFAULT 0;
  DECLARE current_table STRING;
  DECLARE backup_table_name STRING;
  DECLARE ts_suffix STRING DEFAULT FORMAT_TIMESTAMP('%Y%m%d_%H%M%S', CURRENT_TIMESTAMP());

  CREATE TEMP TABLE rollback_audit (
    table_name STRING,
    backup_created STRING,
    rows_to_restore_deleted INT64,
    rows_to_restore_ended INT64,
    rows_to_delete INT64
  );

  WHILE i < ARRAY_LENGTH(target_tables) DO
    SET current_table = target_tables[OFFSET(i)];
    SET backup_table_name = FORMAT("%s_backup_%s", current_table, ts_suffix);

    -- Use a temporary local table to ensure we capture counts correctly
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO rollback_audit (table_name, backup_created, rows_to_restore_deleted, rows_to_restore_ended, rows_to_delete)
      SELECT
        '%s',
        IF(@is_dry, 'NONE', '%s'),
        COUNTIF(DATE(deleted_release_date) = @last_dt),
        COUNTIF(DATE(end_release_date) = @last_dt),
        COUNTIF(DATE(start_release_date) = @last_dt)
      FROM `%s`
    """, current_table, backup_table_name, current_table)
    USING last_release_date AS last_dt, dry_run AS is_dry;

    IF NOT dry_run THEN
      -- Create Backup
      EXECUTE IMMEDIATE FORMAT("CREATE OR REPLACE TABLE `%s` AS SELECT * FROM `%s` ", backup_table_name, current_table);

      -- Update records (Note: Using DATE() cast to ensure equality match)
      EXECUTE IMMEDIATE FORMAT("""
        UPDATE `%s`
        SET
          deleted_release_date = CASE WHEN DATE(deleted_release_date) = @last_dt THEN NULL ELSE deleted_release_date END,
          end_release_date = CASE WHEN DATE(end_release_date) = @last_dt THEN @prev_dt ELSE end_release_date END
        WHERE DATE(deleted_release_date) = @last_dt OR DATE(end_release_date) = @last_dt
      """, current_table)
      USING last_release_date AS last_dt, prev_release_date AS prev_dt;

      -- Delete records
      EXECUTE IMMEDIATE FORMAT("""
        DELETE FROM `%s` WHERE DATE(start_release_date) = @last_dt
      """, current_table)
      USING last_release_date AS last_dt;
    END IF;

    SET i = i + 1;
  END WHILE;

  -- Permanent Logging
  IF NOT dry_run THEN
    INSERT INTO `clinvar_ingest.rollback_log`
      (execution_timestamp, last_release_date, prev_release_date, table_name, rows_restored_deleted, rows_restored_ended, rows_deleted, executed_by)
    SELECT CURRENT_TIMESTAMP(), last_release_date, prev_release_date, table_name, rows_to_restore_deleted, rows_to_restore_ended, rows_to_delete, SESSION_USER()
    FROM rollback_audit;
  END IF;

  SELECT * FROM rollback_audit ORDER BY table_name;
  DROP TABLE rollback_audit;
END;
