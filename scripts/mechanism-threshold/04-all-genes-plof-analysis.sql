-- ============================================================================
-- All-Genes pLOF Analysis  (ad-hoc)  - Sheet 3 source query
-- ============================================================================
-- Ad-hoc / exploratory version of the ALL single-gene report that the
-- refresh_mechanism_threshold procedure materializes into
-- clinvar_ingest.mechanism_threshold_all_genes (see 03-...-table-funcs.sql).
--
-- Same analysis and metrics as 01-mechanism-threshold-analysis.sql, but NOT
-- restricted to ClinGen dosage genes - it covers every single-gene variant in
-- ClinVar so any gene can be looked up for dosage / LOF-mechanism triage.
-- hi_score/ts_score are omitted (dosage-only); hgnc_id is added for lookup.
--
-- Definitions (identical to the dosage report so the two are comparable):
-- - Scope: single-gene variants, length < 1kb or NULL, germline pathogenicity
--   VCV (proposition_type = 'path'); highest rank per variation.
-- - rank: 0=0*, 1=1*, 2=2*, 3=3*, 4=4*   (one_star = rank >= 1)
-- - agg_sig_type = 4 => P/LP (no conflicting classification)
-- - pLOF => MANE-select consequence in {nonsense, frameshift variant,
--   splice donor variant, splice acceptor variant}
--
-- The three fields most used for triage:
--   total_variants, plp_one_star_variants, plp_one_star_plof_variants
-- ============================================================================

DECLARE on_date DATE DEFAULT CURRENT_DATE();
DECLARE rec STRUCT<schema_name STRING, release_date DATE, prev_release_date DATE, next_release_date DATE>;
DECLARE plof_consequences ARRAY<STRING> DEFAULT [
  'nonsense',
  'frameshift variant',
  'splice donor variant',
  'splice acceptor variant'
];

SET rec = (
  SELECT AS STRUCT
    s.schema_name,
    s.release_date,
    s.prev_release_date,
    s.next_release_date
  FROM clinvar_ingest.schema_on(on_date) AS s
);

EXECUTE IMMEDIATE FORMAT("""
  WITH
  -- Every single-gene variant, with its gene symbol / id / hgnc id
  sgv_genes AS (
    SELECT
      sgv.variation_id,
      g.symbol  AS gene_symbol,
      g.id      AS gene_id,
      g.hgnc_id AS hgnc_id
    FROM `%s.single_gene_variation` sgv
    JOIN `%s.gene` g ON g.id = sgv.gene_id
  ),

  -- Top-level (highest-rank) germline pathogenicity VCV per variation
  vcv_path AS (
    SELECT
      sgv.variation_id,
      sgv.gene_symbol,
      sgv.gene_id,
      sgv.hgnc_id,
      svrg.rank AS vcv_rank,
      (svrg.agg_sig_type = 4) AS is_plp
    FROM sgv_genes sgv
    JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` svrg
      ON svrg.variation_id = sgv.variation_id
     AND svrg.proposition_type = 'path'
     AND DATE'%t' BETWEEN svrg.start_release_date
                      AND IFNULL(svrg.end_release_date, CURRENT_DATE())
    QUALIFY svrg.rank = MAX(svrg.rank) OVER (PARTITION BY sgv.variation_id)
  ),

  -- Variant length (drop >=1kb CNVs) and pLOF flag from MANE-select HGVS
  variant_details AS (
    SELECT
      v.id AS variation_id,
      MAX(IF(sl.for_display, sl.variant_length, NULL)) AS variant_length,
      MAX(
        CASE WHEN EXISTS (
          SELECT 1
          FROM UNNEST(@plof_consequences) AS plof_term
          WHERE plof_term IN UNNEST(SPLIT(vh.consq_label, ','))
        ) THEN TRUE ELSE FALSE END
      ) AS is_plof
    FROM `%s.variation` v
    LEFT JOIN UNNEST(`clinvar_ingest.parseSequenceLocations`(JSON_EXTRACT(v.content, r'$.Location'))) AS sl
    LEFT JOIN `%s.variation_hgvs` vh
      ON vh.variation_id = v.id
      AND vh.mane_select = TRUE
    WHERE v.id IN (SELECT variation_id FROM vcv_path)
    GROUP BY v.id
  ),

  filtered_variants AS (
    SELECT
      vp.*,
      vd.variant_length,
      vd.is_plof
    FROM vcv_path vp
    JOIN variant_details vd
    ON
      vd.variation_id = vp.variation_id
    WHERE
      (vd.variant_length IS NULL OR vd.variant_length < 1000)
  )

  SELECT
    gene_symbol,
    gene_id,
    hgnc_id,
    COUNT(DISTINCT variation_id) AS total_variants,
    COUNT(DISTINCT IF(vcv_rank >= 1, variation_id, NULL)) AS one_star_variants,
    COUNT(DISTINCT IF(is_plp, variation_id, NULL)) AS plp_variants,
    COUNT(DISTINCT IF(is_plp AND vcv_rank >= 1, variation_id, NULL)) AS plp_one_star_variants,
    COUNT(DISTINCT IF(is_plof, variation_id, NULL)) AS plof_variants,
    COUNT(DISTINCT IF(is_plof AND vcv_rank >= 1, variation_id, NULL)) AS plof_one_star_variants,
    COUNT(DISTINCT IF(is_plof AND is_plp, variation_id, NULL)) AS plp_plof_variants,
    COUNT(DISTINCT IF(is_plof AND is_plp AND vcv_rank >= 1, variation_id, NULL)) AS plp_one_star_plof_variants,
    ARRAY_TO_STRING(ARRAY_AGG(DISTINCT variation_id ORDER BY variation_id LIMIT 10), ',') AS sample_variation_ids
  FROM filtered_variants
  GROUP BY
    gene_symbol,
    gene_id,
    hgnc_id
  ORDER BY
    gene_symbol
""",
rec.schema_name,
rec.schema_name,
rec.release_date,
rec.schema_name,
rec.schema_name
)
USING
  plof_consequences AS plof_consequences
;
