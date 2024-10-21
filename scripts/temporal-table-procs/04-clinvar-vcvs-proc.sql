CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_vcvs_proc`(start_with DATE)
BEGIN

  FOR rec IN (select s.schema_name, s.release_date, s.prev_release_date, s.next_release_date FROM clinvar_ingest.schemas_on_or_after(start_with) as s)
  DO

    -- deleted vcvs (where it exists in clinvar_vcvs (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cvcv.deleted_release_date is NULL AND
        NOT EXISTS (
          SELECT vcv.id
          FROM `%s.variation_archive` vcv
          left join `clinvar_ingest.clinvar_status` cvs1 
          on 
            cvs1.label = vcv.review_status
          WHERE  
            vcv.variation_id = cvcv.variation_id AND 
            vcv.id = cvcv.id AND 
            vcv.version = cvcv.version AND
            cvs1.rank = cvcv.rank AND
            IFNULL(vcv.interp_description,'') = IFNULL(cvcv.agg_classification,'') AND
            IFNULL(vcv.interp_date_last_evaluated, DATE'1900-01-01') = IFNULL(cvcv.last_evaluated, DATE'1900-01-01')
        )
    """, rec.release_date, rec.schema_name);

    -- updated variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_vcvs` cvcv
        SET 
          end_release_date = vcv.release_date,
          deleted_release_date = NULL
      FROM `%s.variation_archive` vcv
      left join `clinvar_ingest.clinvar_status` cvs1 
      on 
        cvs1.label = vcv.review_status
      WHERE 
        vcv.variation_id = cvcv.variation_id AND 
        vcv.id = cvcv.id AND 
        vcv.version = cvcv.version AND
        cvs1.rank = cvcv.rank AND
        IFNULL(vcv.interp_description,'') = IFNULL(cvcv.agg_classification,'') AND
        IFNULL(vcv.interp_date_last_evaluated, DATE'1900-01-01') = IFNULL(cvcv.last_evaluated, DATE'1900-01-01')
    """, rec.schema_name);

    -- new variations
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `clinvar_ingest.clinvar_vcvs` 
        (variation_id,  id, version, rank, last_evaluated, agg_classification, start_release_date, end_release_date)
      SELECT 
        vcv.variation_id, 
        vcv.id, 
        vcv.version, 
        cvs1.rank, 
        vcv.interp_date_last_evaluated as last_evaluated,
        vcv.interp_description as agg_classification,
        vcv.release_date as start_release_date, 
        vcv.release_date as end_release_date
      FROM `%s.variation_archive` vcv
      left join `clinvar_ingest.clinvar_status` cvs1 
      on 
        cvs1.label = vcv.review_status
      WHERE 
          NOT EXISTS (
          SELECT cvcv.id 
          FROM `clinvar_ingest.clinvar_vcvs` cvcv
          WHERE 
            vcv.variation_id = cvcv.variation_id AND 
            vcv.id = cvcv.id AND 
            vcv.version = cvcv.version AND
            cvs1.rank = cvcv.rank AND
            IFNULL(vcv.interp_description,'') = IFNULL(cvcv.agg_classification,'') AND
            IFNULL(vcv.interp_date_last_evaluated, DATE'1900-01-01') = IFNULL(cvcv.last_evaluated, DATE'1900-01-01')
        )
    """, rec.schema_name);

  END FOR;       

END;