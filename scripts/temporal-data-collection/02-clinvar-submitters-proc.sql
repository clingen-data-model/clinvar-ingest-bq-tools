-- NOTE : SEE additional scripts at end of this page for info on reloading the submitter data prior to 2019-07-01!!!

-- verify where the last update of this table was and only process releases beyond that
-- select release_date from `clinvar_ingest.clinvar_submitters` group by release_date order by 1 desc;

CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_submitters`(
  schema_name STRING, 
  release_date DATE,
  previous_release_date DATE
)
BEGIN
  -- validate the last release date clinvar_submitters
  CALL `clinvar_ingest.validate_last_release`('clinvar_submitters',previous_release_date);
  
  -- deleted submitters (where it exists in clinvar_submitters (for deleted_release_date is null), but doesn't exist in current data set )
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_submitters` cs
      SET 
        deleted_release_date = %T,
        deleted_count = deleted_count + 1
    WHERE 
      cs.deleted_release_date is NULL
      AND 
      NOT EXISTS (
        SELECT 
          s.id 
        FROM `%s.submitter` s
        WHERE 
          s.id = cs.id
      )
  """, release_date, schema_name);

  -- updated submitters
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `clinvar_ingest.clinvar_submitters` cs
      SET 
        current_name = s.current_name, 
        all_names = s.all_names, 
        all_abbrevs = s.all_abbrevs, 
        current_abbrev = s.current_abbrev, 
        org_category = s.org_category,
        end_release_date = s.release_date,
        deleted_release_date = NULL
    FROM `%s.submitter` s
    WHERE 
      s.id = cs.id
  """, schema_name);

  -- new variations
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `clinvar_ingest.clinvar_submitters` (
      id, 
      current_name, 
      current_abbrev, 
      cvc_abbrev, 
      org_category, 
      all_names, 
      all_abbrevs, 
      start_release_date, 
      end_release_date
    )
    SELECT 
      s.id, 
      s.current_name,
      s.current_abbrev,
      IFNULL(s.current_abbrev, csa.current_abbrev) as cvc_abbrev,
      s.org_category,  
      s.all_names, 
      s.all_abbrevs, 
      s.release_date as start_release_date, 
      s.release_date as end_release_date
    FROM `%s.submitter` s
    LEFT JOIN `clinvar_ingest.clinvar_submitter_abbrevs` csa 
    ON 
      csa.submitter_id = s.id
    WHERE 
      NOT EXISTS (
        SELECT 
          cs.id 
        FROM `clinvar_ingest.clinvar_submitters` cs
        WHERE 
          cs.id = s.id
      )
  """, schema_name);

END;



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
-- ;

