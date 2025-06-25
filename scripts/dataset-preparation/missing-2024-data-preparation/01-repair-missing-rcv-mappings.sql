
-- 2024-03-11 x
-- 2024-03-17 m clinvar_2024_03_17_v1_6_62
-- 2024-03-24 m clinvar_2024_03_24_v1_6_62
-- 2024-03-31 x
-- 2024-04-07 m clinvar_2024_04_07_v1_6_62
-- 2024-04-16 m clinvar_2024_04_16_v1_6_62
-- 2024-04-21 m clinvar_2024_04_21_v1_6_62
-- 2024-05-02 x
-- 2024-05-09 m clinvar_2024_05_09_v1_6_62
-- 2024-05-13 m clinvar_2024_05_13_v1_6_62
-- 2024-05-19 m clinvar_2024_05_19_v1_6_62
-- 2024-05-27 m clinvar_2024_05_27_v1_6_62
-- 2024-06-03 x

-- after copying over the above missing datasets from stage to dev
-- run the dataset-preparation scripts on those datasets and then proceed below to pull over the missing somatic records

-- STEP 1
-- repair missing rcv_mapping "RCV003883131" in the 2024-03-06, 2024-03-31 datasets by copying the missing entry from the 2024-05-02 dataset

-- first for the Mar.11.2024 dataset
INSERT INTO `clingen-dev.clinvar_2024_03_11_v2_1_0.rcv_mapping`
(
  rcv_accession,
  scv_accessions,
  trait_set_id,
  trait_set_content,
  release_date
)
SELECT
  rcv_accession,
  scv_accessions,
  trait_set_id,
  trait_set_content,
  DATE'2024-03-11'
from `clingen-dev.clinvar_2024_05_02_v2_1_0.rcv_mapping`
where
  rcv_accession = "RCV003883131";

-- now for the Mar.31.2024 dataset
INSERT INTO `clingen-dev.clinvar_2024_03_31_v2_1_0.rcv_mapping`
(
  rcv_accession,
  scv_accessions,
  trait_set_id,
  trait_set_content,
  release_date
)
SELECT
  rcv_accession,
  scv_accessions,
  trait_set_id,
  trait_set_content,
  DATE'2024-03-11'
from `clingen-dev.clinvar_2024_05_02_v2_1_0.rcv_mapping`
where
  rcv_accession = "RCV003883131";
