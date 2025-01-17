-- create or replace voi_top_group_change
CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change`()
BEGIN

  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.vsp_top_rank_group
    AS
    WITH x AS (
      SELECT
        variation_id,
        statement_type,
        gks_proposition_type,
        start_release_date,
        end_release_date,
        MAX(rank) AS top_rank
      FROM
        `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
      GROUP BY
        variation_id,
        start_release_date,
        end_release_date,
        statement_type,
        gks_proposition_type
    )
    SELECT
      x.start_release_date,
      x.end_release_date,
      x.variation_id,
      x.statement_type,
      x.gks_proposition_type,
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
      st.top_rank,
      row_number () OVER (
        ORDER BY 
          st.variation_id, 
          st.statement_type,
          st.gks_proposition_type,
          st.start_release_date asc nulls first
      ) as rownum
    FROM (
      SELECT
        vtg.start_release_date, 
        vtg.variation_id, 
        vtg.statement_type,
        vtg.gks_proposition_type,
        vtg.top_rank
      FROM _SESSION.vsp_top_rank_group vtg
      UNION DISTINCT
      SELECT 
        r.next_release_date as start_release_date,
        vtg.variation_id,
        vtg.statement_type,
        vtg.gks_proposition_type,
        vtg.top_rank
      FROM _SESSION.vsp_top_rank_group vtg
      JOIN `clinvar_ingest.all_schemas`() r 
      ON 
        r.release_date = vtg.end_release_date
    ) st
  """);

  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.release_end_tg AS
    SELECT 
      en.end_release_date, 
      en.variation_id, 
      en.statement_type,
      en.gks_proposition_type,
      en.top_rank, 
      row_number () over (
        ORDER BY 
          en.variation_id, 
          en.statement_type,
          en.gks_proposition_type,
          en.end_release_date asc nulls last
      ) as rownum
    FROM (
      SELECT 
        vtg.end_release_date, 
        vtg.variation_id,
        vtg.statement_type,
        vtg.gks_proposition_type,
        vtg.top_rank
      FROM _SESSION.vsp_top_rank_group vtg    
      UNION DISTINCT
      SELECT 
        r.prev_release_date as end_release_date,
        vtg.variation_id,
        vtg.statement_type,
        vtg.gks_proposition_type,
        vtg.top_rank
      FROM _SESSION.vsp_top_rank_group vtg
      JOIN `clinvar_ingest.all_schemas`() r 
      ON 
        r.release_date = vtg.start_release_date
    ) en
  """);

  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` 
    AS
    SELECT 
      e.variation_id, 
      e.statement_type,
      e.gks_proposition_type,
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


  DROP TABLE _SESSION.vsp_top_rank_group;
  DROP TABLE _SESSION.release_start_tg;
  DROP TABLE _SESSION.release_end_tg;
  
END;