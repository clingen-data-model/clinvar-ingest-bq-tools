CREATE OR REPLACE PROCEDURE `clinvar_ingest.validate_dataset_terms_v2`(
  schema_name STRING
)
BEGIN
  -- Declare variables to hold results and error messages
  DECLARE scv_classification_terms ARRAY<STRING>;
  DECLARE scv_classification_statement_combo_terms ARRAY<STRING>;
  DECLARE scv_review_status_terms ARRAY<STRING>;
  DECLARE combined_issues STRING;

  -- Check for new interpretation_descriptions in clinical_assertion
  EXECUTE IMMEDIATE FORMAT("""
      SELECT ARRAY_AGG(DISTINCT IFNULL(ca.interpretation_description,'null'))
      FROM `%s.clinical_assertion` ca
      LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
      ON 
        map.scv_term = LOWER(IFNULL(ca.interpretation_description,'not provided'))
      WHERE 
        map.scv_term IS NULL
  """, schema_name) INTO scv_classification_terms;

  -- Check for interpretatoin_descrition+statement_type combos not available in clinvar_clinsig_types
  EXECUTE IMMEDIATE FORMAT("""
    SELECT 
      ARRAY_AGG(DISTINCT IFNULL(ca.interpretation_description,'null') || ' + ' || ca.statement_type)
    FROM `%s.clinical_assertion` ca
    LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
    ON 
      map.scv_term = lower(IFNULL(ca.interpretation_description,'not provided'))
    LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst 
    ON 
      cst.code = map.cv_clinsig_type AND
      cst.statement_type = ca.statement_type
    WHERE
      cst.code IS NULL
  """, schema_name) INTO scv_classification_statement_combo_terms;

  -- Check for new review_status terms in clinical_assertion
  EXECUTE IMMEDIATE FORMAT("""
      SELECT ARRAY_AGG(DISTINCT IFNULL(ca.review_status,'null'))
      FROM `%s.clinical_assertion` ca
      LEFT JOIN `clinvar_ingest.clinvar_status` cs
      ON 
        cs.label = LOWER(ca.review_status)
      WHERE 
        cs.label IS NULL
  """, schema_name) INTO scv_review_status_terms;

  -- Construct a combined error message if there are issues
  SET combined_issues = '';

  IF scv_classification_terms IS NOT NULL AND ARRAY_LENGTH(scv_classification_terms) > 0 THEN
    SET combined_issues = FORMAT("""
      New SCV classification terms found: [%s].
      NOTE: Add scv_clinsig_map records to the '00-setup-translation-tables.sql' script and update, then rerun this script.
    """, ARRAY_TO_STRING(scv_classification_terms, ', '));
  END IF;

  IF scv_classification_statement_combo_terms IS NOT NULL AND ARRAY_LENGTH(scv_classification_statement_combo_terms) > 0 THEN
    SET combined_issues = FORMAT("""
      %s
      New SCV classification+statement_type combos found: [%s].
      NOTE: Add clinvar_clinsig_types records to the '00-setup-translation-tables.sql' script and update, then rerun this script.
    """, combined_issues, ARRAY_TO_STRING(scv_classification_statement_combo_terms, ', '));
  END IF; 

  IF scv_review_status_terms IS NOT NULL AND ARRAY_LENGTH(scv_review_status_terms) > 0 THEN
    SET combined_issues = FORMAT("""
      %s
      New SCV review status terms found: [%s].
      NOTE: Add clinvar_status records to the '00-setup-translation-tables.sql' script and update, then rerun this script.
    """, combined_issues, ARRAY_TO_STRING(scv_review_status_terms, ', '));
  END IF;

  -- Raise a single exception if there are any issues
  IF combined_issues != '' THEN
    RAISE USING message = combined_issues;
  END IF;

END;
