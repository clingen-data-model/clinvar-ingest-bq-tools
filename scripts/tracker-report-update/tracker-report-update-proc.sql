-- schema_name: the release schema being processed (e.g. 'clinvar_2026_09_23_v2_6_0').
-- It is threaded to gc_tracker_report_rebuild so the GC tracker report is built
-- against THIS release's scv_summary rather than whatever schema happens to be the
-- latest one that physically exists. Passing NULL preserves the old "latest schema"
-- behavior (gc_tracker_report_rebuild defaults to MAX(release_date) in all_schemas()).
--
-- report_variation and tracker_reports_rebuild operate ACROSS releases (by reportId,
-- over cross-release temporal tables), not against a single release's scv_summary, so
-- they intentionally remain NULL.
--
-- IMPORTANT: the arity changed from () to (STRING). The clinvar-ingest workflow caller
-- (stored_procedures.py) must be updated to `CALL clinvar_ingest.tracker_report_update({dataset})`
-- and deployed together with this procedure, or the no-arg call will fail.
CREATE OR REPLACE PROCEDURE `clinvar_ingest.tracker_report_update`(schema_name STRING)
BEGIN
  CALL `variation_tracker.report_variation`(null);
  CALL `variation_tracker.tracker_reports_rebuild`(null);
  CALL `variation_tracker.gc_tracker_report_rebuild`(schema_name);
END;
