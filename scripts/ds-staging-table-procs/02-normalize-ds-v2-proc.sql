
CREATE OR REPLACE PROCEDURE `clinvar_ingest.normalize_dataset_v2`(
  schema_name STRING   -- Name of schema/dataset
)
BEGIN
  DECLARE column_exists BOOL;
  DECLARE table_exists BOOL;

  -- TABLE 1. Clinical Assertion
  -- check for clinical_assertion.statement_type column as THE indicator that the dataset has been normalized to v2
  CALL `clinvar_ingest.check_column_exists`(schema_name, 'clinical_assertion', 'statement_type', column_exists);

  -- if the column does not exist, add it with the default value
  IF NOT column_exists THEN
    -- backup the original clinical_assertion table
    EXECUTE IMMEDIATE FORMAT("""
      CREATE TABLE `%s.backup_clinical_assertion` AS 
      SELECT * FROM `%s.clinical_assertion`
    """, schema_name, schema_name);

    
    -- create or replace the clinical_assertion table from the backup
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.clinical_assertion` AS
      SELECT 
        *,
        'GermlineClassification' as statement_type,
        CAST(NULL as STRING) as clinical_impact_assertion_type,
        CAST(NULL as STRING) as clinical_impact_clinical_significance
      FROM `%s.backup_clinical_assertion`
    """, schema_name, schema_name);  
  END IF;

  -- TABLE 2. RCV Accession & RCV Accession Classification (with corrections for v2 rcv_accession_classification.agg_classification column)
  -- check that the rcv_accession_classification table exists as THE indicator that the dataset has been normalized to v2
  CALL `clinvar_ingest.check_table_exists`(schema_name, 'rcv_accession_classification', table_exists);

  -- if the table does not exist, create it
  IF NOT table_exists THEN
    -- backup the original rcv_accession table
    EXECUTE IMMEDIATE FORMAT("""
      CREATE TABLE `%s.backup_rcv_accession` AS 
      SELECT * FROM `%s.rcv_accession`
    """, schema_name, schema_name);

    -- create the rcv_accession_classification table from the backup
    EXECUTE IMMEDIATE FORMAT("""
      CREATE TABLE %s.rcv_accession_classification AS
      SELECT
        release_date,
        id as rcv_id,
        'GermlineClassification' AS statement_type,
        review_status,
        [
          STRUCT(
            submission_count as num_submissions,
            date_last_evaluated,
            interpretation as interp_description,
            CAST(NULL as STRING) as clinical_impact_assertion_type,
            CAST(NULL as STRING) as clinical_impact_clinical_significance
          )
        ] as agg_classification        
      FROM `%s.backup_rcv_accession`
    """, schema_name, schema_name);

    -- create or replace the rcv_accession_classification table from the backup
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.rcv_accession` AS
      SELECT 
        release_date,
        id,
        variation_id,
        independent_observations,
        variation_archive_id,
        version,
        title,
        trait_set_id,
        content
      FROM `%s.backup_rcv_accession`
    """, schema_name, schema_name);

  ELSE
    -- if the table exists, check if the agg_classification column exists
    CALL `clinvar_ingest.check_column_exists`(schema_name, 'rcv_accession_classification', 'agg_classification', column_exists);

    -- if the column does not exist, convert the v2 table to the final format
    IF NOT column_exists THEN
      -- backup the original rcv_accession_classification table
      EXECUTE IMMEDIATE FORMAT("""
        CREATE TABLE `%s.backup_rcv_accession_classification` AS 
        SELECT * FROM `%s.rcv_accession_classification`
      """, schema_name, schema_name);

      -- create or replace the rcv_accession_classification table from the backup
      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `%s.rcv_accession_classification` AS
        SELECT
          release_date,
          rcv_id,
          statement_type,
          review_status,
          `clinvar_ingest.parseAggDescription`(content).description as agg_classification,
        IF(
          REGEXP_CONTAINS(content, r'^{\\s*"Description"\\s*\\:\\s*"[^"]+"\\s*}'),
            NULL, 
            REGEXP_REPLACE(content, r'"Description"\\s*\\:\\s*"[^"]+"\\s*,*\\s*', "")
        ) as content
        FROM `%s.rcv_accession_classification`
        WHERE content is not null
        UNION ALL
        SELECT 
        release_date,
        rcv_id,
        statement_type,
        review_status,
        [
          STRUCT(
            clinical_impact_assertion_type,
            clinical_impact_clinical_significance,
            date_last_evaluated,
            num_submissions,
            interp_description
          )
        ] as agg_classification,
        content
        FROM `%s.rcv_accession_classification`
        WHERE content is null
      """, schema_name, schema_name, schema_name);
    END IF;    
  END IF;

  -- TABLE 3. Variation Archive & Variation Archive Classification
  -- check that the variation_archive_classification table exists as THE indicator that the dataset has been normalized to v2
  CALL `clinvar_ingest.check_table_exists`(schema_name, 'variation_archive_classification', table_exists);

  -- if the table does not exist, create it
  IF NOT table_exists THEN
    -- backup the original variation_archive table
    EXECUTE IMMEDIATE FORMAT("""
      CREATE TABLE `%s.backup_variation_archive` AS 
      SELECT * FROM `%s.variation_archive`
    """, schema_name, schema_name);

    -- create the variation_archive_classification table from the backup
    EXECUTE IMMEDIATE FORMAT("""
      CREATE TABLE %s.variation_archive_classification AS
      SELECT
        id as vcv_id,
        'GermlineClassification' AS statement_type,
        review_status,
        num_submitters,
        num_submissions,
        date_created,
        interp_date_last_evaluated,
        interp_description,
        interp_explanation,
        CAST(JSON_VALUE(REPLACE(content, '@MostRecentSubmission', 'MostRecentSubmission'), '$.MostRecentSubmission') AS DATE) AS most_recent_submission,
        interp_content as content,
        CAST(NULL as STRING) as clinical_impact_assertion_type,
        CAST(NULL as STRING) as clinical_impact_clinical_significance
      FROM `%s.backup_variation_archive`
    """, schema_name, schema_name);

    -- create or replace the variation_archive table from the backup
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.variation_archive` AS
      SELECT 
        date_created,
        record_status,
        variation_id,
        release_date,
        IF(
          REGEXP_CONTAINS(content, r'^{\\s*"@MostRecentSubmission"\\s*\\:\\s*"[^"]+"\\s*}'),
            NULL, 
            REGEXP_REPLACE(content, r'"@MostRecentSubmission"\\s*\\:\\s*"[^"]+"\\s*,*\\s*', "")
        ) as content,
        species,
        id,
        version,
        num_submitters,
        date_last_updated,
        num_submissions
      FROM `%s.backup_variation_archive`
    """, schema_name, schema_name);
  END IF;

END;

-- tested on older set and it added the col and updated the values to the default.
-- CALL `clinvar_ingest.normalize_dataset`('clinvar_2023_01_07_v1_6_57')
-- tested on newer set and no col was added or updated
-- CALL `clinvar_ingest.normalize_dataset`('clinvar_2024_11_26_v2_0_1_alpha')