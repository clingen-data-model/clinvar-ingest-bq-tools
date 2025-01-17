CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_sum_scvs`()
BEGIN  

  -- clinvar_sum_scvs
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_sum_scvs`
    AS
    SELECT 
      vg.start_release_date,
      vg.end_release_date,
      vs.variation_id, 
      vs.id, 
      vs.version, 
      vs.statement_type,
      vs.gks_proposition_type,
      vg.rank, 
      vg.sig_type[OFFSET(vs.clinsig_type)].percent as outlier_pct,
      FORMAT("%%s (%%s) %%3.0f%%%% %%s", 
        IFNULL(vs.submitter_abbrev,LEFT(vs.submitter_name,15)), 
        vs.classification_abbrev, 
        vg.sig_type[OFFSET(vs.clinsig_type)].percent*100, 
        vs.full_scv_id) as scv_label,
      CASE vs.gks_proposition_type
      WHEN 'path' THEN
        CASE vs.clinsig_type
            WHEN 2 THEN '1-PLP'
            WHEN 1 THEN '2-VUS'
            WHEN 0 THEN '3-BLB'
            ELSE '5-???' END
      WHEN 'dr' THEN "4-ADDT'L"
      ELSE "4-ADDT'L" END as scv_group_type
    FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
    JOIN `clinvar_ingest.clinvar_scvs` vs 
    ON 
      vg.variation_id = vs.variation_id 
      AND 
      vg.statement_type IS NOT DISTINCT FROM vs.statement_type 
      AND
      vg.gks_proposition_type IS NOT DISTINCT FROM vs.gks_proposition_type 
      AND
      vg.rank IS NOT DISTINCT FROM vs.rank 
      AND 
      vg.start_release_date <= vs.end_release_date
      AND 
      vg.end_release_date >= vs.start_release_date
  """);

END;


-- find intersection between voi and voi_scv windows for the same variant to create the voi_group records
-- date window intersection is found by using the condition ((start_window1 <= end_window2) AND (end_window1 >= start_window2))
-- the start and end dates are always inclusive, meaning the start date is the date that the record is first available and
-- the end date is the date that the record is last available.
-- https://stackoverflow.com/questions/325933/determine-whether-two-date-ranges-overlap
-- (s1 <= eX) AND (e1 >= sX)

-- A        s1--------------e1
--  |----|----|----|----|----|----|----|
-- B           s2------e2                  s1 <= e2 AND e1 >= s2.   TRUE
-- C s3------------------------e3          s1 <= e3 AND e1 >= s3.   TRUE
-- D   s4------e4                          s1 <= e4 AND e1 >= s4.   TRUE
-- E               s5----------e5          s1 <= e5 AND e1 >= s5.   TRUE
-- F s6--e6                                s1 <= e6 AND e1 >= s6.   FALSE
-- G.                          s7--e7      s1 <= e7 AND e1 >= s7.   FALSE