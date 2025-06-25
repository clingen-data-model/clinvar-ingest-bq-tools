CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_sum_vsp_rank_group`()
BEGIN

  -- create a grouping of scvs based on the var/rank/prop-type/stmt-type to produce the
  -- array of counts & percentages of the 3 major significance categories of scvs within that group
  -- (do not introduce clinical_impact_clinical_significance here)
  CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_sum_vsp_rank_group`
  AS
  WITH x AS
  (
    -- this gets us the count of scvs for a given rank and clinical significance
    -- within a statement_type and gks_proposition_type. It does this for
    -- each variation_id change for a given scv
    SELECT
      vs.variation_id,
      vsc.start_release_date,
      vsc.end_release_date,
      vs.statement_type,
      vs.gks_proposition_type,
      vs.rank,
      vs.clinsig_type,
      vs.classif_type,
      (vs.classif_type||'('||COUNT(DISTINCT vs.id)||')') AS classif_type_w_count
    FROM `clinvar_ingest.clinvar_scvs` vs
    JOIN `clinvar_ingest.clinvar_sum_variation_scv_change` vsc
    ON
        vs.variation_id = vsc.variation_id
        AND
        vs.start_release_date <= vsc.end_release_date
        AND
        vs.end_release_date >= vsc.start_release_date
    GROUP BY
      vs.variation_id,
      vsc.start_release_date,
      vsc.end_release_date,
      vs.statement_type,
      vs.gks_proposition_type,
      vs.rank,
      vs.classif_type,
      vs.clinsig_type
  )
  SELECT
    x.start_release_date,
    x.end_release_date,
    x.variation_id,
    x.statement_type,
    x.gks_proposition_type,
    x.rank,
    COUNT(DISTINCT vs.clinsig_type) as unique_clinsig_type_count,
    SUM(DISTINCT IF(vs.clinsig_type=2,4,IF(vs.clinsig_type=1,2,1))) as agg_sig_type,
    `clinvar_ingest.createSigType`(
      COUNT(DISTINCT IF(vs.clinsig_type = 0, vs.submitter_id, NULL)),
      COUNT(DISTINCT IF(vs.clinsig_type = 1, vs.submitter_id, NULL)),
      COUNT(DISTINCT IF(vs.clinsig_type = 2, vs.submitter_id, NULL))
    ) as sig_type,
    MAX(vs.last_evaluated) as max_last_evaluated,
    MAX(vs.submission_date) as max_submission_date,
    COUNT(DISTINCT vs.id) as submission_count,
    COUNT(DISTINCT vs.submitter_id) as submitter_count,
    STRING_AGG(DISTINCT x.classif_type, '/' ORDER BY x.classif_type) AS agg_classif,
    STRING_AGG(DISTINCT x.classif_type_w_count, '/' ORDER BY x.classif_type_w_count) AS agg_classif_w_count
  FROM x
  JOIN `clinvar_ingest.clinvar_scvs` vs
  ON
    vs.variation_id = x.variation_id
    AND
    vs.statement_type IS NOT DISTINCT FROM x.statement_type
    AND
    vs.gks_proposition_type IS NOT DISTINCT FROM x.gks_proposition_type
    AND
    vs.rank IS NOT DISTINCT FROM x.rank
    AND
    vs.start_release_date <= x.end_release_date
    AND
    vs.end_release_date >= x.start_release_date
  GROUP BY
    x.variation_id,
    x.start_release_date,
    x.end_release_date,
    x.statement_type,
    x.gks_proposition_type,
    x.rank
  ;

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
