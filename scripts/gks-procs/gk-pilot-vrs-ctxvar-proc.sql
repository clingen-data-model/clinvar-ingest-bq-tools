CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_vrs_ctxvar_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_vrs_ctxvar`
      AS
      WITH ctxvar AS  (
        SELECT
          gkv.out.id,
          gkv.out.digest,
          gkv.out.location.id as location,
          gkv.out.type,
          gkv.out.state,
          gkv.out.copies,
          gkv.out.copyChange,
          vi.hgvs.nucleotide as hgvs_exp,
          vi.loc.derived_vcf as gnomad_exp,
          IFNULL(vi.hgvs.assembly, vi.loc.assembly) as assembly,
          vi.canonical_spdi as spdi_exp,
          gkv.in.id as vi_id 
        FROM `%s.gk_pilot_vrs` gkv
        JOIN `%s.variation_identity` vi
        ON
          vi.id = gkv.in.id
        WHERE
          gkv.out.id is not null
      ),
      ext AS (
        -- build assembly extension when available
        SELECT
          DISTINCT ctxvar.id,
          'assembly' AS name,
          ctxvar.assembly AS value
        FROM ctxvar
        WHERE
          ctxvar.assembly IS NOT NULL
      ),
      exp AS (
        -- todo
        SELECT
          DISTINCT ctxvar.id,
          'assembly' AS name,
          ctxvar.assembly AS value
        FROM ctxvar
        WHERE
          ctxvar.assembly IS NOT NULL
      )
      SELECT
        ctxvar.id,
        ctxvar.type,
        ctxvar.digest,
        (
          SELECT AS STRUCT *
          FROM `%s.gk_pilot_vrs_seqloc` loc
          WHERE loc.id = ctxvar.location
        ) as location,
        ctxvar.start,
        seqloc.end,
        ARRAY_AGG(STRUCT(ext.name, ext.value)) AS extensions
      FROM ctxvar
      LEFT JOIN ext
      ON
        ext.id = seqloc.id
      GROUP BY
        seqloc.id,
        seqloc.type,
        seqloc.digest,
        seqloc.sequenceReference,
        seqloc.start,
        seqloc.end
      ORDER BY 3
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);
  END FOR;

END;
