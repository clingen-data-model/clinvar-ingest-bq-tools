CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_scvs_proc`(start_with DATE)
BEGIN

  FOR rec IN (select s.schema_name, s.release_date, s.prev_release_date, s.next_release_date FROM clinvar_ingest.schemas_on_or_after(start_with) as s)
  DO

    -- deletes
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_scvs` cs
        SET deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cs.deleted_release_date is NULL AND 
        NOT EXISTS (
          SELECT scv.id 
          FROM `%s.scv_summary` scv
          WHERE 
            scv.variation_id = cs.variation_id AND
            scv.id = cs.id AND 
            scv.version = cs.version AND 
            scv.rank = cs.rank AND
            IF(scv.cvc_stmt_type NOT IN ('path','dr'), 'oth', scv.cvc_stmt_type) = cs.rpt_stmt_type AND
            IFNULL(scv.last_evaluated,DATE'1900-01-01') = IFNULL(cs.last_evaluated,DATE'1900-01-01') AND
            IFNULL(scv.significance,-999) = IFNULL(cs.clinsig_type,-999)
        )
    """, rec.release_date, rec.schema_name);

    -- updated scv id+ver
    -- NOTE: Further investigation of handling cvc_actions is needed for collating the scv id+ver updates, 
    --       Simply overwriting the changes to last and pending cvc_actions appears to produce invalid outcomes
    --       The problem could be back in the building of the data in the scv_summary_proc?!
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_scvs` cs
      SET 
        cs.variation_id = scv.variation_id,
        cs.local_key = scv.local_key,
        cs.classif_type = scv.classif_type,
        cs.submitted_classification = scv.submitted_classification,
        cs.submitter_id = scv.submitter_id,
        cs.submission_date = scv.submission_date,
        cs.origin = scv.origin,
        cs.affected_status = scv.affected_status,
        cs.method_type = scv.method_type,
        cs.end_release_date = scv.release_date,
        cs.deleted_release_date = NULL
      FROM `%s.scv_summary` scv
      WHERE 
        scv.variation_id = cs.variation_id AND
        scv.id = cs.id AND 
        scv.version=cs.version AND
        scv.rank=cs.rank AND
        IF(scv.cvc_stmt_type NOT IN ('path','dr'), 'oth', scv.cvc_stmt_type) = cs.rpt_stmt_type AND
        IFNULL(scv.last_evaluated,DATE'1900-01-01') = IFNULL(cs.last_evaluated,DATE'1900-01-01') AND
        IFNULL(scv.significance,-999) = IFNULL(cs.clinsig_type,-999)
    """, rec.schema_name);

    -- new scv variation+id+version
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_scvs` 
        (
          variation_id, id, version, rpt_stmt_type, 
          rank, last_evaluated, local_key, classif_type, clinsig_type, 
          submitted_classification, submitter_id, submission_date, origin, 
          affected_status, method_type, start_release_date, end_release_date
        )
      SELECT 
        scv.variation_id,
        scv.id, 
        scv.version, 
        IF(scv.cvc_stmt_type NOT IN ('path','dr'), 'oth', scv.cvc_stmt_type) as rpt_stmt_type,
        scv.rank, 
        scv.last_evaluated,
        scv.local_key,
        scv.classif_type,
        scv.significance as clinsig_type,
        scv.submitted_classification,
        scv.submitter_id,
        scv.submission_date,
        scv.origin,
        scv.affected_status,
        scv.method_type,
        scv.release_date as start_release_date,
        scv.release_date as end_release_date
      FROM `%s.scv_summary` scv
      WHERE 
        NOT EXISTS (
        SELECT cs.id FROM `clinvar_ingest.clinvar_scvs` cs
        WHERE 
          scv.variation_id = cs.variation_id and 
          scv.id = cs.id and 
          scv.version = cs.version AND
          scv.rank = cs.rank AND
          IF(scv.cvc_stmt_type NOT IN ('path','dr'), 'oth', scv.cvc_stmt_type) = cs.rpt_stmt_type AND
          IFNULL(scv.last_evaluated,DATE'1900-01-01') = IFNULL(cs.last_evaluated,DATE'1900-01-01') AND
          IFNULL(scv.significance,-999) = IFNULL(cs.clinsig_type,-999)
        )
    """, rec.schema_name);

  END FOR;

END;
