
CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_variations`(
  schema_name STRING,
  release_date DATE
)
BEGIN

  -- deleted variations (where it exists in clinvar_variations (for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_variations` cv
      SET deleted_release_date = %T,
        deleted_count = deleted_count + 1
    WHERE cv.deleted_release_date is NULL
      AND NOT EXISTS (
        SELECT v.id 
        FROM `%s.variation` v
        WHERE  v.id = cv.id
      )
  """, release_date, schema_name);

  -- updated variations
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_variations` cv
      SET name = v.name, 
        end_release_date = v.release_date,
        deleted_release_date = NULL
    FROM `%s.variation` v
    WHERE v.id = cv.id
  """, schema_name);

  -- new variations
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_variations` 
      (id, name, start_release_date, end_release_date)
    SELECT v.id, v.name, 
      v.release_date as start_release_date, 
      v.release_date as end_release_date
    FROM `%s.variation` v
    WHERE 
      NOT EXISTS (
      SELECT cv.id 
      FROM `clinvar_ingest.clinvar_variations` cv
      WHERE cv.id = v.id 
    )
  """, schema_name);

END;
