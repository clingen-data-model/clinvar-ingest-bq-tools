CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_vrs_seqref_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_vrs_seqref`
      AS
        SELECT
          gkv.out.location.sequenceReference.refgetAccession,
          gkv.in.accession as name,
          gkv.out.location.sequenceReference.type,
        'na' as residueAlphabet,
        'genomic' as moleculeType
        FROM `%s.gk_pilot_vrs` gkv
        WHERE
          gkv.out.id IS NOT NULL
          AND
          gkv.in.accession IS NOT NULL
        GROUP BY
          gkv.out.location.sequenceReference.refgetAccession,
          gkv.in.accession,
          gkv.out.location.sequenceReference.type
    """, rec.schema_name, rec.schema_name);
  END FOR;

END;
