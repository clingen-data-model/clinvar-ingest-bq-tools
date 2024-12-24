CREATE OR REPLACE PROCEDURE `variation_tracker.tracker_reports_rebuild`()
BEGIN  
  DECLARE project_id STRING;
  DECLARE disable_out_of_date_alerts BOOLEAN DEFAULT FALSE;

  SET project_id = 
  (
    SELECT 
      catalog_name as paroject_id
    FROM `INFORMATION_SCHEMA.SCHEMATA`
    WHERE 
      schema_name = 'clinvar_ingest'
  );
  
  FOR rec IN
    (
      SELECT 
        r.id, 
        r.name, 
        r.abbrev, 
        LOWER(FORMAT("%s_%s", r.id, r.abbrev)) as tname, 
        ARRAY_AGG( STRUCT(ro.name, ro.value) ) as opts
      FROM `variation_tracker.report` r
      JOIN `variation_tracker.report_submitter` rs 
      ON 
        rs.report_id = r.id and rs.active
      LEFT JOIN `variation_tracker.report_option` ro
      ON 
        ro.report_id = r.id
      GROUP BY 
        r.id, 
        r.name, 
        r.abbrev
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

    IF (project_id = 'clingen-stage') THEN

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_variation` 
        AS
        SELECT  
          rv.report_id,
          cv.release_date as report_release_date,
          rv.variation_id, 
          vg.rpt_stmt_type, 
          vg.rank,
          FALSE as report_submitter_variation
        FROM `variation_tracker.report_variation` rv
        JOIN `clinvar_ingest.voi_group` vg 
        ON 
          vg.variation_id = rv.variation_id
        JOIN `clinvar_ingest.all_schemas`() cv 
        ON 
          cv.release_date BETWEEN vg.start_release_date AND vg.end_release_date
        WHERE 
          rv.report_id = "%s"
      """, rec.tname, rec.id);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_scv` 
        AS
        SELECT  
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
        FROM `variation_tracker.%s_variation` rv
        JOIN `clinvar_ingest.voi_scv_group` vsg 
        ON 
          vsg.variation_id = rv.variation_id 
          AND
          vsg.rpt_stmt_type = rv.rpt_stmt_type 
          AND
          vsg.rank = rv.rank 
          AND
          rv.report_release_date BETWEEN vsg.start_release_date AND vsg.end_release_date
        JOIN `clinvar_ingest.voi_scv` vs 
        ON 
          vs.variation_id = vsg.variation_id 
          AND
          vs.id = vsg.id 
          AND 
          vs.version = vsg.version 
          AND
          vs.rpt_stmt_type IS NOT DISTINCT FROM vsg.rpt_stmt_type 
          AND
          vs.rank IS NOT DISTINCT FROM vsg.rank 
          AND
          rv.report_release_date BETWEEN vs.start_release_date AND vs.end_release_date
        LEFT JOIN `variation_tracker.report_submitter` rs 
        ON 
          rs.report_id = rv.report_id 
          AND 
          vs.submitter_id = rs.submitter_id
      """, rec.tname, rec.tname);

    -- add convenience control attribute to represent variations that the report_submitter has submitted on at a given point in time
      EXECUTE IMMEDIATE FORMAT("""
        UPDATE `variation_tracker.%s_variation` v
        SET report_submitter_variation = TRUE
        WHERE EXISTS (
          SELECT scv.variation_id
          FROM `variation_tracker.%s_scv` scv
          WHERE 
            scv.report_submitter_submission 
            AND 
            scv.report_release_date = v.report_release_date
            AND 
            v.variation_id = scv.variation_id
        )
      """, rec.tname, rec.tname);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_alerts` 
        AS
        WITH x AS (
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
          JOIN `variation_tracker.%s_variation` var 
          ON 
            scv.variation_id = var.variation_id
            AND
            scv.report_release_date = var.report_release_date
            AND
            scv.rpt_stmt_type IS NOT DISTINCT FROM var.rpt_stmt_type
            AND
            scv.rank IS NOT DISTINCT FROM var.rank
          JOIN `clinvar_ingest.clinvar_status` revstat 
          ON 
            revstat.rank = scv.rank and revstat.scv
          JOIN `clinvar_ingest.voi` v 
          ON
            v.variation_id = scv.variation_id
            AND
            scv.report_release_date BETWEEN v.start_release_date AND v.end_release_date
          LEFT JOIN `clinvar_ingest.voi_vcv` vv
          ON
            scv.variation_id =vv.variation_id
            AND
            scv.report_release_date BETWEEN vv.start_release_date AND vv.end_release_date
          JOIN `clinvar_ingest.voi_scv` vs 
          ON
            vs.variation_id = scv.variation_id
            AND
            vs.id = scv.id
            AND
            vs.version = scv.version
            AND
            scv.report_release_date BETWEEN vs.start_release_date AND vs.end_release_date
          WHERE 
            var.report_submitter_variation
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
        JOIN x as other 
        ON
          other.variation_id = vcep.variation_id 
          AND 
          other.rpt_stmt_type = vcep.rpt_stmt_type 
          AND
          NOT other.report_submitter_submission 
          AND
          other.report_release_date = vcep.report_release_date 
          AND
          other.clinsig_type <> vcep.clinsig_type
        -- -- find all other submissions that have a last eval that is newer than 1 year prior to the EPs submission's last eval date 
        WHERE
          vcep.report_submitter_submission 
          AND
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
          NOT %t 
          AND
          vcep.report_submitter_submission 
          AND 
          vcep.last_eval_age >= 730 
          AND 
          vcep.classif_type NOT IN ('p','lb','b')
      """, rec.tname, rec.tname, rec.tname, disable_out_of_date_alerts);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_var_priorities` 
        AS
        WITH x AS 
        (
          SELECT 
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
            MAX(vg.rank) as max_rank
          FROM `variation_tracker.%s_variation` v
          JOIN `clinvar_ingest.voi_group` vg 
          ON 
            v.variation_id = vg.variation_id 
            AND
            v.rpt_stmt_type = vg.rpt_stmt_type 
            AND
            v.rank = vg.rank 
            AND
            v.report_release_date BETWEEN vg.start_release_date AND vg.end_release_date
          WHERE 
            NOT v.report_submitter_variation 
            AND 
            v.rpt_stmt_type = 'path' 
          GROUP BY
            v.variation_id,
            v.rpt_stmt_type,
            v.report_release_date
        )
        SELECT 
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
        FROM x
        WHERE (
          (x.agg_sig_type = 2 AND x.unc_sig_cnt > 2) 
          OR
          (x.agg_sig_type IN ( 3, 7 )) 
          OR
          (x.agg_sig_type > 4) 
          OR
          (x.max_rank = 0 and x.agg_sig_type >= 4))
      """, rec.tname, rec.tname);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_scv_priorities` 
        AS
        SELECT  
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
        FROM `variation_tracker.%s_var_priorities` vp
        CROSS JOIN UNNEST(vp.priority_type) as p_type
        JOIN `variation_tracker.%s_scv` scv 
        ON 
          vp.variation_id = scv.variation_id 
          AND 
          vp.report_release_date = scv.report_release_date 
        JOIN `clinvar_ingest.voi_scv_group` sgrp 
        ON
          scv.id = sgrp.id 
          AND
          scv.version = sgrp.version
          AND
          scv.rpt_stmt_type = sgrp.rpt_stmt_type
          AND
          scv.rank = sgrp.rank
          AND
          scv.report_release_date BETWEEN sgrp.start_release_date AND sgrp.end_release_date
        JOIN `clinvar_ingest.voi` v
        ON
          vp.variation_id = v.variation_id 
          AND
          vp.report_release_date BETWEEN v.start_release_date AND v.end_release_date
        LEFT JOIN `clinvar_ingest.voi_vcv` vv
        ON
          vp.variation_id =vv.variation_id 
          AND
          vp.report_release_date BETWEEN vv.start_release_date AND vv.end_release_date
        JOIN 
        (
          select 
            release_date,
            IF(next_release_date = DATE'9999-12-31', CURRENT_DATE(), next_release_date) next_release_date
          FROM `clinvar_ingest.schemas_on_or_after`(clinvar_ingest.cvc_project_start_date())
        ) rel
        ON  
          vp.report_release_date = rel.release_date
      """, rec.tname, rec.tname, rec.tname);

    ELSE

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_variation` 
        AS
        SELECT  
          rv.report_id,
          cv.release_date as report_release_date,
          rv.variation_id, 
          vg.statement_type,
          vg.gks_proposition_type,
          vg.clinical_impact_assertion_type,
          vg.clinical_impact_clinical_significance, 
          vg.rank,
          FALSE as report_submitter_variation
        FROM `variation_tracker.report_variation` rv
        JOIN `clinvar_ingest.voi_group` vg 
        ON 
          vg.variation_id = rv.variation_id
        JOIN `clinvar_ingest.all_schemas`() cv 
        ON 
          cv.release_date BETWEEN vg.start_release_date AND vg.end_release_date
        WHERE 
          rv.report_id = "%s"
      """, rec.tname, rec.id);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_scv` 
        AS
        SELECT  
          rv.report_id,
          rv.report_release_date,
          rv.variation_id, 
          rv.statement_type,
          rv.gks_proposition_type,
          rv.clinical_impact_assertion_type,
          rv.clinical_impact_clinical_significance,
          rv.rank,
          vsg.id,
          vsg.version,
          DATE_DIFF(rv.report_release_date, vs.last_evaluated, DAY) as last_eval_age,
          DATE_DIFF(rv.report_release_date, vs.start_release_date, DAY) as released_age,
          DATE_DIFF(rv.report_release_date, vs.submission_date, DAY) as submission_age,
          (rs.submitter_id is not NULL) as report_submitter_submission,
        FROM `variation_tracker.%s_variation` rv
        JOIN `clinvar_ingest.voi_scv_group` vsg 
        ON 
          vsg.variation_id = rv.variation_id 
          AND
          vsg.statement_type IS NOT DISTINCT FROM rv.statement_type
          AND
          vsg.gks_proposition_type IS NOT DISTINCT FROM rv.gks_proposition_type
          AND
          vsg.clinical_impact_assertion_type IS NOT DISTINCT FROM rv.clinical_impact_assertion_type
          AND
          vsg.clinical_impact_clinical_significance IS NOT DISTINCT FROM rv.clinical_impact_clinical_significance
          AND
          vsg.rank IS NOT DISTINCT FROM rv.rank 
          AND
          rv.report_release_date BETWEEN vsg.start_release_date AND vsg.end_release_date
        JOIN `clinvar_ingest.voi_scv` vs 
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
          vs.clinical_impact_assertion_type IS NOT DISTINCT FROM vsg.clinical_impact_assertion_type
          AND
          vs.clinical_impact_clinical_significance IS NOT DISTINCT FROM vsg.clinical_impact_clinical_significance
          AND
          vs.rank IS NOT DISTINCT FROM vsg.rank 
          AND
          rv.report_release_date BETWEEN vs.start_release_date AND vs.end_release_date
        LEFT JOIN `variation_tracker.report_submitter` rs 
        ON 
          rs.report_id = rv.report_id 
          AND 
          vs.submitter_id = rs.submitter_id
      """, rec.tname, rec.tname);

    -- add convenience control attribute to represent variations that the report_submitter has submitted on at a given point in time
      EXECUTE IMMEDIATE FORMAT("""
        UPDATE `variation_tracker.%s_variation` v
        SET report_submitter_variation = TRUE
        WHERE EXISTS (
          SELECT scv.variation_id
          FROM `variation_tracker.%s_scv` scv
          WHERE 
            scv.report_submitter_submission 
            AND 
            scv.report_release_date IS NOT DISTINCT FROM v.report_release_date
            AND 
            v.variation_id = scv.variation_id
        )
      """, rec.tname, rec.tname);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_alerts` 
        AS
        WITH x AS 
        (
          SELECT 
            v.symbol as gene_symbol,
            v.name,
            scv.variation_id,
            vv.id||'.'||vv.version as full_vcv_id,
            scv.statement_type,
            scv.gks_proposition_type,
            scv.clinical_impact_assertion_type,
            scv.clinical_impact_clinical_significance, 
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
          JOIN `variation_tracker.%s_variation` var 
          ON 
            scv.variation_id = var.variation_id
            AND
            scv.report_release_date IS NOT DISTINCT FROM var.report_release_date
            AND
            scv.statement_type IS NOT DISTINCT FROM var.statement_type
            AND
            scv.gks_proposition_type IS NOT DISTINCT FROM var.gks_proposition_type
            AND
            scv.clinical_impact_assertion_type IS NOT DISTINCT FROM var.clinical_impact_assertion_type
            AND
            scv.clinical_impact_clinical_significance IS NOT DISTINCT FROM var.clinical_impact_clinical_significance
            AND
            scv.rank IS NOT DISTINCT FROM var.rank
          JOIN `clinvar_ingest.clinvar_status` revstat 
          ON 
            revstat.rank = scv.rank and revstat.scv
          JOIN `clinvar_ingest.voi` v 
          ON
            v.variation_id = scv.variation_id
            AND
            scv.report_release_date BETWEEN v.start_release_date AND v.end_release_date
          LEFT JOIN `clinvar_ingest.voi_vcv` vv
          ON
            scv.variation_id = vv.variation_id
            AND
            scv.report_release_date BETWEEN vv.start_release_date AND vv.end_release_date
          JOIN `clinvar_ingest.voi_scv` vs 
          ON
            vs.variation_id = scv.variation_id
            AND
            vs.id = scv.id
            AND
            vs.version = scv.version
            AND
            scv.report_release_date BETWEEN vs.start_release_date AND vs.end_release_date
          WHERE 
            var.report_submitter_variation
        )
        SELECT 
          vcep.gene_symbol,
          vcep.name,
          vcep.variation_id, 
          vcep.full_vcv_id,
          vcep.report_release_date,
          vcep.statement_type,
          vcep.gks_proposition_type,
          vcep.clinical_impact_assertion_type,
          vcep.clinical_impact_clinical_significance, 
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
        JOIN x as other 
        ON
          other.variation_id = vcep.variation_id 
          AND 
          other.statement_type IS NOT DISTINCT FROM vcep.statement_type
          AND
          other.gks_proposition_type IS NOT DISTINCT FROM vcep.gks_proposition_type
          AND
          other.clinical_impact_assertion_type IS NOT DISTINCT FROM vcep.clinical_impact_assertion_type
          AND
          other.clinical_impact_clinical_significance IS NOT DISTINCT FROM vcep.clinical_impact_clinical_significance
          AND
          NOT other.report_submitter_submission 
          AND
          other.report_release_date IS NOT DISTINCT FROM vcep.report_release_date 
          AND
          other.clinsig_type IS DISTINCT FROM vcep.clinsig_type
        -- -- find all other submissions that have a last eval that is newer than 1 year prior to the EPs submission's last eval date 
        WHERE
          vcep.report_submitter_submission 
          AND
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
          NOT %t 
          AND
          vcep.report_submitter_submission 
          AND 
          vcep.last_eval_age >= 730 
          AND 
          vcep.classif_type NOT IN ('p','lb','b')
      """, rec.tname, rec.tname, rec.tname, disable_out_of_date_alerts);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_var_priorities` 
        AS
        WITH x AS 
        (
          SELECT 
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
            MAX(vg.rank) as max_rank
          FROM `variation_tracker.%s_variation` v
          JOIN `clinvar_ingest.voi_group` vg 
          ON 
            v.variation_id = vg.variation_id 
            AND
            v.rpt_stmt_type = vg.rpt_stmt_type 
            AND
            v.rank = vg.rank 
            AND
            v.report_release_date BETWEEN vg.start_release_date AND vg.end_release_date
          WHERE 
            NOT v.report_submitter_variation 
            AND 
            v.rpt_stmt_type = 'path' 
          GROUP BY
            v.variation_id,
            v.rpt_stmt_type,
            v.report_release_date
        )
        SELECT 
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
        FROM x
        WHERE (
          (x.agg_sig_type = 2 AND x.unc_sig_cnt > 2) 
          OR
          (x.agg_sig_type IN ( 3, 7 )) 
          OR
          (x.agg_sig_type > 4) 
          OR
          (x.max_rank = 0 and x.agg_sig_type >= 4))
      """, rec.tname, rec.tname);

      EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE `variation_tracker.%s_scv_priorities` 
        AS
        SELECT  
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
        FROM `variation_tracker.%s_var_priorities` vp
        CROSS JOIN UNNEST(vp.priority_type) as p_type
        JOIN `variation_tracker.%s_scv` scv 
        ON 
          vp.variation_id = scv.variation_id 
          AND 
          vp.report_release_date = scv.report_release_date 
        JOIN `clinvar_ingest.voi_scv_group` sgrp 
        ON
          scv.id = sgrp.id 
          AND
          scv.version = sgrp.version
          AND
          scv.rpt_stmt_type IS NOT DISTINCT FROM sgrp.rpt_stmt_type
          AND
          scv.rank IS NOT DISTINCT FROM sgrp.rank
          AND
          scv.report_release_date BETWEEN sgrp.start_release_date AND sgrp.end_release_date
        JOIN `clinvar_ingest.voi` v
        ON
          vp.variation_id = v.variation_id 
          AND
          vp.report_release_date BETWEEN v.start_release_date AND v.end_release_date
        LEFT JOIN `clinvar_ingest.voi_vcv` vv
        ON
          vp.variation_id =vv.variation_id 
          AND
          vp.report_release_date BETWEEN vv.start_release_date AND vv.end_release_date
        JOIN 
        (
          select 
            release_date,
            IF(next_release_date = DATE'9999-12-31', CURRENT_DATE(), next_release_date) next_release_date
          FROM `clinvar_ingest.schemas_on_or_after`(clinvar_ingest.cvc_project_start_date())
        ) rel
        ON  
          vp.report_release_date = rel.release_date
      """, rec.tname, rec.tname, rec.tname);    

    END IF;
    
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