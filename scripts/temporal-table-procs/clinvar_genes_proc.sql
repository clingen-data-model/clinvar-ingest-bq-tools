CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_genes_proc`(start_with DATE)
BEGIN

  FOR rec IN 
  (
    select s.schema_name, s.release_date, s.prev_release_date, s.next_release_date FROM clinvar_ingest.schemas_on_or_after(start_with) as s
  )
  DO

    -- deleted genes (where it exists in clinvar_genes (for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_genes` cg
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        cg.deleted_release_date is NULL AND 
        NOT EXISTS 
        (
          SELECT g.id 
          FROM `%s.gene` g
          WHERE g.id = cg.id
        )
    """, rec.release_date, rec.schema_name);

    -- deleted single gene vars (where it exists in clinvar_single_gene_variations(for deleted_release_date is null), but doesn't exist in current data set )
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_single_gene_variations` csgv
        SET 
          deleted_release_date = %T,
          deleted_count = deleted_count + 1
      WHERE 
        csgv.deleted_release_date is NULL AND
        NOT EXISTS 
        (
          SELECT sgv.variation_id 
          FROM `%s.single_gene_variation` sgv
          WHERE sgv.variation_id = csgv.variation_id 
        )
    """, rec.release_date, rec.schema_name);

    -- updated genes
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_genes` cg
        SET 
          hgnc_id = g.hgnc_id,
          symbol = g.symbol,
          end_release_date = g.release_date,
          deleted_release_date = NULL
      FROM `%s.gene` g
      WHERE g.id = cg.id
    """, rec.schema_name);

      -- updated single gene variations
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `clinvar_ingest.clinvar_single_gene_variations` csgv
        SET 
          gene_id = sgv.gene_id,
          mane_select = sgv.mane_select,
          somatic = sgv.somatic,
          relationship_type = sgv.relationship_type,
          source = sgv.source,
          end_release_date = sgv.release_date,
          deleted_release_date = NULL
      FROM `%s.single_gene_variation` sgv
      WHERE sgv.variation_id = csgv.variation_id 
    """, rec.schema_name);

    -- new genes
    EXECUTE IMMEDIATE FORMAT("""
      INSERT `clinvar_ingest.clinvar_genes` 
      (
        id, symbol, hgnc_id, start_release_date, end_release_date
      )
      SELECT 
        g.id, 
        g.symbol, 
        g.hgnc_id, 
        g.release_date as start_release_date, 
        g.release_date as end_release_date
      FROM `%s.gene` g
      WHERE 
        NOT EXISTS 
        (
          SELECT cg.id 
          FROM `clinvar_ingest.clinvar_genes` cg
          WHERE cg.id = g.id 
        )
    """, rec.schema_name);

    -- new single gene variations
    EXECUTE IMMEDIATE FORMAT("""
      INSERT `clinvar_ingest.clinvar_single_gene_variations` 
      (
        gene_id, 
        variation_id, 
        relationship_type, 
        source, 
        mane_select, 
        somatic, 
        start_release_date, 
        end_release_date
      )
      SELECT 
        sgv.gene_id,
        sgv.variation_id,
        sgv.relationship_type,
        sgv.source,
        sgv.mane_select,
        sgv.somatic,
        sgv.release_date as start_release_date, 
        sgv.release_date as end_release_date
      FROM `%s.single_gene_variation` sgv
      WHERE 
        NOT EXISTS 
        (
          SELECT csgv.variation_id 
          FROM `clinvar_ingest.clinvar_single_gene_variations` csgv
          WHERE sgv.variation_id = csgv.variation_id
        )
    """, rec.schema_name);

  END FOR;       

END;


-- NOTE: we don't need clinvar_gene_assoications captured across all datasets
--       for now we comment out the clinvar_gene_associations create, update and insert statements
--       ONLY clinvar_genes and clinvar_single_gene_variations should be built until there is a need.


-- CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_gene_associations` 
-- (
--   variation_id	STRING NOT NULL,	
--   gene_id	STRING NOT NULL,		
--   relationship_type	STRING,		
--   source	STRING,	
--   start_release_date DATE,
--   end_release_date DATE,
--   deleted_release_date DATE,
--   deleted_count INT DEFAULT 0
-- );

