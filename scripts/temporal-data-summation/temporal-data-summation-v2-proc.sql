CREATE OR REPLACE PROCEDURE `clingen-dev.clinvar_ingest.temporal_data_summation_v2`()
BEGIN
    CALL `clinvar_ingest.clinvar_var_scv_change`();
    CALL `clinvar_ingest.voi_vcv_scv_v2`();
    CALL `clinvar_ingest.voi_and_voi_scv_group_v2`();
    CALL `clinvar_ingest.voi_group_change_v2`();
    CALL `clinvar_ingest.voi_top_group_change_v2`();
    CALL `clinvar_ingest.voi_summary_change_v2`();
END;