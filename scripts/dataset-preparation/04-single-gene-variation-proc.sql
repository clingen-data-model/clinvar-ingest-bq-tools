-- see below for helper / setup scripts
CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation`(
  schema_name STRING,
  release_date DATE
)
BEGIN
  -- single gene variation  plan
  --- step 1. create a table with columns variation_id, gene_id, somatic_flag 
  ---         where the variation_id is the pk. 
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s.single_gene_variation`( 
      release_date DATE NOT NULL,
      variation_id STRING NOT NULL,
      gene_id STRING NOT NULL,
      relationship_type STRING,
      source STRING,
      mane_select BOOL DEFAULT FALSE,
      somatic BOOL DEFAULT FALSE
    )
  """, schema_name);

  -- create a temp table that is the list of remaining variations so as to reduce the query cost of analyzing against the variation table.
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.temp_variation 
    AS 
    SELECT 
      v.id, 
      v.name,
      v.descendant_ids,
      v.subclass_type
    FROM `%s.variation` v
  """, schema_name);

  --- step 2. (Resolvable Gene Symbol in variation name takes precedence as "single gene for variant")
  ---         initialize the set with the extracted variation name gene symbols and the associated relationship info if available

  -- prioritize mane select transcripts in title of variant
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation` (
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source, 
      mane_select 
    )
    SELECT DISTINCT
      %T as release_date,
      v.id as variation_id,
      mane.gene_id,
      IFNULL(ga.relationship_type,'named gene not associated') as relationship_type, 
      IFNULL(ga.source,'cvc calculated') as source, 
      TRUE as mane_select
    FROM `clinvar_ingest.mane_select_gene_transcript` mane
    JOIN _SESSION.temp_variation v 
    ON 
      STARTS_WITH(v.name, mane.transcript_id)
    JOIN `clinvar_ingest.entrez_gene` g 
    ON 
      g.gene_id = mane.gene_id
    LEFT JOIN `%s.gene_association` ga 
    ON 
      ga.gene_id = g.gene_id 
      AND 
      ga.variation_id = v.id
  """, schema_name, release_date, schema_name);

    -- create a temp table that is the list of gene associations 
    --   for variations not yet in the single gene var table and 
    --   don't have the gene symbol ending in an -AS# suffix
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.temp_gene_assoc 
    AS 
    SELECT DISTINCT
      ga.variation_id, 
      ga.gene_id, 
      ga.relationship_type, 
      ga.source
    FROM `%s.gene_association` ga
    JOIN `clinvar_ingest.entrez_gene` g 
    ON 
      ga.gene_id = g.gene_id
    WHERE 
      NOT REGEXP_CONTAINS(g.symbol_from_authority, r'\\-AS\\d$') 
      AND
      NOT EXISTS (
        SELECT 
          sgv.variation_id
        FROM `%s.single_gene_variation` sgv
        WHERE 
          sgv.variation_id = ga.variation_id 
      )
  """, schema_name, schema_name);

    -- NOTE: clinvar has a handful of duplicate gene records that can change over time
    --      the plan will be to test the results of loading the variation_single_gene 
    --      table to verify that any variants with multiple genes are simply duplicates and 
    --      either one can be removed without an issue.

  -- clinvar perferred label hgvs-style format NM_0000.0(GENE):c.234... (not mane select but still in name)
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation`(
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source
    )
    WITH x AS (
      SELECT 
        v.id, 
        v.name, 
        REGEXP_EXTRACT(v.name, r'^N[A-Z]_[0-9]+\\.[0-9]+\\(([A-Za-z0-9\\-]+)\\)') as symbol
      FROM _SESSION.temp_variation v
      WHERE 
        REGEXP_CONTAINS(v.name, r'^N[A-Z]_[0-9]+\\.[0-9]+\\(([A-Za-z0-9\\-]+)\\)') 
        AND 
        NOT EXISTS (
          SELECT 
            sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE 
            sgv.variation_id = v.id 
        )
    )
    SELECT 
      %T as release_date,
      x.id as variation_id,
      g.gene_id, 
      IFNULL(ga.relationship_type,'named gene not associated') as relationship_type, 
      IFNULL(ga.source,'cvc calculated') as source
    FROM x 
    JOIN `clinvar_ingest.entrez_gene` g 
    ON 
      UPPER(g.symbol_from_authority) = UPPER(x.symbol) 
      AND 
      NOT REGEXP_CONTAINS(x.symbol, r'\\-AS\\d$') 
    LEFT JOIN _SESSION.temp_gene_assoc ga 
    ON 
      ga.variation_id = x.id
      AND 
      ga.gene_id = g.gene_id
  """, schema_name, schema_name, release_date); 

    -- star allele format, CYP2C19*10. 
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation`(
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source
    )
    WITH x AS (
      SELECT 
        v.id, 
        v.name, 
        REGEXP_EXTRACT(v.name,  r'^([A-Za-z0-9\\-]+)[\\*\\,]') as symbol
      FROM _SESSION.temp_variation v
      WHERE 
        REGEXP_CONTAINS(v.name,  r'^([A-Za-z0-9\\-]+)[\\*\\,]') 
        AND
        NOT EXISTS (
          SELECT 
            sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE 
          sgv.variation_id = v.id 
        )
    )
    SELECT 
      %T as release_date,
      x.id as variation_id, 
      g.gene_id,
      IFNULL(ga.relationship_type,'named gene not associated') as relationship_type, 
      IFNULL(ga.source,'cvc calculated') as source
    FROM x 
    JOIN `clinvar_ingest.entrez_gene` g 
    ON 
      UPPER(x.symbol) = UPPER(g.symbol_from_authority)
    LEFT JOIN _SESSION.temp_gene_assoc ga 
    ON 
      x.id = ga.variation_id 
      AND 
      g.gene_id = ga.gene_id
  """, schema_name, schema_name, release_date);

    --- step 3. for any variations remaining... load all variations with any 
    ---         genes that are mapped one-to-one from the gene association table
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation`(
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source
    )
    WITH x AS (
      SELECT 
        v.id
      FROM _SESSION.temp_variation v
      WHERE 
        NOT EXISTS (
          SELECT 
            sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE 
            sgv.variation_id = v.id 
        )
    )
    SELECT 
      %T as release_date,
      ga.variation_id, 
      STRING_AGG(ga.gene_id), 
      STRING_AGG(ga.relationship_type), 
      STRING_AGG(ga.source)
    FROM x
    JOIN _SESSION.temp_gene_assoc ga 
    ON 
      x.id = ga.variation_id
    GROUP BY 
      ga.variation_id
    HAVING 
      count(distinct ga.gene_id) = 1
  """, schema_name, schema_name, release_date);

    --- step 4. for any variations remaining... load any variant with one submitted gene that 
    ---          is not either "genes overlapped by variant" or "asserted, but not computed"
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation` (
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source 
    )
    WITH x AS (
      SELECT 
        v.id
      FROM _SESSION.temp_variation v
      WHERE 
        NOT EXISTS (
          SELECT 
            sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE 
            sgv.variation_id = v.id 
        )
    )
    SELECT 
      %T as release_date,
      ga.variation_id, 
      STRING_AGG(ga.gene_id), 
      STRING_AGG(ga.relationship_type), 
      STRING_AGG(ga.source)
    FROM x
    JOIN _SESSION.temp_gene_assoc ga 
    ON 
      x.id = ga.variation_id
    WHERE 
      ga.relationship_type not in ('genes overlapped by variant' , 'asserted, but not computed') 
      AND
      ga.source = 'submitted'
    GROUP BY 
      ga.variation_id
    HAVING 
      count(distinct ga.gene_id) = 1
  """, schema_name, schema_name, release_date);

    --- step 5. for any variations remaining... load any variations with a "within single gene" 
    ---         as long as it is associated to only one gene for that variant
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation` (
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source
    )
    WITH x AS (
      SELECT 
        v.id
      FROM _SESSION.temp_variation v
      WHERE 
        NOT EXISTS (
          SELECT 
            sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE 
            sgv.variation_id = v.id 
        )
    )
    SELECT 
      %T as release_date,
      ga.variation_id, 
      STRING_AGG(ga.gene_id), 
      STRING_AGG(ga.relationship_type), 
      STRING_AGG(ga.source)
    FROM x
    JOIN _SESSION.temp_gene_assoc ga 
    ON 
      x.id = ga.variation_id
    WHERE 
      ga.relationship_type = 'within single gene'
    GROUP BY 
      ga.variation_id
    HAVING 
      count(ga.gene_id) = 1
  """, schema_name, schema_name, release_date);

    --- last step. for any variations remaining... load any haplotype or genotype variations only if all the children have the same gene_id
  EXECUTE IMMEDIATE FORMAT("""
    INSERT INTO `%s.single_gene_variation` (
      release_date, 
      variation_id, 
      gene_id, 
      relationship_type, 
      source 
    )
    WITH x AS (
      SELECT 
        v.id
      FROM _SESSION.temp_variation v
      WHERE 
        NOT EXISTS (
          SELECT 
            sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE 
            sgv.variation_id = v.id 
        )
    )
    SELECT 
      %T as release_date, 
      v.id as variation_id, 
      STRING_AGG(ga.gene_id) as gene_id, 
      'association not provided by clinvar' as relationship_type, 
      'cvc calculated' as source
    FROM x 
    JOIN _SESSION.temp_variation v 
    ON 
      x.id = v.id
    CROSS JOIN UNNEST(v.descendant_ids) AS descendant_id
    JOIN _SESSION.temp_variation d 
    ON 
      d.id = descendant_id 
      AND 
      d.subclass_type='SimpleAllele'
    LEFT JOIN `%s.gene_association` ga 
    ON 
      ga.variation_id = d.id
    WHERE 
      ARRAY_LENGTH(v.descendant_ids) > 0 
    GROUP BY 
      v.id
    HAVING 
      COUNT(ga.gene_id) = 1
  """, schema_name, schema_name, release_date, schema_name);

    --- Finally, update somatic flags based on current onco-gene list (should this be a 
    --- 'change over time' capture of the onco-gene list's state?)
  EXECUTE IMMEDIATE FORMAT("""
    UPDATE `%s.single_gene_variation` sgv
    SET sgv.somatic = TRUE
    WHERE 
      EXISTS (
        SELECT 
          cg.hgnc_id 
        FROM `clinvar_ingest.cancer_genes` cg
        JOIN `clinvar_ingest.entrez_gene` g 
        ON 
          g.hgnc_id = cg.hgnc_id
        WHERE 
          g.gene_id = sgv.gene_id
      )
  """, schema_name);

  DROP TABLE _SESSION.temp_variation;
  DROP TABLE _SESSION.temp_gene_assoc;

END;



-- -- PRE 2019-07-01 data setup one-off
-- -- remove duplicates from contrived gene_association table in pre-2019-07-01 data
-- CREATE OR REPLACE TABLE `clinvar_2019_06_01_v0.gene_association`
-- AS
-- SELECT x.release_date, x.gene_id, x.variation_id, x.relationship_type, x.source
-- FROM (
--   SELECT
--       release_date, gene_id, variation_id, relationship_type, source,
--       ROW_NUMBER()
--           OVER (PARTITION BY release_date, gene_id, variation_id)
--           row_number
--   FROM `clinvar_2019_06_01_v0.gene_association`
-- ) x
-- WHERE x.row_number = 1
-- ;

-- -- contrive a single_gene_variation table for the pre-2019-07-01 data
-- CREATE OR REPLACE TABLE `clinvar_2019_06_01_v0.single_gene_variation`
-- AS
-- WITH x AS
-- (
--   select release_date, variation_id
--   from  `clinvar_2019_06_01_v0.gene_association`
--   group by release_date, variation_id
--   having count(*) = 1
-- )
-- SELECT 
--   x.release_date,
--   ga.gene_id,
--   x.variation_id, 
--   ga.relationship_type,
--   ga.source,
--   (cg.hgnc_id IS NOT NULL) as somatic,
--   FALSE as mane_select
-- FROM x
-- join `clinvar_2019_06_01_v0.gene_association` ga on x.release_date = ga.release_date and x.variation_id = ga.variation_id
-- left join `clinvar_2019_06_01_v0.gene` g on g.id = ga.gene_id and x.release_date = g.release_date
-- left join `clinvar_ingest.cancer_genes` cg on g.hgnc_id = cg.hgnc_id
-- ;


  -- -- validate between steps?...
  -- select vsg.* 
  -- from `clinvar_2022_05_17_v1_6_46.single_gene_variation` vsg
  -- join ( select vsg2.variation_id 
  --        from `clinvar_2022_05_17_v1_6_46.single_gene_variation` vsg2 
  --        group by vsg2.variation_id having count(distinct vsg2.gene_id) > 1) vsg2 on  vsg.variation_id = vsg2.variation_id
  -- order by 1,3;


    -- -- Helper: To Find duplicate gene ids in release
    -- select count(distinct ga.variation_id), ga.gene_id, g.symbol, g.hgnc_id
    -- from `clinvar_2022_05_17_v1_6_46.gene_association` ga, 
    --      `clinvar_2022_05_17_v1_6_46.gene` g,
    --      (SELECT ARRAY_AGG(id) as gene_ids 
    --        from `clinvar_2022_05_17_v1_6_46.gene` g 
    --         group by hgnc_id, symbol, release_date, full_name 
    --         having count(distinct id)>1 ) as gx,
    --      UNNEST(gx.gene_ids) as gid
    -- WHERE gid = ga.gene_id and g.id = ga.gene_id
    -- group by ga.gene_id, g.symbol, g.hgnc_id
    -- order by 3,1;