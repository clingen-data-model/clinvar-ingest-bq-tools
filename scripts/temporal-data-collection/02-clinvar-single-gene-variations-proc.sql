CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_single_gene_variations`(
  schema_name STRING, 
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN 
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_single_gene_variations
  CALL `clinvar_ingest.validate_last_release`('clinvar_single_gene_variations', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted single gene vars (where it exists in clinvar_single_gene_variations(for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_single_gene_variations` csgv
    SET 
      deleted_release_date = %T
    WHERE 
      csgv.deleted_release_date is NULL 
      AND
      NOT EXISTS 
      (
        SELECT 
          sgv.variation_id 
        FROM `%s.single_gene_variation` sgv
        WHERE 
          sgv.variation_id = csgv.variation_id 
      )
  """, release_date, schema_name);

  -- updated single gene variations
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_single_gene_variations` csgv
    SET 
      gene_id = sgv.gene_id,
      mane_select = sgv.mane_select,
      somatic = sgv.somatic,
      relationship_type = sgv.relationship_type,
      source = sgv.source,
      end_release_date = sgv.release_date
    FROM `%s.single_gene_variation` sgv
    WHERE 
      sgv.variation_id = csgv.variation_id 
      AND 
      csgv.deleted_release_date is NULL
  """, schema_name);

  -- new single gene variations
  EXECUTE IMMEDIATE FORMAT("""
    INSERT `clinvar_ingest.clinvar_single_gene_variations` (
      gene_id, 
      variation_id, 
      relationship_type, 
      source, 
      mane_select, 
      somatic, 
      start_release_date, 
      end_release_date
    )
    SELECT 
      sgv.gene_id,
      sgv.variation_id,
      sgv.relationship_type,
      sgv.source,
      sgv.mane_select,
      sgv.somatic,
      sgv.release_date as start_release_date, 
      sgv.release_date as end_release_date
    FROM `%s.single_gene_variation` sgv
    WHERE 
      NOT EXISTS 
      (
        SELECT 
          csgv.variation_id 
        FROM `clinvar_ingest.clinvar_single_gene_variations` csgv
        WHERE 
          sgv.variation_id = csgv.variation_id
          AND 
          csgv.deleted_release_date is NULL
      )
  """, schema_name);

  SET result_message = 'clinvar_single_gene_variations processed successfully';

END;