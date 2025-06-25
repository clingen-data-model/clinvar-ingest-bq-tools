-- create or replace clinvar_sum_variation_rank_prop_stmt_group_change table
CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_sum_vsp_rank_group_change`()
BEGIN

  CREATE TEMP TABLE _SESSION.release_start_vg
  AS
  SELECT
    st.start_release_date,
    st.variation_id,
    st.statement_type,
    st.gks_proposition_type,
    st.rank,
    row_number () OVER (
      ORDER BY
        st.variation_id,
        st.statement_type,
        st.gks_proposition_type,
        st.rank,
        st.start_release_date ASC NULLS FIRST
    ) as rownum
  FROM (
    SELECT
      vg.start_release_date,
      vg.variation_id,
      vg.statement_type,
      vg.gks_proposition_type,
      vg.rank
    FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
    UNION DISTINCT
    SELECT
      r.next_release_date as start_release_date,
      vg.variation_id,
      vg.statement_type,
      vg.gks_proposition_type,
      vg.rank
    FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
    LEFT JOIN `clinvar_ingest.all_releases`() r
    ON
      r.release_date = vg.end_release_date
  ) st;

  CREATE TEMP TABLE _SESSION.release_end_vg
  AS
  SELECT
    en.end_release_date,
    en.variation_id,
    en.statement_type,
    en.gks_proposition_type,
    en.rank,
    row_number () OVER (
      ORDER BY
        en.variation_id,
        en.statement_type,
        en.gks_proposition_type,
        en.rank,
        en.end_release_date ASC NULLS LAST
    ) as rownum
  FROM (
    SELECT
      vg.end_release_date,
      vg.variation_id,
      vg.statement_type,
      vg.gks_proposition_type,
      vg.rank
    FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
    UNION DISTINCT
    SELECT
      r.prev_release_date as end_release_date,
      vg.variation_id,
      vg.statement_type,
      vg.gks_proposition_type,
      vg.rank
    FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
    LEFT JOIN `clinvar_ingest.all_releases`() r
    ON
      r.release_date = vg.start_release_date
  ) en;

  CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_sum_vsp_rank_group_change`
  AS
  SELECT
    e.variation_id,
    e.statement_type,
    e.gks_proposition_type,
    e.rank,
    s.start_release_date,
    e.end_release_date
  FROM _SESSION.release_start_vg s
  JOIN _SESSION.release_end_vg e
  ON
    e.rownum = s.rownum + 1
  WHERE
    e.variation_id = s.variation_id
    and
    e.statement_type = s.statement_type
    and
    e.gks_proposition_type = s.gks_proposition_type
    and
    e.rank = s.rank
  ;

  DROP TABLE _SESSION.release_start_vg;
  DROP TABLE _SESSION.release_end_vg;

END;
