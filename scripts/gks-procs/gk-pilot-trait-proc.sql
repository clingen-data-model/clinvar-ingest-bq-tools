CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_trait_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_trait`
      as
        select
          scv.id as scv_id,
          scv.version as scv_ver,
          FORMAT('%%s.%%i', scv.id, scv.version) as full_scv_id,
          ts.id as trait_set_id,
          ts.type as trait_set_type,
          scv.clinical_assertion_trait_set_id as ca_trait_set_id,
          cat.id as cat_id,
          cat.name as cat_name,
          t.id as trait_id,
          ca_trait_id,
          STRUCT (
            FORMAT("clinvarTrait:%%s",t.id) as id,
            t.type as type,
            IFNULL(t.name, 'None') as label,
            IF(
              t.medgen_id is null, null,
              [
                -- for now just do medgen, leave the other xrefs for later
                STRUCT(
                    STRUCT (
                    t.medgen_id as code,
                    "https://www.ncbi.nlm.nih.gov/medgen/" as system
                    ) as coding,
                  "exactMatch" as relation
                )
              ]
            ) as mappings
          ) as condition
        from `%s.gk_pilot_scv` scv
        join `%s.clinical_assertion_trait_set` cats
        on
          scv.clinical_assertion_trait_set_id = cats.id
        cross join unnest(cats.clinical_assertion_trait_ids) as ca_trait_id
        join `%s.clinical_assertion_trait` cat
        on
          cat.id = ca_trait_id
        left join `%s.trait` t
        on
          t.id = cat.trait_id
        left join `%s.trait_set` ts
        on
          ts.id = scv.trait_set_id
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);

  END FOR;

END;


-- CREATE OR REPLACE TABLE `%s.gk_pilot_ts_lookup`
-- as
-- select
--   ts.id as trait_set_id, ts.type as trait_set_type,
--   ARRAY_TO_STRING((ARRAY_AGG(trait_id RESPECT NULLS ORDER BY trait_id)), '|','NULL') as traits
-- from `%s.trait_set` ts
-- cross join unnest(ts.trait_ids) as trait_id
-- join `%s.trait` t
-- on
--   t.id = trait_id
-- group by ts.id, ts.type
-- ;



-- -- NOTE: WE ARE CHANGING the NULL trait_set_id values in an original clinical assertion table here (BE CAREFUL?)
-- -- -- still need to make sure all trait_set_ids are right for the gks cats table
-- -- select
-- --   ca.trait_set_id,
-- --   x.*,
-- --   tslu.*
-- UPDATE `%s.clinical_assertion` ca
-- set ca.trait_set_id = tslu.trait_set_id
-- from
-- (
--   select
--     gkt.scv_id, gkt.trait_set_id,
--     ARRAY_TO_STRING((ARRAY_AGG(gkt.trait_id RESPECT NULLS ORDER BY gkt.trait_id)), '|','NULL') as traits
--   from `%s.gk_pilot_traits` gkt
--   group by gkt.scv_id, gkt.trait_set_id

--   -- 250,023 of  are null trait_set_ids
--   -- 3,909,572 have trait_set_ids (unclear how confident we are on these)
--   -- total of 4,159,595 records
--   -- some observations below
--   --CN166718 replaced by C5555857
--   --CN181497 replaced by CN204472 (not clear)
--   --CN043578 replaced by C4082197

-- ) x
-- left join `%s.gk_pilot_ts_lookup` tslu
-- on
--   tslu.traits = x.traits
-- -- join `clinvar_2024_08_05_v1_6_62.clinical_assertion` ca
-- -- on x.scv_id = ca.id
-- where
--   x.trait_set_id is null
--   and tslu.trait_set_id is not null
--   and x.scv_id = ca.id
--   -- and ca.trait_set_id is  null
-- ;
