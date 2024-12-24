CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_vcvs`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE
)
BEGIN
  DECLARE project_id STRING;

  SET project_id = 
  (
    SELECT 
      catalog_name as paroject_id
    FROM `INFORMATION_SCHEMA.SCHEMATA`
    WHERE 
      schema_name = 'clinvar_ingest'
  );

  IF (project_id = 'clingen-stage') THEN

    -- validate the last release date clinvar_vcvs
    CALL `clinvar_ingest.validate_last_release`('clinvar_vcvs',previous_release_date);

    -- deleted vcvs (where it exists in clinvar_vcvs (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cvcv.deleted_release_date is NULL 
        AND
        NOT EXISTS (
          SELECT 
            vcv.id
          FROM `%s.variation_archive` vcv
          LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
          ON 
            cvs1.label = vcv.review_status
          WHERE  
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version 
            AND
            cvs1.rank IS NOT DISTINCT FROM cvcv.rank 
            AND
            vcv.interp_description IS NOT DISTINCT FROM cvcv.agg_classification 
            AND
            vcv.interp_date_last_evaluated IS NOT DISTINCT FROM cvcv.last_evaluated
        )
    """, release_date, schema_name);

    -- updated variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          end_release_date = vcv.release_date,
          deleted_release_date = NULL
      FROM `%s.variation_archive` vcv
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
      ON 
        cvs1.label = vcv.review_status
      WHERE 
        vcv.variation_id = cvcv.variation_id 
        AND 
        vcv.id = cvcv.id 
        AND 
        vcv.version = cvcv.version 
        AND
        cvs1.rank IS NOT DISTINCT FROM cvcv.rank 
        AND
        vcv.interp_description IS NOT DISTINCT FROM cvcv.agg_classification 
        AND
        vcv.interp_date_last_evaluated IS NOT DISTINCT FROM cvcv.last_evaluated
    """, schema_name);

    -- new variation_archive
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_vcvs` (
        variation_id,  
        id, 
        version, 
        rank, 
        last_evaluated, 
        agg_classification, 
        start_release_date, 
        end_release_date
      )
      SELECT 
        vcv.variation_id, 
        vcv.id, 
        vcv.version, 
        cvs1.rank, 
        vcv.interp_date_last_evaluated as last_evaluated,
        vcv.interp_description as agg_classification,
        vcv.release_date as start_release_date, 
        vcv.release_date as end_release_date
      FROM `%s.variation_archive` vcv
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
      ON 
        cvs1.label = vcv.review_status
      WHERE 
        NOT EXISTS (
          SELECT 
            cvcv.id 
          FROM `clinvar_ingest.clinvar_vcvs` cvcv
          WHERE 
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version 
            AND
            cvs1.rank IS NOT DISTINCT FROM cvcv.rank 
            AND
            vcv.interp_description IS NOT DISTINCT FROM cvcv.agg_classification 
            AND
            vcv.interp_date_last_evaluated IS NOT DISTINCT FROM cvcv.last_evaluated
        )
    """, schema_name);

  ELSE

    -- validate the last release date clinvar_vcvs
    CALL `clinvar_ingest.validate_last_release`('clinvar_vcvs',previous_release_date);
    CALL `clinvar_ingest.validate_last_release`('clinvar_vcv_classifications',previous_release_date);

    -- deleted vcvs (where it exists in clinvar_vcvs (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cvcv.deleted_release_date is NULL 
        AND
        NOT EXISTS (
          SELECT 
            vcv.id
          FROM `%s.variation_archive` vcv
          WHERE  
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version
        )
    """, release_date, schema_name);

    -- updated variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          end_release_date = vcv.release_date,
          deleted_release_date = NULL
      FROM `%s.variation_archive` vcv
      WHERE 
        vcv.variation_id = cvcv.variation_id 
        AND 
        vcv.id = cvcv.id 
        AND 
        vcv.version = cvcv.version
    """, schema_name);

    -- new variation_archive
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_vcvs` (
        variation_id,  
        id, 
        version, 
        start_release_date, 
        end_release_date
      )
      SELECT 
        vcv.variation_id, 
        vcv.id, 
        vcv.version, 
        vcv.release_date as start_release_date, 
        vcv.release_date as end_release_date
      FROM `%s.variation_archive` vcv
      WHERE 
        NOT EXISTS (
          SELECT 
            cvcv.id 
          FROM `clinvar_ingest.clinvar_vcvs` cvcv
          WHERE 
            vcv.variation_id = cvcv.variation_id 
            AND 
            vcv.id = cvcv.id 
            AND 
            vcv.version = cvcv.version
        )
    """, schema_name);

    -- deleted vcv_classifications (where it exists in clinvar_vcv_classifications (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcv_classifications` cvcvc
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cvcvc.deleted_release_date is NULL 
        AND
        NOT EXISTS (
          SELECT 
            vcvc.vcv_id
          FROM `%s.variation_archive_classification` vcvc
          LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
          ON 
            cvs1.label = vcvc.review_status
          WHERE  
            vcvc.vcv_id = cvcvc.vcv_id 
            AND 
            vcvc.statement_type IS NOT DISTINCT FROM cvcvc.statement_type 
            AND
            cvs1.rank IS NOT DISTINCT FROM cvcvc.rank 
            AND
            vcvc.interp_date_last_evaluated IS NOT DISTINCT FROM cvcvc.last_evaluated 
            AND
            vcvc.interp_description IS NOT DISTINCT FROM cvcvc.agg_classification_description 
            AND
            vcvc.num_submitters IS NOT DISTINCT FROM cvcvc.num_submitters 
            AND
            vcvc.num_submissions IS NOT DISTINCT FROM cvcvc.num_submissions 
            AND
            vcvc.most_recent_submission IS NOT DISTINCT FROM cvcvc.most_recent_submission 
            AND
            vcvc.clinical_impact_assertion_type IS NOT DISTINCT FROM cvcvc.clinical_impact_assertion_type 
            AND
            vcvc.clinical_impact_clinical_significance IS NOT DISTINCT FROM cvcvc.clinical_impact_clinical_significance
        )
    """, release_date, schema_name);

    -- updated variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcv_classifications` cvcvc
        SET 
          end_release_date = %T,
          deleted_release_date = NULL
      FROM `%s.variation_archive_classification` vcvc
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
      ON 
        cvs1.label = vcvc.review_status
      WHERE 
        vcvc.vcv_id = cvcvc.vcv_id 
        AND 
        vcvc.statement_type IS NOT DISTINCT FROM cvcvc.statement_type 
        AND
        cvs1.rank IS NOT DISTINCT FROM cvcvc.rank 
        AND
        vcvc.interp_date_last_evaluated IS NOT DISTINCT FROM cvcvc.last_evaluated 
        AND
        vcvc.interp_description IS NOT DISTINCT FROM cvcvc.agg_classification_description 
        AND
        vcvc.num_submitters IS NOT DISTINCT FROM cvcvc.num_submitters 
        AND
        vcvc.num_submissions IS NOT DISTINCT FROM cvcvc.num_submissions 
        AND
        vcvc.most_recent_submission IS NOT DISTINCT FROM cvcvc.most_recent_submission 
        AND
        vcvc.clinical_impact_assertion_type IS NOT DISTINCT FROM cvcvc.clinical_impact_assertion_type 
        AND
        vcvc.clinical_impact_clinical_significance IS NOT DISTINCT FROM cvcvc.clinical_impact_clinical_significance
    """, release_date, schema_name);

    -- new variation_archive_classification
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_vcv_classifications` (
        vcv_id,
        statement_type,
        rank, 
        last_evaluated, 
        agg_classification_description, 
        num_submitters,
        num_submissions,
        most_recent_submission,
        clinical_impact_assertion_type,
        clinical_impact_clinical_significance,
        start_release_date, 
        end_release_date
      )
      SELECT 
        vcvc.vcv_id,
        vcvc.statement_type,
        cvs1.rank, 
        vcvc.interp_date_last_evaluated as last_evaluated,
        vcvc.interp_description as agg_classification_description,
        vcvc.num_submitters,
        vcvc.num_submissions,
        vcvc.most_recent_submission,
        vcvc.clinical_impact_assertion_type,
        vcvc.clinical_impact_clinical_significance,
        %T as start_release_date, 
        %T as end_release_date
      FROM `%s.variation_archive_classification` vcvc
      -- dataset term check in dataset-preparation scripts should assure all statuses are present
      -- just in case we should keep outer join to allow null 'rank' to be produced to assure no 
      -- records are skipped in the final result set.
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
      ON 
        cvs1.label = vcvc.review_status
      WHERE 
        NOT EXISTS (
        SELECT cvcvc.vcv_id 
        FROM `clinvar_ingest.clinvar_vcv_classifications` cvcvc
        WHERE 
          vcvc.vcv_id = cvcvc.vcv_id AND 
          vcvc.statement_type IS NOT DISTINCT FROM cvcvc.statement_type 
          AND
          cvs1.rank IS NOT DISTINCT FROM cvcvc.rank 
          AND
          vcvc.interp_date_last_evaluated IS NOT DISTINCT FROM cvcvc.last_evaluated 
          AND
          vcvc.interp_description IS NOT DISTINCT FROM cvcvc.agg_classification_description 
          AND
          vcvc.num_submitters IS NOT DISTINCT FROM cvcvc.num_submitters 
          AND
          vcvc.num_submissions IS NOT DISTINCT FROM cvcvc.num_submissions 
          AND
          vcvc.most_recent_submission IS NOT DISTINCT FROM cvcvc.most_recent_submission 
          AND
          vcvc.clinical_impact_assertion_type IS NOT DISTINCT FROM cvcvc.clinical_impact_assertion_type 
          AND
          vcvc.clinical_impact_clinical_significance IS NOT DISTINCT FROM cvcvc.clinical_impact_clinical_significance
        )
    """, release_date, release_date, schema_name);

  END IF;

END;