-- *****************  clinvar_genes & clinvar_single_gene_variations *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_single_gene_variations` 
(
  variation_id	STRING NOT NULL,	
  gene_id	STRING NOT NULL,	
  relationship_type STRING,
  source STRING,
  mane_select BOOLEAN DEFAULT FALSE,
  somatic BOOLEAN DEFAULT FALSE,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_genes`
( 
  id STRING NOT NULL,
  symbol STRING,
  hgnc_id STRING,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_submitters *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_submitters` 
(	
  id	STRING,
  current_name	STRING,
  current_abbrev STRING,
  cvc_abbrev STRING,
  org_category STRING,
  all_names	ARRAY<STRING>,
  all_abbrevs	ARRAY<STRING>,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_variations *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_variations`
( 
  id STRING NOT NULL,
  name STRING,
  mane_select BOOLEAN DEFAULT FALSE,
  gene_id STRING,
  symbol STRING,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_vcvs *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_vcvs`
(
  variation_id STRING NOT NULL,
  id STRING NOT NULL, 
  version INT64 NOT NULL, 
  full_vcv_id STRING,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_vcv_classifications *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_vcv_classifications`
(
  variation_id STRING NOT NULL,
  vcv_id STRING NOT NULL,
  statement_type STRING NOT NULL,
  rank INT64 NOT NULL, 
  review_status STRING,
  last_evaluated DATE,
  agg_classification_description STRING,
  num_submitters INT64,
  num_submissions INT64,
  most_recent_submission DATE,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_rcvs *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_rcvs`
(
  variation_id STRING NOT NULL,
  trait_set_id STRING,
  id STRING NOT NULL, 
  version INT64 NOT NULL, 
  full_rcv_id STRING,
  vcv_id STRING,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_rcv_classifications *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_rcv_classifications`
(
  variation_id STRING NOT NULL,
  trait_set_id STRING,
  rcv_id STRING NOT NULL,
  statement_type STRING NOT NULL,
  rank INT64 NOT NULL, 
  review_status STRING,
  clinical_impact_assertion_type STRING,
  clinical_impact_clinical_significance STRING,
  last_evaluated DATE,
  agg_classification_description STRING,
  num_submissions INT64,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_scvs *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_scvs`
(
  variation_id STRING NOT NULL,
  id STRING NOT NULL, 
  version INT NOT NULL, 
  full_scv_id STRING,
  statement_type STRING NOT NULL,
  original_proposition_type STRING,
  gks_proposition_type STRING,
  clinical_impact_assertion_type STRING,
  clinical_impact_clinical_significance STRING,
  rank INT NOT NULL, 
  review_status STRING,
  last_evaluated DATE,
  local_key STRING,
  classif_type STRING,
  clinsig_type INT,
  classification_label STRING,
  classification_abbrev STRING,
  submitted_classification STRING,
  classification_comment STRING,
  submitter_id STRING,
  submitter_name STRING,
  submitter_abbrev STRING,
  submission_date DATE,
  origin STRING,
  affected_status STRING,
  method_type STRING,
  rcv_accession_id STRING,
  trait_set_id STRING,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);

-- *****************  clinvar_gc_scvs *****************
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_gc_scvs`
(
  variation_id STRING NOT NULL,
  id STRING NOT NULL, 
  version INT NOT NULL, 
  submitter_id STRING,
  method_desc STRING,
  method_type STRING,
  lab_name STRING,
  lab_date_reported DATE,
  lab_id STRING,
  lab_classification STRING,
  lab_classif_type STRING,
  lab_type STRING,
  sample_id STRING,
  start_release_date DATE,
  end_release_date DATE,
  deleted_release_date DATE
);


-- -- initialize submitter info by release based on clinical_assertion release info,
-- --  36 very old submitter ids existed before 2019-07-01 which need to be manually 
-- --  loaded and provided to create the full submitter table pre-2019-07-01

-- CREATE or REPLACE TABLE `clinvar_2019_06_01_v0.pre_2019_07_01_submitter`
-- (
--   id	STRING,
--   current_name	STRING,
--   current_abbrev STRING,
--   cvc_abbrev STRING,
--   org_category STRING,
--   all_names	ARRAY<STRING>,
--   all_abbrevs	ARRAY<STRING>
-- );

-- INSERT `clinvar_2019_06_01_v0.pre_2019_07_01_submitter` (id, current_name, current_abbrev, org_category)
-- VALUES("1237", "Cincinnati Children's Hospital Medical Center", null, "other"),
--       ("279559", "Centogene AG - the Rare Disease Company", null, "other"),
--       ("500168", "Samuels Laboratory (NHGRI/NIH)", null, "other"),
--       ("500266", "Precancer Genomics (Leeds Institute of Molecular Medicine)", null, "other"),
--       ("504846", "<OrgID  504846>", null, "other"),
--       ("504870", "<OrgID  504870>", null, "other"),
--       ("504875", "Human and Clinical Genetics", null, "other"),
--       ("505190", "<OrgID  505190>", null, "other"),
--       ("505191", "<OrgID  505191>", null, "other"),
--       ("505192", "<OrgID  505192>", null, "other"),
--       ("505193", "<OrgID  505193>", null, "other"),
--       ("505194", "<OrgID  505194>", null, "other"),
--       ("505204", "<OrgID  505204>", null, "other"),
--       ("505225", "<OrgID  505225>", null, "other"),
--       ("505229", "<OrgID  505229>", null, "other"),
--       ("505239", "ISCA Site 13", null, "other"),
--       ("505261", "<OrgID  505261>", null, "other"),
--       ("505326", "Yardena Samuels Lab (NHGRI)", null, "other"),
--       ("505327", "<OrgID  505327>", null, "other"),
--       ("505355", "<OrgID  505355>", null, "other"),
--       ("505406", "<OrgID  505406>", null, "other"),
--       ("505428", "<OrgID  505428>", null, "other"),
--       ("505449", "<OrgID  505449>", null, "other"),
--       ("505508", "<OrgID  505508>", null, "other"),
--       ("505521", "<OrgID  505521>", null, "other"),
--       ("505557", "<OrgID  505557>", null, "other"),
--       ("505607", "<OrgID  505607>", null, "other"),
--       ("505649", "Department of Genetics (University Medical Center Groningen)", null, "other"),
--       ("505655", "<OrgID  505655>", null, "other"),
--       ("505689", "<OrgID  505689>", null, "other"),
--       ("505694", "<OrgID  505694>", null, "other"),
--       ("506099", "Genome.One, G1", "G1", "other"),
--       ("506309", "<OrgID  506309>", null, "other"),
--       ("506354", "<OrgID  506354>", null, "other"),
--       ("506387", "<OrgID  506387>", null, "other"),
--       ("507238", "<OrgID  507238>", null, "other"),
--       ("9999990", "<OrgID  9999990>", null, "other"),
--       ("9999991", "<OrgID  9999991>", null, "other")
-- ;

-- create or replace table `clinvar_2019_06_01_v0.submitter`
-- as
-- with ca as (
--   select 
--     ca.release_date, 
--     ca.submitter_id 
--   from `clinvar_2019_06_01_v0.clinical_assertion` ca 
--   group by ca.release_date, ca.submitter_id
-- )
-- select 
--   ca.release_date,
--   ca.submitter_id,
--   s.current_name,
--   s.current_abbrev,
--   s.org_category,
--   s.all_names,
--   s.all_abbrevs  
-- from ca
-- join `clinvar_2019_06_01_v0.pre_2019_07_01_submitter` s
-- on
--   s.id = ca.submitter_id
-- union all
-- select 
--   ca.release_date,
--   ca.submitter_id,
--   s.current_name,
--   s.current_abbrev,
--   s.org_category,
--   s.all_names,
--   s.all_abbrevs  
-- from ca
-- join `clinvar_2019_07_01_v1_1_0_m2.submitter` s
-- on
--   s.id = ca.submitter_id
-- ;


-- ********************** additional working data concerns below *************

-- select  distinct ss.submitter_id, ss.id, ss.variation_id, ss.release_date
-- from `clinvar_2019_06_01_v0.scv_summary` ss
-- where not exists (
--   select id
--   from `clinvar_ingest.clinvar_submitters` cs
--   where cs.id = ss.submitter_id
-- )
--  and ss.release_date = DATE '2015-03-06'
-- -- group by ss.submitter_id
-- order by 1

-- -- repair bad submitter ids pre-201907
-- UPDATE `clinvar_2019_06_01_v0.scv_summary` 
-- SET scv.submitter_id = vals.good_id
-- FROM (
--   SELECT '1' bad_id, '500139' good_id UNION ALL
--   SELECT '500006' bad_id, '506018' good_id UNION ALL
--   SELECT '500007' bad_id, '506018' good_id UNION ALL
--   SELECT '500008' bad_id, '506018' good_id UNION ALL
--   SELECT '500009' bad_id, '506018' good_id UNION ALL
--   SELECT '500010' bad_id, '506018' good_id UNION ALL
--   SELECT '500011' bad_id, '506018' good_id UNION ALL
--   SELECT '500064' bad_id, '1160' good_id UNION ALL
--   SELECT '500166' bad_id, '500133' good_id UNION ALL
--   SELECT '505708' bad_id, '506834' good_id UNION ALL
--   SELECT '505333' bad_id, '1006' good_id UNION ALL
--   SELECT '505345' bad_id, '25969' good_id UNION ALL
--   SELECT '505346' bad_id, '505572' good_id UNION ALL
--   SELECT '505363' bad_id, '320418' good_id UNION ALL
--   SELECT '500121' bad_id, '506047' good_id UNION ALL
--   SELECT '500129' bad_id, '505260' good_id UNION ALL
--   SELECT '500145' bad_id, '25969' good_id UNION ALL
--   SELECT '505751' bad_id, '505642' good_id UNION ALL
--   SELECT '505978' bad_id, '506617' good_id UNION ALL
--   SELECT '506000' bad_id, '506627' good_id UNION ALL
--   SELECT '504961' bad_id, '1006' good_id UNION ALL
--   SELECT '504815' bad_id, '506543' good_id UNION ALL
--   SELECT '500265' bad_id, '500126' good_id UNION ALL
--   SELECT '500293' bad_id, '507238' good_id UNION ALL
--   SELECT '500313' bad_id, '1238' good_id UNION ALL
--   SELECT '504819' bad_id, '504864' good_id UNION ALL
--   SELECT 'Sharing Clinical Report Project' bad_id, '500037' good_id UNION ALL
--   SELECT 'Sharing Clinical Report Project (SCRP)' bad_id, '500037' good_id UNION ALL
--   SELECT 'ISCA Consortium' bad_id, '505237' good_id UNION ALL
--   SELECT 'ARUP' bad_id, '506018' good_id UNION ALL
--   SELECT 'LabCorp' bad_id, '500026' good_id UNION ALL
--   SELECT '505239' bad_id, '319864' good_id UNION ALL
--   SELECT 'Emory Genetics Laboratory' bad_id, '500060' good_id UNION ALL
--   SELECT 'Ambry Genetics,Ambry Genetics Corp' bad_id, '61756' good_id UNION ALL
--   SELECT '505689' bad_id, '505820' good_id UNION ALL
--   SELECT '504846' bad_id, '505291' good_id UNION ALL
--   SELECT '505229' bad_id, '505721' good_id UNION ALL
--   SELECT '505508' bad_id, '505641' good_id
-- ) vals
-- WHERE vals.bad_id = submitter_id
-- ;

-- additional scripts to clean up bogus or modified submitter_ids lost over time
-- SELECT id, submitter_ids
-- FROM (
--   SELECT id, array_agg(distinct submitter_id) as submitter_ids
--   FROM `clinvar_ingest.clinvar_scvs` 
--   group by id
--   HAVING COUNT(distinct submitter_id) > 1 
-- )
-- ;

-- update `clinvar_2019_06_01_v0.scv_summary` ss
--   set submitter_id = "26957"
-- where id = "SCV000079669"
-- ;

-- update `clinvar_ingest.clinvar_scvs` cs
--   set submitter_id = "26957"
-- where id = "SCV000079669"
-- ;

-- update `clinvar_2019_06_01_v0.scv_summary` ss
-- SET ss.submitter_id = scv.submitter_id
-- FROM (
--   SELECT scv1.id, scv1.submitter_id
--   FROM `clinvar_ingest.clinvar_scvs` scv1
--   where scv1.submitter_id not in ("500029", "500062")
--   and exists 
--   (
--     select scv2.id from `clinvar_ingest.clinvar_scvs` scv2 
--     where scv2.id = scv1.id and scv2.submitter_id in ("500029", "500062")
--   )
--   group by scv1.id, scv1.submitter_id
-- ) scv
-- WHERE ss.submitter_id in ("500029", "500062") and scv.id = ss.id 
-- ; 

-- update `clinvar_ingest.clinvar_scvs` cs
-- SET cs.submitter_id = scv.submitter_id
-- FROM (
--   SELECT scv1.id, scv1.submitter_id
--   FROM `clinvar_ingest.clinvar_scvs` scv1
--   where scv1.submitter_id not in ("500029", "500062") 
--   and exists 
--   (
--     select scv2.id from `clinvar_ingest.clinvar_scvs` scv2 
--     where scv2.id = scv1.id and scv2.submitter_id in ("500029", "500062")
--   )
--   group by scv1.id, scv1.submitter_id
-- ) scv
-- WHERE cs.submitter_id in ("500029", "500062") and scv.id = cs.id 
-- ; 

-- CREATE OR REPLACE TABLE `clinvar_2019_06_01_v0.submitter`
-- (
--   id STRING,
--   current_name STRING,
--   current_abbrev STRING,
--   org_category STRING,
--   all_names	ARRAY<STRING>,
--   all_abbrevs	ARRAY<STRING>
-- );

-- INSERT INTO  `clinvar_2019_06_01_v0.submitter`
--   (id, current_name, org_category)
-- VALUES ("500168", "Samuels NHGRI/NIH", "other")
-- ;
-- INSERT INTO  `clinvar_2019_06_01_v0.submitter`
--   (id, current_name, org_category)
-- VALUES ("500266", "Leeds Institute of Molecular Medicine (LIMM)", "other")
-- ;
-- INSERT INTO  `clinvar_2019_06_01_v0.submitter`
--   (id, current_name, org_category)
-- VALUES ("505239", "ISCA site 13", "other")




-- housekeeping issue!
-- -- remove duplicate variation records by replacing variation view with a table from 2022_07_24 dataset
-- -- which contains 107 duplicate variation records!
-- DROP VIEW `clinvar_2022_07_24_v1_6_46.variation`;
-- CREATE OR REPLACE TABLE `clinvar_2022_07_24_v1_6_46.variation`
-- AS
-- SELECT 
--   datarepo_row_id,
--   name,
--   variation_type,
--   allele_id,
--   release_date,
--   subclass_type,
--   protein_change,
--   content,
--   id,
--   descendant_ids,
--   num_chromosomes,
--   num_copies,
--   child_ids
-- FROM (
--   SELECT 
--     *, 
--     ROW_NUMBER() OVER (PARTITION BY release_date, id) row_number
--     FROM `datarepo-550c0177.clinvar_2022_07_24_v1_6_46.variation`
-- )
-- WHERE row_number = 1
-- ;

-- -- housekeeping... the clinvar_2019_06_01_v0.variation table can end up with multiple names for the same variation id
-- --  to correct this we will simply pick the first one and delete the others before running the script below
-- DELETE FROM `clinvar_2019_06_01_v0.variation` v
-- WHERE EXISTS (
--   SELECT v2.release_date, v2.id, v2.first_name
--   FROM (
--     SELECT release_date, id, ARRAY_AGG(name)[OFFSET(0)] as first_name
--     FROM `clinvar_2019_06_01_v0.variation` 
--     GROUP BY release_date, id
--     HAVING count(name) > 1
--   ) v2
--   WHERE v2.release_date = v.release_date AND v2.id = v.id AND v2.first_name <> v.name
-- );

-- one variant processing of SCVs per release

-- -- housekeeping, remove any duplicate rows in scv.summary for the snapshot dbs clinvar_2019_06_01_v0, 
-- --   clinvar_2021_03_02_v1_2_9(SCV001164315), clinvar_2022_07_24_v1_6_46(1,337 duplicates?!)
-- CREATE OR REPLACE TABLE `clinvar_2022_07_24_v1_6_46.scv_summary`
-- AS
-- SELECT 
--   release_date,
--   id,
--   version,
--   variation_id,
--   last_evaluated,
--   rank,
--   review_status,
--   clinvar_stmt_type,
--   cvc_stmt_type,
--   submitted_classification,
--   classif_type,
--   significance,
--   submitter_id,
--   submission_date,
--   origin,
--   affected_status,
--   method_type,
--   last_processed_curation_action,
--   pending_curation_action	
-- FROM (
--   SELECT *, ROW_NUMBER() OVER (PARTITION BY release_date, variation_id, id, version) row_number
--   FROM `clinvar_2022_07_24_v1_6_46.scv_summary`
-- )
-- WHERE row_number = 1
-- ;