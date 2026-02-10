-- ============================================================================
-- Mechanism Threshold Summary Analysis
-- ============================================================================
-- This script produces summary statistics across all dosage genes, grouped by
-- Haploinsufficiency (HI) and Triplosensitivity (TS) scores.
--
-- This helps set mechanism curation thresholds based on the distribution of
-- variants across genes with different dosage curation levels.
--
-- Uses clinvar_sum_vsp_rank_group for efficient pre-aggregated VCV data:
-- - gks_proposition_type = 'path' for pathogenic VCVs
-- - rank: 0=0★, 1=1★, 2=2★, 3=3★, 4=4★
-- - agg_sig_type >= 4 means P/LP (at least one P/LP submission)
--
-- pLOF molecular consequences matched:
-- - nonsense (stop gained)
-- - frameshift variant
-- - splice donor variant, splice acceptor variant
-- ============================================================================

-- All variable declarations must be at the start of the script
DECLARE on_date DATE DEFAULT CURRENT_DATE();
DECLARE rec STRUCT<schema_name STRING, release_date DATE, prev_release_date DATE, next_release_date DATE>;
-- pLOF consequence terms to match against consq_label (comma-delimited from variation_hgvs)
DECLARE plof_consequences ARRAY<STRING> DEFAULT [
  'nonsense',
  'frameshift variant',
  'splice donor variant',
  'splice acceptor variant'
];

-- Get the schema for the given date
SET rec = (
  SELECT AS STRUCT
    s.schema_name,
    s.release_date,
    s.prev_release_date,
    s.next_release_date
  FROM clinvar_ingest.schema_on(on_date) AS s
);

