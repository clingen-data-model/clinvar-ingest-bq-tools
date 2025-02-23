CREATE OR REPLACE PROCEDURE `clinvar_ingest.tracker_report_update`()
BEGIN
  CALL `variation_tracker.report_variation`();
  CALL `variation_tracker.tracker_reports_rebuild`(null);
  CALL `variation_tracker.gc_tracker_report_rebuild`();
END;