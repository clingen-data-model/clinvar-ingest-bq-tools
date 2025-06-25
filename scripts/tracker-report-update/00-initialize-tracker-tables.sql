
CREATE OR REPLACE TABLE `variation_tracker.gc_variation`
(
  report_date DATE,
  submitter_id STRING NOT NULL,
  variation_id STRING NOT NULL,
  hgnc_id STRING,
  symbol STRING,
  name STRING,
  agg_classification STRING,
  rank INT NOT NULL,
  clinvar_name STRING,
  submitted_classification STRING,
  classif_type STRING,
  last_evaluated DATE,
  scv_acxn STRING,
  gc_scv_first_in_clinvar DATE,
  local_key STRING,
  gc_case_count INT,
  all_scvs STRING,
  variant_first_in_clinvar DATE,
  novel_at_first_gc_submission STRING,
  novel_as_of_report_run_date STRING,
  only_other_gc_submitters STRING
)
;

CREATE OR REPLACE TABLE `variation_tracker.gc_case`
(
  report_date DATE NOT NULL,
  submitter_id STRING NOT NULL,
  variation_id STRING NOT NULL,
  gene_id STRING,
  gene_symbol STRING,
  variant_name STRING,
  ep_name STRING,
  ep_classification STRING,
  ep_classif_type STRING,
  ep_last_evaluated_date DATE,
  case_report_lab_name STRING,
  case_report_lab_id STRING,
  case_report_lab_classification STRING,
  case_report_lab_classif_type STRING,
  case_report_lab_date_reported DATE,
  gc_scv_acxn STRING,
  gc_scv_first_in_clinvar DATE,
  gc_scv_local_key STRING,
  case_report_sample_id STRING,
  lab_scv_classification STRING,
  lab_scv_classif_type STRING,
  lab_scv_last_evaluated DATE,
  lab_scv_first_in_clinvar DATE,
  lab_scv_before_gc_scv STRING,
  lab_scv_in_clinvar_as_of_release STRING,
  ep_diff_alert STRING,
  lab_diff_alert STRING,
  classification_comment STRING
)
;

CREATE OR REPLACE TABLE `variation_tracker.alert_type`
AS
SELECT * FROM UNNEST([
  STRUCT(NULL AS sort_order, '' AS label),
  (0, 'Out of Date'),
  (1, 'P/LP vs Newer VUS/B/LB'),
  (2, 'VUS vs Newer P/LP'),
  (3, 'VUS vs Newer B/LB'),
  (4, 'B/LB vs Newer P/LP'),
  (5, 'B/LB vs Newer VUS')
])
WHERE NOT sort_order IS NULL
;