-- Execute the summary analysis
EXECUTE IMMEDIATE FORMAT("""
  WITH
  -- Get dosage genes with their gene IDs from the gene table
  dosage_gene_ids AS (
    SELECT DISTINCT
      dg.gene_symbol,
      dg.hgnc_dosage_id,
      dg.hi_score,
      dg.ts_score,
      g.id AS gene_id
    FROM `clinvar_ingest.dosage_genes` dg
    JOIN `%s.gene` g
    ON
      g.symbol = dg.gene_symbol
      OR g.hgnc_id = dg.hgnc_dosage_id
  ),

  -- Get single gene variants associated with dosage genes
  single_gene_variants AS (
    SELECT DISTINCT
      sgv.variation_id,
      dgi.gene_symbol,
      dgi.gene_id,
      dgi.hi_score,
      dgi.ts_score
    FROM `%s.single_gene_variation` sgv
    JOIN dosage_gene_ids dgi
    ON
      sgv.gene_id = dgi.gene_id
  ),

  -- Get VCV pathogenic proposition data from pre-aggregated table
  vcv_path AS (
    SELECT
      sgv.variation_id,
      sgv.gene_symbol,
      sgv.gene_id,
      sgv.hi_score,
      sgv.ts_score,
      svrg.rank AS vcv_rank,
      svrg.agg_sig_type,
      -- P/LP if agg_sig_type >= 4 (at least one P/LP submission)
      (svrg.agg_sig_type >= 4) AS is_plp
    FROM single_gene_variants sgv
    JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` svrg
    ON
      svrg.variation_id = sgv.variation_id
      AND svrg.gks_proposition_type = 'path'
      AND DATE'%t' BETWEEN svrg.start_release_date AND IFNULL(svrg.end_release_date, CURRENT_DATE())
  ),

  -- Get variant lengths and molecular consequences from variation_hgvs
  variant_details AS (
    SELECT
      v.id AS variation_id,
      MAX(IF(sl.for_display, sl.variant_length, NULL)) AS variant_length,
      MAX(vh.consq_label) AS consq_label,
      -- Check if any pLOF consequence exists in the consq_label
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
    ON
      vh.variation_id = v.id
      AND vh.mane_select = TRUE
    GROUP BY v.id
  ),

  -- Combine VCV data with variant details and apply filters
  filtered_variants AS (
    SELECT
      vp.*,
      vd.variant_length,
      vd.consq_label,
      vd.is_plof
    FROM vcv_path vp
    JOIN variant_details vd
    ON
      vd.variation_id = vp.variation_id
    WHERE
      (vd.variant_length IS NULL OR vd.variant_length < 1000)
  ),

  -- Per-gene aggregation
  gene_stats AS (
    SELECT
      gene_symbol,
      gene_id,
      hi_score,
      ts_score,
      COUNT(DISTINCT variation_id) AS total_variants,
      COUNT(DISTINCT IF(vcv_rank >= 1, variation_id, NULL)) AS one_star_variants,
      COUNT(DISTINCT IF(is_plp, variation_id, NULL)) AS plp_variants,
      COUNT(DISTINCT IF(is_plp AND vcv_rank >= 1, variation_id, NULL)) AS plp_one_star_variants,
      COUNT(DISTINCT IF(is_plof, variation_id, NULL)) AS plof_variants,
      COUNT(DISTINCT IF(is_plof AND vcv_rank >= 1, variation_id, NULL)) AS plof_one_star_variants,
      COUNT(DISTINCT IF(is_plof AND is_plp, variation_id, NULL)) AS plp_plof_variants,
      COUNT(DISTINCT IF(is_plof AND is_plp AND vcv_rank >= 1, variation_id, NULL)) AS plp_one_star_plof_variants
    FROM filtered_variants
    GROUP BY
      gene_symbol,
      gene_id,
      hi_score,
      ts_score
  )

  -- Summary by HI score
  SELECT
    'HI Score Summary' AS report_type,
    hi_score AS score_category,
    COUNT(DISTINCT gene_symbol) AS gene_count,
    SUM(total_variants) AS total_variants,
    SUM(one_star_variants) AS one_star_variants,
    SUM(plp_variants) AS plp_variants,
    SUM(plp_one_star_variants) AS plp_one_star_variants,
    SUM(plof_variants) AS plof_variants,
    SUM(plof_one_star_variants) AS plof_one_star_variants,
    SUM(plp_plof_variants) AS plp_plof_variants,
    SUM(plp_one_star_plof_variants) AS plp_one_star_plof_variants,
    -- Averages per gene
    ROUND(AVG(total_variants), 1) AS avg_variants_per_gene,
    ROUND(AVG(plp_one_star_plof_variants), 1) AS avg_plp_1star_plof_per_gene
  FROM gene_stats
  GROUP BY hi_score

  UNION ALL

  -- Summary by TS score
  SELECT
    'TS Score Summary' AS report_type,
    ts_score AS score_category,
    COUNT(DISTINCT gene_symbol) AS gene_count,
    SUM(total_variants) AS total_variants,
    SUM(one_star_variants) AS one_star_variants,
    SUM(plp_variants) AS plp_variants,
    SUM(plp_one_star_variants) AS plp_one_star_variants,
    SUM(plof_variants) AS plof_variants,
    SUM(plof_one_star_variants) AS plof_one_star_variants,
    SUM(plp_plof_variants) AS plp_plof_variants,
    SUM(plp_one_star_plof_variants) AS plp_one_star_plof_variants,
    ROUND(AVG(total_variants), 1) AS avg_variants_per_gene,
    ROUND(AVG(plp_one_star_plof_variants), 1) AS avg_plp_1star_plof_per_gene
  FROM gene_stats
  GROUP BY ts_score

  UNION ALL

  -- Overall totals
  SELECT
    'Overall Total' AS report_type,
    'All Dosage Genes' AS score_category,
    COUNT(DISTINCT gene_symbol) AS gene_count,
    SUM(total_variants) AS total_variants,
    SUM(one_star_variants) AS one_star_variants,
    SUM(plp_variants) AS plp_variants,
    SUM(plp_one_star_variants) AS plp_one_star_variants,
    SUM(plof_variants) AS plof_variants,
    SUM(plof_one_star_variants) AS plof_one_star_variants,
    SUM(plp_plof_variants) AS plp_plof_variants,
    SUM(plp_one_star_plof_variants) AS plp_one_star_plof_variants,
    ROUND(AVG(total_variants), 1) AS avg_variants_per_gene,
    ROUND(AVG(plp_one_star_plof_variants), 1) AS avg_plp_1star_plof_per_gene
  FROM gene_stats

  ORDER BY report_type, score_category
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
