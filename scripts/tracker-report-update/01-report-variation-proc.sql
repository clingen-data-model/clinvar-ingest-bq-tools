-- report_variations (run when you want to update the variants of inteterest driven by the reporting tables for vceps, etc...)
CREATE OR REPLACE PROCEDURE `variation_tracker.report_variation`(
  reportIds ARRAY<STRING>
)
BEGIN

  IF (reportIds IS NULL OR ARRAY_LENGTH(reportIds) = 0) THEN
    SET reportIds = (SELECT ARRAY_AGG(r.id) FROM `variation_tracker.report` r WHERE r.active);
  END IF;

  CREATE TEMP TABLE temp_report_variation
  AS
  -- get all the submitted variations for the report submitter
  SELECT
    r.id as report_id, 
    scv.variation_id
  FROM `variation_tracker.report` r
  JOIN `variation_tracker.report_submitter` rs 
  ON 
    rs.report_id = r.id
  JOIN `clinvar_ingest.clinvar_scvs` scv 
  ON 
    scv.submitter_id = rs.submitter_id
  WHERE 
    (r.id IN UNNEST(reportIds))
  GROUP BY 
    r.id, 
    scv.variation_id
  UNION DISTINCT
   -- union all variations associated with any genes associated with active report ids
  SELECT 
    r.id as report_id, 
    vsg.variation_id
  FROM `variation_tracker.report` r
  JOIN `variation_tracker.report_gene` rg 
  ON 
    rg.report_id = r.id
  JOIN `clinvar_ingest.entrez_gene` cg 
  ON 
    UPPER(cg.symbol_from_authority) = UPPER(TRIM(rg.gene_symbol))
  JOIN `clinvar_ingest.clinvar_single_gene_variations` vsg 
  ON 
    vsg.gene_id = cg.gene_id
  WHERE 
    (r.id IN UNNEST(reportIds))
  GROUP BY 
    r.id, 
    vsg.variation_id
  UNION DISTINCT
  -- union all variations associated directly with active report ids
  SELECT 
    r.id as report_id, 
    cv.id as variation_id
  FROM `variation_tracker.report` r
  JOIN `variation_tracker.report_variant_list` rvl 
  ON 
    rvl.report_id = r.id
  JOIN `clinvar_ingest.clinvar_variations` cv 
  ON 
    cv.id = rvl.variation_id
  WHERE 
    (r.id IN UNNEST(reportIds))
  GROUP BY r.id, cv.id
  ;

  DELETE FROM `variation_tracker.report_variation`
  WHERE report_id IN (SELECT DISTINCT report_id FROM temp_report_variation);

  INSERT INTO  `variation_tracker.report_variation` (report_id, variation_id)
  SELECT report_id, variation_id from temp_report_variation;
  

END;