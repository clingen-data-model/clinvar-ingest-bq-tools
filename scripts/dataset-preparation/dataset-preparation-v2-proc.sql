CREATE OR REPLACE PROCEDURE `clinvar_ingest.dataset_preparation_v2`(
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
    CALL `clinvar_ingest.validate_dataset_terms`(rec.schema_name);
    CALL `clinvar_ingest.normalize_dataset_v2`(rec.schema_name);
    CALL `clinvar_ingest.scv_summary_v2`(rec.schema_name);
    CALL `clinvar_ingest.single_gene_variation`(rec.schema_name, rec.release_date);
    CALL `clinvar_ingest.gc_scv`(rec.schema_name);
  END FOR;

END;