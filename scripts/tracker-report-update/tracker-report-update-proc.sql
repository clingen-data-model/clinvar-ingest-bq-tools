CREATE OR REPLACE PROCEDURE `clinvar_ingest.tracker_report_update`()
BEGIN
  CALL `variation_tracker.report_variation_proc`();
  CALL `variation_tracker.tracker_reports_rebuild`();
  CALL `variation_tracker.gc_tracker_report_rebuild`();
END;


ALTER TABLE table_name 
RENAME COLUMN old_column_name TO new_column_name;