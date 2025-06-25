CREATE OR REPLACE PROCEDURE `clinvar_ingest.refresh_scv_lookup`(
  schema_name STRING   -- Name of schema/dataset
)
BEGIN
  -- add a special table containing only local_key's that match
  -- the UUID format for SCV lookups from VCI clinvar submission service
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `clingen-dx.clinvar_qa.scv_lookup`
    AS
      SELECT DISTINCT
        REGEXP_EXTRACT(
          ca.local_key,
          r'^\\w{8}\\-\\w{4}\\-\\w{4}\\-\\w{4}\\-\\w{12}'
        ) AS prefix_key,
        ca.local_key,
        ca.id,
        s.current_name
      FROM `%s.clinical_assertion` ca
      JOIN `%s.submitter` s
      ON
        s.id = ca.submitter_id
      WHERE
        REGEXP_CONTAINS(
          ca.local_key,
          r'^\\w{8}\\-\\w{4}\\-\\w{4}\\-\\w{4}\\-\\w{12}'
        )
    """, schema_name, schema_name);
END;
