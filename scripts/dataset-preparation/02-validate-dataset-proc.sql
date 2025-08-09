
CREATE OR REPLACE PROCEDURE `clinvar_ingest.validate_dataset`(
  schema_name STRING
)
BEGIN
  DECLARE scv_classification_terms ARRAY<STRING>;
  DECLARE scv_classification_statement_combo_terms ARRAY<STRING>;
  DECLARE scv_review_status_terms ARRAY<STRING>;
  DECLARE rcv_classification_review_status_terms ARRAY<STRING>;
  DECLARE vcv_classification_review_status_terms ARRAY<STRING>;
  DECLARE trait_set_id_mismatch INT64;
  DECLARE required_field_validation_errors ARRAY<STRING>;
  DECLARE release_date_validation_errors ARRAY<STRING>;
  DECLARE all_validation_errors ARRAY<STRING> default [];
  DECLARE error_message STRING;
  DECLARE rcv_mapping_exists BOOLEAN;
  DECLARE required_check_table_fields ARRAY<STRUCT<table_name STRING, field_name STRING>>;
  DECLARE release_check_tables ARRAY<STRING>;

  -- Check for new interpretation_descriptions in clinical_assertion
  EXECUTE IMMEDIATE FORMAT("""
    SELECT ARRAY_AGG(DISTINCT IFNULL(ca.interpretation_description,'null'))
    FROM `%s.clinical_assertion` ca
    LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
    ON
      map.scv_term = LOWER(IFNULL(ca.interpretation_description,'not provided'))
    WHERE
      map.scv_term IS NULL
  """,
  schema_name) INTO scv_classification_terms;

  IF scv_classification_terms IS NOT NULL AND ARRAY_LENGTH(scv_classification_terms) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      [CONCAT(
        "New SCV classification terms found: [",
        ARRAY_TO_STRING(scv_classification_terms, ', '),
        "].\nNOTE: Add scv_clinsig_map records to the '00-setup-translation-tables.sql' script and update, then rerun this script."
      )]
    );
  END IF;

  -- Check for interpretation_description+statement_type combos not available in clinvar_clinsig_types
  EXECUTE IMMEDIATE FORMAT("""
    SELECT
      ARRAY_AGG(DISTINCT IFNULL(ca.interpretation_description,'null') || ' + ' || ca.statement_type)
    FROM `%s.clinical_assertion` ca
    LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
    ON
      map.scv_term = lower(IFNULL(ca.interpretation_description,'not provided'))
    LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst
    ON
      cst.code = map.cv_clinsig_type
      AND
      cst.statement_type = ca.statement_type
    WHERE
      cst.code IS NULL
      AND
      -- exclude null statement_type records which were introduced in the 2025-08-08 release due to
      -- the segregation of functional data statements from GermlineClassification scvs.
      ca.statement_type IS NOT NULL
  """,
  schema_name) INTO scv_classification_statement_combo_terms;

  IF scv_classification_statement_combo_terms IS NOT NULL AND ARRAY_LENGTH(scv_classification_statement_combo_terms) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      [CONCAT(
        all_validation_errors,
        "New SCV classification+statement_type combos found: [",
        ARRAY_TO_STRING(scv_classification_statement_combo_terms, ', '),
        "].\nNOTE: Add clinvar_clinsig_types records to the '00-setup-translation-tables.sql' script and update, then rerun this script."
      )]
    );
  END IF;

  -- Check for new review_status terms in clinical_assertion
  EXECUTE IMMEDIATE FORMAT("""
    SELECT ARRAY_AGG(DISTINCT IFNULL(ca.review_status,'null'))
    FROM `%s.clinical_assertion` ca
    LEFT JOIN `clinvar_ingest.clinvar_status` cs
    ON
      cs.label = LOWER(ca.review_status)
      AND
      ca.release_date BETWEEN cs.start_release_date AND cs.end_release_date
      AND
      cs.scv = TRUE
    WHERE
      cs.label IS NULL
      AND
      -- exclude null statement_type records which were introduced in the 2025-08-08 release due to
      -- the segregation of functional data statements from GermlineClassification scvs.
      ca.statement_type IS NOT NULL
  """,
  schema_name) INTO scv_review_status_terms;

  IF scv_review_status_terms IS NOT NULL AND ARRAY_LENGTH(scv_review_status_terms) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      [CONCAT(
        "New SCV review status terms found: [",
        ARRAY_TO_STRING(scv_review_status_terms, ', '),
        "].\nNOTE: Add clinvar_status records to the '00-setup-translation-tables.sql' script and update, then rerun this script."
      )]
    );
  END IF;

  -- Check for new review_status terms in rcv_accession_classification
  EXECUTE IMMEDIATE FORMAT("""
    SELECT ARRAY_AGG(DISTINCT IFNULL(rcvc.review_status,'null'))
    FROM `%s.rcv_accession_classification` rcvc
    LEFT JOIN `clinvar_ingest.clinvar_status` cs
    ON
      cs.label = LOWER(rcvc.review_status)
      AND
      rcvc.release_date BETWEEN cs.start_release_date AND cs.end_release_date
    WHERE
      cs.label IS NULL
  """,
  schema_name) INTO rcv_classification_review_status_terms;

  IF rcv_classification_review_status_terms IS NOT NULL AND ARRAY_LENGTH(rcv_classification_review_status_terms) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      [CONCAT(
        "New RCV classification review status terms found: [",
        ARRAY_TO_STRING(rcv_classification_review_status_terms, ', '),
        "].\nNOTE: Add clinvar_status records to the '00-setup-translation-tables.sql' script and update, then rerun this script."
      )]
    );
  END IF;

  -- Check for new review_status terms in variation_archive_classification
  EXECUTE IMMEDIATE FORMAT("""
    SELECT ARRAY_AGG(DISTINCT IFNULL(vcvc.review_status,'null'))
    FROM `%s.variation_archive_classification` vcvc
    JOIN `%s.variation_archive` va
    ON
      va.id = vcvc.vcv_id
    LEFT JOIN `clinvar_ingest.clinvar_status` cs
    ON
      cs.label = LOWER(vcvc.review_status)
      AND
      va.release_date between cs.start_release_date and cs.end_release_date
    WHERE
      cs.label IS NULL
  """, schema_name, schema_name) INTO vcv_classification_review_status_terms;

  IF vcv_classification_review_status_terms IS NOT NULL AND ARRAY_LENGTH(vcv_classification_review_status_terms) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      [CONCAT(
        "New VCV classification review status terms found: [",
        ARRAY_TO_STRING(vcv_classification_review_status_terms, ', '),
        "].\nNOTE: Add clinvar_status records to the '00-setup-translation-tables.sql' script and update, then rerun this script."
      )]
    );
  END IF;

  CALL `clinvar_ingest.check_table_exists`(schema_name, 'rcv_mapping', rcv_mapping_exists);

  -- if the table exist, update the fks
   IF rcv_mapping_exists THEN

    -- throw an exception if any of the rcv_mapping.trait_set_id values do not match the rcv_accession.trait_set_id values
    EXECUTE IMMEDIATE FORMAT("""
      SELECT
        COUNT(*)
      FROM `%s.rcv_mapping` rm
      JOIN `%s.rcv_accession` ra
      ON
        ra.id = rm.rcv_accession
      WHERE
        ra.trait_set_id != rm.trait_set_id
    """,
    schema_name,
    schema_name) INTO trait_set_id_mismatch;

    IF trait_set_id_mismatch > 0 THEN
      SET all_validation_errors = ARRAY_CONCAT(
        all_validation_errors,
        ['Trait set ID mismatch detected in ' || schema_name || '.rcv_mapping']
      );
    END IF;

  END IF;

  SET required_check_table_fields = [
    STRUCT('clinical_assertion', 'rcv_accession_id'),
    STRUCT('clinical_assertion', 'submitter_id'),
    STRUCT('clinical_assertion', 'submission_id'),
    STRUCT('clinical_assertion', 'variation_id'),
    STRUCT('clinical_assertion', 'variation_archive_id'),
    STRUCT('clinical_assertion', 'review_status'),
    -- null statement_type records which were introduced in the 2025-08-08 release due to
    -- the segregation of functional data statements from GermlineClassification scvs.
    -- STRUCT('clinical_assertion', 'statement_type'),
    STRUCT('clinical_assertion', 'release_date'),
    STRUCT('rcv_accession', 'id'),
    STRUCT('rcv_accession', 'version'),
    STRUCT('rcv_accession', 'variation_id'),
    STRUCT('rcv_accession', 'variation_archive_id'),
    STRUCT('rcv_accession', 'trait_set_id'),
    STRUCT('rcv_accession', 'release_date'),
    STRUCT('rcv_accession_classification', 'rcv_id'),
    STRUCT('rcv_accession_classification', 'statement_type'),
    STRUCT('rcv_accession_classification', 'review_status'),
    STRUCT('rcv_accession_classification', 'release_date'),
    STRUCT('submission', 'submitter_id'),
    STRUCT('submission', 'id'),
    STRUCT('submission', 'submission_date'),
    STRUCT('submission', 'release_date'),
    STRUCT('submitter', 'id'),
    STRUCT('submitter', 'current_name'),
    STRUCT('submitter', 'release_date'),
    STRUCT('trait', 'id'),
    STRUCT('trait', 'type'),
    STRUCT('trait', 'release_date'),
    STRUCT('trait_set', 'id'),
    STRUCT('trait_set', 'type'),
    STRUCT('trait_set', 'id'),
    STRUCT('variation', 'name'),
    STRUCT('variation', 'subclass_type'),
    STRUCT('variation', 'variation_type'),
    STRUCT('variation', 'release_date'),
    STRUCT('variation_archive', 'id'),
    STRUCT('variation_archive', 'version'),
    STRUCT('variation_archive', 'variation_id'),
    STRUCT('variation_archive', 'release_date'),
    STRUCT('variation_archive_classification', 'vcv_id'),
    STRUCT('variation_archive_classification', 'statement_type'),
    STRUCT('variation_archive_classification', 'review_status'),
    STRUCT('variation_archive_classification', 'interp_description')
  ];
  CALL `clinvar_ingest.check_required_fields`(schema_name, required_check_table_fields, required_field_validation_errors);
  IF ARRAY_LENGTH(required_field_validation_errors) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      required_field_validation_errors
    );
  END IF;

  SET release_check_tables = [
    'clinical_assertion',
    'rcv_accession',
    'rcv_accession_classification',
    'submission',
    'submitter',
    'trait',
    'trait_set',
    'variation',
    'variation_archive'
  ];
  CALL `clinvar_ingest.check_release_dates`(schema_name, release_check_tables, release_date_validation_errors);
  IF ARRAY_LENGTH(release_date_validation_errors) > 0 THEN
    SET all_validation_errors = ARRAY_CONCAT(
      all_validation_errors,
      release_date_validation_errors
    );
  END IF;

  IF ARRAY_LENGTH(all_validation_errors) > 0 THEN
    -- raise an exception with the error messages in a user friendly listed format
    SET error_message =
      'One or more validation all_validation_errors occurred:\n' ||
      ARRAY_TO_STRING(
        ARRAY(
          SELECT
            '- ' || validation_error
          FROM UNNEST(all_validation_errors) AS validation_error
        ),
        '\n'
      );
    RAISE USING MESSAGE = error_message;
  END IF;

END;
