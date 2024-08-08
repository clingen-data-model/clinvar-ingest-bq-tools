#!/bin/bash
bq extract \
  --destination_format NEWLINE_DELIMITED_JSON \
  --compression GZIP \
  'clinvar_2024_08_05_v1_6_62.variation_identity' \
  gs://clinvar-gk-pilot/2024-08-05/stage/vi.json.gz
  # gs://clinvar-gk-pilot/20??-??-??/dev/vi.json.gz