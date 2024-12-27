CREATE OR REPLACE PROCEDURE `clinvar_ingest.temporal_data_collection`(
  on_date DATE
)
BEGIN
  DECLARE all_result_messages STRING DEFAULT '';
  DECLARE result_message STRING DEFAULT '';
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

  CALL `clinvar_ingest.clinvar_genes`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = result_message;

  CALL `clinvar_ingest.clinvar_single_gene_variations`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = CONCAT(all_result_messages, '\n', result_message);

  CALL `clinvar_ingest.clinvar_submitters`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = CONCAT(all_result_messages, '\n', result_message);

  CALL `clinvar_ingest.clinvar_variations`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = CONCAT(all_result_messages, '\n', result_message);

  CALL `clinvar_ingest.clinvar_vcvs`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = CONCAT(all_result_messages, '\n', result_message);

  CALL `clinvar_ingest.clinvar_scvs`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = CONCAT(all_result_messages, '\n', result_message);

  CALL `clinvar_ingest.clinvar_gc_scvs`(rec.schema_name, rec.release_date, rec.prev_release_date, result_message);
  SET all_result_messages = CONCAT(all_result_messages, '\n', result_message);
  
  -- Display the concatenated result_message
  SELECT all_result_messages AS consolidated_result_message;

END;