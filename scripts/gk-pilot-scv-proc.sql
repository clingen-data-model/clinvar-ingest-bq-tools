--isolate the gkpilot scvs
CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_scv_proc`(start_with DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(start_with) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_scv`
      AS
        SELECT 
          ca.id,
          ca.version,
          ca.assertion_type,
          ca.clinical_assertion_trait_set_id,
          ca.date_created,
          ca.date_last_updated,
          ca.local_key,
          ca.interpretation_date_last_evaluated,
          ca.interpretation_description,
          ca.rcv_accession_id,
          ca.release_date,
          ca.submission_id,
          ca.submitted_assembly,
          ca.title,
          ca.trait_set_id,
          ca.variation_archive_id,
          ca.variation_id,
          ca.submitter_id,
          scv.review_status,
          scv.submitted_classification,
          scv.method_type,
          scv.origin,
          scv.classif_type,
          scv.classification_comment,
          STRUCT (
            FORMAT("clinvar.submitter:%%s",ca.submitter_id) as id,
            "Agent" as type,
            s.current_name as label
          ) as submitter,
          JSON_EXTRACT_SCALAR(ca.content, "$.ClinVarAccession['@DateCreated']") as record_date_created,
          JSON_EXTRACT_SCALAR(ca.content, "$.ClinVarAccession['@DateUpdated']") as record_date_updated,
          `clinvar_ingest.parseAttributeSet`(ca.content) as attribs,
          `clinvar_ingest.parseCitations`(JSON_EXTRACT(ca.content,"$.Interpretation")) as interpCitations
          
        from `%s.clinical_assertion` ca
        left join `%s.scv_summary` scv
        on
          scv.id = ca.id
        left join `%s.submitter` s
        on
          s.id = ca.submitter_id
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);
  END FOR;

END;
-- 4,159,595 (2024-04-07)
-- 4,435,155 (2024-08-05)



-- call clinvar_ingest.gk_pilot_scv_proc(CURRENT_DATE());


