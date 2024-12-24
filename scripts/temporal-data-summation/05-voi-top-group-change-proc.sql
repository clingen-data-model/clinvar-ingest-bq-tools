-- create or replace voi_top_group_change
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_top_group_change`()
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
      CREATE TEMP TABLE _SESSION.voi_top_group 
      AS
      WITH x AS (
        SELECT
          variation_id,
          rpt_stmt_type,
          start_release_date,
          end_release_date,
          MAX(rank) AS top_rank
        FROM
          `clinvar_ingest.voi_group` vg
        GROUP BY
          variation_id,
          start_release_date,
          end_release_date,
          rpt_stmt_type
      )
      SELECT
        x.start_release_date,
        x.end_release_date,
        x.variation_id,
        x.rpt_stmt_type,
        x.top_rank
      FROM x
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_start_tg 
      AS
      SELECT 
        st.start_release_date, 
        st.variation_id, 
        st.rpt_stmt_type,
        st.top_rank,
        row_number () OVER (
          ORDER BY 
            st.variation_id, 
            st.rpt_stmt_type, 
            st.start_release_date ASC NULLS FIRST
        ) as rownum
      FROM (
        SELECT 
          vtg.start_release_date, 
          vtg.variation_id, 
          vtg.rpt_stmt_type,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg
        UNION DISTINCT
        SELECT 
          MIN(r.release_date) as start_release_date,
          vtg.variation_id,
          vtg.rpt_stmt_type,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date > vtg.end_release_date
        GROUP BY
          vtg.end_release_date, 
          vtg.variation_id, 
          vtg.rpt_stmt_type, 
          vtg.top_rank
      ) st
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_end_tg AS
      select 
        en.end_release_date, 
        en.variation_id, 
        en.rpt_stmt_type,
        en.top_rank, 
        row_number () OVER (
          ORDER BY 
            en.variation_id, 
            en.rpt_stmt_type, 
            en.end_release_date ASC NULLS LAST
        ) as rownum
      FROM (
        SELECT 
          vtg.end_release_date, 
          vtg.variation_id,
          vtg.rpt_stmt_type,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg    
        UNION DISTINCT
        SELECT 
          MAX(r.release_date) as end_release_date,
          vtg.variation_id,
          vtg.rpt_stmt_type,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date < vtg.start_release_date
        GROUP BY 
          vtg.start_release_date,
          vtg.variation_id, 
          vtg.rpt_stmt_type, 
          vtg.top_rank      
      ) en
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_top_group_change` 
      AS
      SELECT 
        e.variation_id, 
        e.rpt_stmt_type,
        e.top_rank,
        s.start_release_date, 
        e.end_release_date
      FROM _SESSION.release_start_tg s
      JOIN _SESSION.release_end_tg e 
      ON 
        e.rownum = s.rownum + 1
      WHERE e.variation_id = s.variation_id
    """);

  ELSE

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.voi_top_group 
      AS
      WITH x AS (
        SELECT
          variation_id,
          statement_type,
          gks_proposition_type,
          clinical_impact_assertion_type,
          clinical_impact_clinical_significance,
          start_release_date,
          end_release_date,
          MAX(rank) AS top_rank
        FROM
          `clinvar_ingest.voi_group` vg
        GROUP BY
          variation_id,
          start_release_date,
          end_release_date,
          statement_type,
          gks_proposition_type,
          clinical_impact_assertion_type,
          clinical_impact_clinical_significance
      )
      SELECT
        x.start_release_date,
        x.end_release_date,
        x.variation_id,
        x.statement_type,
        x.gks_proposition_type,
        x.clinical_impact_assertion_type,
        x.clinical_impact_clinical_significance,
        x.top_rank
      FROM x
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_start_tg 
      AS
      SELECT
        st.start_release_date, 
        st.variation_id, 
        st.statement_type,
        st.gks_proposition_type,
        st.clinical_impact_assertion_type,
        st.clinical_impact_clinical_significance,
        st.top_rank,
        row_number () OVER (
          ORDER BY 
            st.variation_id, 
            st.statement_type,
            st.gks_proposition_type,
            st.clinical_impact_assertion_type,
            st.clinical_impact_clinical_significance,
            st.start_release_date asc nulls first
        ) as rownum
      FROM (
        SELECT
          vtg.start_release_date, 
          vtg.variation_id, 
          vtg.statement_type,
          vtg.gks_proposition_type,
          vtg.clinical_impact_assertion_type,
          vtg.clinical_impact_clinical_significance,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg
        UNION DISTINCT
        SELECT 
          MIN(r.release_date) as start_release_date,
          vtg.variation_id,
          vtg.statement_type,
          vtg.gks_proposition_type,
          vtg.clinical_impact_assertion_type,
          vtg.clinical_impact_clinical_significance,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date > vtg.end_release_date
        GROUP BY
          vtg.end_release_date, 
          vtg.variation_id, 
          vtg.statement_type,
          vtg.gks_proposition_type,
          vtg.clinical_impact_assertion_type,
          vtg.clinical_impact_clinical_significance,
          vtg.top_rank
      ) st
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_end_tg AS
      SELECT 
        en.end_release_date, 
        en.variation_id, 
        en.statement_type,
        en.gks_proposition_type,
        en.clinical_impact_assertion_type,
        en.clinical_impact_clinical_significance,
        en.top_rank, 
        row_number () over (
          ORDER BY 
            en.variation_id, 
            en.statement_type,
            en.gks_proposition_type,
            en.clinical_impact_assertion_type,
            en.clinical_impact_clinical_significance,
            en.end_release_date asc nulls last
        ) as rownum
      FROM (
        SELECT 
          vtg.end_release_date, 
          vtg.variation_id,
          vtg.statement_type,
          vtg.gks_proposition_type,
          vtg.clinical_impact_assertion_type,
          vtg.clinical_impact_clinical_significance,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg    
        UNION DISTINCT
        SELECT 
          MAX(r.release_date) as end_release_date,
          vtg.variation_id,
          vtg.statement_type,
          vtg.gks_proposition_type,
          vtg.clinical_impact_assertion_type,
          vtg.clinical_impact_clinical_significance,
          vtg.top_rank
        FROM _SESSION.voi_top_group vtg
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date < vtg.start_release_date
        GROUP BY
          vtg.start_release_date,
          vtg.variation_id, 
          vtg.statement_type,
          vtg.gks_proposition_type,
          vtg.clinical_impact_assertion_type,
          vtg.clinical_impact_clinical_significance,
          vtg.top_rank      
      ) en
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_top_group_change` 
      AS
      SELECT 
        e.variation_id, 
        e.statement_type,
        e.gks_proposition_type,
        e.clinical_impact_assertion_type,
        e.clinical_impact_clinical_significance,
        e.top_rank,
        s.start_release_date, 
        e.end_release_date
      FROM _SESSION.release_start_tg s
      JOIN _SESSION.release_end_tg e 
      ON 
        e.rownum = s.rownum + 1
      WHERE 
        e.variation_id = s.variation_id
    """);

  END IF;

  DROP TABLE _SESSION.voi_top_group;
  DROP TABLE _SESSION.release_start_tg;
  DROP TABLE _SESSION.release_end_tg;
  
END;