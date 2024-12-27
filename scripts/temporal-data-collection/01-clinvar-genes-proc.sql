CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_genes`(
  schema_name STRING, 
  release_date DATE,
  previous_release_date DATE,
  OUT result_message STRING
)
BEGIN 
  DECLARE is_valid BOOL DEFAULT TRUE;
  DECLARE validation_message STRING DEFAULT '';

  -- validate the last release date for clinvar_genes
  CALL `clinvar_ingest.validate_last_release`('clinvar_genes', previous_release_date, is_valid, validation_message);

  IF NOT is_valid THEN
    SET result_message = FORMAT("Skipping processing. %s", validation_message);
    RETURN;
  END IF;

  -- deleted genes (where it exists in clinvar_genes (for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_genes` cg
    SET 
      deleted_release_date = %T,
      deleted_count = deleted_count + 1
    WHERE 
      cg.deleted_release_date is NULL 
      AND 
      NOT EXISTS 
      (
        SELECT 
          g.id 
        FROM `%s.gene` g
        WHERE 
          g.id = cg.id
      )
  """, release_date, schema_name);

  -- updated genes
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_genes` cg
    SET 
      hgnc_id = g.hgnc_id,
      symbol = g.symbol,
      end_release_date = g.release_date,
      deleted_release_date = NULL
    FROM `%s.gene` g
    WHERE 
      g.id = cg.id
  """, schema_name);

  -- new genes
  EXECUTE IMMEDIATE FORMAT("""
    INSERT `clinvar_ingest.clinvar_genes` (
      id, 
      symbol, 
      hgnc_id, 
      start_release_date, 
      end_release_date
    )
    SELECT 
      g.id, 
      g.symbol, 
      g.hgnc_id, 
      g.release_date as start_release_date, 
      g.release_date as end_release_date
    FROM `%s.gene` g
    WHERE 
      NOT EXISTS 
      (
        SELECT 
          cg.id 
        FROM `clinvar_ingest.clinvar_genes` cg
        WHERE 
          cg.id = g.id 
      )
  """, schema_name);

  SET result_message = "clinvar_genes processing completed successfully.";

END;