CREATE OR REPLACE PROCEDURE `variation_tracker.tracker_reports_rebuild`(
  reportIds ARRAY<STRING>
)
BEGIN
  DECLARE disable_out_of_date_alerts BOOLEAN DEFAULT FALSE;

  -- process ALL active reports if the reportIds argument is null or an empty array
  IF (reportIds IS NULL OR ARRAY_LENGTH(reportIds) = 0) THEN
    SET reportIds = (SELECT ARRAY_AGG(r.id) FROM `variation_tracker.report` r WHERE r.active);
  END IF;

  -- =====================================================================================
  -- BATCH PHASE: Build shared temp tables once for ALL reports
  -- This avoids re-scanning large temporal tables 50+ times in the loop
  -- =====================================================================================

  -- Pre-materialize all_releases() once (eliminates 250+ INFORMATION_SCHEMA lookups from the loop)
  CREATE TEMP TABLE _all_releases AS
  SELECT * FROM `clinvar_ingest.all_releases`();

  -- Phase 1: Build compact SCV ranges using equi-joins + range overlap.
  -- NO date expansion here — produces one row per (report × variation × SCV × date range).
  -- This avoids the massive intermediate that BETWEEN joins on expanded dates create.
  CREATE TEMP TABLE _scv_ranges AS
  SELECT
    rv.report_id,
    rv.variation_id,
    vsg.statement_type,
    vsg.gks_proposition_type,
    vsg.rank,
    vsg.id,
    vsg.version,
    -- effective date range = intersection of vsg and vs ranges
    GREATEST(vsg.start_release_date, vs.start_release_date) as eff_start_release_date,
    LEAST(vsg.end_release_date, vs.end_release_date) as eff_end_release_date,
    -- SCV detail columns (widened to eliminate re-joins in alerts)
    vs.full_scv_id,
    vs.submitter_id,
    vs.submission_date,
    vs.last_evaluated,
    vs.start_release_date as released_date,
    vs.clinsig_type,
    vs.classif_type,
    vs.classification_abbrev,
    vs.classification_comment,
    vs.submitter_name,
    vs.submitter_abbrev,
    -- summary columns (widened to eliminate re-joins in scv_priorities)
    vsg.outlier_pct,
    vsg.scv_group_type,
    vsg.scv_label
  FROM `variation_tracker.report_variation` rv
  JOIN `clinvar_ingest.clinvar_sum_scvs` vsg
  ON
    vsg.variation_id = rv.variation_id
  JOIN `clinvar_ingest.clinvar_scvs` vs
  ON
    vs.variation_id = vsg.variation_id
    AND
    vs.id = vsg.id
    AND
    vs.version = vsg.version
    AND
    vs.statement_type IS NOT DISTINCT FROM vsg.statement_type
    AND
    vs.gks_proposition_type IS NOT DISTINCT FROM vsg.gks_proposition_type
    AND
    vs.rank IS NOT DISTINCT FROM vsg.rank
    -- range overlap condition (not point-in-time BETWEEN)
    AND
    vsg.start_release_date <= vs.end_release_date
    AND
    vsg.end_release_date >= vs.start_release_date
  WHERE
    rv.report_id IN UNNEST(reportIds)
    -- only keep valid range intersections
    AND
    GREATEST(vsg.start_release_date, vs.start_release_date) <= LEAST(vsg.end_release_date, vs.end_release_date);

  -- Pre-compute which (report_id, variation_id, release_date) combos have submitter SCVs.
  -- This is a small table: only submitter SCVs (a tiny subset) expanded to individual dates.
  CREATE TEMP TABLE _submitter_var_dates AS
  SELECT DISTINCT
    rsr.report_id,
    rsr.variation_id,
    rel.release_date
  FROM _scv_ranges rsr
  JOIN `variation_tracker.report_submitter` rs
  ON
    rs.report_id = rsr.report_id
    AND
    rsr.submitter_id = rs.submitter_id
  JOIN _all_releases rel
  ON
    rel.release_date BETWEEN rsr.eff_start_release_date AND rsr.eff_end_release_date;

  -- Build _all_variation by expanding _scv_ranges to individual dates and collapsing
  -- to variation level via GROUP BY. This correctly preserves gaps from deletions —
  -- only dates where at least one SCV actually exists are included.
  -- (The prior MIN/MAX approach bridged over deletion gaps, creating phantom rows.)
  CREATE TEMP TABLE _all_variation AS
  SELECT
    rsr.report_id,
    rel.release_date as report_release_date,
    rsr.variation_id,
    rsr.statement_type,
    rsr.gks_proposition_type,
    rsr.rank,
    LOGICAL_OR(svd.variation_id IS NOT NULL) as report_submitter_variation
  FROM _scv_ranges rsr
  JOIN _all_releases rel
  ON
    rel.release_date BETWEEN rsr.eff_start_release_date AND rsr.eff_end_release_date
  LEFT JOIN _submitter_var_dates svd
  ON
    svd.report_id = rsr.report_id
    AND
    svd.variation_id = rsr.variation_id
    AND
    svd.release_date = rel.release_date
  GROUP BY
    rsr.report_id,
    rel.release_date,
    rsr.variation_id,
    rsr.statement_type,
    rsr.gks_proposition_type,
    rsr.rank;

  -- Pre-compute variation-level temporal lookups for submitter variation dates only.
  -- This avoids repeating the same BETWEEN lookups against clinvar_variations and
  -- clinvar_vcvs for every SCV of a variation (10 SCVs = 10x redundant lookups).
  -- _submitter_var_dates is small, so these BETWEEN joins are cheap here.
  CREATE TEMP TABLE _var_date_lookups AS
  SELECT
    svd.report_id,
    svd.variation_id,
    svd.release_date,
    v.symbol as gene_symbol,
    v.name,
    vv.full_vcv_id
  FROM _submitter_var_dates svd
  JOIN `clinvar_ingest.clinvar_variations` v
  ON
    v.id = svd.variation_id
    AND
    svd.release_date BETWEEN v.start_release_date AND v.end_release_date
  LEFT JOIN `clinvar_ingest.clinvar_vcvs` vv
  ON
    svd.variation_id = vv.variation_id
    AND
    svd.release_date BETWEEN vv.start_release_date AND vv.end_release_date;

  -- Pre-compute (rank, release_date) → review_status lookup.
  -- Collapses status_rules × status_definitions into a tiny equi-joinable table,
  -- eliminating the cross-join multiplication from status_rules and the BETWEEN
  -- against status_definitions in _all_alerts_base.
  CREATE TEMP TABLE _rank_review_status AS
  SELECT DISTINCT
    def.rank,
    svd.release_date,
    def.review_status
  FROM (SELECT DISTINCT release_date FROM _submitter_var_dates) svd
  JOIN `clinvar_ingest.status_rules` rules
  ON
    rules.is_scv = TRUE
  JOIN `clinvar_ingest.status_definitions` def
  ON
    rules.review_status = def.review_status
    AND
    svd.release_date BETWEEN def.start_release_date AND def.end_release_date;

  -- Batch _all_alerts_base: the CTE "x" equivalent, computed once for ALL reports.
  -- Joins _scv_ranges to _submitter_var_dates for date expansion,
  -- then equi-joins for variation lookups and rank/review_status (no BETWEEN).
  CREATE TEMP TABLE _all_alerts_base AS
  SELECT
    rsr.report_id,
    vdl.gene_symbol,
    vdl.name,
    rsr.variation_id,
    vdl.full_vcv_id,
    rsr.statement_type,
    rsr.gks_proposition_type,
    rsr.rank,
    svd.release_date as report_release_date,
    rsr.id,
    rsr.version,
    rsr.full_scv_id,
    rrs.review_status as review_status,
    rsr.submitter_id,
    rsr.submission_date,
    DATE_DIFF(svd.release_date, rsr.submission_date, DAY) as submission_age,
    rsr.last_evaluated,
    DATE_DIFF(svd.release_date, rsr.last_evaluated, DAY) as last_eval_age,
    rsr.released_date,
    DATE_DIFF(svd.release_date, rsr.released_date, DAY) as released_age,
    rsr.clinsig_type,
    rsr.classif_type,
    rsr.classification_abbrev,
    rsr.classification_comment,
    rsr.submitter_name,
    rsr.submitter_abbrev,
    (rs.submitter_id IS NOT NULL) as report_submitter_submission,
    -- COALESCE join keys to enable hash joins in the _all_alerts self-join
    -- (IS NOT DISTINCT FROM prevents hash joins; equi-join on sentinels is equivalent)
    COALESCE(rsr.statement_type, '___NULL___') as _jk_statement_type,
    COALESCE(rsr.gks_proposition_type, '___NULL___') as _jk_gks_proposition_type
  FROM _scv_ranges rsr
  JOIN _submitter_var_dates svd
  ON
    svd.report_id = rsr.report_id
    AND
    svd.variation_id = rsr.variation_id
    AND
    svd.release_date BETWEEN rsr.eff_start_release_date AND rsr.eff_end_release_date
  JOIN _var_date_lookups vdl
  ON
    vdl.report_id = svd.report_id
    AND
    vdl.variation_id = svd.variation_id
    AND
    vdl.release_date = svd.release_date
  JOIN _rank_review_status rrs
  ON
    rrs.rank = rsr.rank
    AND
    rrs.release_date = svd.release_date
  LEFT JOIN `variation_tracker.report_submitter` rs
  ON
    rs.report_id = rsr.report_id
    AND
    rsr.submitter_id = rs.submitter_id;

  -- Batch _all_alerts: self-join + UNION ALL computed once for ALL reports
  -- Includes all "Out of Date" alerts; per-report filtering handles disable_out_of_date_alerts
  CREATE TEMP TABLE _all_alerts AS
  SELECT
    vcep.report_id,
    vcep.gene_symbol,
    vcep.name,
    vcep.variation_id,
    vcep.full_vcv_id,
    vcep.report_release_date,
    vcep.statement_type,
    vcep.gks_proposition_type,
    vcep.id as submitted_scv_id,
    vcep.version as submitted_scv_version,
    vcep.full_scv_id as submitted_full_scv_id,
    vcep.rank as submitted_rank,
    vcep.review_status as submitted_review_status,
    vcep.clinsig_type as submitted_clinsig_type,
    vcep.classif_type as submitted_classif_type,
    vcep.submitter_abbrev as submitted_submitter_abbrev,
    vcep.submitter_name as submitted_submitter_name,
    vcep.classification_abbrev as submitted_classif_abbrev,
    vcep.classification_comment as submitted_classif_comment,
    vcep.submission_date as submitted_submission_date,
    vcep.submission_age as submitted_submission_age,
    vcep.last_evaluated as submitted_last_evaluated,
    vcep.last_eval_age as submitted_last_eval_age,
    vcep.released_date as submitted_released_date,
    vcep.released_age as submitted_released_age,
    CASE
      WHEN (vcep.clinsig_type = 2 AND other.clinsig_type <> 2) THEN
        "P/LP vs Newer VUS/B/LB"
      WHEN (vcep.clinsig_type = 1 AND other.clinsig_type = 2) THEN
        "VUS vs Newer P/LP"
      WHEN (vcep.clinsig_type = 1 AND other.clinsig_type = 0) THEN
        "VUS vs Newer B/LB"
      WHEN (vcep.clinsig_type = 0 AND other.clinsig_type = 1) THEN
        "B/LB vs Newer VUS"
      WHEN (vcep.clinsig_type = 0 AND other.clinsig_type = 2) THEN
        "B/LB vs Newer P/LP"
      END as alert_type,
    other.id as other_scv_id,
    other.version  as other_scv_version,
    other.full_scv_id as other_full_scv_id,
    other.rank  as other_rank,
    other.review_status as other_review_status,
    other.clinsig_type  as other_clinsig_type,
    other.classif_type  as other_classif_type,
    other.submitter_abbrev  as other_submitter_abbrev,
    other.submitter_name  as other_submitter_name,
    other.classification_abbrev as other_classif_abbrev,
    other.classification_comment as other_classif_comment,
    other.submission_date as other_submission_date,
    other.submission_age as other_submission_age,
    other.last_evaluated as other_last_evaluated,
    other.last_eval_age as other_last_eval_age,
    other.released_date as other_released_date,
    other.released_age as other_released_age,
    (vcep.submission_age - other.submission_age) as newer_submission_age,
    (vcep.last_eval_age - other.last_eval_age) as newer_last_eval_age,
    (vcep.released_age - other.released_age) as newer_released_age
  FROM _all_alerts_base as vcep
  JOIN _all_alerts_base as other
  ON
    other.report_id = vcep.report_id
    AND
    other.variation_id = vcep.variation_id
    AND
    other._jk_statement_type = vcep._jk_statement_type
    AND
    other._jk_gks_proposition_type = vcep._jk_gks_proposition_type
    AND
    NOT other.report_submitter_submission
    AND
    other.report_release_date = vcep.report_release_date
    AND
    other.clinsig_type <> vcep.clinsig_type
  -- find all other submissions that have a last eval that is newer than 1 year prior to the EPs submission's last eval date
  WHERE
    vcep.report_submitter_submission
    AND
    (vcep.last_eval_age - other.last_eval_age) >= 0
  UNION ALL
  SELECT
    vcep.report_id,
    vcep.gene_symbol,
    vcep.name,
    vcep.variation_id,
    vcep.full_vcv_id,
    vcep.report_release_date,
    vcep.statement_type,
    vcep.gks_proposition_type,
    vcep.id as submitted_scv_id,
    vcep.version as submitted_scv_version,
    vcep.full_scv_id as submitted_full_scv_id,
    vcep.rank as submitted_rank,
    vcep.review_status as submitted_review_status,
    vcep.clinsig_type as submitted_clinsig_type,
    vcep.classif_type as submitted_classif_type,
    vcep.submitter_abbrev as submitted_submitter_abbrev,
    vcep.submitter_name as submitted_submitter_name,
    vcep.classification_abbrev as submitted_classif_abbrev,
    vcep.classification_comment as submitted_classif_comment,
    vcep.submission_date as submitted_submission_date,
    vcep.submission_age as submitted_submission_age,
    vcep.last_evaluated as submitted_last_evaluated,
    vcep.last_eval_age as submitted_last_eval_age,
    vcep.released_date as submitted_released_date,
    vcep.released_age as submitted_released_age,
    "Out of Date" as alert_type,
    null as other_scv_id,
    null as other_scv_version,
    null as other_full_scv_id,
    null as other_rank,
    null as other_review_status,
    null as other_clinsig_type,
    null as other_classif_type,
    null as other_submitter_abbrev,
    null as other_submitter_name,
    null as other_classif_abbrev,
    null as other_classif_comment,
    null as other_submission_date,
    null as other_submission_age,
    null as other_last_evaluated,
    null as other_last_eval_age,
    null as other_released_date,
    null as other_released_age,
    null as newer_submission_age,
    null as newer_last_eval_age,
    null as newer_released_age
  FROM _all_alerts_base as vcep
  WHERE
    vcep.report_submitter_submission
    AND
    vcep.last_eval_age >= 730
    AND
    vcep.classif_type NOT IN ('p','lb','b');

  -- Batch _all_var_priorities: one scan of clinvar_sum_vsp_rank_group for ALL reports
  CREATE TEMP TABLE _all_var_priorities AS
  WITH x AS
  (
    SELECT DISTINCT
      v.report_id,
      v.variation_id,
      v.statement_type,
      v.gks_proposition_type,
      v.report_release_date,
      sum(vg.sig_type[OFFSET(0)].count) as no_sig_cnt,
      sum(vg.sig_type[OFFSET(1)].count) as unc_sig_cnt,
      sum(vg.sig_type[OFFSET(2)].count) as sig_cnt,
      CASE
        WHEN (sum(vg.sig_type[OFFSET(0)].count)>0 AND sum(vg.sig_type[OFFSET(1)].count)>0 AND sum(vg.sig_type[OFFSET(2)].count)>0) THEN
          7
        WHEN (sum(vg.sig_type[OFFSET(0)].count)=0 AND sum(vg.sig_type[OFFSET(1)].count)>0 AND sum(vg.sig_type[OFFSET(2)].count)>0) THEN
          6
        WHEN (sum(vg.sig_type[OFFSET(0)].count)>0 AND sum(vg.sig_type[OFFSET(1)].count)=0 AND sum(vg.sig_type[OFFSET(2)].count)>0) THEN
          5
        WHEN (sum(vg.sig_type[OFFSET(0)].count)=0 AND sum(vg.sig_type[OFFSET(1)].count)=0 AND sum(vg.sig_type[OFFSET(2)].count)>0) THEN
          4
        WHEN (sum(vg.sig_type[OFFSET(0)].count)>0 AND sum(vg.sig_type[OFFSET(1)].count)>0 AND sum(vg.sig_type[OFFSET(2)].count)=0) THEN
          3
        WHEN (sum(vg.sig_type[OFFSET(0)].count)=0 AND sum(vg.sig_type[OFFSET(1)].count)>0 AND sum(vg.sig_type[OFFSET(2)].count)=0) THEN
          2
        WHEN (sum(vg.sig_type[OFFSET(0)].count)>0 AND sum(vg.sig_type[OFFSET(1)].count)=0 AND sum(vg.sig_type[OFFSET(2)].count)=0) THEN
          1
        ELSE
          0
        END as agg_sig_type,
      MAX(vg.rank) as max_rank
    FROM _all_variation v
    JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` vg
    ON
      v.variation_id = vg.variation_id
      AND
      v.statement_type = vg.statement_type
      AND
      v.gks_proposition_type = vg.gks_proposition_type
      AND
      v.rank = vg.rank
      AND
      v.report_release_date BETWEEN vg.start_release_date AND vg.end_release_date
    WHERE
      NOT v.report_submitter_variation
      AND
      v.statement_type = 'GermlineClassification'
      AND
      v.gks_proposition_type = 'path'
    GROUP BY
      v.report_id,
      v.variation_id,
      v.statement_type,
      v.gks_proposition_type,
      v.report_release_date
  )
  SELECT
    x.report_id,
    x.variation_id,
    x.statement_type,
    x.gks_proposition_type,
    x.report_release_date,
    x.agg_sig_type,
    x.no_sig_cnt, x.unc_sig_cnt, x.sig_cnt,
    x.max_rank,
    SPLIT(ARRAY_TO_STRING(ARRAY(
      select IF(x.agg_sig_type = 2 AND x.unc_sig_cnt > 2,'VUS priority',NULL) UNION ALL
      select IF(x.agg_sig_type IN ( 3, 7 ), 'VUS vs LBB', NULL) UNION ALL
      select IF(x.agg_sig_type > 4, 'PLP vs VUSLBB', NULL) UNION ALL
      select IF(x.max_rank = 0 and x.agg_sig_type >= 4 and x.sig_cnt > 1, 'No criteria PLP', NULL)),','),',') as priority_type
  FROM x
  WHERE (
    (x.agg_sig_type = 2 AND x.unc_sig_cnt > 2)
    OR
    (x.agg_sig_type IN ( 3, 7 ))
    OR
    (x.agg_sig_type > 4)
    OR
    (x.max_rank = 0 and x.agg_sig_type >= 4 and x.sig_cnt > 1));

  -- Batch _all_scv_priorities: uses _scv_ranges with point-in-time range check
  -- instead of joining the fully-expanded _all_scv table.
  CREATE TEMP TABLE _all_scv_priorities AS
  SELECT DISTINCT
    vp.report_id,
    vp.report_release_date,
    vp.variation_id,
    vp.statement_type,
    vp.gks_proposition_type,
    vp.max_rank,
    p_type,
    rsr.rank as scv_rank,
    rsr.id as scv_id,
    rsr.version as scv_ver,
    rsr.outlier_pct,
    rsr.scv_group_type,
    rsr.scv_label,
    v.name,
    v.symbol as gene_symbol,
    v.mane_select,
    vv.id as vcv_id,
    vv.version as vcv_ver,
    vvc.rank as vcv_rank,
    vvc.agg_classification_description as vcv_classification,
    IF(rel.next_release_date=DATE'9999-12-31', CURRENT_DATE(), rel.next_release_date) as next_release_date
  FROM _all_var_priorities vp
  CROSS JOIN UNNEST(vp.priority_type) as p_type
  JOIN _scv_ranges rsr
  ON
    vp.report_id = rsr.report_id
    AND
    vp.variation_id = rsr.variation_id
    AND
    vp.report_release_date BETWEEN rsr.eff_start_release_date AND rsr.eff_end_release_date
  JOIN `clinvar_ingest.clinvar_variations` v
  ON
    vp.variation_id = v.id
    AND
    vp.report_release_date BETWEEN v.start_release_date AND v.end_release_date
  LEFT JOIN `clinvar_ingest.clinvar_vcvs` vv
  ON
    vp.variation_id = vv.variation_id
    AND
    vp.report_release_date BETWEEN vv.start_release_date AND vv.end_release_date
  LEFT JOIN `clinvar_ingest.clinvar_vcv_classifications` vvc
  ON
    vp.variation_id = vvc.variation_id
    AND
    vp.report_release_date BETWEEN vvc.start_release_date AND vvc.end_release_date
  JOIN _all_releases rel
  ON
    vp.report_release_date = rel.release_date;

  -- =====================================================================================
  -- PER-REPORT PHASE: Filtered copies from batch temp tables to per-report output tables
  -- Each iteration is now a simple filter, no large table scans
  -- =====================================================================================

  FOR rec IN
    (
      SELECT
        r.id,
        r.name,
        r.abbrev,
        LOWER(FORMAT("%s_%s", r.id, r.abbrev)) as tname,
        ARRAY_AGG( STRUCT(ro.name, ro.value) ) as opts
      FROM `variation_tracker.report` r
      LEFT JOIN `variation_tracker.report_option` ro
      ON
        ro.report_id = r.id
      WHERE
        (r.id IN UNNEST(reportIds))
      GROUP BY
        r.id,
        r.name,
        r.abbrev
      ORDER BY
        r.id
    )
  DO

    SET disable_out_of_date_alerts = (
      SELECT
        CAST(
          IFNULL(
            (
              SELECT
                opt.value
              FROM UNNEST(rec.opts) as opt
              WHERE opt.name = "DISABLE_OUT_OF_DATE_ALERTS"
            ),
            "FALSE"
          ) AS BOOL
        )
    );

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_variation`
      AS
      SELECT
        report_id,
        report_release_date,
        variation_id,
        statement_type,
        gks_proposition_type,
        rank,
        report_submitter_variation
      FROM _all_variation
      WHERE report_id = "%s"
    """, rec.tname, rec.id);

    -- Per-report SCV table: expand _scv_ranges to individual dates for this report only.
    -- This is the only place date expansion happens, and it's small (one report at a time).
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_scv`
      AS
      SELECT
        rsr.report_id,
        rel.release_date as report_release_date,
        rsr.variation_id,
        rsr.statement_type,
        rsr.gks_proposition_type,
        rsr.rank,
        rsr.id,
        rsr.version,
        DATE_DIFF(rel.release_date, rsr.last_evaluated, DAY) as last_eval_age,
        DATE_DIFF(rel.release_date, rsr.released_date, DAY) as released_age,
        DATE_DIFF(rel.release_date, rsr.submission_date, DAY) as submission_age,
        (rs.submitter_id is not NULL) as report_submitter_submission
      FROM _scv_ranges rsr
      JOIN _all_releases rel
      ON
        rel.release_date BETWEEN rsr.eff_start_release_date AND rsr.eff_end_release_date
      LEFT JOIN `variation_tracker.report_submitter` rs
      ON
        rs.report_id = rsr.report_id
        AND
        rsr.submitter_id = rs.submitter_id
      WHERE
        rsr.report_id = "%s"
    """, rec.tname, rec.id);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_alerts`
      AS
      SELECT * EXCEPT(report_id)
      FROM _all_alerts
      WHERE
        report_id = "%s"
        AND
        (NOT %t OR alert_type <> 'Out of Date')
    """, rec.tname, rec.id, disable_out_of_date_alerts);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_var_priorities`
      AS
      SELECT * EXCEPT(report_id)
      FROM _all_var_priorities
      WHERE report_id = "%s"
    """, rec.tname, rec.id);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_scv_priorities`
      AS
      SELECT * EXCEPT(report_id)
      FROM _all_scv_priorities
      WHERE report_id = "%s"
    """, rec.tname, rec.id);

  END FOR;

  -- Cleanup temp tables
  DROP TABLE IF EXISTS _all_releases;
  DROP TABLE IF EXISTS _scv_ranges;
  DROP TABLE IF EXISTS _submitter_var_dates;
  DROP TABLE IF EXISTS _var_date_lookups;
  DROP TABLE IF EXISTS _rank_review_status;
  DROP TABLE IF EXISTS _all_variation;
  DROP TABLE IF EXISTS _all_alerts_base;
  DROP TABLE IF EXISTS _all_alerts;
  DROP TABLE IF EXISTS _all_var_priorities;
  DROP TABLE IF EXISTS _all_scv_priorities;

END;


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
