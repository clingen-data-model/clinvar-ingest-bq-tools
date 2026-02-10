-- ============================================================================
-- Mechanism Threshold Results Tables and Views
-- ============================================================================
-- This script creates:
-- 1. Result tables to store the analysis output
-- 2. A procedure to refresh the results
-- 3. Views for Google Sheets data connector
--
-- Usage in Google Sheets:
--   SELECT * FROM `clinvar_ingest.mechanism_threshold_by_gene_view`
--   SELECT * FROM `clinvar_ingest.mechanism_threshold_summary_view`
--
-- To refresh the data, run:
--   CALL `clinvar_ingest.refresh_mechanism_threshold`();
-- ============================================================================

-- ============================================================================
-- Result Tables
-- ============================================================================

-- Table to store per-gene variant counts
CREATE OR REPLACE TABLE `clinvar_ingest.mechanism_threshold_by_gene` (
  release_date DATE,
  gene_symbol STRING,
  gene_id STRING,
  hi_score STRING,
  ts_score STRING,
  total_variants INT64,
  one_star_variants INT64,
  plp_variants INT64,
  plp_one_star_variants INT64,
  plof_variants INT64,
  plof_one_star_variants INT64,
  plp_plof_variants INT64,
  plp_one_star_plof_variants INT64,
  sample_variation_ids STRING,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Table to store summary statistics
CREATE OR REPLACE TABLE `clinvar_ingest.mechanism_threshold_summary` (
  release_date DATE,
  report_type STRING,
  score_category STRING,
  gene_count INT64,
  total_variants INT64,
  one_star_variants INT64,
  plp_variants INT64,
  plp_one_star_variants INT64,
  plof_variants INT64,
  plof_one_star_variants INT64,
  plp_plof_variants INT64,
  plp_one_star_plof_variants INT64,
  avg_variants_per_gene FLOAT64,
  avg_plp_1star_plof_per_gene FLOAT64,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- Refresh Procedure
-- ============================================================================
CREATE OR REPLACE PROCEDURE `clinvar_ingest.refresh_mechanism_threshold`(
  in_date DATE
)
BEGIN
  DECLARE on_date DATE DEFAULT IFNULL(in_date, CURRENT_DATE());
  DECLARE rec STRUCT<schema_name STRING, release_date DATE, prev_release_date DATE, next_release_date DATE>;
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

  -- Clear existing data for this release
  DELETE FROM `clinvar_ingest.mechanism_threshold_by_gene` WHERE release_date = rec.release_date;
  DELETE FROM `clinvar_ingest.mechanism_threshold_summary` WHERE release_date = rec.release_date;

  -- Populate per-gene results
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.mechanism_threshold_by_gene` (
      release_date,
      gene_symbol,
      gene_id,
      hi_score,
      ts_score,
      total_variants,
      one_star_variants,
      plp_variants,
      plp_one_star_variants,
      plof_variants,
      plof_one_star_variants,
      plp_plof_variants,
      plp_one_star_plof_variants,
      sample_variation_ids
    )
    WITH
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
    vcv_path AS (
      SELECT
        sgv.variation_id,
        sgv.gene_symbol,
        sgv.gene_id,
        sgv.hi_score,
        sgv.ts_score,
        svrg.rank AS vcv_rank,
        svrg.agg_sig_type,
        (svrg.agg_sig_type >= 4) AS is_plp
      FROM single_gene_variants sgv
      JOIN `clinvar_ingest.clinvar_sum_vsp_rank_group` svrg
      ON
        svrg.variation_id = sgv.variation_id
        AND svrg.gks_proposition_type = 'path'
        AND DATE'%t' BETWEEN svrg.start_release_date AND IFNULL(svrg.end_release_date, CURRENT_DATE())
    ),
    variant_details AS (
      SELECT
        v.id AS variation_id,
        MAX(IF(sl.for_display, sl.variant_length, NULL)) AS variant_length,
        MAX(vh.consq_label) AS consq_label,
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
    )
    SELECT
      DATE'%t' AS release_date,
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
      COUNT(DISTINCT IF(is_plof AND is_plp AND vcv_rank >= 1, variation_id, NULL)) AS plp_one_star_plof_variants,
      ARRAY_TO_STRING(ARRAY_AGG(DISTINCT variation_id ORDER BY variation_id LIMIT 10), ',') AS sample_variation_ids
    FROM filtered_variants
    GROUP BY
      gene_symbol,
      gene_id,
      hi_score,
      ts_score
  """,
  rec.schema_name,
  rec.schema_name,
  rec.release_date,
  rec.schema_name,
  rec.schema_name,
  rec.release_date
  )
  USING
    plof_consequences AS plof_consequences
  ;

  -- Populate summary results
  INSERT INTO `clinvar_ingest.mechanism_threshold_summary` (
    release_date,
    report_type,
    score_category,
    gene_count,
    total_variants,
    one_star_variants,
    plp_variants,
    plp_one_star_variants,
    plof_variants,
    plof_one_star_variants,
    plp_plof_variants,
    plp_one_star_plof_variants,
    avg_variants_per_gene,
    avg_plp_1star_plof_per_gene
  )
  WITH gene_stats AS (
    SELECT * FROM `clinvar_ingest.mechanism_threshold_by_gene`
    WHERE release_date = rec.release_date
  )
  -- Summary by HI score
  SELECT
    rec.release_date,
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
    ROUND(AVG(total_variants), 1) AS avg_variants_per_gene,
    ROUND(AVG(plp_one_star_plof_variants), 1) AS avg_plp_1star_plof_per_gene
  FROM gene_stats
  GROUP BY hi_score

  UNION ALL

  -- Summary by TS score
  SELECT
    rec.release_date,
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
    rec.release_date,
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
  FROM gene_stats;

END;

-- ============================================================================
-- Views for Google Sheets Data Connector
-- These views show the latest release data
-- ============================================================================

-- View: Per-gene variant counts (latest release)
CREATE OR REPLACE VIEW `clinvar_ingest.mechanism_threshold_by_gene_view`
AS
SELECT
  release_date,
  gene_symbol,
  gene_id,
  hi_score,
  ts_score,
  total_variants,
  one_star_variants,
  plp_variants,
  plp_one_star_variants,
  plof_variants,
  plof_one_star_variants,
  plp_plof_variants,
  plp_one_star_plof_variants,
  sample_variation_ids
FROM `clinvar_ingest.mechanism_threshold_by_gene`
WHERE release_date = (SELECT MAX(release_date) FROM `clinvar_ingest.mechanism_threshold_by_gene`)
ORDER BY gene_symbol;

-- View: Summary statistics (latest release)
CREATE OR REPLACE VIEW `clinvar_ingest.mechanism_threshold_summary_view`
AS
SELECT
  release_date,
  report_type,
  score_category,
  gene_count,
  total_variants,
  one_star_variants,
  plp_variants,
  plp_one_star_variants,
  plof_variants,
  plof_one_star_variants,
  plp_plof_variants,
  plp_one_star_plof_variants,
  avg_variants_per_gene,
  avg_plp_1star_plof_per_gene
FROM `clinvar_ingest.mechanism_threshold_summary`
WHERE release_date = (SELECT MAX(release_date) FROM `clinvar_ingest.mechanism_threshold_summary`)
ORDER BY report_type, score_category;
