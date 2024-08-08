CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_vrs_seqloc_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_vrs_seqloc`
      AS
        WITH seqloc AS (
          SELECT
            DISTINCT 
            gkv.out.location.id,
            gkv.out.location.digest,
            gkv.out.location.sequenceReference.refgetAccession as sequenceReference,
            gkv.out.location.type,
            gkv.out.location.start,
            gkv.out.location.end,
            vi.loc.cyto,
            IFNULL(vi.hgvs.assembly, vi.loc.assembly) as assembly
          FROM `%s.gks_pilot_vrs` gkv
          JOIN `%s.variation_identity` vi
          ON
            vi.id = gkv.in.id
          WHERE
            gkv.out.id IS NOT NULL
            AND IFNULL(`in`.loc.accession, `in`.hgvs.accession) IS NOT NULL 
        ),
        e AS (
          -- build cytogenetic and assembly extension when available
          SELECT
            DISTINCT seqloc.id,
            'cytogenetic' AS name,
            seqloc.cyto AS value
          FROM seqloc
          WHERE
            seqloc.cyto IS NOT NULL
          UNION ALL
          SELECT
            DISTINCT seqloc.id,
            'assembly' AS name,
            seqloc.assembly AS value
          FROM seqloc
          WHERE
            seqloc.assembly IS NOT NULL 
        )
        SELECT
          seqloc.id,
          seqloc.type,
          seqloc.digest,
          (
            SELECT AS STRUCT * 
            FROM `%s.gk_pilot_vrs_seqref` seqref 
            WHERE seqref.refgetAccession = seqloc.sequenceReference
          ) as sequenceReference,
          seqloc.start,
          seqloc.end,
          ARRAY_AGG(STRUCT(e.name, e.value)) AS extensions
        FROM seqloc
        LEFT JOIN e
        ON
          e.id = seqloc.id
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

