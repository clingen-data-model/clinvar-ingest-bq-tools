CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_var_scv_change`()
BEGIN

  CREATE TEMP TABLE _SESSION.release_start_vsc AS
  select 
    st.start_release_date, 
    st.variation_id, 
    row_number () over (order by st.variation_id, st.start_release_date asc nulls first) as rownum
  from (
    select 
        start_release_date as start_release_date, 
        variation_id
      from `clinvar_ingest.clinvar_scvs` vs
      union distinct
      select 
        MIN(r.release_date) as start_release_date,
        vs.variation_id
      from `clinvar_ingest.clinvar_scvs` vs
      join `clinvar_ingest.clinvar_releases` r 
      on 
        r.release_date > vs.end_release_date
      group by 
        vs.end_release_date, 
        vs.variation_id
  ) st;

  CREATE TEMP TABLE _SESSION.release_end_vsc AS
  select 
    en.end_release_date, 
    en.variation_id, 
    row_number () over (order by en.variation_id, en.end_release_date asc nulls last) as rownum
  from (
      select 
        end_release_date as end_release_date, 
        variation_id 
      from `clinvar_ingest.clinvar_scvs` vs
      union distinct
      select 
        MAX(r.release_date) as end_release_date,
        vs.variation_id
      from `clinvar_ingest.clinvar_scvs` vs
      join `clinvar_ingest.clinvar_releases` r 
      on 
        r.release_date < vs.start_release_date
      group by 
        vs.start_release_date, 
        vs.variation_id
  ) en;
  
  CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_var_scv_change` AS
  select 
    e.variation_id, 
    s.start_release_date, 
    e.end_release_date
  from _SESSION.release_start_vsc s
  join _SESSION.release_end_vsc e on e.rownum = s.rownum+1
  where e.variation_id = s.variation_id
  ;

  DROP TABLE _SESSION.release_start_vsc;
  DROP TABLE _SESSION.release_end_vsc;

END;
