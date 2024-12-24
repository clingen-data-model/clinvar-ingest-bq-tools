CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_vcv_scv`()
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

  CREATE OR REPLACE TABLE `clinvar_ingest.voi`
  AS
  SELECT 
    cv.id AS variation_id,
    cv.name,
    csgv.mane_select,
    csgv.gene_id,
    cg.symbol,
    cv.start_release_date,
    cv.end_release_date,
    cv.deleted_release_date,
    cv.deleted_count
  FROM `clinvar_ingest.clinvar_variations` cv 
  LEFT JOIN `clinvar_ingest.clinvar_single_gene_variations` csgv 
  ON 
    cv.id = csgv.variation_id 
  LEFT JOIN `clinvar_ingest.clinvar_genes`  cg 
  ON 
    cg.id = csgv.gene_id
  ;

  IF (project_id = 'clingen-stage') THEN

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_vcv`
      AS
      SELECT 
        cv.variation_id,
        cv.id,
        cv.version,
        FORMAT('%%s.%%i', cv.id, cv.version) as full_vcv_id,
        cv.rank,
        cv.last_evaluated,
        cv.agg_classification,
        cv.start_release_date,
        cv.end_release_date,
        cv.deleted_release_date,
        cv.deleted_count
      FROM `clinvar_ingest.clinvar_vcvs` cv
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_scv`
      AS
      SELECT 
        cs.variation_id,
        cs.id,
        cs.version,
        FORMAT('%%s.%%i', cs.id, cs.version) as full_scv_id,
        cs.rpt_stmt_type,
        cs.rank,
        cs.last_evaluated,
        cs.classif_type,
        cs.submitted_classification,
        cs.clinsig_type,
        FORMAT( '%%s, %%s, %%t', 
            cct.label, 
            if(cs.rank > 0,format("%%i%%s", cs.rank, CHR(9733)), IF(cs.rank = 0, format("%%i%%s", cs.rank, CHR(9734)), "n/a")), 
            if(cs.last_evaluated is null, "<n/a>", format("%%t", cs.last_evaluated))) as classification_label,
        FORMAT( '%%s, %%s, %%t', 
            UPPER(cs.classif_type), 
            if(cs.rank > 0,format("%%i%%s", cs.rank, CHR(9733)), IF(cs.rank = 0, format("%%i%%s", cs.rank, CHR(9734)), "n/a")), 
            if(cs.last_evaluated is null, "<n/a>", format("%%t", cs.last_evaluated))) as classification_abbrev,
        cs.submitter_id,
        s.current_name as submitter_name,
        s.cvc_abbrev as submitter_abbrev,
        cs.submission_date,
        cs.origin,
        cs.affected_status,
        cs.method_type,
        cs.start_release_date,
        cs.end_release_date,
        cs.deleted_release_date,
        cs.deleted_count
      FROM `clinvar_ingest.clinvar_scvs` cs 
      LEFT JOIN `clinvar_ingest.clinvar_submitters` s 
      ON 
        cs.submitter_id = s.id
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cct 
      ON 
        cct.code = cs.classif_type
    """);

  ELSE

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_vcv`
      AS
      SELECT 
        cv.variation_id,
        cv.id,
        cv.version,
        FORMAT('%%s.%%i', cv.id, cv.version) as full_vcv_id,
        cv.start_release_date,
        cv.end_release_date,
        cv.deleted_release_date,
        cv.deleted_count
      FROM `clinvar_ingest.clinvar_vcvs` cv
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_vcv_classification`
      AS
      SELECT 
        cvc.vcv_id,
        cvc.statement_type,
        cvc.rank,
        cvc.last_evaluated,
        cvc.agg_classification_description,
        cvc.clinical_impact_assertion_type,
        cvc.clinical_impact_clinical_significance,
        cvc.start_release_date,
        cvc.end_release_date,
        cvc.deleted_release_date,
        cvc.deleted_count
      FROM `clinvar_ingest.clinvar_vcv_classifications` cvc
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_scv`
      AS
      SELECT 
        cs.variation_id,
        cs.id,
        cs.version,
        FORMAT('%%s.%%i', cs.id, cs.version) as full_scv_id,
        cs.statement_type,
        cs.gks_proposition_type,
        cs.clinical_impact_assertion_type,
        cs.clinical_impact_clinical_significance,
        cs.rank,
        cs.last_evaluated,
        cs.classif_type,
        cs.submitted_classification,
        cs.clinsig_type,
        FORMAT( '%%s, %%s, %%t', 
            cct.label, 
            if(cs.rank > 0,format("%%i%%s", cs.rank, CHR(9733)), IF(cs.rank = 0, format("%%i%%s", cs.rank, CHR(9734)), "n/a")), 
            if(cs.last_evaluated is null, "<n/a>", format("%%t", cs.last_evaluated))) as classification_label,
        FORMAT( '%%s, %%s, %%t', 
            UPPER(cs.classif_type), 
            if(cs.rank > 0,format("%%i%%s", cs.rank, CHR(9733)), IF(cs.rank = 0, format("%%i%%s", cs.rank, CHR(9734)), "n/a")), 
            if(cs.last_evaluated is null, "<n/a>", format("%%t", cs.last_evaluated))) as classification_abbrev,
        cs.submitter_id,
        s.current_name as submitter_name,
        s.cvc_abbrev as submitter_abbrev,
        cs.submission_date,
        cs.origin,
        cs.affected_status,
        cs.method_type,
        cs.start_release_date,
        cs.end_release_date,
        cs.deleted_release_date,
        cs.deleted_count
      FROM `clinvar_ingest.clinvar_scvs` cs 
      LEFT JOIN `clinvar_ingest.clinvar_submitters` s 
      ON 
        cs.submitter_id = s.id
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cct 
      ON 
        cct.code = cs.classif_type
    """);

  END IF;

END;