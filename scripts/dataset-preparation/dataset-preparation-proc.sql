CREATE OR REPLACE PROCEDURE `clinvar_ingest.dataset_preparation`(
  on_date DATE
)
BEGIN
  DECLARE rec STRUCT<schema_name STRING, release_date DATE, prev_release_date DATE, next_release_date DATE>;
  
  -- Declare a cursor to fetch the row
  SET rec = (
    SELECT AS STRUCT
      s.schema_name, 
      s.release_date, 
      s.prev_release_date, 
      s.next_release_date
    FROM clinvar_ingest.schema_on(on_date) AS s
  );

  CALL `clinvar_ingest.normalize_dataset`(rec.schema_name);
  CALL `clinvar_ingest.validate_dataset`(rec.schema_name);
  CALL `clinvar_ingest.scv_summary`(rec.schema_name);
  CALL `clinvar_ingest.single_gene_variation`(rec.schema_name, rec.release_date);
  CALL `clinvar_ingest.gc_scv`(rec.schema_name);
  CALL `clinvar_ingest.refresh_scv_lookup`(rec.schema_name);

END;