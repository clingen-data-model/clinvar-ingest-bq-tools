CREATE OR REPLACE PROCEDURE `clinvar_ingest.tracker_report_update_v2`()
BEGIN
  CALL `variation_tracker.report_variation_proc`();
  CALL `variation_tracker.tracker_reports_rebuild_v2`();
  CALL `variation_tracker.gc_tracker_report_rebuild`();
END;