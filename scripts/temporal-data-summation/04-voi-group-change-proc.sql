-- create or replace voi_group_change_recalc table
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_group_change`()
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

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_start_vg 
      AS
      SELECT
        st.start_release_date, 
        st.variation_id, 
        st.rpt_stmt_type,
        st.rank,
        row_number () OVER (
          ORDER BY 
            st.variation_id, 
            st.rpt_stmt_type, 
            st.rank, 
            st.start_release_date ASC NULLS FIRST
        ) as rownum
      FROM (
        SELECT 
          vg.start_release_date, 
          vg.variation_id, 
          vg.rpt_stmt_type,
          vg.rank
        FROM `clinvar_ingest.voi_group` vg 
        UNION DISTINCT
        SELECT 
          MIN(r.release_date) as start_release_date,
          variation_id,
          rpt_stmt_type,
          rank
        FROM `clinvar_ingest.voi_group` vg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date > vg.end_release_date
        GROUP BY
          vg.end_release_date, 
          vg.variation_id, 
          vg.rpt_stmt_type, 
          vg.rank
      ) st
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_end_vg 
      AS
      SELECT 
        en.end_release_date, 
        en.variation_id, 
        en.rpt_stmt_type,
        en.rank, 
        row_number () OVER (
          ORDER BY 
            en.variation_id, 
            en.rpt_stmt_type, 
            en.rank, 
            en.end_release_date ASC NULLS LAST
        ) as rownum
      FROM (
        SELECT 
          end_release_date, 
          variation_id,
          rpt_stmt_type,
          rank
        FROM `clinvar_ingest.voi_group` vg    
        UNION DISTINCT
        SELECT 
          MAX(r.release_date) as end_release_date,
          variation_id,
          rpt_stmt_type,
          rank
        FROM `clinvar_ingest.voi_group` vg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date < vg.start_release_date
        GROUP BY 
          vg.start_release_date,
          vg.variation_id, 
          vg.rpt_stmt_type, 
          vg.rank
      ) en
    """);
    
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_group_change` 
      AS
      SELECT 
        e.variation_id, 
        e.rpt_stmt_type,
        e.rank,
        s.start_release_date, 
        e.end_release_date
      FROM _SESSION.release_start_vg s
      JOIN _SESSION.release_end_vg e 
      ON 
        e.rownum = s.rownum + 1
      WHERE 
        e.variation_id = s.variation_id
    """);
  
  ELSE

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_start_vg 
      AS
      SELECT 
        st.start_release_date, 
        st.variation_id, 
        st.statement_type,
        st.gks_proposition_type,
        st.clinical_impact_assertion_type,
        st.clinical_impact_clinical_significance,
        st.rank,
        row_number () OVER (
          ORDER BY 
            st.variation_id, 
            st.rpt_stmt_type, 
            st.rank, 
            st.start_release_date ASC NULLS FIRST
        ) as rownum
      FROM (
        SELECT 
          vg.start_release_date, 
          vg.variation_id,  
          vg.statement_type,
          vg.gks_proposition_type,
          vg.clinical_impact_assertion_type,
          vg.clinical_impact_clinical_significance,
          vg.rank
        FROM `clinvar_ingest.voi_group` vg 
        UNION DISTINCT
        SELECT 
          MIN(r.release_date) as start_release_date,
          variation_id,
          rpt_stmt_type,
          rank
        FROM `clinvar_ingest.voi_group` vg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date > vg.end_release_date
        GROUP BY
          vg.end_release_date, 
          vg.variation_id,   
          vg.statement_type,
          vg.gks_proposition_type,
          vg.clinical_impact_assertion_type,
          vg.clinical_impact_clinical_significance,
          vg.rank
      ) st
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_end_vg 
      AS
      SELECT 
        en.end_release_date, 
        en.variation_id,   
        en.statement_type,
        en.gks_proposition_type,
        en.clinical_impact_assertion_type,
        en.clinical_impact_clinical_significance,
        en.rank, 
        row_number () OVER (
          ORDER BY 
            en.variation_id,  
            en.statement_type,
            en.gks_proposition_type,
            en.clinical_impact_assertion_type,
            en.clinical_impact_clinical_significance,
            en.rank, 
            en.end_release_date ASC NULLS LAST
        ) as rownum
      FROM (
        SELECT 
          end_release_date, 
          variation_id, 
          statement_type,
          gks_proposition_type,
          clinical_impact_assertion_type,
          clinical_impact_clinical_significance,
          rank
        FROM `clinvar_ingest.voi_group` vg    
        UNION DISTINCT
        SELECT 
          MAX(r.release_date) as end_release_date,
          variation_id,
          statement_type,
          gks_proposition_type,
          clinical_impact_assertion_type,
          clinical_impact_clinical_significance,
          rank
        FROM `clinvar_ingest.voi_group` vg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date < vg.start_release_date
        GROUP BY
          vg.start_release_date,
          vg.variation_id, 
          vg.statement_type,
          vg.gks_proposition_type,
          vg.clinical_impact_assertion_type,
          vg.clinical_impact_clinical_significance,
          vg.rank
      ) en
    """);
    
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_group_change` 
      AS
      SELECT 
        e.variation_id, 
        e.statement_type,
        e.gks_proposition_type,
        e.clinical_impact_assertion_type,
        e.clinical_impact_clinical_significance,
        e.rank,
        s.start_release_date, 
        e.end_release_date
      FROM _SESSION.release_start_vg s
      JOIN _SESSION.release_end_vg e 
      ON 
        e.rownum = s.rownum + 1
      WHERE 
        e.variation_id = s.variation_id
    """);

  END IF;

  DROP TABLE _SESSION.release_start_vg;
  DROP TABLE _SESSION.release_end_vg;

END;
