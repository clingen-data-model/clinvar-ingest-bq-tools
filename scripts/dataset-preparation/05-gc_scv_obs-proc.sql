CREATE OR REPLACE PROCEDURE `clingen-dev.clinvar_ingest.gc_scv_obs`(schema_name STRING)
BEGIN
  EXECUTE IMMEDIATE FORMAT("""
    CREATE OR REPLACE TABLE `%s.gc_scv_obs`
    AS
     WITH gc_scv_obs AS (
      SELECT
        cao.id as scv_obs_id,
        cao.content as obs_content,
        cao.clinical_assertion_trait_set_id as scv_obs_ts_id,
        caots.clinical_assertion_trait_ids as scv_obs_trait_ids,
        sgv.gene_id,
        scv.variation_id,
        scv.submitter_id,
        scv.id,
        scv.version,
        IF(scv.local_key IS NULL, NULL, SPLIT(scv.local_key, "|")[0]) as local_key,
        scv.statement_type,
        scv.origin as obs_origin,
        scv.date_created as first_in_clinvar,
        scv.classification_comment,
        g.hgnc_id,
        g.symbol as gene_symbol,
        v.name as variant_name,
        vcv.date_created as vcv_first_in_clinvar,
        vac.interp_description as vcvc_classification,
        cvs1.rank as vcvc_rank,
        `clinvar_ingest.parseSample`(cao.content) s
      FROM `variation_tracker.report_submitter` rs
      JOIN `%s.scv_summary` scv
      ON
        rs.submitter_id = scv.submitter_id
        AND
        rs.type = 'GC'
      CROSS JOIN UNNEST(scv.clinical_assertion_observation_ids) as cao_id
      JOIN `%s.clinical_assertion_observation` cao
      ON
        cao.id = cao_id
      LEFT JOIN `%s.clinical_assertion_trait_set` caots
      ON
        caots.id = cao.clinical_assertion_trait_set_id
      LEFT JOIN `%s.single_gene_variation` sgv
      ON
        sgv.variation_id = scv.variation_id
      LEFT JOIN `%s.gene` g
      ON
        sgv.gene_id = g.id
      JOIN `%s.variation` v
      ON
        v.id = scv.variation_id
      JOIN `%s.variation_archive` vcv
      ON
        vcv.variation_id = scv.variation_id
      JOIN `%s.variation_archive_classification` vac
      ON
        vac.vcv_id = vcv.id
        AND
        vac.statement_type = scv.statement_type
      LEFT JOIN `clinvar_ingest.clinvar_status` cvs1
      ON
        cvs1.label = vac.review_status
        AND
        vcv.release_date between cvs1.start_release_date and cvs1.end_release_date
      WHERE
        -- these are the dupe gc submissions that are older
        scv.id NOT IN (
          "SCV000607136","SCV000986740",
          "SCV000986708","SCV000986786",
          "SCV000986705","SCV000986788",
          "SCV000986813","SCV000607109"
        )
    ),
    gc_scv_obs_testing AS (
      -- there should be 1 testing lab per case and it MUST have an id or name to be legit
      SELECT
        gso.scv_obs_id,
        m.description as method_desc,
        m.method_type,
        oma.attribute.type as lab_type,
        oma.attribute.value as lab_name,
        CAST(oma.attribute.integer_value AS STRING) as lab_id,
        oma.attribute.date_value as lab_date_reported,
        oma.comment.text as lab_classification,
        cct.code as lab_classif_type
      FROM gc_scv_obs gso
      JOIN UNNEST (`clinvar_ingest.parseMethods`(obs_content)) as m
      JOIN UNNEST( m.obs_method_attribute ) as oma
      LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cct
      ON
        lower(cct.label) = lower(oma.comment.text)
        AND
        cct.statement_type = gso.statement_type
      WHERE
        oma.attribute.type = 'TestingLaboratory'
        AND
        (
          oma.attribute.value IS NOT NULL
          OR
          oma.attribute.integer_value IS NOT NULL
          OR
          oma.comment.text IS NOT NULL
        )
        AND
        -- lab id or name must NOT be null to be a valid case
        IFNULL(CAST(oma.attribute.integer_value as STRING), oma.attribute.value) IS NOT NULL
    ),
    gc_scv_obs_case_count AS (
      SELECT
        gso.id,
        COUNT(gsot.scv_obs_id) as case_count
      FROM gc_scv_obs gso
      JOIN gc_scv_obs_testing gsot
      ON
        gsot.scv_obs_id = gso.scv_obs_id
      GROUP BY
        gso.id
    ),
    gc_scv_obs_attribs AS (
      SELECT
        gso.scv_obs_id,
        MAX(
          IF(
            od.attribute.type = 'SampleLocalID', od.attribute.value, NULL
          )
        ) AS sample_id,
        MAX(
          IF(
            od.attribute.type = 'SampleVariantID', od.attribute.value, NULL
          )
        ) AS sample_variant_id
      FROM gc_scv_obs as gso
      JOIN UNNEST( `clinvar_ingest.parseObservedData`(gso.obs_content) ) as od
      GROUP BY
        gso.scv_obs_id
    ),
    gc_scv_obs_patient_prep AS (
      SELECT
        gso.scv_obs_id,
        gsoa.sample_id,
        gso.local_key,
        IFNULL(
          IF(
            gsoa.sample_id IS NOT NULL,
            REGEXP_EXTRACT(gsoa.sample_id, r'[a-zA-Z]+[_-]*[a-zA-Z]+'),
            REGEXP_EXTRACT(gso.local_key, r'[a-zA-Z]+[_-]*[a-zA-Z]+')
          ),
          'ss'
        ) as prefix,
        IF(
          gsoa.sample_id IS NOT NULL,
          REGEXP_EXTRACT_ALL(gsoa.sample_id, r'[_-]*(\\d{5})[_-]*'),
          REGEXP_EXTRACT_ALL(gso.local_key, r'[_-]*(\\d{5})[_-]*')
        ) as ids
      FROM gc_scv_obs as gso
      JOIN gc_scv_obs_attribs as gsoa
      ON
        gsoa.scv_obs_id = gso.scv_obs_id
      GROUP BY
        gso.scv_obs_id,
        gsoa.sample_id,
        gso.local_key
    ),
    gc_scv_obs_patient AS (
      SELECT
        gsopp.scv_obs_id,
        ARRAY_AGG(FORMAT("%%s_%%s",gsopp.prefix, id)) as patient_ids
      FROM gc_scv_obs_patient_prep gsopp
      CROSS JOIN UNNEST(gsopp.ids) as id
      GROUP BY
        gsopp.scv_obs_id
    ),
    patient_co_occurring_same_gene AS (
      SELECT
        patient_id,
        gso.gene_id,
        ARRAY_AGG(DISTINCT gso.scv_obs_id) as scv_obs_ids
      FROM gc_scv_obs gso
      JOIN gc_scv_obs_patient gsop
      ON
        gso.scv_obs_id = gsop.scv_obs_id
      CROSS JOIN UNNEST(gsop.patient_ids) as patient_id
      WHERE
        gso.gene_id IS NOT NULL
      GROUP BY
        patient_id,
        gso.gene_id
      HAVING
        COUNT(DISTINCT gso.variation_id) > 1
    ),
    obs_patient_co_occuring_scv AS (
      -- determine which scv_obs_id has patients with co-occurring variants in the same gene as the current scv
      SELECT
        this_scv_obs_id as scv_obs_id,
        pcosg_this.gene_id,
        pcosg_this.patient_id,
        ARRAY_AGG(STRUCT(gso_other.variation_id, other_scv_obs_id as scv_obs_id)) as co_occuring
      FROM patient_co_occurring_same_gene pcosg_this
      CROSS JOIN UNNEST(pcosg_this.scv_obs_ids) as this_scv_obs_id
      JOIN patient_co_occurring_same_gene pcosg_other
      ON
        pcosg_other.patient_id = pcosg_this.patient_id
        AND
        pcosg_other.gene_id = pcosg_this.gene_id
      CROSS JOIN UNNEST(pcosg_other.scv_obs_ids) as other_scv_obs_id
      JOIN gc_scv_obs gso_other
      ON
        gso_other.scv_obs_id = other_scv_obs_id
      WHERE
        other_scv_obs_id <> this_scv_obs_id
      GROUP BY
        this_scv_obs_id,
        pcosg_this.gene_id,
        pcosg_this.patient_id
    ),
    clinical_feature AS (
      SELECT
        gso.scv_obs_id,
        xref.id as xref_id,
        IFNULL(obs_trait.name, hpo.lbl) as name,
        JSON_EXTRACT_SCALAR(obs_trait.content, "$['@ClinicalFeaturesAffectedStatus']") as clinical_feature_affected_status
      FROM gc_scv_obs gso
      CROSS JOIN UNNEST( scv_obs_trait_ids ) as scv_obs_trait_id
      JOIN `%s.clinical_assertion_trait` obs_trait
      ON
        obs_trait.id = scv_obs_trait_id
      CROSS JOIN UNNEST (`clinvar_ingest.parseXRefs`(obs_trait.content)) as xref
      LEFT JOIN `clinvar_ingest.hpo_terms` hpo
      ON
        hpo.id = xref.id
      GROUP BY
        gso.scv_obs_id,
        xref.id,
        obs_trait.name,
        hpo.lbl,
        obs_trait.content
    ),
    gc_clinical_feature_set AS (
      select
        cf.scv_obs_id,
        ARRAY_TO_STRING(ARRAY_AGG(cf.name ORDER BY cf.name), ',\\n') as clinical_features
      FROM clinical_feature cf
      GROUP BY
        cf.scv_obs_id
    )

    -- filter out any records that don't have at least one of the
    -- following properties: lab_name, lab_id, lab_classification
    SELECT
      gso.scv_obs_id,
      gso.variation_id,
      gso.id,
      gso.version,
      FORMAT("%%s.%%i", gso.id, gso.version) as scv_acxn,
      gso.submitter_id,
      gsot.method_type,
      gsot.method_desc,
      gsot.lab_type,
      gsot.lab_id,
      gsot.lab_name,
      gsot.lab_classification,
      gsot.lab_classif_type,
      gsot.lab_date_reported,
      gso.local_key,
      gsoa.sample_id,
      gsoa.sample_variant_id,
      gso.obs_origin,
      gso.first_in_clinvar,
      gso.classification_comment,
      gso.hgnc_id,
      gso.gene_symbol,
      gso.variant_name,
      gso.vcv_first_in_clinvar,
      gso.vcvc_classification,
      gso.vcvc_rank,
      gsocc.case_count,
      cfs.clinical_features,
      opcos.co_occuring,
      gsop.patient_ids,
      gso.gene_id
    FROM gc_scv_obs gso
    JOIN gc_scv_obs_testing gsot
    ON
      gsot.scv_obs_id = gso.scv_obs_id
    LEFT JOIN gc_scv_obs_case_count gsocc
    ON
      gsocc.id = gso.id
    JOIN gc_scv_obs_attribs gsoa
    ON
      gsoa.scv_obs_id = gso.scv_obs_id
    JOIN gc_scv_obs_patient gsop
    ON
      gsop.scv_obs_id = gso.scv_obs_id
    LEFT JOIN gc_clinical_feature_set cfs
    ON
      cfs.scv_obs_id = gso.scv_obs_id
    LEFT JOIN obs_patient_co_occuring_scv opcos
    ON
      opcos.scv_obs_id = gso.scv_obs_id
    """, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name, schema_name);
END;
