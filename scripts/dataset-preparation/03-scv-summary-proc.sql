CREATE OR REPLACE PROCEDURE `clinvar_ingest.scv_summary`(
  schema_name STRING
)
BEGIN

  DECLARE sql STRING;

  -- ============================================================
  -- Step 1: Single pass over clinical_assertion
  --         Parse all content-dependent fields once, drop content
  -- ============================================================
  SET sql = """
    CREATE TEMP TABLE ca_parsed
    CLUSTER BY id AS
    SELECT
      ca.id,
      ca.version,
      ca.variation_id,
      ca.local_key,
      ca.release_date,
      ca.date_created,
      ca.date_last_updated,
      ca.statement_type,
      ca.clinical_impact_assertion_type,
      ca.clinical_impact_clinical_significance,
      ca.review_status,
      ca.interpretation_description,
      ca.interpretation_date_last_evaluated,
      -- flatten interpretation_comments here to avoid carrying the raw array
      (SELECT STRING_AGG(JSON_EXTRACT_SCALAR(c, r'$.text'), '\\n')
       FROM UNNEST(ca.interpretation_comments) as c) as classification_comment,
      ca.rcv_accession_id,
      ca.submitter_id,
      ca.submission_id,
      ca.clinical_assertion_observation_ids,
      -- extract classification/interpretation JSON in one pass
      JSON_EXTRACT(ca.content, r'$.Classification') as classification_json,
      JSON_EXTRACT(ca.content, r'$.Interpretation') as interpretation_json,
      -- parse attribute sets and comments from content once
      `clinvar_ingest.parseAttributeSet`(ca.content) as attribute_sets,
      `clinvar_ingest.parseComments`(ca.content) as comments
    FROM
      `@schema.clinical_assertion` ca
    WHERE
      -- exclude null statement_type records which were introduced in the 2025-08-08 release due to
      -- the segregation of functional data statements from GermlineClassification scvs.
      ca.statement_type IS NOT NULL
  """;
  SET sql = REPLACE(sql, '@schema', schema_name);
  EXECUTE IMMEDIATE sql;

  -- ============================================================
  -- Step 2: Single pass over clinical_assertion_observation
  --         Parse both sample and method in one scan
  -- ============================================================
  SET sql = """
    CREATE TEMP TABLE obs_parsed
    CLUSTER BY id AS
    SELECT
      REGEXP_EXTRACT(obs.id, r'^SCV[0-9]+') as id,
      `clinvar_ingest.parseSample`(obs.content) as s,
      m.description as method_desc,
      m.method_type
    FROM
      `@schema.clinical_assertion_observation` obs
    LEFT JOIN UNNEST(`clinvar_ingest.parseMethods`(obs.content)) as m
    WHERE
      -- only keep observations that match a known clinical_assertion id
      REGEXP_EXTRACT(obs.id, r'^SCV[0-9]+') IN (SELECT id FROM ca_parsed)
  """;
  SET sql = REPLACE(sql, '@schema', schema_name);
  EXECUTE IMMEDIATE sql;

  -- ============================================================
  -- Step 3: Build derived temp tables from materialized data
  -- ============================================================

  -- 3a: Assertion method from pre-extracted attribute sets
  EXECUTE IMMEDIATE """
    CREATE TEMP TABLE assertion_method
    CLUSTER BY id AS
    SELECT
      ca.id,
      a.attribute.type,
      a.attribute.value,
      STRING_AGG(DISTINCT c.url, ';') as url
    FROM
      ca_parsed ca,
      UNNEST(ca.attribute_sets) as a,
      UNNEST(a.citation) as c
    WHERE
      a.attribute.type = 'AssertionMethod'
      AND c.url IS NOT NULL
    GROUP BY
      ca.id,
      a.attribute.type,
      a.attribute.value
  """;

  -- 3b: Observation aggregates
  EXECUTE IMMEDIATE """
    CREATE TEMP TABLE obs_agg
    CLUSTER BY id AS
    SELECT
      ca.id,
      STRING_AGG(DISTINCT op.s.origin, ', ' ORDER BY op.s.origin) as origin,
      STRING_AGG(DISTINCT op.s.affected_status, ', ' ORDER BY op.s.affected_status) as affected_status,
      STRING_AGG(DISTINCT op.method_desc, ', ' ORDER BY op.method_desc) as method_desc,
      STRING_AGG(DISTINCT op.method_type, ', ' ORDER BY op.method_type) as method_type
    FROM
      ca_parsed ca
    LEFT JOIN obs_parsed op
    ON
      op.id = ca.id
    GROUP BY
      ca.id
  """;

  -- 3c: PubMed citation IDs (only from rows that have citation data)
  EXECUTE IMMEDIATE """
    CREATE TEMP TABLE scv_pmids
    CLUSTER BY id AS
    SELECT
      ca.id,
      STRING_AGG(cit_id.id, ',' ORDER BY cit_id.id) as pmids
    FROM
      ca_parsed ca,
      UNNEST(`clinvar_ingest.parseCitations`(
        COALESCE(ca.classification_json, ca.interpretation_json)
      )) as cit,
      UNNEST(cit.id) as cit_id
    WHERE
      cit_id.source = 'PubMed'
      AND (ca.classification_json IS NOT NULL OR ca.interpretation_json IS NOT NULL)
    GROUP BY
      ca.id
  """;

  -- 3e: Clinical significance with review status ranking
  SET sql = """
    CREATE TEMP TABLE clinsig
    CLUSTER BY id AS
    SELECT
      ca.id,
      cst.original_proposition_type,
      cst.gks_proposition_type,
      def.rank,
      IFNULL(map.cv_clinsig_type, '-') as classif_type,
      cst.significance,
      FORMAT( '%s, %s, %t',
          cst.label,
          if(def.rank > 0, format("%i%s", def.rank, CHR(9733)), IF(def.rank = 0, format("%i%s", def.rank, CHR(9734)), "n/a")),
          if(ca.interpretation_date_last_evaluated is null, "<n/a>", format("%t", ca.interpretation_date_last_evaluated))) as classification_label,
      FORMAT( '%s, %s, %t',
          UPPER(map.cv_clinsig_type),
          if(def.rank > 0, format("%i%s", def.rank, CHR(9733)), IF(def.rank = 0, format("%i%s", def.rank, CHR(9734)), "n/a")),
          if(ca.interpretation_date_last_evaluated is null, "<n/a>", format("%t", ca.interpretation_date_last_evaluated))) as classification_abbrev
    FROM
      ca_parsed ca
    LEFT JOIN `clinvar_ingest.scv_clinsig_map` map
    ON
      map.scv_term = lower(IFNULL(ca.interpretation_description, 'not provided'))
    LEFT JOIN `clinvar_ingest.clinvar_clinsig_types` cst
    ON
      cst.code = map.cv_clinsig_type
      AND cst.statement_type = ca.statement_type
    LEFT JOIN `clinvar_ingest.status_rules` rules
    ON
      rules.review_status = LOWER(ca.review_status)
      AND rules.is_scv = TRUE
    LEFT JOIN `clinvar_ingest.status_definitions` def
    ON
      rules.review_status = def.review_status
      AND ca.release_date BETWEEN def.start_release_date AND def.end_release_date
  """;
  EXECUTE IMMEDIATE sql;

  -- ============================================================
  -- Step 4: Final assembly — joins only lightweight temp tables
  -- ============================================================
  SET sql = """
    CREATE OR REPLACE TABLE `@schema.scv_summary` AS
    SELECT
      ca.release_date,
      ca.id,
      ca.version,
      FORMAT('%s.%i', ca.id, ca.version) as full_scv_id,
      ca.variation_id,
      ca.local_key,
      ca.interpretation_date_last_evaluated as last_evaluated,
      ca.statement_type,
      cst.original_proposition_type,
      cst.gks_proposition_type,
      ca.clinical_impact_assertion_type,
      ca.clinical_impact_clinical_significance,
      cst.rank,
      ca.review_status,
      cst.classif_type,
      cst.significance,
      cst.classification_label,
      cst.classification_abbrev,
      ca.interpretation_description as submitted_classification,
      ca.comments,
      ca.classification_comment,
      ca.rcv_accession_id,
      rcv.trait_set_id,
      ca.date_created,
      ca.date_last_updated,
      ca.clinical_assertion_observation_ids,
      ca.submitter_id,
      subr.current_name as submitter_name,
      IFNULL(IFNULL(subr.current_abbrev, csa.current_abbrev), LEFT(subr.current_name, 25) || '...') as submitter_abbrev,
      subm.submission_date,
      obs.origin,
      obs.affected_status,
      obs.method_desc,
      obs.method_type,
      am.value as assertion_method,
      am.url as assertion_method_url,
      spm.pmids
    FROM
      ca_parsed ca
    LEFT JOIN clinsig cst
    ON
      cst.id = ca.id
    LEFT JOIN obs_agg obs
    ON
      obs.id = ca.id
    LEFT JOIN assertion_method am
    ON
      am.id = ca.id
    LEFT JOIN scv_pmids spm
    ON
      spm.id = ca.id
    LEFT JOIN `@schema.submitter` subr
    ON
      subr.id = ca.submitter_id
    LEFT JOIN `clinvar_ingest.clinvar_submitter_abbrevs` csa
    ON
      csa.submitter_id = subr.id
    LEFT JOIN `@schema.submission` subm
    ON
      subm.id = ca.submission_id
    LEFT JOIN `@schema.rcv_accession` rcv
    ON
      rcv.id = ca.rcv_accession_id
  """;
  SET sql = REPLACE(sql, '@schema', schema_name);
  EXECUTE IMMEDIATE sql;

  -- cleanup temp tables
  DROP TABLE IF EXISTS ca_parsed;
  DROP TABLE IF EXISTS obs_parsed;
  DROP TABLE IF EXISTS assertion_method;
  DROP TABLE IF EXISTS obs_agg;
  DROP TABLE IF EXISTS scv_pmids;
  DROP TABLE IF EXISTS clinsig;

END;
