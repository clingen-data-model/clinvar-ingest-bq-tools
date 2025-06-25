-- STEP 2
-- this script copies all non-GermlineClassification records
-- from the 2024-03-11, 2024-03-31, 2024-05-02 datasets
-- to the 2024-03-17, 2024-03-24, 2024-04-07, 2024-04-16,
-- 2024-04-21, 2024-05-09, 2024-05-13, 2024-05-19, 2024-05-27 datasets
-- since the target datasets were copied from the old xml ingest due
-- to the fact that NCBI could not get us these missing xml files for the
-- new xml format for those weekly releases.
BEGIN

  DECLARE inputs ARRAY<STRUCT<
    schema STRING,
    targets ARRAY<STRING>
  >>;

  SET inputs = [
    STRUCT(
      'clinvar_2024_03_11_v2_1_0',
      [
        'clinvar_2024_03_17_v1_6_62',
        'clinvar_2024_03_24_v1_6_62'
      ]
    ),
    STRUCT(
      'clinvar_2024_03_31_v2_1_0',
      [
        'clinvar_2024_04_07_v1_6_62',
        'clinvar_2024_04_16_v1_6_62',
        'clinvar_2024_04_21_v1_6_62'
      ]
    ),
    STRUCT(
      'clinvar_2024_05_02_v2_1_0',
      [
        'clinvar_2024_05_09_v1_6_62',
        'clinvar_2024_05_13_v1_6_62',
        'clinvar_2024_05_19_v1_6_62',
        'clinvar_2024_05_27_v1_6_62'
      ]
    )
  ];

  -- update review_status values on old datasets that are being useds to replace missing 2024 Mar/Apr/May datasets
  CREATE TEMP TABLE revstat
  AS
    SELECT
      'criteria provided, conflicting interpretations' as cur_label,
      'criteria provided, conflicting classifications' as new_label
    UNION ALL
    SELECT
      'no interpretation for the single variant',
      'no classification for the single variant'
    UNION ALL
    SELECT
      'no assertion provided',
      'no classification provided'
  ;

  -- Loop through the top-level schemas array of structs
  FOR src IN (SELECT i.* FROM UNNEST(inputs) as i)
  DO

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TEMP TABLE rcv_map
      AS
      SELECT DISTINCT
        rcvc.rcv_id,
        rcv.version,
        rcv.variation_archive_id,
        rcv.variation_id,
        rcv_map.rcv_accession,
        scv_accession,
        ca.clinical_assertion_observation_ids,
        ca.clinical_assertion_trait_set_id,
        cats.clinical_assertion_trait_ids,
        ca.submission_id,
        ca.submitter_id,
        rcv_map.trait_set_id,
        ts.trait_ids,
        ARRAY_AGG(STRUCT(ga.gene_id, ga.variation_id, ga.relationship_type, ga.source, ga.content)) AS genes,
        ARRAY_AGG(DISTINCT rcvc.statement_type) AS rcv_stmt_types,
        ARRAY_AGG(DISTINCT vcvc.statement_type) AS vcv_stmt_types
      FROM `%s.rcv_accession_classification` rcvc
      LEFT JOIN `%s.rcv_mapping` rcv_map
      ON
        rcv_map.rcv_accession = rcvc.rcv_id
      LEFT JOIN unnest(rcv_map.scv_accessions) AS scv_accession
      on true
      LEFT JOIN `%s.rcv_accession` rcv
      ON
        rcv.id = rcvc.rcv_id
      LEFT JOIN `%s.trait_set` ts
      ON
        ts.id = rcv_map.trait_set_id
      LEFT JOIN `%s.clinical_assertion` ca
      ON
        scv_accession = ca.id
      LEFT JOIN `%s.clinical_assertion_trait_set` cats
      ON
        ca.clinical_assertion_trait_set_id = cats.id
      LEFT JOIN `%s.gene_association` ga
      ON
        rcv.variation_id = ga.variation_id
      LEFT JOIN `%s.variation_archive_classification` vcvc
      ON
        rcv.variation_archive_id = vcvc.vcv_id
        AND
        vcvc.statement_type <> 'GermlineClassification'
      WHERE
        rcvc.statement_type <> 'GermlineClassification'
      group by
        rcvc.rcv_id,
        rcv.version,
        rcv.variation_archive_id,
        rcv.variation_id,
        rcv_map.rcv_accession,
        scv_accession,
        ca.clinical_assertion_observation_ids,
        ca.clinical_assertion_trait_set_id,
        cats.clinical_assertion_trait_ids,
        ca.submission_id,
        ca.submitter_id,
        rcv_map.trait_set_id,
        ts.trait_ids
      """,
      src.schema,
      src.schema,
      src.schema,
      src.schema,
      src.schema,
      src.schema,
      src.schema,
      src.schema
    );

    -- copy source schema records for each target schema table that are missing
    FOR tgt IN (SELECT schema FROM UNNEST(src.targets) as schema)
    DO

      -- trait_set table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.trait_set` (
          release_date,
          content,
          id,
          type,
          trait_ids
        )
        SELECT
          src.release_date,
          src.content,
          src.id,
          src.type,
          src.trait_ids
        FROM (
          SELECT DISTINCT
            rcv_map.trait_set_id
          FROM rcv_map
          LEFT JOIN `%s.trait_set` ts
          ON
            rcv_map.trait_set_id = ts.id
          WHERE
            ts.id IS NULL
        ) x
        JOIN `%s.trait_set` src
        ON
          src.id = x.trait_set_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- trait table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.trait` (
          disease_mechanism_id,
          name,
          attribute_content,
          mode_of_inheritance,
          release_date,
          ghr_links,
          keywords,
          content,
          gard_id,
          id,
          medgen_id,
          public_definition,
          type,
          symbol,
          disease_mechanism,
          alternate_symbols,
          gene_reviews_short,
          alternate_names,
          xrefs
        )
        SELECT
          src.disease_mechanism_id,
          src.name,
          src.attribute_content,
          src.mode_of_inheritance,
          src.release_date,
          src.ghr_links,
          src.keywords,
          src.content,
          src.gard_id,
          src.id,
          src.medgen_id,
          src.public_definition,
          src.type,
          src.symbol,
          src.disease_mechanism,
          src.alternate_symbols,
          src.gene_reviews_short,
          src.alternate_names,
          src.xrefs
        FROM (
          SELECT DISTINCT
            trait_id
          FROM rcv_map
          LEFT JOIN UNNEST(rcv_map.trait_ids) AS trait_id
          LEFT JOIN `%s.trait` t
          ON
            trait_id = t.id
          WHERE
            t.id IS NULL
        ) x
        JOIN `%s.trait` src
        ON
          src.id = x.trait_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- clinical_assertion (scv) table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.clinical_assertion` (
          date_created,
          rcv_accession_id,
          record_status,
          interpretation_description,
          submitter_id,
          clinical_assertion_observation_ids,
          variation_id,
          submitted_assembly,
          release_date,
          interpretation_date_last_evaluated,
          submission_id,
          clinical_assertion_trait_set_id,
          interpretation_comments,
          content,
          local_key,
          id,
          variation_archive_id,
          internal_id,
          version,
          title,
          date_last_updated,
          assertion_type,
          trait_set_id,
          review_status,
          submission_names,
          statement_type,
          clinical_impact_assertion_type,
          clinical_impact_clinical_significance
        )
        SELECT
          src.date_created,
          src.rcv_accession_id,
          src.record_status,
          src.interpretation_description,
          src.submitter_id,
          src.clinical_assertion_observation_ids,
          src.variation_id,
          src.submitted_assembly,
          src.release_date,
          src.interpretation_date_last_evaluated,
          src.submission_id,
          src.clinical_assertion_trait_set_id,
          src.interpretation_comments,
          src.content,
          src.local_key,
          src.id,
          src.variation_archive_id,
          src.internal_id,
          src.version,
          src.title,
          src.date_last_updated,
          src.assertion_type,
          src.trait_set_id,
          src.review_status,
          src.submission_names,
          src.statement_type,
          src.clinical_impact_assertion_type,
          src.clinical_impact_clinical_significance
        FROM (
          SELECT DISTINCT
            rcv_map.scv_accession
          FROM rcv_map
          LEFT JOIN `%s.clinical_assertion` ca
          ON
            rcv_map.scv_accession = ca.id
          WHERE
            ca.id IS NULL
        ) x
        JOIN `%s.clinical_assertion` src
        ON
          src.id = x.scv_accession
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- clinical_assertion_trait_set table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.clinical_assertion_trait_set` (
          clinical_assertion_trait_ids,
          release_date,
          content,
          id,
          type
        )
        SELECT
          src.clinical_assertion_trait_ids,
          src.release_date,
          src.content,
          src.id,
          src.type
        FROM (
          SELECT DISTINCT
            rcv_map.clinical_assertion_trait_set_id
          FROM rcv_map
          LEFT JOIN `%s.clinical_assertion_trait_set` cats
          ON
            rcv_map.clinical_assertion_trait_set_id = cats.id
          WHERE
            cats.id IS NULL
        ) x
        JOIN `%s.clinical_assertion_trait_set` src
        ON
          src.id = x.clinical_assertion_trait_set_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- clinical_assertion_trait table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.clinical_assertion_trait` (
          name,
          release_date,
          content,
          id,
          medgen_id,
          trait_id,
          type,
          alternate_names,
          xrefs
        )
        SELECT
          src.name,
          src.release_date,
          src.content,
          src.id,
          src.medgen_id,
          src.trait_id,
          src.type,
          src.alternate_names,
          src.xrefs
        FROM (
          SELECT DISTINCT
            ca_trait_id
          FROM rcv_map
          LEFT JOIN unnest(rcv_map.clinical_assertion_trait_ids) AS ca_trait_id
          LEFT JOIN `%s.clinical_assertion_trait` cat
          ON
            ca_trait_id = cat.id
          WHERE
            cat.id IS NULL
        ) x
        JOIN `%s.clinical_assertion_trait` src
        ON
          src.id = x.ca_trait_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- clinical_assertion_observation table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.clinical_assertion_observation` (
          id,
          release_date,
          clinical_assertion_trait_set_id,
          content
        )
        SELECT
          src.id,
          src.release_date,
          src.clinical_assertion_trait_set_id,
          src.content
        FROM (
          SELECT DISTINCT
            ca_obs_id
          FROM rcv_map
          LEFT JOIN unnest(rcv_map.clinical_assertion_observation_ids) AS ca_obs_id
          LEFT JOIN `%s.clinical_assertion_observation` caobs
          ON
            ca_obs_id = caobs.id
          WHERE
            caobs.id IS NULL
        ) x
        JOIN `%s.clinical_assertion_observation` src
        ON
          src.id = x.ca_obs_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- trait_mapping table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.trait_mapping` (
          trait_type,
          mapping_value,
          release_date,
          mapping_type,
          medgen_name,
          mapping_ref,
          medgen_id,
          clinical_assertion_id
        )
        SELECT
          src.trait_type,
          src.mapping_value,
          src.release_date,
          src.mapping_type,
          src.medgen_name,
          src.mapping_ref,
          src.medgen_id,
          src.clinical_assertion_id
        FROM (
          SELECT DISTINCT
            rcv_map.scv_accession
          FROM rcv_map
          LEFT JOIN `%s.trait_mapping` tm
          ON
            rcv_map.scv_accession = tm.clinical_assertion_id
          WHERE
            tm.clinical_assertion_id IS NULL
        ) x
        JOIN `%s.trait_mapping` src
        ON
          src.clinical_assertion_id = x.scv_accession
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- clinical_assertion_variation table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.clinical_assertion_variation` (
          variation_type,
          release_date,
          subclass_type,
          content,
          id,
          descendant_ids,
          child_ids,
          clinical_assertion_id
        )
        SELECT
          src.variation_type,
          src.release_date,
          src.subclass_type,
          src.content,
          src.id,
          src.descendant_ids,
          src.child_ids,
          src.clinical_assertion_id
        FROM (
          SELECT DISTINCT
            rcv_map.scv_accession
          FROM rcv_map
          LEFT JOIN `%s.clinical_assertion_variation` cav
          ON
            rcv_map.scv_accession = cav.id
          WHERE
            cav.id IS NULL
        ) x
        JOIN `%s.clinical_assertion_variation` src
        ON
          src.id = x.scv_accession
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- variation table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.variation` (
          name,
          variation_type,
          allele_id,
          release_date,
          subclass_type,
          protein_change,
          content,
          id,
          descendant_ids,
          num_chromosomes,
          child_ids
        )
        SELECT
          src.name,
          src.variation_type,
          src.allele_id,
          src.release_date,
          src.subclass_type,
          src.protein_change,
          src.content,
          src.id,
          src.descendant_ids,
          src.num_chromosomes,
          src.child_ids
        FROM (
          SELECT DISTINCT
            rcv_map.variation_id
          FROM rcv_map
          LEFT JOIN `%s.variation` v
          ON
            rcv_map.variation_id = v.id
          WHERE
            v.id IS NULL
        ) x
        JOIN `%s.variation` src
        ON
          src.id = x.variation_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- gene_association table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.gene_association` (
          source,
          variation_id,
          release_date,
          relationship_type,
          content,
          gene_id
        )
        SELECT
          src.source,
          src.variation_id,
          src.release_date,
          src.relationship_type,
          src.content,
          src.gene_id
        FROM (
          SELECT DISTINCT
            ga_source.gene_id,
            ga_source.variation_id
          FROM rcv_map
          LEFT JOIN unnest(rcv_map.genes) AS ga_source
          LEFT JOIN `%s.gene_association` ga
          ON
            ga_source.gene_id = ga.gene_id
            and
            ga_source.variation_id = ga.variation_id
          WHERE
            ga.gene_id IS NULL
        ) x
        JOIN `%s.gene_association` src
        ON
          src.variation_id = x.variation_id
          AND
          src.gene_id = x.gene_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- gene table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.gene` (
          release_date,
          hgnc_id,
          id,
          symbol,
          full_name
        )
        SELECT
          src.release_date,
          src.hgnc_id,
          src.id,
          src.symbol,
          src.full_name
        FROM (
          SELECT DISTINCT
            g_source.gene_id
          FROM rcv_map
          LEFT JOIN unnest(rcv_map.genes) AS g_source
          LEFT JOIN `%s.gene` g
          ON
            g_source.gene_id = g.id
          WHERE
            g.id IS NULL
        ) x
        JOIN `%s.gene` src
        ON
          src.id = x.gene_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- rcv_accession table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.rcv_accession` (
          release_date,
          id,
          variation_id,
          independent_observations,
          variation_archive_id,
          version,
          title,
          trait_set_id,
          content
        )
        SELECT
          src.release_date,
          src.id,
          src.variation_id,
          src.independent_observations,
          src.variation_archive_id,
          src.version,
          src.title,
          src.trait_set_id,
          src.content
        FROM (
          SELECT DISTINCT
            rcv_map.rcv_accession
          FROM rcv_map
          LEFT JOIN `%s.rcv_accession` rcv
          ON
            rcv_map.rcv_accession = rcv.id
          WHERE
            rcv.id IS NULL
        ) x
        JOIN `%s.rcv_accession` src
        ON
          src.id = x.rcv_accession
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- rcv_accession_classification table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.rcv_accession_classification` (
          release_date,
          rcv_id,
          statement_type,
          review_status,
          agg_classification
        )
        SELECT
          src.release_date,
          src.rcv_id,
          src.statement_type,
          src.review_status,
          ARRAY_AGG(
            STRUCT(
              clfn.num_submissions,
              clfn.date_last_evaluated,
              clfn.interp_description,
              clfn.clinical_impact_assertion_type,
              clfn.clinical_impact_clinical_significance
            )
          ) AS agg_classification
        FROM (
          SELECT DISTINCT
            rcv_map.rcv_accession,
            rcv_stmt_type
          FROM rcv_map
          cross join unnest(rcv_map.rcv_stmt_types) AS rcv_stmt_type
          LEFT JOIN `%s.rcv_accession_classification` rcvc
          ON
            rcv_map.rcv_accession = rcvc.rcv_id
            and
            rcvc.statement_type = rcv_stmt_type
          WHERE
            rcvc.rcv_id IS NULL
        ) x
        JOIN `%s.rcv_accession_classification` src
        ON
          src.rcv_id = x.rcv_accession
          and
          src.statement_type = x.rcv_stmt_type
        LEFT JOIN UNNEST(src.agg_classification) AS clfn
        GROUP BY
          src.release_date,
          src.rcv_id,
          src.statement_type,
          src.review_status
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- variation_archive (vcv) table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.variation_archive` (
          date_created,
          record_status,
          variation_id,
          release_date,
          content,
          species,
          id,
          version,
          num_submitters,
          date_last_updated,
          num_submissions
        )
        SELECT
          src.date_created,
          src.record_status,
          src.variation_id,
          src.release_date,
          src.content,
          src.species,
          src.id,
          src.version,
          src.num_submitters,
          src.date_last_updated,
          src.num_submissions
        FROM (
          SELECT DISTINCT
            rcv_map.variation_archive_id
          FROM rcv_map
          LEFT JOIN `%s.variation_archive` vcv
          ON
            rcv_map.variation_archive_id = vcv.id
          WHERE
            vcv.id IS NULL
        ) x
        JOIN `%s.variation_archive` src
        ON
          src.id = x.variation_archive_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );


      -- variation_archive_classification table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.variation_archive_classification` (
          vcv_id,
          statement_type,
          review_status,
          num_submitters,
          num_submissions,
          date_created,
          date_last_evaluated,
          interp_description,
          interp_explanation,
          most_recent_submission,
          content,
          clinical_impact_assertion_type,
          clinical_impact_clinical_significance
        )
        SELECT
          src.vcv_id,
          src.statement_type,
          src.review_status,
          src.num_submitters,
          src.num_submissions,
          src.date_created,
          src.date_last_evaluated,
          src.interp_description,
          src.interp_explanation,
          src.most_recent_submission,
          src.content,
          src.clinical_impact_assertion_type,
          src.clinical_impact_clinical_significance
        FROM (
          SELECT DISTINCT
            rcv_map.variation_archive_id,
            vcv_stmt_type
          FROM rcv_map
          cross join unnest(rcv_map.vcv_stmt_types) AS vcv_stmt_type
          LEFT JOIN `%s.variation_archive_classification` vcvc
          ON
            rcv_map.variation_archive_id = vcvc.vcv_id
            and
            vcvc.statement_type = vcv_stmt_type
          WHERE
            vcvc.vcv_id IS NULL
        ) x
        JOIN `%s.variation_archive_classification` src
        ON
          src.vcv_id = x.variation_archive_id
          and
          src.statement_type = x.vcv_stmt_type
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- submission table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.submission` (
          submitter_id,
          release_date,
          id,
          additional_submitter_ids,
          submission_date
        )
        SELECT
          src.submitter_id,
          src.release_date,
          src.id,
          src.additional_submitter_ids,
          src.submission_date
        FROM (
          SELECT DISTINCT
            rcv_map.submission_id
          FROM rcv_map
          LEFT JOIN `%s.submission` s
          ON
            rcv_map.submission_id = s.id
          WHERE
            s.id IS NULL
        ) x
        JOIN `%s.submission` src
        ON
          src.id = x.submission_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- submitter table
      EXECUTE IMMEDIATE FORMAT("""
        INSERT INTO `%s.submitter` (
          release_date,
          current_name,
          all_names,
          all_abbrevs,
          id,
          current_abbrev,
          org_category
        )
        SELECT
          src.release_date,
          src.current_name,
          src.all_names,
          src.all_abbrevs,
          src.id,
          src.current_abbrev,
          src.org_category
        FROM (
          SELECT DISTINCT
            rcv_map.submitter_id
          FROM rcv_map
          LEFT JOIN `%s.submitter` s
          ON
            rcv_map.submitter_id = s.id
          WHERE
            s.id IS NULL
        ) x
        JOIN `%s.submitter` src
        ON
          src.id = x.submitter_id
        """,
        tgt.schema,
        tgt.schema,
        src.schema
      );

      -- update the review_status values on the target datasets
      -- since we are porting older datasets into the period of
      -- time that is based on the newer xml datasets
      -- clinical_assertion, rcv_accession_classification, and vcv_archive_classification
      EXECUTE IMMEDIATE FORMAT("""
        UPDATE `%s.clinical_assertion` tgt
        SET
          tgt.review_status = revstat.new_label
        FROM revstat
        WHERE
          revstat.cur_label = tgt.review_status
      """,
        tgt.schema
      );

      EXECUTE IMMEDIATE FORMAT("""
        UPDATE `%s.rcv_accession_classification` tgt
        SET
          tgt.review_status = revstat.new_label
        FROM revstat
        WHERE
          revstat.cur_label = tgt.review_status
      """,
        tgt.schema
      );

      EXECUTE IMMEDIATE FORMAT("""
        UPDATE `%s.variation_archive_classification` tgt
        SET
          tgt.review_status = revstat.new_label
        FROM revstat
        WHERE
          revstat.cur_label = tgt.review_status
      """,
        tgt.schema
      );

    END FOR;
  END FOR;
END;
