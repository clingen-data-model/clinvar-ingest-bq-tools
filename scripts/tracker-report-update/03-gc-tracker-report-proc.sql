CREATE OR REPLACE PROCEDURE `variation_tracker.gc_tracker_report_rebuild`(schemaName STRING)
BEGIN

  DECLARE cur STRUCT<schema_name STRING, release_date DATE>;

  -- default to the latest schema if no schema_name argument is passed
  IF (schemaName IS NULL) THEN
    SET cur = (SELECT STRUCT(schema_name, release_date) FROM `clinvar_ingest.all_schemas`() ORDER BY release_date DESC LIMIT 1);
  ELSE
    SET cur = (SELECT STRUCT(schema_name, release_date) FROM `clinvar_ingest.all_schemas`() WHERE schema_name = schemaName);
  END IF;

  -- vceps for current release
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE vcep
    AS
    SELECT
      scv.variation_id,
      scv.submitter_id,
      FORMAT("%%s.%%i", scv.id, scv.version) as scv_acxn,
      rs.clinvar_name,
      scv.classif_type,
      scv.submitted_classification,
      scv.last_evaluated
    FROM `variation_tracker.report_submitter` rs
    JOIN `%s.scv_summary` scv
    ON
      scv.submitter_id = rs.submitter_id
    WHERE
      rs.type = "VCEP"
      AND
      rs.submitter_id IS NOT NULL
      -- NEW test for rank to exclude COGR tagged VCEPs
      AND
      scv.rank = 3
  """, cur.schema_name);

  -- gc case related lab info fo current release
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE lab_case
    AS
    SELECT
      gso.variation_id,
      gso.lab_id as submitter_id,
      gso.scv_obs_id,
      STRING_AGG(DISTINCT FORMAT("%%s.%%i", lab_scv.id, lab_scv.version)) as acxn,
      STRING_AGG(DISTINCT lab_scv.classif_type ORDER BY lab_scv.classif_type) as classif_type,
      STRING_AGG(DISTINCT lab_scv.submitted_classification ORDER BY lab_scv.submitted_classification) as classification,
      MIN(lab_scv.last_evaluated) as last_evaluated,
      MIN(lab_scv.date_created) as first_in_clinvar,
      COUNT(DISTINCT lab_scv.id) as scv_count
    FROM `%s.gc_scv_obs` gso
    LEFT JOIN `%s.scv_summary` lab_scv
    ON
      lab_scv.submitter_id = gso.lab_id
      and
      lab_scv.variation_id = gso.variation_id
    GROUP BY
      gso.lab_id,
      gso.variation_id,
      gso.scv_obs_id
  """, cur.schema_name, cur.schema_name);

  -- gc var report
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE var
    AS
    WITH v AS
    (
      SELECT
        gso.variation_id,
        COUNT(gso.id) as gc_scv_count,
        MIN(gso.vcv_first_in_clinvar) as first_in_clinvar
      FROM `%s.gc_scv_obs` gso
      GROUP BY
        gso.variation_id
    ),
    sgrp AS (
      SELECT
        sgrp.id,
        sgrp.variation_id,
        sgrp.scv_group_type,
        v.first_in_clinvar,
        v.gc_scv_count,
        REGEXP_EXTRACT(sgrp.scv_label, r'\\(([0-9A-Z\\-]+)\\, ') as class_type,
        split( sgrp.scv_label, "%%")[0]||"%%"  label,
        sgrp.rank,
        sgrp.scv_label
      FROM v
      JOIN `clinvar_ingest.clinvar_sum_scvs` sgrp
      ON
        sgrp.variation_id = v.variation_id
        AND
        %T between sgrp.start_release_date and sgrp.end_release_date
    ),
    sgrp_var_class_type AS (
      SELECT
        sgrp.variation_id,
        sgrp.scv_group_type,
        sgrp.class_type,
        cct.gks_code_order,
        FORMAT("%%s (%%i)", sgrp.class_type, COUNT(DISTINCT sgrp.id)) as label
      FROM sgrp
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cct
      ON
        LOWER(cct.code) = LOWER(sgrp.class_type)
      GROUP BY
        sgrp.variation_id,
        sgrp.scv_group_type,
        sgrp.class_type,
        cct.gks_code_order
    ),
    sgrp_var_class_type_count AS (
      SELECT
        svct.variation_id,
        STRING_AGG(
          svct.label,
          "\\n"
          ORDER BY
            svct.scv_group_type,
            svct.gks_code_order
        ) as class_type_count_label
      FROM sgrp_var_class_type svct
      GROUP BY
        svct.variation_id
    ),
    sgrp_var_scv_lists AS (
      SELECT
        sgrp.variation_id,
        sgrp.first_in_clinvar,
        sgrp.gc_scv_count,
        COUNT(
          distinct sgrp.id
        ) as scv_count,
        STRING_AGG(
          sgrp.label,
          "\\n"
          ORDER BY
            sgrp.rank desc,
            sgrp.scv_group_type,
            sgrp.label
        ) as all_scvs,
        STRING_AGG(
          IF(
            sgrp.scv_group_type = "2-VUS",
            sgrp.label,
            NULL
          ),
          "\\n"
          ORDER BY
            sgrp.rank desc,
            sgrp.scv_group_type,
            sgrp.label
        ) AS vus_scvs
      FROM sgrp
      GROUP BY
        sgrp.variation_id,
        sgrp.first_in_clinvar,
        sgrp.gc_scv_count
    )
    -- variation data related to single GC submitter's submissions
    SELECT
      sgrp_var.variation_id,
      sgrp_var.first_in_clinvar,
      sgrp_var.scv_count,
      sgrp_var.gc_scv_count,
      sgrp_var.all_scvs,
      sgrp_var.vus_scvs,
      svctc.class_type_count_label
    FROM sgrp_var_scv_lists sgrp_var
    LEFT JOIN sgrp_var_class_type_count svctc
    ON
      svctc.variation_id = sgrp_var.variation_id
  """, cur.schema_name, cur.release_date);

  -- gc variation report (1 of 2)  - first remove all gc_variation records for the release_date being processed
  EXECUTE IMMEDIATE FORMAT("""
    DELETE FROM `variation_tracker.gc_variation`
    WHERE report_date = %T
  """, cur.release_date);

  -- gc variation report (2 of 2)- now insert the newly processed records for the current release_date
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `variation_tracker.gc_variation`
    (
      report_date,
      submitter_id,
      variation_id,
      hgnc_id,
      gene_symbol,
      variant_name,
      vcvc_classification,
      vcvc_rank,
      clinvar_name,
      submitted_classification,
      classif_type,
      last_evaluated,
      scv_acxn,
      gc_scv_first_in_clinvar,
      local_key,
      gc_case_count,
      all_scvs,
      vus_scvs,
      class_type_count_label,
      variant_first_in_clinvar,
      novel_at_first_gc_submission,
      novel_as_of_report_run_date,
      only_other_gc_submitters
    )
    -- variant-centric output for single GC submitter
    SELECT DISTINCT
      %T as report_date,
      gso.submitter_id,
      gso.variation_id,
      gso.hgnc_id,
      gso.gene_symbol,
      gso.variant_name,
      gso.vcvc_classification,
      gso.vcvc_rank,
      vcep.clinvar_name,
      vcep.submitted_classification,
      vcep.classif_type,
      vcep.last_evaluated,
      gso.scv_acxn,
      gso.first_in_clinvar as gc_scv_first_in_clinvar,
      gso.local_key,
      gso.case_count as gc_case_count,
      var.all_scvs,
      var.vus_scvs,
      var.class_type_count_label,
      var.first_in_clinvar as variant_first_in_clinvar,
      IF((var.first_in_clinvar = gso.first_in_clinvar), "Yes", "No") as novel_at_first_gc_submission,
      IF((var.scv_count = 1), "Yes", "No") as novel_as_of_report_run_date,
      IF((var.scv_count > 1 AND var.scv_count = var.gc_scv_count), "Yes", "No") as only_other_gc_submitters
    FROM `%s.gc_scv_obs` gso
    LEFT JOIN vcep
    ON
      vcep.variation_id = gso.variation_id
    LEFT JOIN var
    ON
      var.variation_id = gso.variation_id
  """, cur.release_date, cur.schema_name);

  -- gc case report (1 of 2)  - first remove all gc_case records for the release_date being processed
  EXECUTE IMMEDIATE FORMAT("""
    DELETE FROM `variation_tracker.gc_case`
    WHERE report_date = %T
  """, cur.release_date);

  -- gc case report (2 of 2)- now insert the newly processed records for the current release_date
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `variation_tracker.gc_case`
    (
      report_date,
      scv_obs_id,
      submitter_id,
      variation_id,
      hgnc_id,
      gene_symbol,
      variant_name,
      ep_name,
      ep_classification,
      ep_classif_type,
      ep_last_evaluated_date,
      case_report_lab_name,
      case_report_lab_id,
      case_report_lab_classification,
      case_report_lab_classif_type,
      case_report_lab_date_reported,
      gc_scv_acxn,
      gc_scv_first_in_clinvar,
      gc_scv_local_key,
      case_report_sample_id,
      case_report_sample_variant_id,
      lab_scv_classification,
      lab_scv_classif_type,
      lab_scv_last_evaluated,
      lab_scv_first_in_clinvar,
      lab_scv_before_gc_scv,
      lab_scv_in_clinvar_as_of_release,
      ep_diff_alert,
      lab_diff_alert,
      classification_comment,
      obs_origin,
      vcvc_classification,
      vcvc_rank,
      case_count,
      clinical_features,
      co_occuring_variation_ids,
      patient_ids,
      all_scvs,
      vus_scvs,
      class_type_count_label
    )
    WITH gso_co_occuring AS
    (
      SELECT
        gso.scv_obs_id,
        ARRAY_TO_STRING(ARRAY_AGG(DISTINCT co.variation_id), ', ') as variation_ids
      FROM `%s.gc_scv_obs` gso
      CROSS JOIN UNNEST(gso.co_occuring) as co
      GROUP BY
        gso.scv_obs_id
    )
    SELECT
      %T as report_date,
      gso.scv_obs_id,
      gso.submitter_id,
      gso.variation_id,
      gso.hgnc_id,
      gso.gene_symbol,
      gso.variant_name,
      vcep.clinvar_name as ep_name,
      vcep.submitted_classification as ep_classification,
      vcep.classif_type as ep_classif_type,
      vcep.last_evaluated as ep_last_evaluated_date,
      gso.lab_name as case_report_lab_name,
      gso.lab_id as case_report_lab_id,
      gso.lab_classification as case_report_lab_classification,
      gso.lab_classif_type as case_report_lab_classif_type,
      gso.lab_date_reported as case_report_lab_date_reported,
      gso.scv_acxn as gc_scv_acxn,
      gso.first_in_clinvar as gc_scv_first_in_clinvar,
      gso.local_key as gc_scv_local_key,
      gso.sample_id as case_report_sample_id,
      gso.sample_variant_id as case_report_sample_variant_id,
      -- classification
      lab_case.classification as lab_scv_classification,
      -- classification type
      lab_case.classif_type as lab_scv_classif_type,
      -- last eval'd
      lab_case.last_evaluated as lab_scv_last_evaluated,
      -- do not show lab_scv_first_in_clinvar unless the lab_scv_count is 1
      IF(lab_case.scv_count=1,lab_case.first_in_clinvar, null) as lab_scv_first_in_clinvar,
      -- show error if more than 1 scv exists on variant for case report submitter
      CASE lab_case.scv_count
        WHEN 0 THEN
          null
        WHEN 1 THEN
          IF(gso.first_in_clinvar <= lab_case.first_in_clinvar, "No", "Yes")
        ELSE
          "Error: multiple lab scvs."
        END as lab_scv_before_gc_scv,
      -- is lab_case.scv_count = 1 then the lab scv is submitted at time of clinvar release, error if more than one scv from lab in release
      CASE lab_case.scv_count
        WHEN 0 THEN
          null
        WHEN 1 THEN
          "Yes"
        ELSE
            "Error: multiple lab scvs."
        END as lab_scv_in_clinvar_as_of_release,
      -- alert for VCEP diff, show null if no vcep scv or if VCEP classification exactly matches GC CASE report classification
      CASE
        WHEN vcep.classif_type IS NULL THEN
          null
        WHEN (IFNULL(gso.lab_classif_type,"n/a") <> vcep.classif_type) THEN
          FORMAT("%%s vs %%s (%%s)",
            UPPER(IFNULL(gso.lab_classif_type,"n/a")),
            UPPER(vcep.classif_type),
            IF(IFNULL(gso.lab_date_reported,vcep.last_evaluated) is NULL, "?",IF(gso.lab_date_reported > vcep.last_evaluated, "<",">"))
          )
        ELSE
          null
        END as ep_diff_alert,
      -- alert for LAB diff, show null if no vcep scv or if LAB classification exactly matches GC CASE report classification
      -- show error if more than 1 scv exists on variant for case report submitter
      CASE
        WHEN lab_case.scv_count=1 AND (IFNULL(gso.lab_classif_type,"n/a") <> lab_case.classif_type) THEN
          FORMAT("%%s vs %%s (%%s)",
            UPPER(IFNULL(gso.lab_classif_type,"n/a")),
            UPPER(lab_case.classif_type),
            IF(IFNULL(gso.lab_date_reported,vcep.last_evaluated) is NULL, "?",IF(gso.lab_date_reported > lab_case.last_evaluated, "<",">"))
          )
        WHEN lab_case.scv_count > 1 THEN
          -- error
          "Error: multiple lab scvs."
        ELSE
          -- lab_case count = 0 OR gc_cc and lab_case classifications match so do nothing
          null
        END as lab_diff_alert,
      gso.classification_comment,
      gso.obs_origin,
      gso.vcvc_classification,
      gso.vcvc_rank,
      gso.case_count,
      gso.clinical_features,
      gso_co.variation_ids as co_occuring_variation_ids,
      gso.patient_ids,
      var.all_scvs,
      var.vus_scvs,
      var.class_type_count_label
    FROM `%s.gc_scv_obs` gso
    LEFT JOIN vcep
    ON
      vcep.variation_id = gso.variation_id
    LEFT JOIN lab_case
    ON
      lab_case.scv_obs_id = gso.scv_obs_id
    LEFT JOIN gso_co_occuring gso_co
    ON
      gso_co.scv_obs_id = gso.scv_obs_id
    LEFT JOIN var
    ON
      var.variation_id = gso.variation_id
  """, cur.schema_name, cur.release_date, cur.schema_name);

    -- gc alerts? (TODO)

END;
