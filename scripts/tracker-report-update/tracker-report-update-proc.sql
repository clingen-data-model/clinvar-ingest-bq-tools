CREATE OR REPLACE PROCEDURE `clinvar_ingest.tracker_report_update`(
  on_date DATE
)
BEGIN
  FOR rec IN (
    select 
      s.schema_name, 
      s.release_date, 
      s.prev_release_date, 
      s.next_release_date 
    FROM clinvar_ingest.schema_on(on_date) as s
  )
  DO
    CALL `variation_tracker.report_variation_proc`();
    CALL `variation_tracker.tracker_reports_rebuild`();
    CALL `variation_tracker.gc_tracker_report_rebuild`(rec.scheman_name, rec.release_date);
  END FOR;
END;