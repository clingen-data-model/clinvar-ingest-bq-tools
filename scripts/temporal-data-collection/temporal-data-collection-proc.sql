CREATE OR REPLACE PROCEDURE `clinvar_ingest.temporal_data_collection`(
  on_date DATE
)
BEGIN
  DECLARE last_complete_release_processed_date DATE;
  DECLARE all_processed_results ARRAY<STRING> DEFAULT [];
  DECLARE single_call_result STRING;
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

  -- use the max end-release-date from clinvar_gc_scvs as the last_complete_release_processed_date, since it is the last table to be processed
  SET last_complete_release_processed_date = (select max(end_release_date) from clinvar_ingest.clinvar_gc_scvs);

  -- if the previous release date is not equal to the last_complete_release_processed_date, raise an exception 
  IF rec.prev_release_date != last_complete_release_processed_date THEN
    RAISE USING MESSAGE = FORMAT(
      "Previous release date for the release date on %t does not match the last complete release date processed which was %t.", 
      rec.release_date, 
      last_complete_release_processed_date
    );
  END IF;

  CALL `clinvar_ingest.clinvar_genes`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_result);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_result]);

  CALL `clinvar_ingest.clinvar_single_gene_variations`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_result);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_result]);

  CALL `clinvar_ingest.clinvar_submitters`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_result);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_result]);

  CALL `clinvar_ingest.clinvar_variations`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_result);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_result]);

  CALL `clinvar_ingest.clinvar_vcvs`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_result);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_result]);

  CALL `clinvar_ingest.clinvar_scvs`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_result);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_processed_results]);

  CALL `clinvar_ingest.clinvar_gc_scvs`(rec.schema_name, rec.release_date, rec.prev_release_date, single_call_processed_results);
  SET all_processed_results = ARRAY_CONCAT(all_processed_results, [single_call_result]);
  
  -- output the list of all processed results for auditing purposes.
  SELECT * FROM UNNEST(all_processed_results);

END;