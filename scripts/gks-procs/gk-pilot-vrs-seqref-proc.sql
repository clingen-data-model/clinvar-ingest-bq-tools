CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_vrs_seqref_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_vrs_seqref`
      AS
        WITH seqref AS (
          SELECT
            DISTINCT gkv.out.location.sequenceReference.refgetAccession,
            -- add in the new `accession` field from the cannonical spdi when available.
            IFNULL(`in`.loc.accession, `in`.hgvs.accession) AS accession,
            `in`.hgvs.assembly,
            `in`.loc.chr,
            out.location.sequenceReference.type
          FROM `%s.gk_pilot_vrs` gkv
          WHERE
            gkv.out.id IS NOT NULL
            AND IFNULL(`in`.loc.accession, `in`.hgvs.accession) IS NOT NULL 
        ),
        m AS (
          SELECT
            seqref.refgetAccession,
            STRUCT( 
              SPLIT(seqref.accession, '.')[OFFSET(0)] AS code,
              SPLIT(seqref.accession, '.')[OFFSET(1)] AS version,
              'https://identifiers.org/refseq' AS system ) AS coding,
            'closeMatch' AS relation,
          FROM seqref 
        ),
        e AS (
          -- build a union of assembly and chromosome extensions when available
          SELECT
            DISTINCT seqref.refgetAccession,
            'assembly' AS name,
            seqref.assembly AS value
          FROM seqref
          WHERE
            seqref.assembly IS NOT NULL
          UNION ALL
          SELECT
            DISTINCT seqref.refgetAccession,
            'chromosome' AS name,
            seqref.chr AS value
          FROM seqref
          WHERE
            seqref.chr IS NOT NULL 
        )
        SELECT
          seqref.accession AS label,
          seqref.type,
          seqref.refgetAccession,
          'na' as residueAlphabet,
          ARRAY_AGG(STRUCT(m.coding, m.relation)) AS mappings,
          ARRAY_AGG(STRUCT(e.name, e.value)) AS extensions
        FROM seqref
        LEFT JOIN e
        ON
          e.refgetAccession = seqref.refgetAccession
        LEFT JOIN m
        ON
          m.refgetAccession = seqref.refgetAccession
        GROUP BY
          seqref.accession,
          seqref.type,
          seqref.refgetAccession
        ORDER BY 3 
    """, rec.schema_name, rec.schema_name);
  END FOR;

END;