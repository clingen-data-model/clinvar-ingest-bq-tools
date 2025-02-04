BEGIN

  DECLARE prior_schema STRING DEFAULT 'clinvar_2024_05_02_v2_1_0';
  DECLARE target_schema STRING DEFAULT 'clinvar_2024_05_27_v1_6_62';
  DECLARE next_schema STRING DEFAULT 'clinvar_2024_06_03_v2_1_0';

  -- backup rcv_accession
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TABLE `%s.backup_rcv_accession_2`
    AS
    SELECT
      *
    FROM `%s.rcv_accession`
  """, target_schema, target_schema);
  
  -- clear out trait_set_id
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `%s.rcv_accession`
    SET trait_set_id = NULL
    WHERE TRUE
  """, target_schema);

  -- update the trait_set_id with the prior month's new xml rcv data 
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `%s.rcv_accession` rcv
    SET trait_set_id = source_rcv.trait_set_id
    FROM `%s.rcv_accession` source_rcv
    WHERE 
      rcv.id = source_rcv.id
      and
      rcv.trait_set_id is null
  """, target_schema, prior_schema);

  -- update the trait_set_id with the next month's new xml rcv data for any remaining nulls
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `%s.rcv_accession` rcv
    SET trait_set_id = source_rcv.trait_set_id
    FROM `%s.rcv_accession` source_rcv
    WHERE 
      rcv.id = source_rcv.id
      and
      rcv.trait_set_id is null
  """, target_schema, next_schema);

  --remaining nulls get repopulated from original DSP method
  EXECUTE IMMEDIATE FORMAT("""
    update `%s.rcv_accession` rcv
    set
      rcv.trait_set_id = bu_rcv.trait_set_id
    FROM `%s.backup_rcv_accession_2` bu_rcv
    WHERE 
      bu_rcv.id = rcv.id
      and
      rcv.trait_set_id is null
  """, target_schema, target_schema);

  -- VERIFY that NOTHING IS LEFT UNMAPPED!@@are there any null trait_set_ids left?
  EXECUTE IMMEDIATE FORMAT("""
    select
      rcv.id,
      rcv.variation_archive_id,
      rcv.trait_set_id,
      bu_rcv.trait_set_id
    from `%s.rcv_accession` rcv
    left join `%s.backup_rcv_accession_2` bu_rcv
    on
      bu_rcv.id = rcv.id
    where 
      rcv.trait_set_id is null
    order by 1
  """, target_schema, target_schema);


  -- CLINICAL_ASSERTION DATA PREP starts here

  -- backup clinical_assertion, 
  EXECUTE IMMEDIATE FORMAT("""
    create table `%s.backup_clinical_assertion_2`
    as
    select
      *
    from `%s.clinical_assertion`
  """, target_schema, target_schema);

  -- clear out rcv_accession_id and trait_set_id
  EXECUTE IMMEDIATE FORMAT("""
    update `%s.clinical_assertion`
    set
      rcv_accession_id = null,
      trait_set_id = null
    where
      true
  """, target_schema);

  -- ASSUMPTION: assume the source-scv tables have already been populated with the proper rcv_accession_id, 
  --             so we can just copy the data over

  -- update the rcv_accession_id with the prior month's rcv data
  EXECUTE IMMEDIATE FORMAT("""
    update `%s.clinical_assertion` scv
    set
      scv.rcv_accession_id = source_scv.rcv_accession_id
    from `%s.clinical_assertion` source_scv
    WHERE 
      scv.id = source_scv.id
      and
      scv.rcv_accession_id is null
  """, target_schema, prior_schema); 

  -- update the remaining rcv_accession_ids with the next month's rcv data based on scv id alone, verfiy rcvs are valid for this release
  EXECUTE IMMEDIATE FORMAT("""
    update `%s.clinical_assertion` scv
    set
      scv.rcv_accession_id = source_scv.rcv_accession_id
    from `%s.clinical_assertion` source_scv
    WHERE 
      scv.id = source_scv.id
      and
      scv.rcv_accession_id is null
  """, target_schema, next_schema);

  -- remaining nulls get repopulated from original DSP method
  EXECUTE IMMEDIATE FORMAT("""
    update `%s.clinical_assertion` scv
    set
      scv.rcv_accession_id = bu_scv.rcv_accession_id
    from `%s.backup_clinical_assertion_2` bu_scv
    WHERE 
      scv.id = bu_scv.id
      and
      scv.rcv_accession_id is null
  """, target_schema, target_schema);

  -- VERIFY that NOTHING IS LEFT UNMAPPED!@@are there any null rcv_accession_ids left?
  EXECUTE IMMEDIATE FORMAT("""
    select 
      scv.id,
      scv.rcv_accession_id,
      bu_scv.rcv_accession_id
    from `%s.clinical_assertion` scv
    left join `%s.backup_clinical_assertion_2` bu_scv
    on
      bu_scv.id = scv.id
    where
      scv.rcv_accession_id is null
    order by 1
  """, target_schema, target_schema);
    

END;