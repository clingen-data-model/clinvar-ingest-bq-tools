CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_rcv_classifications`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_rcv_classifications
  CALL `clinvar_ingest.validate_last_release`('clinvar_rcv_classifications', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted rcv_classifications (where it exists in clinvar_rcv_classifications (for deleted_release_date is null), 
  -- but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_rcv_classifications` crcvc
      SET 
        deleted_release_date = %T,
        deleted_count = deleted_count + 1
    WHERE 
      crcvc.deleted_release_date is NULL 
      AND
      NOT EXISTS (
        SELECT 
          rcvc.rcv_id
        FROM `%s.rcv_accession_classification` rcvc
        CROSS JOIN UNNEST(rcvc.agg_classification) as cx
        JOIN `%s.rcv_accession` rcv
        ON
          rcvc.rcv_id = rcv.id
        LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
        ON 
          cvs1.label = rcvc.review_status
        WHERE       
          rcv.variation_id = crcvc.variation_id
          AND
          rcv.trait_set_id = crcvc.trait_set_id
          AND
          rcvc.rcv_id = crcvc.rcv_id 
          AND 
          rcvc.statement_type IS NOT DISTINCT FROM crcvc.statement_type 
          AND
          cvs1.rank IS NOT DISTINCT FROM crcvc.rank 
          AND
          cx.date_last_evaluated IS NOT DISTINCT FROM crcvc.last_evaluated 
          AND
          cx.interp_description IS NOT DISTINCT FROM crcvc.agg_classification_description 
          AND
          cx.num_submissions IS NOT DISTINCT FROM crcvc.num_submissions 
          AND
          cx.clinical_impact_assertion_type IS NOT DISTINCT FROM crcvc.clinical_impact_assertion_type 
          AND
          cx.clinical_impact_clinical_significance IS NOT DISTINCT FROM crcvc.clinical_impact_clinical_significance
      )
  """, release_date, schema_name, schema_name);

  -- updated variations
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_rcv_classifications` crcvc
      SET 
        end_release_date = %T,
        deleted_release_date = NULL
    FROM `%s.rcv_accession_classification` rcvc
    CROSS JOIN UNNEST(rcvc.agg_classification) as cx
    JOIN `%s.rcv_accession` rcv
    ON
      rcvc.rcv_id = rcv.id
    LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
    ON 
      cvs1.label = rcvc.review_status
    WHERE 
      rcv.variation_id = crcvc.variation_id
      AND
      rcv.trait_set_id = crcvc.trait_set_id
      AND
      rcvc.rcv_id = crcvc.rcv_id 
      AND 
      rcvc.statement_type IS NOT DISTINCT FROM crcvc.statement_type 
      AND
      cvs1.rank IS NOT DISTINCT FROM crcvc.rank 
      AND
      cx.date_last_evaluated IS NOT DISTINCT FROM crcvc.last_evaluated 
      AND
      cx.interp_description IS NOT DISTINCT FROM crcvc.agg_classification_description 
      AND
      cx.num_submissions IS NOT DISTINCT FROM crcvc.num_submissions 
      AND
      cx.clinical_impact_assertion_type IS NOT DISTINCT FROM crcvc.clinical_impact_assertion_type 
      AND
      cx.clinical_impact_clinical_significance IS NOT DISTINCT FROM crcvc.clinical_impact_clinical_significance     
  """, release_date, schema_name, schema_name);

  -- new rcv_accession_classification
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_rcv_classifications` (
      variation_id,
      trait_set_id,
      rcv_id,
      statement_type,
      rank, 
      last_evaluated, 
      agg_classification_description, 
      num_submissions,
      clinical_impact_assertion_type,
      clinical_impact_clinical_significance,
      start_release_date, 
      end_release_date
    )
    SELECT 
      rcv.variation_id,
      rcv.trait_set_id,
      rcvc.rcv_id,
      rcvc.statement_type,
      cvs1.rank, 
      cx.date_last_evaluated as last_evaluated,
      cx.interp_description as agg_classification_description,
      cx.num_submissions,
      cx.clinical_impact_assertion_type,
      cx.clinical_impact_clinical_significance,
      %T as start_release_date, 
      %T as end_release_date
    FROM `%s.rcv_accession_classification` rcvc
    CROSS JOIN UNNEST(rcvc.agg_classification) as cx
    JOIN `%s.rcv_accession` rcv
    ON
      rcvc.rcv_id = rcv.id
    -- dataset term check in dataset-preparation scripts should assure all statuses are present
    -- just in case we should keep outer join to allow null 'rank' to be produced to assure no 
    -- records are skipped in the final result set.
    LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
    ON 
      cvs1.label = rcvc.review_status
    WHERE 
      NOT EXISTS (
      SELECT crcvc.rcv_id 
      FROM `clinvar_ingest.clinvar_rcv_classifications` crcvc
      WHERE 
        rcv.variation_id = crcvc.variation_id
        AND
        rcv.trait_set_id = crcvc.trait_set_id
        AND
        rcvc.rcv_id = crcvc.rcv_id 
        AND 
        rcvc.statement_type IS NOT DISTINCT FROM crcvc.statement_type 
        AND
        cvs1.rank IS NOT DISTINCT FROM crcvc.rank 
        AND
        cx.date_last_evaluated IS NOT DISTINCT FROM crcvc.last_evaluated 
        AND
        cx.interp_description IS NOT DISTINCT FROM crcvc.agg_classification_description 
        AND
        cx.num_submissions IS NOT DISTINCT FROM crcvc.num_submissions 
        AND
        cx.clinical_impact_assertion_type IS NOT DISTINCT FROM crcvc.clinical_impact_assertion_type 
        AND
        cx.clinical_impact_clinical_significance IS NOT DISTINCT FROM crcvc.clinical_impact_clinical_significance
      )
  """, release_date, release_date, schema_name, schema_name);

  SET result_message = "clinvar_rcv_classifications processed successfully."; 

END;