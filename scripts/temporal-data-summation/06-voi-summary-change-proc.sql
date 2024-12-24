-- calc voi summary
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_summary_change`()
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
      CREATE TEMP TABLE _SESSION.voi_summary 
      AS
      SELECT
        variation_id,
        start_release_date,
        end_release_date
      FROM
        `clinvar_ingest.voi_top_group_change` vtg
      GROUP BY
        variation_id,
        start_release_date,
        end_release_date
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_start_vs 
      AS
      SELECT 
        st.start_release_date, 
        st.variation_id,
        row_number () OVER (
          ORDER BY 
            st.variation_id, 
            st.start_release_date ASC NULLS FIRST
        ) as rownum
      FROM (
        SELECT 
          vs.start_release_date, 
          vs.variation_id
        FROM _SESSION.voi_summary vs
        UNION DISTINCT
        SELECT 
          MIN(r.release_date) as start_release_date,
          vs.variation_id
        FROM _SESSION.voi_summary vs
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date > vs.end_release_date
        GROUP BY
          vs.end_release_date, 
          vs.variation_id
      ) st
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_end_vs 
      AS
      SELECT 
        en.end_release_date, 
        en.variation_id, 
        row_number () OVER (
          ORDER BY 
            en.variation_id, 
            en.end_release_date ASC NULLS LAST
        ) as rownum
      FROM (
        SELECT 
          vs.end_release_date, 
          vs.variation_id
        FROM _SESSION.voi_summary vs    
        UNION DISTINCT
        SELECT 
          MAX(r.release_date) as end_release_date,
          vs.variation_id
        FROM _SESSION.voi_summary vs 
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date < vs.start_release_date
        GROUP BY 
          vs.start_release_date,
          vs.variation_id
      ) en
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_summary_change` 
      AS
      SELECT 
        e.variation_id, 
        s.start_release_date, 
        e.end_release_date
      FROM _SESSION.release_start_vs s
      JOIN _SESSION.release_end_vs e 
      ON 
        e.rownum = s.rownum + 1
      WHERE 
        e.variation_id = s.variation_id
    """);

  ELSE

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.voi_summary 
      AS
      SELECT
        variation_id,
        start_release_date,
        end_release_date
      FROM
        `clinvar_ingest.voi_top_group_change` vtg
      GROUP BY
        variation_id,
        start_release_date,
        end_release_date
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_start_vs 
      AS
      SELECT 
        st.start_release_date, 
        st.variation_id,
        row_number () OVER (
          ORDER BY 
            st.variation_id, 
            st.start_release_date ASC NULLS FIRST
        ) as rownum
      FROM (
        SELECT 
          vs.start_release_date, 
          vs.variation_id
        FROM _SESSION.voi_summary vs
        UNION DISTINCT
        SELECT 
          MIN(r.release_date) as start_release_date,
          vs.variation_id
        FROM _SESSION.voi_summary vs
        LEFT join `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date > vs.end_release_date
        GROUP BY
          vs.end_release_date, 
          vs.variation_id
      ) st
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE TEMP TABLE _SESSION.release_end_vs 
      AS
      SELECT 
        en.end_release_date, 
        en.variation_id, 
        row_number () OVER (
          ORDER BY 
            en.variation_id, 
            en.end_release_date ASC NULLS LAST
        ) as rownum
      FROM (
        SELECT 
          vs.end_release_date, 
          vs.variation_id
        FROM _SESSION.voi_summary vs    
        UNION DISTINCT
        SELECT 
          MAX(r.release_date) as end_release_date,
          vs.variation_id
        FROM _SESSION.voi_summary vs 
        LEFT JOIN `clinvar_ingest.clinvar_releases` r 
        ON 
          r.release_date < vs.start_release_date
        GROUP BY 
          vs.start_release_date,
          vs.variation_id
      ) en
    """);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clinvar_ingest.voi_summary_change` 
      AS
      SELECT 
        e.variation_id, 
        s.start_release_date, 
        e.end_release_date
      FROM _SESSION.release_start_vs s
      JOIN _SESSION.release_end_vs e 
      ON 
        e.rownum = s.rownum + 1
      WHERE 
        e.variation_id = s.variation_id
    """);

  END IF;

  DROP TABLE _SESSION.voi_summary;
  DROP TABLE _SESSION.release_start_vs;
  DROP TABLE _SESSION.release_end_vs;
  
END;