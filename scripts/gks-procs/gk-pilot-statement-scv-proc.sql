CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_statement_scv_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_pre_statement_scv`
      as
      WITH scv_citation AS
      (
        select
          gks.id,
          STRUCT(
            "Document" as type,
            IF(lower(cid.source) = 'pubmed', cid.id, null) as pmid, 
            IF(lower(cid.source) = 'doi', cid.id, null) as doi,
            CASE 
            WHEN c.url is not null THEN 
              c.url
            WHEN lower(cid.source) = "pubmed" THEN 
              FORMAT('https://pubmed.ncbi.nlm.nih.gov/%%s',cid.id)
            WHEN lower(cid.source) = "pmc" THEN 
              FORMAT('https://europepmc.org/article/PMC/%%s',cid.id)
            WHEN lower(cid.source) = "doi" THEN 
              FORMAT('https://doi.org/%%s',cid.id)
            WHEN lower(cid.source) = "bookshelf" THEN 
              FORMAT('https://www.ncbi.nlm.nih.gov/books/%%s',cid.id)
            ELSE
              cid.curie
            END as url
          ) as doc
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.interpCitations) as c
        cross join unnest(c.id) as cid
        where cid.source is not null
        UNION ALL
        select
          gks.id,
          STRUCT(
            "Document" as type,
            IF(lower(cid.source) = 'pubmed', cid.id, null) as pmid,
            IF(lower(cid.source) = 'doi', cid.id, null) as doi,
            CASE 
            WHEN c.url is not null THEN 
              c.url
            WHEN lower(cid.source) = "pubmed" THEN 
              FORMAT('https://pubmed.ncbi.nlm.nih.gov/%%s',cid.id)
            WHEN lower(cid.source) = "pmc" THEN 
              FORMAT('https://europepmc.org/article/PMC/%%s',cid.id)
            WHEN lower(cid.source) = "doi" THEN 
              FORMAT('https://doi.org/%%s',c.id)
            WHEN lower(cid.source) = "bookshelf" THEN 
              FORMAT('https://www.ncbi.nlm.nih.gov/books/%%s',cid.id)
            ELSE
              cid.curie
            END as url
          ) as doc
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.interpCitations) as c
        cross join unnest(c.id) as cid
        where cid.source is null and c.url is not null
      ),
      scv_citations as (
        SELECT
          id,
          ARRAY_AGG(doc) as reportedIn
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
            "First in Clinvar" as label,
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
              (cid.source is not null OR c.url is not null),
              STRUCT(
                "Document" as type,
                IF(lower(cid.source) = 'pubmed', STRING_AGG(cid.id), null) as pmid,
                IF(lower(cid.source) = 'doi', STRING_AGG(cid.id), null) as doi,
                CASE 
                WHEN c.url is not null THEN 
                  c.url
                WHEN lower(ccid.source) = "pubmed" THEN 
                  FORMAT('https://pubmed.ncbi.nlm.nih.gov/%%s',STRING_AGG(cid.id))
                WHEN lower(cidsource) = "pmc" THEN 
                  FORMAT('https://europepmc.org/article/PMC/%%s',STRING_AGG(cid.id))
                WHEN lower(cid.source) = "doi" THEN 
                  FORMAT('https://doi.org/%%s',STRING_AGG(cid.id))
                WHEN lower(cid.source) = "bookshelf" THEN 
                  FORMAT('https://www.ncbi.nlm.nih.gov/books/%%s',STRING_AGG(cid.id))
                ELSE
                  FORMAT('%%s:%%s', cid.source, STRING_AGG(cid.id))
                END as url
              ),
              null
            ) as reportedIn
          ) as specifiedBy
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.attribs) as a
        left join unnest(a.citation) as c
        left join unnest(c.id) as cid
        where a.attribute.type = "AssertionMethod"
        group by 
          gks.id,
          a.attribute.value,
          cid.source,
          c.url
      ),
      scv_moi as (
        select
          gks.id,
          a.attribute.value as label
        from `%s.gk_pilot_scv` gks
        cross join unnest(gks.attribs) as a
        where a.attribute.type = "ModeOfInheritance"
      ),
      scv_ext as (
        select
          gks.id,
          "alleleOrigin" as name, 
          gks.origin as value
        from `%s.gk_pilot_scv` gks
        where (gks.review_status is not null)
        UNION ALL      
        select
          gks.id,
          "reviewStatus" as name, 
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
          "methodCategory" as name, 
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
      -- final output before it is normalized into json
      select 
        gks.id as scv_id,
        gks.version as scv_ver,  

        FORMAT('%%s.%%i', gks.id, gks.version) as id,
        (
          CASE cct.clinvar_prop_type
          WHEN 'path' THEN 'VariantPathogenicityStatement' 
          WHEN 'dr' THEN 'VariantDrugResponseStatement' 
          WHEN 'np' THEN 'VariantNoAssertionStatement' 
          ELSE 'VariantMiscallaneousAssertionStatement' 
          END
        ) as type,
        STRUCT(
          cv.id as id,
          cv.type as type,
          cv.label as label,
          cv.constraints as constraints,
          cv.members as members,
          cv.mappings as mappings,
          cv.extensions as extensions
        ) as subjectVariation,   
        (
          CASE cct.clinvar_prop_type
          WHEN 'path' THEN 'isCausalFor'
          WHEN 'dr' THEN 'isClinvarDrugResponseFor'
          WHEN 'np' THEN 'isClinvarNonAssertionFor'
          ELSE 'isClinvarOtherAssertionFor'
          END
        ) as predicate,
        simple_cond.condition as objectCondition_simple,
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
        as objectCondition_complex,
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
        gks.classification_comment as statementText,
        cct.penetrance_level as penetranceQualifier,
        gks.geneContextQualifier,
        contrib.contributions,
        scv_method.specifiedBy,
        scv_citations.reportedIn,
        scv_exts.extensions
      from  `%s.gk_pilot_scv` gks
      join `%s.gk_pilot_pre_catvar` cv
      on
        SPLIT(cv.id, ":")[OFFSET(1)] = gks.variation_id
      left join scv_citations
      on
        gks.id = scv_citations.id
      left join `clinvar_ingest.clinvar_clinsig_types` cct 
      on 
        cct.code = gks.classif_type
        and
        cct.statement_type = gks.statement_type??
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
        from `%s.gk_pilot_trait` gkt
        JOIN (
          select scv_id
          from `%s.gk_pilot_trait`
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
        from `%s.gk_pilot_trait` gkt
        JOIN (
          select scv_id
          from `%s.gk_pilot_trait`
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
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_statement_scv`
      AS
      WITH x as (
        SELECT 
          JSON_STRIP_NULLS(
            TO_JSON(tv),
          remove_empty => TRUE
          ) AS json_data
        FROM `%s.gk_pilot_pre_statement_scv` tv
      )
      select `clinvar_ingest.normalizeAndKeyById`(x.json_data) as rec from x
    """, rec.schema_name, rec.schema_name);

  END FOR;

END;