-- create or replace voi_group_change_recalc table
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_group_change_proc`()
BEGIN

  BEGIN

    CREATE TEMP TABLE _SESSION.release_start_vg AS
    select 
      st.start_release_date, 
      st.variation_id, 
      st.rpt_stmt_type,
      st.rank,
      row_number () over (order by st.variation_id, st.rpt_stmt_type, st.rank, st.start_release_date asc nulls first) as rownum
    from (
      select 
        vg.start_release_date, 
        vg.variation_id, 
        vg.rpt_stmt_type,
        vg.rank
      from `clinvar_ingest.voi_group` vg 
      UNION DISTINCT
      select 
        MIN(r.release_date) as start_release_date,
        variation_id,
        rpt_stmt_type,
        rank
      from `clinvar_ingest.voi_group` vg
      left join `clinvar_ingest.clinvar_releases` r 
      on 
        r.release_date > vg.end_release_date
      group by
        vg.end_release_date, 
        vg.variation_id, 
        vg.rpt_stmt_type, 
        vg.rank
    ) st;

    CREATE TEMP TABLE _SESSION.release_end_vg AS
    select 
      en.end_release_date, 
      en.variation_id, 
      en.rpt_stmt_type,
      en.rank, 
      row_number () over (order by en.variation_id, en.rpt_stmt_type, en.rank, en.end_release_date asc nulls last) as rownum
    from (
      select 
        end_release_date, 
        variation_id,
        rpt_stmt_type,
        rank
      from `clinvar_ingest.voi_group` vg    
      UNION DISTINCT
      select 
        MAX(r.release_date) as end_release_date,
        variation_id,
        rpt_stmt_type,
        rank
      from `clinvar_ingest.voi_group` vg
      left join `clinvar_ingest.clinvar_releases` r 
      on 
        r.release_date < vg.start_release_date
      group by 
        vg.start_release_date,
        vg.variation_id, 
        vg.rpt_stmt_type, 
        vg.rank
    ) en;
    
    CREATE OR REPLACE TABLE `clinvar_ingest.voi_group_change` AS
    select 
      e.variation_id, 
      e.rpt_stmt_type,
      e.rank,
      s.start_release_date, 
      e.end_release_date
    from _SESSION.release_start_vg s
    join _SESSION.release_end_vg e on e.rownum = s.rownum + 1
    where e.variation_id = s.variation_id;

    DROP TABLE _SESSION.release_start_vg;
    DROP TABLE _SESSION.release_end_vg;

  END;

END;
