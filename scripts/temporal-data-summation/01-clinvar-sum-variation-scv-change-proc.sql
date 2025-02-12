
-- this procedure creates a table that contains a record for each variation with a start-end range
-- that represents every time the scvs associated with the variation change in some way.
-- "change" is defined by the uniqueness of records in the clinvar_scvs temporal collection table.

-- scvs can change for obvious reasons (e.g. new submissions, updated submissions, deleted submissions),
-- but also for less obvious reasons (e.g. internal trait-set-id change or reassigned to a new rcv_accession_id...).
CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_sum_variation_scv_change`()
BEGIN

  CREATE TEMP TABLE _SESSION.release_start_vsc 
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
      start_release_date as start_release_date, 
      variation_id
    FROM `clinvar_ingest.clinvar_scvs` vs
    UNION DISTINCT
    SELECT 
      r.next_release_date as start_release_date,
      vs.variation_id
    FROM `clinvar_ingest.clinvar_scvs` vs
    JOIN `clinvar_ingest.all_releases`() r 
    ON 
      r.release_date = vs.end_release_date  
  ) st;

  CREATE TEMP TABLE _SESSION.release_end_vsc 
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
      end_release_date as end_release_date, 
      variation_id 
    FROM `clinvar_ingest.clinvar_scvs` vs
    UNION DISTINCT
    SELECT 
      r.prev_release_date as end_release_date,
      vs.variation_id
    FROM `clinvar_ingest.clinvar_scvs` vs
    JOIN `clinvar_ingest.all_releases`() r 
    ON 
      r.release_date = vs.start_release_date  
  ) en;
  
  CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_sum_variation_scv_change` 
  AS
  SELECT 
    e.variation_id, 
    s.start_release_date, 
    e.end_release_date
  FROM _SESSION.release_start_vsc s
  JOIN _SESSION.release_end_vsc e 
  ON 
    e.rownum = s.rownum+1
  WHERE 
    e.variation_id = s.variation_id
  ;

  DROP TABLE _SESSION.release_start_vsc;
  DROP TABLE _SESSION.release_end_vsc;

END;
