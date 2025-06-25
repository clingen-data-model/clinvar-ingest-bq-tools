BEGIN
  DECLARE sql STRING DEFAULT '';
  DECLARE mmyy_array ARRAY<STRING>;

  SET mmyy_array = [
    '2023-01',
    '2023-02',
    '2023-03',
    '2023-04',
    '2023-05',
    '2023-06',
    '2023-07',
    '2023-08',
    '2023-09',
    '2023-10',
    '2023-11',
    '2023-12',
    '2024-01',
    '2024-02'];

  -- Loop through the array
  FOR rec IN (SELECT mmyy FROM UNNEST(mmyy_array) as mmyy)
  DO

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clingen-dev.clinvar_000.%s-rcv`
      AS
      SELECT
        id,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.ClinVarAccession['@Acc']") as rcv_accession,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.ClinVarAccession['@Version']") as rcv_version,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.ClinicalSignificance.Description") as clinical_significance,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.ClinicalSignificance.ReviewStatus") as review_status,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.MeasureSet['@Acc']") as vcv_id,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.MeasureSet['@Version']") as vcv_version,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.MeasureSet['@ID']") as variation_id,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.TraitSet['@ID']") as trait_set_id,
        JSON_EXTRACT_SCALAR(content, "$.ClinVarSet.ReferenceClinVarAssertion.TraitSet['@Type']") as trait_set_type,
        IF(
          ARRAY_LENGTH(JSON_EXTRACT_ARRAY(content, "$.ClinVarSet.ReferenceClinVarAssertion.TraitSet.Trait")) > 0,
          JSON_EXTRACT_ARRAY(content, "$.ClinVarSet.ReferenceClinVarAssertion.TraitSet.Trait"),
          [JSON_EXTRACT(content, "$.ClinVarSet.ReferenceClinVarAssertion.TraitSet.Trait")]
        ) as trait_content,
        IF(
          ARRAY_LENGTH(JSON_EXTRACT_ARRAY(content, "$.ClinVarSet.ClinVarAssertion")) > 0,
          JSON_EXTRACT_ARRAY(content, "$.ClinVarSet.ClinVarAssertion"),
          [JSON_EXTRACT(content, "$.ClinVarSet.ClinVarAssertion")]
        ) as scv_content
      FROM `clingen-dev.clinvar_000.%s-rcv-source`
    """, rec.mmyy, rec.mmyy);

    EXECUTE IMMEDIATE FORMAT(
      """
      CREATE OR REPLACE TABLE `clingen-dev.clinvar_000.%s-scv`
      AS
      SELECT
        rcv.rcv_accession,
        rcv.rcv_version,
        JSON_EXTRACT_SCALAR(scv_content, "$.ClinVarAccession['@Acc']") as scv_id,
        JSON_EXTRACT_SCALAR(scv_content, "$.ClinVarAccession['@Version']") as scv_version
      FROM `clingen-dev.clinvar_000.%s-rcv` rcv
      CROSS JOIN UNNEST(rcv.scv_content) as scv_content
    """
    , rec.mmyy, rec.mmyy);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clingen-dev.clinvar_000.%s-trait-extract`
      AS
      SELECT
        rcv.rcv_accession,
        rcv.rcv_version,
        rcv.trait_set_id,
        JSON_EXTRACT_SCALAR(trait_content, "$['@ID']") as trait_id,
        JSON_EXTRACT_SCALAR(trait_content, "$['@Type']") as trait_type,
        IF(
          ARRAY_LENGTH(JSON_EXTRACT_ARRAY(trait_content, "$.Name")) > 0,
          JSON_EXTRACT_ARRAY(trait_content, "$.Name"),
          IF(JSON_EXTRACT(trait_content, "$.Name") is NULL, NULL, [JSON_EXTRACT(trait_content, "$.Name")])
        ) as trait_name_content,
        IF(
          ARRAY_LENGTH(JSON_EXTRACT_ARRAY(trait_content, "$.Symbol")) > 0,
          JSON_EXTRACT_ARRAY(trait_content, "$.Symbol"),
          IF(JSON_EXTRACT(trait_content, "$.Symbol") is NULL, NULL, [JSON_EXTRACT(trait_content, "$.Symbol")])
        ) as trait_symbol_content,
        `clinvar_ingest.parseXRefs`(TO_JSON_STRING(trait_content)) as xrefs
      FROM `clingen-dev.clinvar_000.%s-rcv` rcv
      CROSS JOIN UNNEST(rcv.trait_content) as trait_content
    """, rec.mmyy, rec.mmyy);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clingen-dev.clinvar_000.%s-trait`
      AS
      WITH trait_name AS (
        SELECT DISTINCT
          trait.trait_id,
          JSON_EXTRACT_SCALAR(name_content, "$.ElementValue['#text']") as name
        FROM `clingen-dev.clinvar_000.%s-trait-extract` trait
        CROSS JOIN UNNEST(trait.trait_name_content) as name_content
        WHERE
          JSON_EXTRACT_SCALAR(name_content, "$.ElementValue['@Type']") = 'Preferred'
      ),
      trait_symbol AS (
        SELECT DISTINCT
          trait.trait_id,
          JSON_EXTRACT_SCALAR(symbol_content, "$.ElementValue['#text']") as symbol
        FROM `clingen-dev.clinvar_000.%s-trait-extract` trait
        LEFT JOIN UNNEST(trait.trait_symbol_content) as symbol_content
        WHERE
          JSON_EXTRACT_SCALAR(symbol_content, "$.ElementValue['@Type']") = 'Preferred'
      ),
      trait_xref_id AS (
        SELECT DISTINCT
          trait.trait_id,
          IF(xref.id like '%%:%%', LOWER(xref.id), IF(xref.db = 'OMIM', IF(xref.id LIKE 'PS%%', 'mimps:'||xref.id , 'mim:'||xref.id),LOWER(xref.db)||':'||xref.id)) as xref_id
        FROM `clingen-dev.clinvar_000.%s-trait-extract` trait
        LEFT JOIN UNNEST(trait.xrefs) as xref
        WHERE IFNULL(xref.type,'') <> 'secondary'
      ),
      uniq_trait AS (
        SELECT
          trait.trait_id
        from `clingen-dev.clinvar_000.%s-trait-extract` trait
        group by
          trait.trait_id
      )
      select
        trait.trait_id,
        trait_name.name,
        trait_symbol.symbol,
        ARRAY_TO_STRING(ARRAY_AGG(DISTINCT trait_xref_id.xref_id ORDER BY trait_xref_id.xref_id ASC),', ') as xref_ids
      from uniq_trait trait
      left join trait_name
      on
        trait_name.trait_id = trait.trait_id
      left join trait_symbol
      on
        trait_symbol.trait_id = trait.trait_id
      left join trait_xref_id
      on
        trait_xref_id.trait_id = trait.trait_id
      group by
        trait.trait_id,
        trait_name.name,
        trait_symbol.symbol
    """, rec.mmyy, rec.mmyy, rec.mmyy, rec.mmyy, rec.mmyy);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `clingen-dev.clinvar_000.%s-trait-set-mapping`
      AS
      SELECT
          trait.trait_set_id,
          trait.trait_id
      from `clingen-dev.clinvar_000.%s-trait-extract` trait
      group by
          trait.trait_set_id,
          trait.trait_id
    """, rec.mmyy, rec.mmyy);

  END FOR;

END;
