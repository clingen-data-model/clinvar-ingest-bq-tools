-- create or replace voi_group_change_recalc table
CREATE OR REPLACE PROCEDURE `clinvar_ingest.voi_group_change`()
BEGIN

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
  ) st;

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
  ) en;
  
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
    e.variation_id = s.variation_id;

  DROP TABLE _SESSION.release_start_vg;
  DROP TABLE _SESSION.release_end_vg;

END;
