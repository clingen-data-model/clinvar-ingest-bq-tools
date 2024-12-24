CREATE OR REPLACE PROCEDURE `clinvar_ingest.temporal_data_summation`()
BEGIN
    CALL `clinvar_ingest.clinvar_var_scv_change`();
    CALL `clinvar_ingest.voi_vcv_scv`();
    CALL `clinvar_ingest.voi_and_voi_scv_group`();
    CALL `clinvar_ingest.voi_group_change`();
    CALL `clinvar_ingest.voi_top_group_change`();
    CALL `clinvar_ingest.voi_summary_change`();
END;