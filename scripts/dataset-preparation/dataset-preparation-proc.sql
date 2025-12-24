CREATE OR REPLACE PROCEDURE `clinvar_ingest.dataset_preparation`(
  in_schema_name STRING
)
BEGIN
  -- All variable declarations must be grouped together at the top of the block.
  DECLARE dataset_count INT64;
  DECLARE release_date_str STRING;
  DECLARE release_date DATE;
  DECLARE rec STRUCT<schema_name STRING, release_date DATE>;

  -- Check if the dataset exists in the current project
  SET dataset_count = (
    SELECT COUNT(1)
    FROM INFORMATION_SCHEMA.SCHEMATA
    WHERE schema_name = in_schema_name
  );

  IF dataset_count = 0 THEN
    RAISE USING MESSAGE = FORMAT('Dataset "%s" does not exist in the current project.', in_schema_name);
  END IF;

  -- Now the rest of the procedural logic can execute.
  SET release_date_str = REGEXP_EXTRACT(in_schema_name, r'^clinvar_(\d{4}_\d{2}_\d{2})_v\d+_\d+_\d+$');

  -- Throw an error if schema_name does not match expected format
  IF release_date_str IS NULL THEN
    RAISE USING MESSAGE = FORMAT(
      'Invalid schema_name format: "%s". Expected: clinvar_YYYY_MM_DD_vX_X_X',
      in_schema_name
    );
  END IF;

  -- Convert the extracted string to DATE
  SET release_date = PARSE_DATE('%Y_%m_%d', release_date_str);

  -- Create the rec struct
  SET rec = STRUCT(in_schema_name, release_date);

  CALL `clinvar_ingest.normalize_dataset`(rec.schema_name);
  CALL `clinvar_ingest.validate_dataset`(rec.schema_name);
  CALL `clinvar_ingest.scv_summary`(rec.schema_name);
  CALL `clinvar_ingest.single_gene_variation`(rec.schema_name, rec.release_date);
  CALL `clinvar_ingest.gc_scv_obs`(rec.schema_name);
  CALL `clinvar_ingest.refresh_scv_lookup`(rec.schema_name);

END;
