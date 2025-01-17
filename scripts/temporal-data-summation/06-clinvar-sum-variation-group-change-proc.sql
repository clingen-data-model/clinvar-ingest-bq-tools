-- calc voi summary
CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_sum_variation_group_change`()
BEGIN
 
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.variation_group 
    AS
    SELECT
      variation_id,
      start_release_date,
      end_release_date
    FROM
      `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` vtg
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
      FROM _SESSION.variation_group vs
      UNION DISTINCT
      SELECT 
        r.next_release_date as start_release_date,
        vs.variation_id
      FROM _SESSION.variation_group vs
      LEFT join `clinvar_ingest.all_schemas`() r 
      ON 
        r.release_date = vs.end_release_date
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
      FROM _SESSION.variation_group vs    
      UNION DISTINCT
      SELECT 
        r.prev_release_date as end_release_date,
        vs.variation_id
      FROM _SESSION.variation_group vs 
      LEFT JOIN `clinvar_ingest.all_schemas`() r 
      ON 
        r.release_date = vs.start_release_date
    ) en
  """);

  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_sum_variation_group_change` 
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

  DROP TABLE _SESSION.variation_group;
  DROP TABLE _SESSION.release_start_vs;
  DROP TABLE _SESSION.release_end_vs;
  
END;