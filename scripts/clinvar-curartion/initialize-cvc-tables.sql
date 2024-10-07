CREATE OR REPLACE TABLE `clinvar_curator.cvc_clinvar_reviews`
(
  annotation_id STRING,
  date_added TIMESTAMP,
  status STRING,
  reviewer STRING,
  notes STRING,
  date_last_updated TIMESTAMP
)
;

CREATE OR REPLACE TABLE `clinvar_curator.cvc_clinvar_submissions`
(
  annotation_id STRING,
  scv_id STRING,
  scv_ver STRING,
  batch_id STRING
)
;

CREATE OR REPLACE TABLE `clinvar_curator.cvc_clinvar_batches`
(
  batch_id STRING,
  finalized_datetime TIMESTAMP
)
;