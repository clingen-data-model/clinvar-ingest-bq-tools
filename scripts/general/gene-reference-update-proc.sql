-- Add-only update of the gene reference tables used by clinvar_ingest.single_gene_variation,
-- from NCBI Gene files that the caller has already parsed into two staging tables:
--
--   clinvar_ingest.entrez_gene_stage        human rows of Homo_sapiens.gene_info
--     (gene_id, symbol_from_authority, symbol, hgnc_id, type_of_gene, description, has_hgnc)
--   clinvar_ingest.ncbi_gene_history_stage  human rows of gene_history
--     (discontinued_gene_id, replaced_by_gene_id, discontinued_symbol, discontinue_date)
--
-- Callers: the clinvar-ingest stored-procedures job (at the start of every run) and
-- scripts/general/update-gene-reference.sh (by hand). validate_dataset fails a release when no
-- applied refresh is logged on or after its release date.
--
-- Never changes or removes an existing row (see docs/methods/single-gene-variation.md):
--   - entrez_gene: inserts gene ids not yet present (HGNC-named genes only) and fills
--     type_of_gene / description where they are still NULL
--   - ncbi_gene_history: inserts discontinued ids not yet present (NCBI only appends to it)
--
-- apply_changes = FALSE only reports the counts. Every applied run is logged to
-- clinvar_ingest.gene_reference_refresh_log, even when there is nothing new.
CREATE OR REPLACE PROCEDURE `clinvar_ingest.gene_reference_update`(
  apply_changes BOOL,
  triggered_by STRING
)
BEGIN
  DECLARE staged_hgnc_genes INT64;
  DECLARE current_entrez_genes INT64;
  DECLARE staged_history_rows INT64;
  DECLARE current_history_rows INT64;
  DECLARE genes_to_insert INT64;
  DECLARE rows_to_fill INT64;
  DECLARE history_to_insert INT64;

  -- one-time setup; idempotent. ncbi_gene_history must exist before the counts below.
  CREATE TABLE IF NOT EXISTS `clinvar_ingest.ncbi_gene_history` (
    discontinued_gene_id STRING NOT NULL OPTIONS (description = 'NCBI gene id that was discontinued'),
    replaced_by_gene_id STRING OPTIONS (description = 'NCBI gene id that replaced it, if any'),
    discontinued_symbol STRING OPTIONS (description = 'symbol of the discontinued gene id'),
    discontinue_date DATE NOT NULL OPTIONS (description = 'date NCBI discontinued the gene id')
  )
  OPTIONS (description = 'Human rows of NCBI gene_history. Add-only; see docs/methods/single-gene-variation.md');

  ALTER TABLE `clinvar_ingest.entrez_gene`
    ADD COLUMN IF NOT EXISTS type_of_gene STRING OPTIONS (description = 'NCBI gene_info type_of_gene'),
    ADD COLUMN IF NOT EXISTS description STRING OPTIONS (description = 'NCBI gene_info description');

  SET staged_hgnc_genes = (SELECT COUNTIF(has_hgnc) FROM `clinvar_ingest.entrez_gene_stage`);
  SET current_entrez_genes = (SELECT COUNT(*) FROM `clinvar_ingest.entrez_gene`);
  SET staged_history_rows = (SELECT COUNT(*) FROM `clinvar_ingest.ncbi_gene_history_stage`);
  SET current_history_rows = (SELECT COUNT(*) FROM `clinvar_ingest.ncbi_gene_history`);

  -- refuse a truncated or empty download rather than partially updating
  IF staged_hgnc_genes < 0.9 * current_entrez_genes THEN
    RAISE USING MESSAGE = FORMAT(
      'gene_reference_update: the staged gene_info has %d HGNC-named genes, under 90%% of the %d in entrez_gene. The download may be incomplete.',
      staged_hgnc_genes, current_entrez_genes
    );
  END IF;
  IF staged_history_rows < current_history_rows THEN
    RAISE USING MESSAGE = FORMAT(
      'gene_reference_update: the staged gene_history has %d rows, fewer than the %d already loaded. NCBI only appends to it, so the download may be incomplete.',
      staged_history_rows, current_history_rows
    );
  END IF;

  SET genes_to_insert = (
    SELECT COUNT(*)
    FROM `clinvar_ingest.entrez_gene_stage` s
    WHERE
      s.has_hgnc
      AND
      s.gene_id NOT IN (SELECT gene_id FROM `clinvar_ingest.entrez_gene`)
  );
  SET rows_to_fill = (
    SELECT COUNT(*)
    FROM `clinvar_ingest.entrez_gene` e
    JOIN `clinvar_ingest.entrez_gene_stage` s
    ON
      s.gene_id = e.gene_id
    WHERE
      e.type_of_gene IS NULL
      OR
      e.description IS NULL
  );
  SET history_to_insert = (
    SELECT COUNT(*)
    FROM `clinvar_ingest.ncbi_gene_history_stage` s
    WHERE
      s.discontinued_gene_id NOT IN (SELECT discontinued_gene_id FROM `clinvar_ingest.ncbi_gene_history`)
  );

  IF apply_changes THEN
    -- MERGE with only a NOT MATCHED clause, so overlapping runs cannot insert a gene twice
    MERGE `clinvar_ingest.entrez_gene` e
    USING (
      SELECT gene_id, symbol_from_authority, symbol, hgnc_id, type_of_gene, description
      FROM `clinvar_ingest.entrez_gene_stage`
      WHERE has_hgnc
    ) s
    ON
      e.gene_id = s.gene_id
    WHEN NOT MATCHED THEN
      INSERT (gene_id, symbol_from_authority, symbol, hgnc_id, type_of_gene, description)
      VALUES (s.gene_id, s.symbol_from_authority, s.symbol, s.hgnc_id, s.type_of_gene, s.description);

    UPDATE `clinvar_ingest.entrez_gene` e
    SET
      type_of_gene = IFNULL(e.type_of_gene, s.type_of_gene),
      description = IFNULL(e.description, s.description)
    FROM `clinvar_ingest.entrez_gene_stage` s
    WHERE
      s.gene_id = e.gene_id
      AND
      (e.type_of_gene IS NULL OR e.description IS NULL);

    MERGE `clinvar_ingest.ncbi_gene_history` h
    USING `clinvar_ingest.ncbi_gene_history_stage` s
    ON
      h.discontinued_gene_id = s.discontinued_gene_id
    WHEN NOT MATCHED THEN
      INSERT (discontinued_gene_id, replaced_by_gene_id, discontinued_symbol, discontinue_date)
      VALUES (s.discontinued_gene_id, NULLIF(s.replaced_by_gene_id, ''), s.discontinued_symbol, s.discontinue_date);

    CREATE TABLE IF NOT EXISTS `clinvar_ingest.gene_reference_refresh_log` (
      refreshed_at TIMESTAMP NOT NULL OPTIONS (description = 'when the refresh was applied'),
      triggered_by STRING OPTIONS (description = 'caller, e.g. the clinvar-ingest job or update-gene-reference.sh'),
      staged_hgnc_genes INT64 OPTIONS (description = 'HGNC-named human genes in the NCBI gene_info file'),
      staged_history_rows INT64 OPTIONS (description = 'human rows in the NCBI gene_history file'),
      entrez_genes_inserted INT64,
      entrez_rows_filled INT64,
      history_rows_inserted INT64
    )
    OPTIONS (description = 'One row per applied gene reference refresh; checked by validate_dataset');

    INSERT INTO `clinvar_ingest.gene_reference_refresh_log` (
      refreshed_at,
      triggered_by,
      staged_hgnc_genes,
      staged_history_rows,
      entrez_genes_inserted,
      entrez_rows_filled,
      history_rows_inserted
    )
    VALUES (
      CURRENT_TIMESTAMP(),
      triggered_by,
      staged_hgnc_genes,
      staged_history_rows,
      genes_to_insert,
      rows_to_fill,
      history_to_insert
    );
  END IF;

  SELECT
    apply_changes AS applied,
    genes_to_insert AS entrez_genes_to_insert,
    rows_to_fill AS entrez_rows_to_fill,
    history_to_insert AS history_rows_to_insert,
    staged_hgnc_genes,
    staged_history_rows;
END;
