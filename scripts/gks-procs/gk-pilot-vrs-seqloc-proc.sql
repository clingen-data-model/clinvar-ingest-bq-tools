CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_vrs_seqloc_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_vrs_seqloc`
      AS
        WITH seqloc AS (
          SELECT
            gkv.out.location.id,
            gkv.out.location.digest,
            gkv.out.location.sequenceReference.refgetAccession as sequenceReference,
            gkv.out.location.type,
            gkv.out.location.start,
            gkv.out.location.end
          FROM `%s.gk_pilot_vrs` gkv
          WHERE
            gkv.out.id IS NOT NULL
            AND
            gkv.in.accession IS NOT NULL
          GROUP BY
            gkv.out.location.id,
            gkv.out.location.digest,
            gkv.out.location.sequenceReference.refgetAccession,
            gkv.out.location.type,
            gkv.out.location.start,
            gkv.out.location.end
        )
        SELECT
          seqloc.id,
          seqloc.type,
          seqloc.digest,
          STRUCT(seqref) as sequenceReference,
          seqloc.start,
          seqloc.end
        FROM seqloc
        JOIN `%s.gk_pilot_vrs_seqref` seqref
        ON
          seqref.refgetAccession = seqloc.sequenceReference
    """, rec.schema_name, rec.schema_name, rec.schema_name);
  END FOR;

END;