-- -- FIX gene_association duplicate row issues by
-- --     removing dupes and saving as table 
-- DROP VIEW `clinvar_2022_07_24_v1_6_46.gene_association`;
-- CREATE OR REPLACE TABLE `clinvar_2022_07_24_v1_6_46.gene_association`
-- AS
-- SELECT 
--   x.datarepo_row_id,
--   x.source,
--   x.variation_id,
--   x.release_date,			
--   x.relationship_type,				
--   x.content,		
--   x.gene_id				
-- FROM (
--   SELECT
--       *,
--       ROW_NUMBER()
--           OVER (PARTITION BY gene_id, variation_id)
--           row_number
--   FROM `datarepo-550c0177.clinvar_2022_07_24_v1_6_46.gene_association`
-- ) x
-- WHERE x.row_number = 1
-- ;
-- CREATE OR REPLACE PROCEDURE `clinvar_ingest.clinvar_genes_proc`(start_with DATE)
-- BEGIN

--   FOR rec IN (select s.schema_name, s.release_date, s.next_release_date FROM clinvar_ingest.schemas_on_or_after(start_with) as s)
--   DO

--     -- -- deleted genes (where it exists in clinvar_genes (for deleted_release_date is null), but doesn't exist in current data set )
--     -- EXECUTE IMMEDIATE FORMAT("""
--     --   UPDATE `clinvar_ingest.clinvar_genes` cg
--     --     SET deleted_release_date = %T,
--     --       deleted_count = deleted_count + 1
--     --   WHERE cg.deleted_release_date is NULL
--     --     AND NOT EXISTS (
--     --       SELECT g.id FROM `%s.gene` g
--     --       WHERE  g.release_date = %T AND g.id = cg.id
--     --     )
--     -- """, rec.release_date, rec.schema_name, rec.release_date);

--     -- -- deleted gene assocs (where it exists in clinvar_gene_associations (for deleted_release_date is null), but doesn't exist in current data set )
--     -- EXECUTE IMMEDIATE FORMAT("""
--     --   UPDATE `clinvar_ingest.clinvar_gene_associations` cga
--     --     SET deleted_release_date = %T,
--     --       deleted_count = deleted_count + 1
--     --   WHERE cga.deleted_release_date is NULL
--     --     AND NOT EXISTS (
--     --       SELECT ga.gene_id, ga.variation_id FROM `%s.gene_association` ga
--     --       WHERE  ga.release_date = %T AND ga.variation_id = cga.variation_id AND ga.gene_id = cga.gene_id
--     --     )
--     -- """, rec.release_date, rec.schema_name, rec.release_date);

--     -- deleted single gene vars (where it exists in clinvar_single_gene_variations(for deleted_release_date is null), but doesn't exist in current data set )
--     EXECUTE IMMEDIATE FORMAT("""
--       UPDATE `clinvar_ingest.clinvar_single_gene_variations` csgv
--         SET deleted_release_date = %T,
--           deleted_count = deleted_count + 1
--       WHERE csgv.deleted_release_date is NULL
--         AND NOT EXISTS (
--           SELECT sgv.variation_id FROM `%s.single_gene_variation` sgv
--           WHERE  sgv.release_date = %T AND sgv.variation_id = csgv.variation_id 
--         )
--     """, rec.release_date, rec.schema_name, rec.release_date);

--     -- -- updated genes
--     -- EXECUTE IMMEDIATE FORMAT("""
--     --   UPDATE `clinvar_ingest.clinvar_genes` cg
--     --     SET 
--     --       hgnc_id = g.hgnc_id,
--     --       symbol = g.symbol,
--     --       end_release_date = g.release_date,
--     --       deleted_release_date = NULL
--     --   FROM `%s.gene` g
--     --   WHERE g.release_date = %T AND g.id = cg.id
--     -- """, rec.schema_name, rec.release_date);

--     -- -- updated gene associations
--     -- EXECUTE IMMEDIATE FORMAT("""
--     --   UPDATE `clinvar_ingest.clinvar_gene_associations` cga
--     --     SET 
--     --       relationship_type = ga.relationship_type,
--     --       source = ga.source,
--     --       end_release_date = ga.release_date,
--     --       deleted_release_date = NULL
--     --   FROM `%s.gene_association` ga
--     --   WHERE ga.release_date = %T AND ga.variation_id = cga.variation_id AND ga.gene_id = cga.gene_id
--     -- """, rec.schema_name, rec.release_date);

--       -- updated single gene variations
--     EXECUTE IMMEDIATE FORMAT("""
--       UPDATE `clinvar_ingest.clinvar_single_gene_variations` csgv
--         SET 
--           gene_id = sgv.gene_id,
--           mane_select = sgv.mane_select,
--           somatic = sgv.somatic,
--           relationship_type = sgv.relationship_type,
--           source = sgv.source,
--           end_release_date = sgv.release_date,
--           deleted_release_date = NULL
--       FROM `%s.single_gene_variation` sgv
--       WHERE sgv.release_date = %T AND sgv.variation_id = csgv.variation_id 
--     """, rec.schema_name, rec.release_date);

--     -- -- new genes
--     -- EXECUTE IMMEDIATE FORMAT("""
--     --   INSERT `clinvar_ingest.clinvar_genes` 
--     --     (id, symbol, hgnc_id, start_release_date, end_release_date)
--     --   SELECT 
--     --     g.id, 
--     --     g.symbol, 
--     --     g.hgnc_id, 
--     --     g.release_date as start_release_date, 
--     --     g.release_date as end_release_date
--     --   FROM `%s.gene` g
--     --   WHERE g.release_date = %T
--     --   AND NOT EXISTS (
--     --      SELECT cg.id FROM `clinvar_ingest.clinvar_genes` cg
--     --      WHERE cg.id = g.id 
--     --   )
--     -- """, rec.schema_name, rec.release_date);

--     -- -- new gene associations
--     -- EXECUTE IMMEDIATE FORMAT("""
--     --   INSERT `clinvar_ingest.clinvar_gene_associations` 
--     --     (gene_id, variation_id, relationship_type, source, start_release_date, end_release_date)
--     --   SELECT 
--     --     ga.gene_id,
--     --     ga.variation_id,
--     --     ga.relationship_type,
--     --     ga.source,
--     --     ga.release_date as start_release_date, 
--     --     ga.release_date as end_release_date
--     --   FROM `%s.gene_association` ga
--     --   WHERE ga.release_date = %T
--     --   AND NOT EXISTS (
--     --      SELECT cga.gene_id, cga.variation_id FROM `clinvar_ingest.clinvar_gene_associations` cga
--     --      WHERE ga.variation_id = cga.variation_id AND ga.gene_id = cga.gene_id
--     --   )
--     -- """, rec.schema_name, rec.release_date);

--     -- new single gene variations
--     EXECUTE IMMEDIATE FORMAT("""
--       INSERT `clinvar_ingest.clinvar_single_gene_variations` 
--         (gene_id, variation_id, relationship_type, source, mane_select, somatic, start_release_date, end_release_date)
--       SELECT 
--         sgv.gene_id,
--         sgv.variation_id,
--         sgv.relationship_type,
--         sgv.source,
--         sgv.mane_select,
--         sgv.somatic,
--         sgv.release_date as start_release_date, 
--         sgv.release_date as end_release_date
--       FROM `%s.single_gene_variation` sgv
--       WHERE sgv.release_date = %T
--       AND NOT EXISTS (
--         SELECT csgv.variation_id FROM `clinvar_ingest.clinvar_single_gene_variations` csgv
--         WHERE sgv.variation_id = csgv.variation_id
--       )
--     """, rec.schema_name, rec.release_date);

--   END FOR;       

-- END;

