-- calc voi summary
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_summary_change_v2`()
BEGIN

  CREATE TEMP TABLE _SESSION.voi_summary AS
    SELECT
      variation_id,
      start_release_date,
      end_release_date
    FROM
      `clinvar_ingest.voi_top_group_change` vtg
    GROUP BY
      variation_id,
      start_release_date,
      end_release_date;

  CREATE TEMP TABLE _SESSION.release_start_vs AS
  select 
    st.start_release_date, 
    st.variation_id,
    row_number () over (order by st.variation_id, st.start_release_date asc nulls first) as rownum
  from (
    select 
      vs.start_release_date, 
      vs.variation_id
    from _SESSION.voi_summary vs
    UNION DISTINCT
    select 
      MIN(r.release_date) as start_release_date,
      vs.variation_id
    from _SESSION.voi_summary vs
    left join `clinvar_ingest.clinvar_releases` r 
    on 
      r.release_date > vs.end_release_date
    group by
      vs.end_release_date, 
      vs.variation_id
  ) st;

  CREATE TEMP TABLE _SESSION.release_end_vs AS
  select 
    en.end_release_date, 
    en.variation_id, 
    row_number () over (order by en.variation_id, en.end_release_date asc nulls last) as rownum
  from (
    select 
      vs.end_release_date, 
      vs.variation_id
    from _SESSION.voi_summary vs    
    UNION DISTINCT
    select 
      MAX(r.release_date) as end_release_date,
      vs.variation_id
    from _SESSION.voi_summary vs 
    left join `clinvar_ingest.clinvar_releases` r 
    on 
      r.release_date < vs.start_release_date
    group by 
      vs.start_release_date,
      vs.variation_id
  ) en;


  CREATE OR REPLACE TABLE `clinvar_ingest.voi_summary_change` AS
  select 
    e.variation_id, 
    s.start_release_date, 
    e.end_release_date
  from _SESSION.release_start_vs s
  join _SESSION.release_end_vs e on e.rownum = s.rownum + 1
  where e.variation_id = s.variation_id;

  DROP TABLE _SESSION.voi_summary;
  DROP TABLE _SESSION.release_start_vs;
  DROP TABLE _SESSION.release_end_vs;
  
END;