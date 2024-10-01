CREATE OR REPLACE PROCEDURE `clinvar_ingest.variation_track_proc`()
BEGIN
  DECLARE disable_out_of_date_alerts BOOLEAN DEFAULT FALSE;
  FOR rec IN
    (
      select 
        r.id, r.name, r.abbrev, lower(format("%s_%s", r.id, r.abbrev)) as tname, 
        ARRAY_AGG( STRUCT(ro.name, ro.value) ) as opts
      from `clinvar_ingest.report` r
      join `clinvar_ingest.report_submitter` rs 
      on 
        rs.report_id = r.id and rs.active
      left join `clinvar_ingest.report_option` ro
      on 
        ro.report_id = r.id
      group by 
        r.id, r.name, r.abbrev
    )
  DO
    SET disable_out_of_date_alerts = (SELECT CAST(IFNULL((SELECT opt.value FROM UNNEST(rec.opts) as opt WHERE opt.name = "DISABLE_OUT_OF_DATE_ALERTS"), "FALSE") AS BOOL));

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_variation` AS
      select  
        rv.report_id,
        cv.release_date as report_release_date,
        rv.variation_id, 
        vg.rpt_stmt_type, 
        vg.rank,
        FALSE as report_submitter_variation

      from `clinvar_ingest.report_variation` rv
      join `clinvar_ingest.voi_group` vg on vg.variation_id = rv.variation_id
      join `clinvar_ingest.clinvar_project_releases` cv on 
        cv.release_date between vg.start_release_date and vg.end_release_date
      where rv.report_id = "%s"
    """, rec.tname, rec.id);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_scv` AS
      select  
        rv.report_id,
        rv.report_release_date,
        rv.variation_id, 
        rv.rpt_stmt_type, 
        rv.rank,
        vsg.id,
        vsg.version,
        DATE_DIFF(rv.report_release_date, vs.last_evaluated, DAY) as last_eval_age,
        DATE_DIFF(rv.report_release_date, vs.start_release_date, DAY) as released_age,
        DATE_DIFF(rv.report_release_date, vs.submission_date, DAY) as submission_age,
        (rs.submitter_id is not NULL) as report_submitter_submission,
      from `variation_tracker.%s_variation` rv
      join `clinvar_ingest.voi_scv_group` vsg on 
        vsg.variation_id = rv.variation_id AND
        vsg.rpt_stmt_type = rv.rpt_stmt_type AND
        vsg.rank = rv.rank AND
        rv.report_release_date between vsg.start_release_date AND vsg.end_release_date
      join `clinvar_ingest.voi_scv` vs on 
        vs.variation_id = vsg.variation_id AND
        vs.id = vsg.id AND 
        vs.version = vsg.version AND
        vs.rpt_stmt_type = vsg.rpt_stmt_type AND
        vs.rank = vsg.rank AND
        rv.report_release_date between vs.start_release_date and vs.end_release_date
      left join `clinvar_ingest.report_submitter` rs on 
        rs.report_id = rv.report_id AND 
        vs.submitter_id = rs.submitter_id
    """, rec.tname, rec.tname);

  -- add convenience control attribute to represent variations that the report_submitter has submitted on at a given point in time
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `variation_tracker.%s_variation` v
      SET report_submitter_variation = TRUE
      WHERE EXISTS (
        SELECT scv.variation_id
        FROM `variation_tracker.%s_scv` scv
        WHERE scv.report_submitter_submission 
          AND scv.report_release_date = v.report_release_date
          AND v.variation_id = scv.variation_id
      )
    """, rec.tname, rec.tname);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_alerts` AS
      WITH x AS 
      (
        SELECT 
          v.symbol as gene_symbol,
          v.name,
          scv.variation_id,
          vv.id||'.'||vv.version as full_vcv_id,
          scv.rpt_stmt_type, 
          scv.rank, 
          scv.report_release_date,
          scv.id, scv.version, 
          vs.full_scv_id,
          revstat.label as review_status,
          vs.submitter_id, 
          vs.submission_date,
          scv.submission_age, 
          vs.last_evaluated,
          scv.last_eval_age,
          vs.start_release_date as released_date,
          scv.released_age,
          vs.clinsig_type,
          vs.classif_type,
          vs.classification_abbrev,
          vs.submitter_name,
          vs.submitter_abbrev,
          scv.report_submitter_submission
        FROM `variation_tracker.%s_scv`  scv
        JOIN `variation_tracker.%s_variation` var on 
          scv.variation_id = var.variation_id and
          scv.report_release_date = var.report_release_date and
          scv.rpt_stmt_type = var.rpt_stmt_type and
          scv.rank = var.rank
        JOIN `clinvar_ingest.clinvar_status` revstat on 
          revstat.rank = scv.rank and revstat.scv
        JOIN `clinvar_ingest.voi` v on
          v.variation_id = scv.variation_id AND
          scv.report_release_date between v.start_release_date and v.end_release_date
        left join `clinvar_ingest.voi_vcv` vv
        on
          scv.variation_id =vv.variation_id and
          scv.report_release_date between vv.start_release_date and vv.end_release_date
        JOIN `clinvar_ingest.voi_scv` vs on
          vs.variation_id = scv.variation_id AND
          vs.id = scv.id AND
          vs.version = scv.version AND
          scv.report_release_date between vs.start_release_date and vs.end_release_date
        where var.report_submitter_variation
      )
      SELECT 
        vcep.gene_symbol,
        vcep.name,
        vcep.variation_id, 
        vcep.full_vcv_id,
        vcep.report_release_date,
        vcep.rpt_stmt_type, 
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
        vcep.submission_date as submitted_submission_date,
        vcep.submission_age as submitted_submission_age,
        vcep.last_evaluated as submitted_last_evaluated,
        vcep.last_eval_age as submitted_last_eval_age,
        vcep.released_date as submitted_released_date,
        vcep.released_age as submitted_released_age,
        case
        when (vcep.clinsig_type = 2 AND other.clinsig_type <> 2) THEN
          "P/LP vs Newer VUS/B/LB"
        when (vcep.clinsig_type = 1 AND other.clinsig_type = 2) THEN
          "VUS vs Newer P/LP"
        when (vcep.clinsig_type = 1 AND other.clinsig_type = 0) THEN
          "VUS vs Newer B/LB"
        when (vcep.clinsig_type = 0 AND other.clinsig_type = 1) THEN
          "B/LB vs Newer VUS"
        when (vcep.clinsig_type = 0 AND other.clinsig_type = 2) THEN
          "B/LB vs Newer P/LP"
        end as alert_type,
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
        other.submission_date as other_submission_date,
        other.submission_age as other_submission_age,
        other.last_evaluated as other_last_evaluated,
        other.last_eval_age as other_last_eval_age,
        other.released_date as other_released_date,
        other.released_age as other_released_age,
        (vcep.submission_age - other.submission_age) as newer_submission_age,
        (vcep.last_eval_age - other.last_eval_age) as newer_last_eval_age,
        (vcep.released_age - other.released_age) as newer_released_age
      FROM x as vcep
      JOIN x as other on 
        other.variation_id = vcep.variation_id AND 
        other.rpt_stmt_type = vcep.rpt_stmt_type AND
        NOT other.report_submitter_submission AND
        other.report_release_date = vcep.report_release_date AND
        other.clinsig_type <> vcep.clinsig_type
      -- -- find all other submissions that have a last eval that is newer than 1 year prior to the EPs submission's last eval date 
      WHERE
        vcep.report_submitter_submission AND
        (vcep.last_eval_age - other.last_eval_age) >= 0
      UNION ALL
      SELECT 
        vcep.gene_symbol,
        vcep.name,
        vcep.variation_id, 
        vcep.full_vcv_id,
        vcep.report_release_date,
        vcep.rpt_stmt_type, 
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
        null as other_submission_date,
        null as other_submission_age,
        null as other_last_evaluated,
        null as other_last_eval_age,
        null as other_released_date,
        null as other_released_age,
        null as newer_submission_age,
        null as newer_last_eval_age,
        null as newer_released_age
      FROM x as vcep
      WHERE 
        NOT %t AND
        vcep.report_submitter_submission AND 
        vcep.last_eval_age >= 730 AND 
        vcep.classif_type NOT IN ('p','lb','b')
    """, rec.tname, rec.tname, rec.tname, disable_out_of_date_alerts);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_var_priorities` AS
      WITH x AS 
      (
        select 
          v.variation_id,
          v.rpt_stmt_type,
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
          max(vg.rank) as max_rank
        from `variation_tracker.%s_variation` v
        join `clinvar_ingest.voi_group` vg on 
          v.variation_id = vg.variation_id and
          v.rpt_stmt_type = vg.rpt_stmt_type and
          v.rank = vg.rank and
          v.report_release_date between vg.start_release_date and vg.end_release_date
        WHERE NOT v.report_submitter_variation 
          AND v.rpt_stmt_type = 'path' 
        GROUP BY
          v.variation_id,
          v.rpt_stmt_type,
          v.report_release_date
      )
      select 
        x.variation_id,
        x.rpt_stmt_type,
        x.report_release_date,
        x.agg_sig_type,
        x.no_sig_cnt, x.unc_sig_cnt, x.sig_cnt,
        x.max_rank,
        SPLIT(ARRAY_TO_STRING(ARRAY(
          select IF(x.agg_sig_type = 2 AND x.unc_sig_cnt > 2,'VUS priority',NULL) UNION ALL
          select IF(x.agg_sig_type IN ( 3, 7 ), 'VUS vs LBB', NULL) UNION ALL
          select IF(x.agg_sig_type > 4, 'PLP vs VUSLBB', NULL) UNION ALL
          select IF(x.max_rank = 0 and x.agg_sig_type >= 4, 'No criteria PLP', NULL)),','),',') as priority_type
      from x
      where (
        (x.agg_sig_type = 2 AND x.unc_sig_cnt > 2) OR
        (x.agg_sig_type IN ( 3, 7 )) OR
        (x.agg_sig_type > 4) OR
        (x.max_rank = 0 and x.agg_sig_type >= 4))
    """, rec.tname, rec.tname);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `variation_tracker.%s_scv_priorities` AS
      select  
        vp.report_release_date,
        vp.variation_id,
        vp.rpt_stmt_type,
        vp.max_rank,
        p_type,
        scv.rank as scv_rank,
        scv.id as scv_id,
        scv.version as scv_ver,
        sgrp.outlier_pct,
        sgrp.scv_group_type, 
        sgrp.scv_label,
        v.name,
        v.symbol as gene_symbol,
        v.mane_select,
        vv.id as vcv_id,
        vv.version as vcv_ver,
        vv.rank as vcv_rank,
        vv.agg_classification as vcv_classification,
        rel.next_release_date
      from `variation_tracker.%s_var_priorities` vp
      cross join unnest(vp.priority_type) as p_type
      join `variation_tracker.%s_scv` scv 
      on 
        vp.variation_id = scv.variation_id and 
        vp.report_release_date = scv.report_release_date 
      join `clinvar_ingest.voi_scv_group` sgrp 
      on
        scv.id = sgrp.id and
        scv.version = sgrp.version and
        scv.rpt_stmt_type = sgrp.rpt_stmt_type and
        scv.rank = sgrp.rank and
        scv.report_release_date between sgrp.start_release_date and sgrp.end_release_date
      join `clinvar_ingest.voi` v
      on
        vp.variation_id = v.variation_id and
        vp.report_release_date between v.start_release_date and v.end_release_date
      left join `clinvar_ingest.voi_vcv` vv
      on
        vp.variation_id =vv.variation_id and
        vp.report_release_date between vv.start_release_date and vv.end_release_date
      join 
      (
        select release_date,
          LEAD(release_date, 1, CURRENT_DATE()) OVER (ORDER BY release_date ASC) as next_release_date
        FROM `clinvar_ingest.clinvar_project_releases`
        WHERE NOT ENDS_WITH(release_type, 'placeholder')
      ) rel
      on
        vp.report_release_date = rel.release_date
    """, rec.tname, rec.tname, rec.tname);
    
  END FOR;

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