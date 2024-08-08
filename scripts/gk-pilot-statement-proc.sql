CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_statement_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_pre_statement`
      as
      WITH scv_citation AS
      (
        select
          gks.id,
          STRUCT(
            "Document" as type,
            IF(lower(c.source) = 'pubmed', c.id, null) as pmid,
            IF(lower(c.source) = 'doi', c.id, null) as doi,
            CASE 
            WHEN c.url is not null THEN 
              c.url
            WHEN lower(c.source) = "pubmed" THEN 
              FORMAT('https://pubmed.ncbi.nlm.nih.gov/%%s',c.id)
            WHEN lower(c.source) = "pmc" THEN 
              FORMAT('https://europepmc.org/article/PMC/%%s',c.id)
            WHEN lower(c.source) = "doi" THEN 
              FORMAT('https://doi.org/%%s',c.id)
            WHEN lower(c.source) = "bookshelf" THEN 
              FORMAT('https://www.ncbi.nlm.nih.gov/books/%%s',c.id)
            ELSE
              FORMAT('%%s:%%s', c.source, c.id)
            END as url
          ) as doc
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.interpCitations) as c
        where c.source is not null
        UNION ALL
        select
          gks.id,
          STRUCT(
            "Document" as type,
            IF(lower(c.source) = 'pubmed', c.id, null) as pmid,
            IF(lower(c.source) = 'doi', c.id, null) as doi,
            CASE 
            WHEN c.url is not null THEN 
              c.url
            WHEN lower(c.source) = "pubmed" THEN 
              FORMAT('https://pubmed.ncbi.nlm.nih.gov/%%s',c.id)
            WHEN lower(c.source) = "pmc" THEN 
              FORMAT('https://europepmc.org/article/PMC/%%s',c.id)
            WHEN lower(c.source) = "doi" THEN 
              FORMAT('https://doi.org/%%s',c.id)
            WHEN lower(c.source) = "bookshelf" THEN 
              FORMAT('https://www.ncbi.nlm.nih.gov/books/%%s',c.id)
            ELSE
              FORMAT('%%s:%%s', c.source, c.id)
            END as url
          ) as doc
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.interpCitations) as c
        where c.source is null and c.url is not null
      ),
      scv_citations as (
        SELECT
          id,
          ARRAY_AGG(doc) as isReportedIn
        from scv_citation
        group by id
      ),
      contrib AS (
        select
          gks.id ,
        [
          STRUCT(
            "Last Updated" as label,
            "Contribution" as type,
            gks.submitter as agent,
            gks.date_last_updated as date,
            STRUCT(
                "CRO_0000105" as code,
                "http://purl.obolibrary.org/obo/" as system,
                "submitter role" as label
            ) as activity
          ),
          STRUCT(
            "First in ClinVar" as label,
            "Contribution" as type,
            gks.submitter as agent,
            gks.date_created as date,
            STRUCT(
                "CRO_0000105" as code,
                "http://purl.obolibrary.org/obo/" as system,
                "submitter role" as label
            ) as activity
          ),
          STRUCT(
            "Last Evaluated" as label,
            "Contribution" as type,
            gks.submitter as agent,
            gks.interpretation_date_last_evaluated as date,
            STRUCT(
                "CRO_0000001" as code,
                "http://purl.obolibrary.org/obo/" as system,
                "author role" as label
            ) as activity
          )
        ] as contributions
        from `%s.gk_pilot_scv` gks
      ),
      scv_method as (
        -- there are less than 10 assertion method attributes that contain multiple citations
        --   these are likely mis-submitted info since they should be in the interp citations not the assertion method citations which should almost exclusively be 1 item
        --   for now we comprimise by grouping any multi- citation id values together as a string and hoping that the citation source and url will aggregate to the same single record.
        --  this hacky policy works around the bad data as of 2024-04-07
        select
          gks.id,
          STRUCT (
            "Method" as type,
            a.attribute.value as label,
            IF(
              (c.source is not null OR c.url is not null),
              STRUCT(
                "Document" as type,
                IF(lower(c.source) = 'pubmed', STRING_AGG(c.id), null) as pmid,
                IF(lower(c.source) = 'doi', STRING_AGG(c.id), null) as doi,
                CASE 
                WHEN c.url is not null THEN 
                  c.url
                WHEN lower(c.source) = "pubmed" THEN 
                  FORMAT('https://pubmed.ncbi.nlm.nih.gov/%%s',STRING_AGG(c.id))
                WHEN lower(c.source) = "pmc" THEN 
                  FORMAT('https://europepmc.org/article/PMC/%%s',STRING_AGG(c.id))
                WHEN lower(c.source) = "doi" THEN 
                  FORMAT('https://doi.org/%%s',STRING_AGG(c.id))
                WHEN lower(c.source) = "bookshelf" THEN 
                  FORMAT('https://www.ncbi.nlm.nih.gov/books/%%s',STRING_AGG(c.id))
                ELSE
                  FORMAT('%%s:%%s', c.source, STRING_AGG(c.id))
                END as url
              ),
              null
            ) as isReportedIn
          ) as method
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.attribs) as a
        left join unnest(a.citation) as c
        where a.attribute.type = "AssertionMethod"
        group by 
          gks.id,
          a.attribute.value,
          c.source,
          c.url
      ),
      scv_ext as (
        select
          gks.id,
          "clinvarReviewStatus" as name, 
          gks.review_status as value
        from `%s.gk_pilot_scv` gks
        where (gks.review_status is not null)
        UNION ALL
        select
          gks.id,
          "submittedClassification" as name, 
          gks.submitted_classification as value
        from `%s.gk_pilot_scv` gks
        where (gks.submitted_classification is not null)
        UNION ALL
        select
          gks.id,
          "clinvarMethodCategory" as name, 
          gks.method_type as value
        from `%s.gk_pilot_scv` gks
        where (gks.method_type is not null)
        UNION ALL
        select
          gks.id,
          "localKey" as name, 
          gks.local_key as value
        from `%s.gk_pilot_scv` gks
        where (gks.local_key is not null)
      ),
      scv_exts AS (
        select
          se.id,
          ARRAY_AGG(STRUCT(name, value)) as extensions
        from scv_ext as se
        group by se.id
      )
      select 
        gks.id as scv_id,
        gks.version as scv_ver,  
        FORMAT('%%s.%%i', gks.id, gks.version) as id,
        (
          CASE cct.clinvar_prop_type
          WHEN 'path' THEN 'VariationPathogenicity' 
          WHEN 'dr' THEN 'ClinVarDrugResponse' 
          WHEN 'np' THEN 'ClinVarNonAssertion' 
          ELSE 'ClinVarOtherAssertion' 
          END
        ) as type,
        cv as variation,  
        (
          CASE cct.clinvar_prop_type
          WHEN 'path' THEN 'isCausalFor'
          WHEN 'dr' THEN 'isClinVarDrugResponseFor'
          WHEN 'np' THEN 'isClinVarNonAssertionFor'
          ELSE 'isClinVarOtherAssertionFor'
          END
        ) as predicate,
        simple_cond.condition as condition_simple,
        IF(
          complex_cond.scv_id is not null,
          STRUCT(
            FORMAT("clinvarTraitSet:%%s",IFNULL(complex_cond.trait_set_id, complex_cond.scv_id)) as id,
            "TraitSet" as type,
            complex_cond.label,
            complex_cond.traits,
            IF(
              complex_cond.trait_set_type is null,
              null,
              [STRUCT("clinvarTraitSetType" as name, complex_cond.trait_set_type as value)]
            ) as extensions
          ),
          null
        )
        as condition_complex,
        STRUCT(
          cct.label as label,
          cct.classification_code as code,
          "https://dataexchange.clinicalgenome.org/codes/" as system
        ) as classification,
        STRUCT(
          cct.strength_label as label,
          cct.strength_code as code,
          "https://dataexchange.clinicalgenome.org/codes/" as system
        ) as strength,
        cct.direction,
        gks.description,
        STRUCT (
          cct.penetrance_level as penetrance
        ) as qualifiers,
        contrib.contributions,
        scv_method.method,
        scv_citations.isReportedIn,
        scv_exts.extensions
      from  `%s.gk_pilot_scv` gks
      -- use the pre-processed gk_pilot_catvars table since you will need to reprocess everthing inlined again
      -- NOTE teh pre_catvar.id is a CURIE (dumb idea - now that i'm trying to join - maybe go back and keep it simple)
      join `%s.pre_catvar` cv
      on
        SPLIT(cv.id, ":")[OFFSET(1)] = gks.variation_id
      left join scv_citations
      on
        gks.id = scv_citations.id
      left join `clinvar_ingest.clinvar_clinsig_types` cct 
      on 
        cct.code = gks.classif_type
      left join scv_exts
      on
        scv_exts.id = gks.id
      left join contrib 
      on
        contrib.id = gks.id
      left join scv_method 
      on
        scv_method.id = gks.id
      left join (
        select
          gkt.scv_id,
          gkt.condition
        from `%s.gk_pilot_traits` gkt
        JOIN (
          select scv_id
          from `%s.gk_pilot_traits`
          group by scv_id
          having count(*) = 1
        ) solo 
        on solo.scv_id = gkt.scv_id
      ) simple_cond
      on
        simple_cond.scv_id = gks.id
      left join (
        select
          gkt.scv_id,
          gkt.trait_set_id,
          gkt.trait_set_type,
          STRING_AGG(CONCAT("- ",gkt.condition.label), "\\n" ORDER BY gkt.condition.label) as label,
          ARRAY_AGG(gkt.condition) as traits
        from `%s.gk_pilot_traits` gkt
        JOIN (
          select scv_id
          from `%s.gk_pilot_traits`
          group by scv_id
          having count(*) > 1
        ) multi 
        on multi.scv_id = gkt.scv_id
        group by 
          gkt.scv_id,
          gkt.trait_set_id,
          gkt.trait_set_type
      ) complex_cond
      on
        complex_cond.scv_id = gks.id
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_statement`
      AS
      WITH x as (
        SELECT 
          JSON_STRIP_NULLS(
            TO_JSON(tv),
          remove_empty => TRUE
          ) AS json_data
        FROM `%s.gk_pilot_pre_statement` tv
      )
      select `clinvar_ingest.normalizeAndKeyById`(x.json_data) as rec from x
    """, rec.schema_name, rec.schema_name);

  END FOR;

END;