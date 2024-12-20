CREATE OR REPLACE PROCEDURE `clinvar_ingest.temporal_data_collection_v2`(
  on_date DATE
)
BEGIN
  FOR rec IN (
    select 
      s.schema_name, 
      s.release_date, 
      s.prev_release_date, 
      s.next_release_date 
    FROM clinvar_ingest.schema_on_v2(on_date) as s
  )
  DO
    CALL `clinvar_ingest.clinvar_genes`(rec.schema_name, rec.release_date);
    CALL `clinvar_ingest.clinvar_submitters`(rec.schema_name, rec.release_date);
    CALL `clinvar_ingest.clinvar_variations`(rec.schema_name, rec.release_date);
    CALL `clinvar_ingest.clinvar_vcvs_v2`(rec.schema_name, rec.release_date);
    CALL `clinvar_ingest.clinvar_scvs_v2`(rec.schema_name, rec.release_date);
    CALL `clinvar_ingest.clinvar_gc_scvs`(rec.schema_name, rec.release_date);

    CALL `clinvar_ingest.clinvar_var_scv_change`();
    CALL `clinvar_ingest.voi_vcv_scv_v2`();
    CALL `clinvar_ingest.voi_and_voi_scv_group_v2`();
    CALL `clinvar_ingest.voi_group_change_v2`();
    CALL `clinvar_ingest.voi_top_group_change_v2`();
    CALL `clinvar_ingest.voi_summary_change_proc_v2`();
  END FOR;

END;