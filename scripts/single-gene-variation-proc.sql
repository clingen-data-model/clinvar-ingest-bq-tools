CREATE OR REPLACE PROCEDURE `clinvar_ingest.single_gene_variation_proc`(start_with DATE)
BEGIN

  FOR rec IN (select s.schema_name, s.release_date, s.prev_release_date, s.next_release_date FROM clinvar_ingest.schemas_on_or_after(start_with) as s)
  DO

    -- single gene variation  plan
    --- step 1. create a table with columns variation_id, gene_id, somatic_flag 
    ---         where the variation_id is the pk. 
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.single_gene_variation`
          ( release_date DATE NOT NULL,
            variation_id STRING NOT NULL,
            gene_id STRING NOT NULL,
            relationship_type STRING,
            source STRING,
            mane_select BOOL DEFAULT FALSE,
            somatic BOOL DEFAULT FALSE)
    """, rec.schema_name);

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
    """, rec.schema_name);


      --- step 2. (Resolvable Gene Symbol in variation name takes precedence as "single gene for variant")
      ---         initialize the set with the extracted variation name gene symbols and the associated relationship info if available

    -- prioritize mane select transcripts in title of variant
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source, mane_select )
      SELECT DISTINCT
        %T as release_date,
        v.id as variation_id,
        mane.gene_id,
        IFNULL(ga.relationship_type,'named gene not associated') as relationship_type, 
        IFNULL(ga.source,'cvc calculated') as source, 
        TRUE as mane_select
      FROM `clinvar_ingest.mane_select_gene_transcript` mane
      JOIN _SESSION.temp_variation v on STARTS_WITH(v.name, mane.transcript_id)
      JOIN `clinvar_ingest.entrez_gene` g on g.gene_id = mane.gene_id
      LEFT JOIN `%s.gene_association` ga on ga.gene_id = g.gene_id and ga.variation_id = v.id
    """, rec.schema_name, rec.release_date, rec.schema_name);

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
      JOIN `clinvar_ingest.entrez_gene` g on ga.gene_id = g.gene_id
      WHERE 
        NOT REGEXP_CONTAINS(g.symbol_from_authority, r'\\-AS\\d$') AND
        NOT EXISTS (
          SELECT sgv.variation_id
          FROM `%s.single_gene_variation` sgv
          WHERE sgv.variation_id = ga.variation_id 
        )
    """, rec.schema_name, rec.schema_name);

      -- NOTE: clinvar has a handful of duplicate gene records that can change over time
      --      the plan will be to test the results of loading the variation_single_gene 
      --      table to verify that any variants with multiple genes are simply duplicates and 
      --      either one can be removed without an issue.

    -- clinvar perferred label hgvs-style format NM_0000.0(GENE):c.234... (not mane select but still in name)
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source)
      WITH x AS
      (
        SELECT 
          v.id, 
          v.name, 
          REGEXP_EXTRACT(v.name, r'^N[A-Z]_[0-9]+\\.[0-9]+\\(([A-Za-z0-9\\-]+)\\)') as symbol
        FROM _SESSION.temp_variation v
        WHERE REGEXP_CONTAINS(v.name, r'^N[A-Z]_[0-9]+\\.[0-9]+\\(([A-Za-z0-9\\-]+)\\)') AND 
          NOT EXISTS (
            SELECT sgv.variation_id
            FROM `%s.single_gene_variation` sgv
            WHERE sgv.variation_id = v.id 
          )
      )
      SELECT 
        %T as release_date,
        x.id as variation_id,
        g.gene_id, 
        IFNULL(ga.relationship_type,'named gene not associated') as relationship_type, 
        IFNULL(ga.source,'cvc calculated') as source
      FROM x 
      JOIN `clinvar_ingest.entrez_gene` g on UPPER(g.symbol_from_authority) = UPPER(x.symbol) AND NOT REGEXP_CONTAINS(x.symbol, r'\\-AS\\d$') 
      LEFT JOIN _SESSION.temp_gene_assoc ga on ga.variation_id = x.id and ga.gene_id = g.gene_id
    """, rec.schema_name, rec.schema_name, rec.release_date); 


      -- star allele format, CYP2C19*10. 
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source)
      WITH x AS
      (
        SELECT 
          v.id, 
          v.name, 
          REGEXP_EXTRACT(v.name,  r'^([A-Za-z0-9\\-]+)[\\*\\,]') as symbol
        FROM _SESSION.temp_variation v
        WHERE REGEXP_CONTAINS(v.name,  r'^([A-Za-z0-9\\-]+)[\\*\\,]') AND
          NOT EXISTS (
            SELECT sgv.variation_id
            FROM `%s.single_gene_variation` sgv
            WHERE sgv.variation_id = v.id 
          )
      )
      SELECT 
        %T as release_date,
        x.id as variation_id, 
        g.gene_id,
        IFNULL(ga.relationship_type,'named gene not associated') as relationship_type, 
        IFNULL(ga.source,'cvc calculated') as source
      FROM x 
      JOIN `clinvar_ingest.entrez_gene` g ON UPPER(x.symbol) = UPPER(g.symbol_from_authority)
      LEFT JOIN _SESSION.temp_gene_assoc ga ON x.id = ga.variation_id AND g.gene_id = ga.gene_id
    """, rec.schema_name, rec.schema_name, rec.release_date);

      --- step 3. for any variations remaining... load all variations with any 
      ---         genes that are mapped one-to-one from the gene association table
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source)
      WITH x AS
      (
        SELECT 
          v.id
        FROM _SESSION.temp_variation v
        WHERE 
          NOT EXISTS (
            SELECT sgv.variation_id
            FROM `%s.single_gene_variation` sgv
            WHERE sgv.variation_id = v.id 
          )
      )
      SELECT 
        %T as release_date,
        ga.variation_id, 
        STRING_AGG(ga.gene_id), 
        STRING_AGG(ga.relationship_type), 
        STRING_AGG(ga.source)
      FROM x
      JOIN _SESSION.temp_gene_assoc ga on x.id = ga.variation_id
      group by ga.variation_id
      having count(distinct ga.gene_id) = 1
    """, rec.schema_name, rec.schema_name, rec.release_date);

      --- step 4. for any variations remaining... load any variant with one submitted gene that 
      ---          is not either "genes overlapped by variant" or "asserted, but not computed"
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source )
      WITH x AS
      (
        SELECT 
          v.id
        FROM _SESSION.temp_variation v
        WHERE 
          NOT EXISTS (
            SELECT sgv.variation_id
            FROM `%s.single_gene_variation` sgv
            WHERE sgv.variation_id = v.id 
          )
      )
      SELECT 
        %T as release_date,
        ga.variation_id, 
        STRING_AGG(ga.gene_id), 
        STRING_AGG(ga.relationship_type), 
        STRING_AGG(ga.source)
      FROM x
      JOIN _SESSION.temp_gene_assoc ga on x.id = ga.variation_id
      WHERE 
        ga.relationship_type not in ('genes overlapped by variant' , 'asserted, but not computed') AND
        ga.source = 'submitted'
      GROUP BY ga.variation_id
      HAVING count(distinct ga.gene_id) = 1
    """, rec.schema_name, rec.schema_name, rec.release_date);

      --- step 5. for any variations remaining... load any variations with a "within single gene" 
      ---         as long as it is associated to only one gene for that variant
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source)
      WITH x AS
      (
        SELECT 
          v.id
        FROM _SESSION.temp_variation v
        WHERE 
          NOT EXISTS (
            SELECT sgv.variation_id
            FROM `%s.single_gene_variation` sgv
            WHERE sgv.variation_id = v.id 
          )
      )
      SELECT 
        %T as release_date,
        ga.variation_id, 
        STRING_AGG(ga.gene_id), 
        STRING_AGG(ga.relationship_type), 
        STRING_AGG(ga.source)
      FROM x
      JOIN _SESSION.temp_gene_assoc ga on x.id = ga.variation_id
      WHERE (ga.relationship_type = 'within single gene')
      GROUP BY ga.variation_id
      having count(ga.gene_id) = 1
    """, rec.schema_name, rec.schema_name, rec.release_date);

      --- last step. for any variations remaining... load any haplotype or genotype variations only if all the children have the same gene_id
    EXECUTE IMMEDIATE FORMAT("""
      INSERT INTO `%s.single_gene_variation` 
        (release_date, variation_id, gene_id, relationship_type, source )
      WITH x AS
      (
        SELECT 
          v.id
        FROM _SESSION.temp_variation v
        WHERE 
          NOT EXISTS (
            SELECT sgv.variation_id
            FROM `%s.single_gene_variation` sgv
            WHERE sgv.variation_id = v.id 
          )
      )
      SELECT 
        %T as release_date, 
        v.id as variation_id, 
        STRING_AGG(ga.gene_id) as gene_id, 
        'association not provided by clinvar' as relationship_type, 
        'cvc calculated' as source
      FROM x 
      JOIN _SESSION.temp_variation v ON x.id = v.id
      CROSS JOIN UNNEST(v.descendant_ids) AS descendant_id
      JOIN _SESSION.temp_variation d ON 
          d.id = descendant_id AND 
          d.subclass_type='SimpleAllele'
      LEFT JOIN `%s.gene_association` ga on ga.variation_id = d.id
      WHERE ARRAY_LENGTH(v.descendant_ids) > 0 
      GROUP BY v.id
      HAVING COUNT(ga.gene_id) = 1
    """, rec.schema_name, rec.schema_name, rec.release_date, rec.schema_name);

      --- Finally, update somatic flags based on current onco-gene list (should this be a 
      --- 'change over time' capture of the onco-gene list's state?)
    EXECUTE IMMEDIATE FORMAT("""
      UPDATE `%s.single_gene_variation` sgv
      SET sgv.somatic = TRUE
      WHERE EXISTS (
        SELECT cg.hgnc_id from `clinvar_ingest.cancer_genes` cg
        join `clinvar_ingest.entrez_gene` g on g.hgnc_id = cg.hgnc_id
        WHERE g.gene_id = sgv.gene_id
      )
    """, rec.schema_name);

    DROP TABLE _SESSION.temp_variation;
    DROP TABLE _SESSION.temp_gene_assoc;

  END FOR;

END;