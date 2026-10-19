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

  -- create a temp table of the genes that had an HGNC-approved symbol when the release was published.
  --   it is the gene reference for every step, so each release only sees the genes and symbols that
  --   were current at the time. see docs/methods/single-gene-variation.md
  --   - the release's own gene table supplies the symbols clinvar used at the time
  --   - genes the release does not list at all (named in a variant title but not associated by clinvar)
  --     come from entrez_gene, so the name-matching steps can still find them
  --   - gene ids that NCBI had discontinued by the release date are excluded; clinvar's gene table
  --     keeps some of them, still carrying an HGNC id
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.temp_gene
    AS
    WITH release_gene AS (
      SELECT DISTINCT
        g.id as gene_id,
        g.symbol,
        g.hgnc_id,
        g.full_name
      FROM `%s.gene` g
      WHERE
        g.hgnc_id IS NOT NULL
    ),
    unlisted_gene AS (
      SELECT
        e.gene_id,
        e.symbol_from_authority as symbol,
        e.hgnc_id,
        e.description as full_name
      FROM `clinvar_ingest.entrez_gene` e
      WHERE
        e.gene_id NOT IN (SELECT g.id FROM `%s.gene` g)
    ),
    discontinued AS (
      SELECT DISTINCT
        h.discontinued_gene_id as gene_id
      FROM `clinvar_ingest.ncbi_gene_history` h
      WHERE
        h.discontinue_date <= %T
    )
    SELECT
      g.*
    FROM (
      SELECT * FROM release_gene
      UNION ALL
      SELECT * FROM unlisted_gene
    ) g
    LEFT JOIN discontinued d
    ON
      d.gene_id = g.gene_id
    WHERE
      d.gene_id IS NULL
  """, schema_name, schema_name, release_date);

  --- step 2. (Resolvable Gene Symbol in variation name takes precedence as "single gene for variant")
  ---         initialize the set with the extracted variation name gene symbols and the associated relationship info if available

  -- create a temp table of the MANE transcripts (MANE Select and MANE Plus Clinical) of the MANE release
  --   that was current when this release was published, so a variant name is matched against the
  --   transcript versions in use at the time. see docs/methods/single-gene-variation.md
  CREATE TEMP TABLE _SESSION.temp_mane
  AS
  SELECT
    m.gene_id,
    m.transcript_id
  FROM `clinvar_ingest.mane_transcript` m
  WHERE
    m.mane_version = (
      SELECT
        ARRAY_AGG(mane_version ORDER BY mane_release_date DESC LIMIT 1)[SAFE_OFFSET(0)]
      FROM `clinvar_ingest.mane_transcript`
      WHERE
        mane_release_date <= release_date
    );

  -- prioritize mane transcripts in title of variant
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
    FROM _SESSION.temp_mane mane
    JOIN _SESSION.temp_variation v
    ON
      STARTS_WITH(v.name, mane.transcript_id)
    JOIN _SESSION.temp_gene g
    ON
      g.gene_id = mane.gene_id
    LEFT JOIN `%s.gene_association` ga
    ON
      ga.gene_id = g.gene_id
      AND
      ga.variation_id = v.id
  """, schema_name, release_date, schema_name);

    -- create a temp table of "companion" genes: non-coding transcripts named after, and lying
    --   beside, a main gene. matched by HGNC naming convention, except readthroughs, which are
    --   taken from the gene full_name. see docs/methods/single-gene-variation.md
    --   a companion is only ignored when the variation has exactly one main gene
    --   (see temp_one_main_gene_variation); a variation whose only genes are companions keeps them
  CREATE TEMP TABLE _SESSION.temp_companion_gene
  AS
  SELECT
    g.gene_id
  FROM _SESSION.temp_gene g
  WHERE
    REGEXP_CONTAINS(g.symbol, r'\-DT$')            -- divergent transcript
    OR
    REGEXP_CONTAINS(g.symbol, r'^LINC\d+$')        -- long intergenic non-coding RNA
    OR
    REGEXP_CONTAINS(g.symbol, r'^MIR\d+[A-Z0-9]*HG$') -- microRNA host gene
    OR
    REGEXP_CONTAINS(g.symbol, r'\-OT\d*$')         -- overlapping transcript
    OR
    REGEXP_CONTAINS(g.symbol, r'\-IT\d*$')         -- intronic transcript
    OR
    REGEXP_CONTAINS(g.symbol, r'\-AS\d*$')         -- antisense RNA, with or without a number
    OR
    (                                              -- older antisense names without the hyphen, e.g. ZFAS1
      REGEXP_CONTAINS(g.symbol, r'AS\d*$')
      AND
      REGEXP_CONTAINS(LOWER(g.full_name), r'antisense')
    )
    OR
    REGEXP_CONTAINS(LOWER(g.full_name), r'readthrough');        -- readthrough (GENE1-GENE2)

    -- create a temp table of the variations associated with exactly one main gene
    --   (a gene in temp_gene that is not a companion). only for these is there
    --   a single main gene for a companion to give way to.
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.temp_one_main_gene_variation
    AS
    SELECT
      ga.variation_id
    FROM `%s.gene_association` ga
    JOIN _SESSION.temp_gene g
    ON
      ga.gene_id = g.gene_id
    WHERE
      g.gene_id NOT IN (SELECT gene_id FROM _SESSION.temp_companion_gene)
    GROUP BY
      ga.variation_id
    HAVING
      COUNT(DISTINCT ga.gene_id) = 1
  """, schema_name);

    -- create a temp table that is the list of gene associations
    --   for variations not yet in the single gene var table and
    --   aren't a companion gene of a variation that has exactly one main gene
  EXECUTE IMMEDIATE FORMAT("""
    CREATE TEMP TABLE _SESSION.temp_gene_assoc
    AS
    SELECT DISTINCT
      ga.variation_id,
      ga.gene_id,
      ga.relationship_type,
      ga.source
    FROM `%s.gene_association` ga
    JOIN _SESSION.temp_gene g
    ON
      ga.gene_id = g.gene_id
    WHERE
      NOT (
        ga.gene_id IN (SELECT gene_id FROM _SESSION.temp_companion_gene)
        AND
        ga.variation_id IN (SELECT variation_id FROM _SESSION.temp_one_main_gene_variation)
      )
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
    JOIN _SESSION.temp_gene g
    ON
      UPPER(g.symbol) = UPPER(x.symbol)
    LEFT JOIN _SESSION.temp_gene_assoc ga
    ON
      ga.variation_id = x.id
      AND
      ga.gene_id = g.gene_id
    WHERE
      -- skip a named companion gene when the variation has exactly one main gene to give way to
      NOT (
        g.gene_id IN (SELECT gene_id FROM _SESSION.temp_companion_gene)
        AND
        x.id IN (SELECT variation_id FROM _SESSION.temp_one_main_gene_variation)
      )
    -- a symbol can map to more than one gene_id (e.g. NCBI replaced the id and the retired id is kept),
    -- so keep one row per variation: prefer the gene_id clinvar associates with the variation, then the newest gene_id
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY x.id
      ORDER BY IF(ga.gene_id IS NULL, 1, 0), SAFE_CAST(g.gene_id AS INT64) DESC, ga.relationship_type, ga.source
    ) = 1
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
    JOIN _SESSION.temp_gene g
    ON
      UPPER(x.symbol) = UPPER(g.symbol)
    LEFT JOIN _SESSION.temp_gene_assoc ga
    ON
      x.id = ga.variation_id
      AND
      g.gene_id = ga.gene_id
    WHERE TRUE
    -- a symbol can map to more than one gene_id (e.g. NCBI replaced the id and the retired id is kept),
    -- so keep one row per variation: prefer the gene_id clinvar associates with the variation, then the newest gene_id
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY x.id
      ORDER BY IF(ga.gene_id IS NULL, 1, 0), SAFE_CAST(g.gene_id AS INT64) DESC, ga.relationship_type, ga.source
    ) = 1
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
      -- HAVING COUNT(DISTINCT ga.gene_id) = 1 guarantees all non-null gene_id values in the group are identical
      -- (ANY_VALUE ignores the NULLs from children with no gene association via the LEFT JOIN)
      ANY_VALUE(ga.gene_id) as gene_id,
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
      COUNT(DISTINCT ga.gene_id) = 1
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
        JOIN _SESSION.temp_gene g
        ON
          g.hgnc_id = cg.hgnc_id
        WHERE
          g.gene_id = sgv.gene_id
      )
  """, schema_name);

  DROP TABLE _SESSION.temp_variation;
  DROP TABLE _SESSION.temp_gene;
  DROP TABLE _SESSION.temp_mane;
  DROP TABLE _SESSION.temp_companion_gene;
  DROP TABLE _SESSION.temp_one_main_gene_variation;
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
