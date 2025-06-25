CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_vcv_classifications`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_vcv_classifications
  CALL `clinvar_ingest.validate_last_release`('clinvar_vcv_classifications', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted vcv_classifications (where it exists in clinvar_vcv_classifications (for deleted_release_date is null),
  -- but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_vcv_classifications` cvcvc
      SET
        deleted_release_date = %T
    WHERE
      cvcvc.deleted_release_date is NULL
      AND
      NOT EXISTS (
        SELECT
          vcvc.vcv_id
        FROM `%s.variation_archive_classification` vcvc
        JOIN `%s.variation_archive` vcv
        ON
          vcvc.vcv_id = vcv.id
        LEFT JOIN `clinvar_ingest.clinvar_status` cvs1
        ON
          cvs1.label = vcvc.review_status
          AND
          vcv.release_date between cvs1.start_release_date and cvs1.end_release_date
        WHERE
          vcv.variation_id = cvcvc.variation_id
          AND
          vcvc.vcv_id = cvcvc.vcv_id
          AND
          vcvc.statement_type IS NOT DISTINCT FROM cvcvc.statement_type
          AND
          cvs1.rank IS NOT DISTINCT FROM cvcvc.rank
          AND
          vcvc.date_last_evaluated IS NOT DISTINCT FROM cvcvc.last_evaluated
          AND
          vcvc.interp_description IS NOT DISTINCT FROM cvcvc.agg_classification_description
          AND
          vcvc.num_submitters IS NOT DISTINCT FROM cvcvc.num_submitters
          AND
          vcvc.num_submissions IS NOT DISTINCT FROM cvcvc.num_submissions
          AND
          vcvc.most_recent_submission IS NOT DISTINCT FROM cvcvc.most_recent_submission
      )
  """, release_date, schema_name, schema_name);

  -- updated variations
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_vcv_classifications` cvcvc
      SET
        end_release_date = %T,
        review_status = vcvc.review_status
    FROM `%s.variation_archive_classification` vcvc
    JOIN `%s.variation_archive` vcv
    ON
      vcvc.vcv_id = vcv.id
    LEFT JOIN `clinvar_ingest.clinvar_status` cvs1
    ON
      cvs1.label = vcvc.review_status
      AND
      vcv.release_date between cvs1.start_release_date and cvs1.end_release_date
    WHERE
      vcv.variation_id = cvcvc.variation_id
      AND
      vcvc.vcv_id = cvcvc.vcv_id
      AND
      vcvc.statement_type IS NOT DISTINCT FROM cvcvc.statement_type
      AND
      cvs1.rank IS NOT DISTINCT FROM cvcvc.rank
      AND
      vcvc.date_last_evaluated IS NOT DISTINCT FROM cvcvc.last_evaluated
      AND
      vcvc.interp_description IS NOT DISTINCT FROM cvcvc.agg_classification_description
      AND
      vcvc.num_submitters IS NOT DISTINCT FROM cvcvc.num_submitters
      AND
      vcvc.num_submissions IS NOT DISTINCT FROM cvcvc.num_submissions
      AND
      vcvc.most_recent_submission IS NOT DISTINCT FROM cvcvc.most_recent_submission
      AND
      cvcvc.deleted_release_date is NULL
  """, release_date, schema_name, schema_name);

  -- new variation_archive_classification
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_vcv_classifications` (
      variation_id,
      vcv_id,
      statement_type,
      rank,
      review_status,
      last_evaluated,
      agg_classification_description,
      num_submitters,
      num_submissions,
      most_recent_submission,
      start_release_date,
      end_release_date
    )
    SELECT
      vcv.variation_id,
      vcvc.vcv_id,
      vcvc.statement_type,
      cvs1.rank,
      vcvc.review_status,
      vcvc.date_last_evaluated as last_evaluated,
      vcvc.interp_description as agg_classification_description,
      vcvc.num_submitters,
      vcvc.num_submissions,
      vcvc.most_recent_submission,
      %T as start_release_date,
      %T as end_release_date
    FROM `%s.variation_archive_classification` vcvc
    JOIN `%s.variation_archive` vcv
    ON
      vcvc.vcv_id = vcv.id
    -- dataset term check in dataset-preparation scripts should assure all statuses are present
    -- just in case we should keep outer join to allow null 'rank' to be produced to assure no
    -- records are skipped in the final result set.
    LEFT JOIN `clinvar_ingest.clinvar_status` cvs1
    ON
      cvs1.label = vcvc.review_status
      AND
      vcv.release_date between cvs1.start_release_date and cvs1.end_release_date
    WHERE
      NOT EXISTS (
      SELECT cvcvc.vcv_id
      FROM `clinvar_ingest.clinvar_vcv_classifications` cvcvc
      WHERE
        vcv.variation_id = cvcvc.variation_id
        AND
        vcvc.vcv_id = cvcvc.vcv_id
        AND
        vcvc.statement_type IS NOT DISTINCT FROM cvcvc.statement_type
        AND
        cvs1.rank IS NOT DISTINCT FROM cvcvc.rank
        AND
        vcvc.date_last_evaluated IS NOT DISTINCT FROM cvcvc.last_evaluated
        AND
        vcvc.interp_description IS NOT DISTINCT FROM cvcvc.agg_classification_description
        AND
        vcvc.num_submitters IS NOT DISTINCT FROM cvcvc.num_submitters
        AND
        vcvc.num_submissions IS NOT DISTINCT FROM cvcvc.num_submissions
        AND
        vcvc.most_recent_submission IS NOT DISTINCT FROM cvcvc.most_recent_submission
        AND
        cvcvc.deleted_release_date is NULL
      )
  """, release_date, release_date, schema_name, schema_name);

  SET result_message = "clinvar_vcv_classifications processed successfully.";

END;
