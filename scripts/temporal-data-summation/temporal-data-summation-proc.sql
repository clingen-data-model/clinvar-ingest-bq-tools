CREATE OR REPLACE PROCEDURE `clinvar_ingest.temporal_data_summation`()
BEGIN
    CALL `clinvar_ingest.clinvar_sum_variation_scv_change`();  --`clinvar_ingest.clinvar_var_scv_change`();
    CALL `clinvar_ingest.clinvar_sum_vsp_rank_group`();  -- clinvar_scv_rank_groups
    CALL `clinvar_ingest.clinvar_sum_scvs`();   -- clinvar_scv_rank_groups
    CALL `clinvar_ingest.clinvar_sum_vsp_rank_group_change`();  -- voi_group_change
    CALL `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change`();  -- voi_top_group_change
    CALL `clinvar_ingest.clinvar_sum_variation_group_change`(); -- voi_summary_change

END;
