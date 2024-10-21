-- create or replace voi_top_group_change
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_top_group_change_proc`()
BEGIN

  BEGIN

    CREATE TEMP TABLE _SESSION.voi_top_group AS
    WITH
      x AS (
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
        rpt_stmt_type)
    SELECT
      x.start_release_date,
      x.end_release_date,
      x.variation_id,
      x.rpt_stmt_type,
      x.top_rank
    FROM x;

    CREATE TEMP TABLE _SESSION.release_start_tg AS
    select 
      st.start_release_date, 
      st.variation_id, 
      st.rpt_stmt_type,
      st.top_rank,
      row_number () over (order by st.variation_id, st.rpt_stmt_type, st.start_release_date asc nulls first) as rownum
    from (
      select 
        vtg.start_release_date, 
        vtg.variation_id, 
        vtg.rpt_stmt_type,
        vtg.top_rank
      from _SESSION.voi_top_group vtg
      UNION DISTINCT
      select 
        MIN(r.release_date) as start_release_date,
        vtg.variation_id,
        vtg.rpt_stmt_type,
        vtg.top_rank
      from _SESSION.voi_top_group vtg
      left join `clinvar_ingest.clinvar_releases` r 
      on 
        r.release_date > vtg.end_release_date
      group by
        vtg.end_release_date, 
        vtg.variation_id, 
        vtg.rpt_stmt_type, 
        vtg.top_rank
    ) st;

    CREATE TEMP TABLE _SESSION.release_end_tg AS
    select 
      en.end_release_date, 
      en.variation_id, 
      en.rpt_stmt_type,
      en.top_rank, 
      row_number () over (order by en.variation_id, en.rpt_stmt_type, en.end_release_date asc nulls last) as rownum
    from (
      select 
        vtg.end_release_date, 
        vtg.variation_id,
        vtg.rpt_stmt_type,
        vtg.top_rank
      from _SESSION.voi_top_group vtg    
      UNION DISTINCT
      select 
        MAX(r.release_date) as end_release_date,
        vtg.variation_id,
        vtg.rpt_stmt_type,
        vtg.top_rank
      from _SESSION.voi_top_group vtg
      left join `clinvar_ingest.clinvar_releases` r 
      on 
        r.release_date < vtg.start_release_date
      group by 
        vtg.start_release_date,
        vtg.variation_id, 
        vtg.rpt_stmt_type, 
        vtg.top_rank      
    ) en;

    CREATE OR REPLACE TABLE `clinvar_ingest.voi_top_group_change` AS
    select 
      e.variation_id, 
      e.rpt_stmt_type,
      e.top_rank,
      s.start_release_date, 
      e.end_release_date
    from _SESSION.release_start_tg s
    join _SESSION.release_end_tg e on e.rownum = s.rownum + 1
    where e.variation_id = s.variation_id;

    DROP TABLE _SESSION.voi_top_group;
    DROP TABLE _SESSION.release_start_tg;
    DROP TABLE _SESSION.release_end_tg;

  END;
  
END;