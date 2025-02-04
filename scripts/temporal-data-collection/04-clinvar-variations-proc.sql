
CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_variations`(
  schema_name STRING,
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_variations
  CALL `clinvar_ingest.validate_last_release`('clinvar_variations', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted variations (where it exists in clinvar_variations (for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_variations` cv
      SET 
        deleted_release_date = %T
    WHERE 
      cv.deleted_release_date is NULL
      AND 
      NOT EXISTS (
        SELECT 
          v.id 
        FROM `%s.variation` v
        WHERE  
          v.id = cv.id
      )
  """, release_date, schema_name);

  -- The clinvar_variations is designed to only have one record per variation_id, 
  -- and it will use the latest variation name or single_gene_variation record to update the gene_id and symbol
  -- in the event that any of those values change over the life of the variation_id record.

  -- updated variations
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_variations` cv
      SET 
        name = v.name, 
        mane_select = sgv.mane_select,
        gene_id = sgv.gene_id,
        symbol = g.symbol,
        end_release_date = v.release_date
    FROM `%s.variation` v
    LEFT JOIN `%s.single_gene_variation` sgv 
    ON 
      v.id = sgv.variation_id 
    LEFT JOIN `%s.gene`  g 
    ON 
      g.id = sgv.gene_id
    WHERE 
      v.id = cv.id
      AND
      cv.deleted_release_date is NULL
  """, schema_name, schema_name, schema_name);

  -- new variations
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_variations` (
      id, 
      name, 
      mane_select,
      gene_id,
      symbol,
      start_release_date, 
      end_release_date
    )
    SELECT 
      v.id, 
      v.name, 
      sgv.mane_select,
      sgv.gene_id,
      g.symbol,
      v.release_date as start_release_date, 
      v.release_date as end_release_date
    FROM `%s.variation` v
    LEFT JOIN `%s.single_gene_variation` sgv 
    ON 
      v.id = sgv.variation_id 
    LEFT JOIN `%s.gene`  g 
    ON 
      g.id = sgv.gene_id
    WHERE 
      NOT EXISTS (
        SELECT 
          cv.id 
        FROM `clinvar_ingest.clinvar_variations` cv
        WHERE 
          cv.id = v.id 
          AND
          cv.deleted_release_date is NULL
      )
  """, schema_name, schema_name, schema_name);

  SET result_message = "clinvar_variations processed successfully";

END;
