CREATE OR REPLACE PROCEDURE `variation_tracker.gc_tracker_report_rebuild`()
BEGIN
  DECLARE release_date DATE;
  DECLARE
  SET release_date = (
    SELECT max(end_release_date)
    FROM `clinvar_ingest.voi_scv_group`
  );
  SET schema_name = (
    SELECT schema_name
    FROM `clinvar_ingest.schema_on`(release_date)
  );

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
  """, schema_name);

  -- gc scv info for current release
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE gc_scv
    AS
    SELECT
      scv.submitter_id,
      scv.variation_id,
      gscv.id,
      FORMAT("%%s.%%i", gscv.id, gscv.version) as scv_acxn,
      IF(scv.local_key IS NULL, NULL, SPLIT(scv.local_key, "|")[0]) as local_key,
      scv.local_key as local_key_orig,
      scv.date_created as first_in_clinvar,
      scv.classification_comment,
      COUNT(IFNULL(gscv.lab_id,gscv.lab_name)) as case_count
    FROM `%s.gc_scv` gscv
    JOIN `%s.scv_summary` scv
    ON
      scv.id = gscv.id
    WHERE 
      -- these are the dupe gc submissions that are older
      gscv.id NOT IN (
        "SCV000607136","SCV000986740",
        "SCV000986708","SCV000986786",
        "SCV000986705","SCV000986788",
        "SCV000986813","SCV000607109"
      )
    GROUP BY
      scv.submitter_id,
      scv.variation_id,
      gscv.id,
      gscv.version,
      scv.local_key,
      scv.date_created,
      scv.classification_comment
  """, schema_name, schema_name);

  -- gc scv w/ agg info for current release
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE gc 
    AS
    SELECT
      gc_scv.submitter_id,
      gc_scv.variation_id,
      g.hgnc_id,
      g.symbol,
      v.name,
      vcv.interp_description as agg_classification,
      cvs1.rank
      gc_scv.scv_acxn,
      gc_scv.local_key,
      gc_scv.case_count,
      gc_scv.first_in_clinvar,
      gc_scv.classification_comment
    FROM gc_scv
    JOIN `%s.variation` v
    ON
      v.id = gc_scv.variation_id
    LEFT JOIN `%s.single_gene_variation` sgv
    ON
      sgv.variation_id = gc_scv.variation_id
    LEFT JOIN `%s.gene` g
    ON
      sgv.gene_id = g.id 
    JOIN `%s.variation_archive` vcv
    ON
      vcv.variation_id = gc_scv.variation_id
    LEFT JOIN `clinvar_ingest.clinvar_status` cvs1 
    ON 
      cvs1.label = vcv.review_status
  """, schema_name, schema_name, schema_name, schema_name);

  -- gc case info for current release
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE gc_case
    AS
    SELECT
      gscv.variation_id,
      gc_scv.scv_acxn,
      gc_scv.local_key,
      gc_scv.local_key_orig,
      gscv.lab_name,
      gscv.lab_id,
      gscv.lab_classification,
      gscv.lab_classif_type,
      gscv.lab_date_reported,
      gscv.sample_id,
      IF(
        gscv.sample_id IS NULL, 
        gc_scv.local_key, 
        CONCAT(gc_scv.local_key, "|", gscv.sample_id)
      ) as case_report_key
    FROM gc_scv
    JOIN `%s.gc_scv` gscv
    ON 
      gc_scv.id = gscv.id
  """, schema_name);

  -- gc case related lab info fo current release
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE lab_case
    AS
    SELECT
      gc_case.variation_id,
      gc_case.lab_id as submitter_id,
      gc_case.case_report_key,
      STRING_AGG(DISTINCT FORMAT("%%s.%%i", lab_scv.id, lab_scv.version)) as acxn,
      STRING_AGG(DISTINCT lab_scv.classif_type ORDER BY lab_scv.classif_type) as classif_type,
      STRING_AGG(DISTINCT lab_scv.submitted_classification ORDER BY lab_scv.submitted_classification) as classification,
      MIN(lab_scv.last_evaluated) as last_evaluated,
      MIN(lab_scv.date_created) as first_in_clinvar,
      COUNT(DISTINCT lab_scv.id) as scv_count
    FROM gc_case
    LEFT JOIN `%s.scv_summary` lab_scv
    ON
      lab_scv.submitter_id = gc_case.lab_id and
      lab_scv.variation_id = gc_case.variation_id 
    GROUP BY
      gc_case.lab_id,
      gc_case.variation_id,
      gc_case.case_report_key
  """, schema_name);

  -- gc var report
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TEMP TABLE var
    AS
    WITH v AS 
    (
      SELECT 
        gc_scv.variation_id,
        COUNT(gc_scv.id) as gc_scv_count,
        MIN(vcv.date_created) as first_in_clinvar
      FROM gc_scv
      JOIN `%s.variation_archive` vcv
      ON
        vcv.variation_id = gc_scv.variation_id
      GROUP BY 
        gc_scv.variation_id
    )
    -- variation data related to single GC submitter's submissions
    SELECT
      v.variation_id,
      v.first_in_clinvar,
      COUNT(distinct sgrp.id) as scv_count,
      v.gc_scv_count,
      STRING_AGG(split( sgrp.scv_label, "%%")[0]||"%%", "\\n" ORDER BY sgrp.rank desc, sgrp.scv_group_type, sgrp.scv_label) as all_scvs
    FROM v
    JOIN `clinvar_ingest.voi_scv_group` sgrp
    ON
      sgrp.variation_id = v.variation_id 
      AND
      %T between sgrp.start_release_date and sgrp.end_release_date
    GROUP BY
      v.variation_id,
      v.first_in_clinvar,
      v.gc_scv_count
  """, schema_name, release_date);

  -- gc variation report (1 of 2)  - first remove all gc_variation records for the release_date being processed
  EXECUTE IMMEDIATE FORMAT("""
    DELETE FROM `variation_tracker.gc_variation` 
    WHERE report_date = %T
  """, release_date);

  -- gc variation report (2 of 2)- now insert the newly processed records for the current release_date
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `variation_tracker.gc_variation` 
    (
      report_date, 
      submitter_id, 
      variation_id, 
      hgnc_id, 
      symbol,
      name, 
      agg_classification, 
      rank, 
      clinvar_name, 
      submitted_classification,
      classif_type, 
      last_evaluated, 
      scv_acxn, 
      gc_scv_first_in_clinvar, 
      local_key,
      gc_case_count,
      all_scvs, 
      variant_first_in_clinvar, 
      novel_at_first_gc_submission,
      novel_as_of_report_run_date, 
      only_other_gc_submitters
    )
    -- variant-centric output for single GC submitter
    SELECT
      %T as report_date,
      gc.submitter_id,
      gc.variation_id,
      gc.hgnc_id,
      gc.symbol,
      gc.name,
      gc.agg_classification,
      gc.rank,
      vcep.clinvar_name,
      vcep.submitted_classification,
      vcep.classif_type,
      vcep.last_evaluated,
      gc.scv_acxn,
      gc.first_in_clinvar as gc_scv_first_in_clinvar,
      gc.local_key,
      gc.case_count as gc_case_count,
      var.all_scvs,
      var.first_in_clinvar as variant_first_in_clinvar,
      IF((var.first_in_clinvar = gc.first_in_clinvar), "Yes", "No") as novel_at_first_gc_submission,
      IF((var.scv_count = 1), "Yes", "No") as novel_as_of_report_run_date,
      IF((var.scv_count > 1 AND var.scv_count = var.gc_scv_count), "Yes", "No") as only_other_gc_submitters
    FROM gc
    LEFT JOIN vcep 
    ON 
      vcep.variation_id = gc.variation_id
    LEFT JOIN var
    ON
      var.variation_id = gc.variation_id
  """, release_date);

  -- gc case report (1 of 2)  - first remove all gc_case records for the release_date being processed
  EXECUTE IMMEDIATE FORMAT("""
    DELETE FROM `variation_tracker.gc_case` 
    WHERE report_date = %T
  """, release_date);

  -- gc case report (2 of 2)- now insert the newly processed records for the current release_date
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `variation_tracker.gc_case` 
    (
      report_date,
      submitter_id,
      variation_id,
      gene_id,
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
      lab_scv_classification,
      lab_scv_classif_type,
      lab_scv_last_evaluated,
      lab_scv_first_in_clinvar,
      lab_scv_before_gc_scv,
      lab_scv_in_clinvar_as_of_release,
      ep_diff_alert,
      lab_diff_alert,
      classification_comment
    )
    SELECT
      %T as report_date,
      gc.submitter_id,
      gc.variation_id,
      gc.hgnc_id as gene_id,
      gc.symbol as gene_symbol,
      gc.name as variant_name,
      vcep.clinvar_name as ep_name,
      vcep.submitted_classification as ep_classification,
      vcep.classif_type as ep_classif_type,
      vcep.last_evaluated as ep_last_evaluated_date,
      gc_case.lab_name as case_report_lab_name,
      gc_case.lab_id as case_report_lab_id,
      gc_case.lab_classification as case_report_lab_classification,
      gc_case.lab_classif_type as case_report_lab_classif_type,
      gc_case.lab_date_reported as case_report_lab_date_reported,
      gc.scv_acxn as gc_scv_acxn,
      gc.first_in_clinvar as gc_scv_first_in_clinvar,
      gc.local_key as gc_scv_local_key,
      gc_case.sample_id as case_report_sample_id,
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
          IF(gc.first_in_clinvar <= lab_case.first_in_clinvar, "No", "Yes") 
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
        WHEN (IFNULL(gc_case.lab_classif_type,"n/a") <> vcep.classif_type) THEN
          FORMAT("%%s vs %%s (%%s)", 
            UPPER(IFNULL(gc_case.lab_classif_type,"n/a")), 
            UPPER(vcep.classif_type), 
            IF(IFNULL(gc_case.lab_date_reported,vcep.last_evaluated) is NULL, "?",IF(gc_case.lab_date_reported > vcep.last_evaluated, "<",">"))
          )
        ELSE 
          null
        END as ep_diff_alert,
      -- alert for LAB diff, show null if no vcep scv or if LAB classification exactly matches GC CASE report classification
      -- show error if more than 1 scv exists on variant for case report submitter
      CASE 
        WHEN lab_case.scv_count=1 AND (IFNULL(gc_case.lab_classif_type,"n/a") <> lab_case.classif_type) THEN 
          FORMAT("%%s vs %%s (%%s)", 
            UPPER(IFNULL(gc_case.lab_classif_type,"n/a")), 
            UPPER(lab_case.classif_type), 
            IF(IFNULL(gc_case.lab_date_reported,vcep.last_evaluated) is NULL, "?",IF(gc_case.lab_date_reported > lab_case.last_evaluated, "<",">"))
          )
        WHEN lab_case.scv_count > 1 THEN
          -- error 
          "Error: multiple lab scvs."
        ELSE
          -- lab_case count = 0 OR gc_case and lab_case classifications match so do nothing
          null
        END as lab_diff_alert,
      gc.classification_comment
    FROM gc
    LEFT JOIN vcep 
    ON 
      vcep.variation_id = gc.variation_id
    LEFT JOIN gc_case
    ON
      gc.scv_acxn = gc_case.scv_acxn
    LEFT JOIN lab_case
    ON 
      lab_case.variation_id = gc_case.variation_id 
      AND
      lab_case.case_report_key = gc_case.case_report_key
  """, release_date);

--     -- gc alerts? (TODO)

END;
