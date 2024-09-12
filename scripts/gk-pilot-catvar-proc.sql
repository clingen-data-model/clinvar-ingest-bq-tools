CREATE OR REPLACE PROCEDURE `clinvar_ingest.gk_pilot_catvar_proc`(on_date DATE)
BEGIN
  FOR rec IN (select s.schema_name FROM clinvar_ingest.schema_on(on_date) as s)
  DO
    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_pre_catvar_expression`
      AS
      WITH axn_chr_repair AS (
        select 
          variation_id,
          accession,
          IFNULL((CAST(REGEXP_EXTRACT(accession, r'CM000([0-9]+)\\.1') as INTEGER) - 662), CAST(REGEXP_EXTRACT(accession, r'NC_[0]+([0-9]+)\\.[0-9]+') AS INTEGER)) as derived_chr,
          CASE accession
            WHEN "CM000663.1" THEN "NC_000001.10"
            WHEN "CM000664.1" THEN "NC_000002.11"
            WHEN "CM000665.1" THEN "NC_000003.11"
            WHEN "CM000666.1" THEN "NC_000004.11"
            WHEN "CM000667.1" THEN "NC_000005.9"
            WHEN "CM000668.1" THEN "NC_000006.11"
            WHEN "CM000669.1" THEN "NC_000007.13"
            WHEN "CM000670.1" THEN "NC_000008.10"
            WHEN "CM000671.1" THEN "NC_000009.11"
            WHEN "CM000672.1" THEN "NC_000010.10"
            WHEN "CM000673.1" THEN "NC_000011.9"
            WHEN "CM000674.1" THEN "NC_000012.11"
            WHEN "CM000675.1" THEN "NC_000013.10"
            WHEN "CM000676.1" THEN "NC_000014.8"
            WHEN "CM000677.1" THEN "NC_000015.9"
            WHEN "CM000678.1" THEN "NC_000016.9"
            WHEN "CM000679.1" THEN "NC_000017.10"
            WHEN "CM000680.1" THEN "NC_000018.9"
            WHEN "CM000681.1" THEN "NC_000019.9"
            WHEN "CM000682.1" THEN "NC_000020.10"
            WHEN "CM000683.1" THEN "NC_000021.8"
            WHEN "CM000684.1" THEN "NC_000022.10"
            WHEN "CM000685.1" THEN "NC_000023.10"
            WHEN "CM000686.1" THEN "NC_000024.9"
            ELSE accession
          END AS NCBI_accession
        from `%s.variation_members`
        where 
          chr is null and assembly_version is not null
      ),
      exp_item AS ( 
        select 
          vi.variation_id,
          vi.accession,
          vi.fmt as syntax,
          vi.source as value,
          CAST(null as STRING) as hgvs_type,
          CAST(null as STRING) as issue,
          1 as precedence,
          IF(vi.accession = 'NC_012920.1', CAST(null as INTEGER), vi.assembly_version) as assembly_version
        from `%s.variation_identity` vi
        where 
          vi.fmt = 'spdi'
        UNION ALL
        -- select DISTINCT to eliminate the dupe MT occurences across builds
        select DISTINCT
          vl.variation_id,
          IFNULL(
            vl.accession,
            FORMAT('%%i-chr%%s', vl.assembly_version, vl.chr)
          ) as accession,
          'gnomad' as syntax,
          vl.gnomad_source as value,
          CAST(null as STRING) as hgvs_type,
          CAST(null as STRING) as issue,
          3 as precedence,
          IF(vl.accession = 'NC_012920.1', CAST(null as INTEGER), vl.assembly_version) as assembly_version
        from `%s.variation_loc` vl
        where
            vl.gnomad_source is not null 
        UNION ALL
        select 
          vh.variation_id,
          vh.accession,
          format('hgvs.%%s', IFNULL(REGEXP_EXTRACT(e.nucleotide, r':([gmcnrp])\\.'), LEFT(vh.type, 1))) as syntax,
          e.nucleotide as value,
          vh.type as hgvs_type,
          vh.issue,
          2 as precedence,
          IF(vh.accession = 'NC_012920.1', CAST(null as INTEGER), vh.assembly_version) as assembly_version
        from `%s.variation_hgvs` vh
        cross join unnest(expr) as e
        where
          e.nucleotide is not null
        UNION ALL
        select DISTINCT
          vl.variation_id,
          vl.accession,
          'hgvs.g' as syntax,
          vl.loc_hgvs_source as value,
          'genomic' as hgvs_type,
          vl.loc_hgvs_issue as issue,
          4 as precedence,    
          IF(vl.accession = 'NC_012920.1', CAST(null as INTEGER), vl.assembly_version) as assembly_version
        from `%s.variation_loc` vl
        left join `%s.variation_hgvs` vh
        on
          vh.variation_id = vl.variation_id
          and
          vh.accession = vl.accession
          and
          vh.assembly_version = vl.assembly_version
          and
          vh.assembly = vl.assembly 
        where
          vl.gnomad_source is null
          and
          vl.loc_hgvs_source is not null
          and 
          vh.variation_id is null
      )
      select
        exp_item.variation_id,
        IFNULL(acr.NCBI_accession, exp_item.accession) as accession,
        exp_item.assembly_version,
        (CASE exp_item.assembly_version WHEN 38 THEN 'GRCh38' WHEN 37 THEN 'GRCh37' WHEN 36 THEN 'NCBI36' ELSE null END) as assembly,
        ARRAY_AGG(STRUCT(exp_item.syntax, exp_item.value) ORDER BY exp_item.precedence) as expressions,
        ARRAY_AGG(DISTINCT exp_item.hgvs_type IGNORE NULLS ORDER BY exp_item.hgvs_type DESC) as types,
        ARRAY_AGG(DISTINCT exp_item.issue IGNORE NULLS) as issues
      from exp_item
      left join axn_chr_repair as acr
      on
        acr.variation_id = exp_item.variation_id
        and
        acr.accession = exp_item.accession
      group by 
        exp_item.variation_id,
        IFNULL(acr.NCBI_accession, exp_item.accession),
        exp_item.assembly_version 
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);

    EXECUTE IMMEDIATE FORMAT("""
      -- build pre-merged variation members
      CREATE OR REPLACE TABLE `%s.gk_pilot_pre_catvar_member`
      AS 
      WITH axn_chr_repair AS (
        select 
          variation_id,
          accession,
          IFNULL((CAST(REGEXP_EXTRACT(accession, r'CM000([0-9]+)\\.1') as INTEGER) - 662), CAST(REGEXP_EXTRACT(accession, r'NC_[0]+([0-9]+)\\.[0-9]+') AS INTEGER)) as derived_chr,
          CASE accession
            WHEN "CM000663.1" THEN "NC_000001.10"
            WHEN "CM000664.1" THEN "NC_000002.11"
            WHEN "CM000665.1" THEN "NC_000003.11"
            WHEN "CM000666.1" THEN "NC_000004.11"
            WHEN "CM000667.1" THEN "NC_000005.9"
            WHEN "CM000668.1" THEN "NC_000006.11"
            WHEN "CM000669.1" THEN "NC_000007.13"
            WHEN "CM000670.1" THEN "NC_000008.10"
            WHEN "CM000671.1" THEN "NC_000009.11"
            WHEN "CM000672.1" THEN "NC_000010.10"
            WHEN "CM000673.1" THEN "NC_000011.9"
            WHEN "CM000674.1" THEN "NC_000012.11"
            WHEN "CM000675.1" THEN "NC_000013.10"
            WHEN "CM000676.1" THEN "NC_000014.8"
            WHEN "CM000677.1" THEN "NC_000015.9"
            WHEN "CM000678.1" THEN "NC_000016.9"
            WHEN "CM000679.1" THEN "NC_000017.10"
            WHEN "CM000680.1" THEN "NC_000018.9"
            WHEN "CM000681.1" THEN "NC_000019.9"
            WHEN "CM000682.1" THEN "NC_000020.10"
            WHEN "CM000683.1" THEN "NC_000021.8"
            WHEN "CM000684.1" THEN "NC_000022.10"
            WHEN "CM000685.1" THEN "NC_000023.10"
            WHEN "CM000686.1" THEN "NC_000024.9"
            ELSE accession
          END AS NCBI_accession
          from `%s.variation_members`
        where 
          chr is null and assembly_version is not null
      ),
      seqref_ext_item AS (
        select 
          exp.variation_id,
          exp.accession,
          'chromosome' as name, 
          IFNULL(
            (CASE acr.derived_chr WHEN 24 THEN "Y" WHEN 23 THEN "X" ELSE CAST(acr.derived_chr as STRING) END), 
            vm.chr
          ) as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.gk_pilot_pre_catvar_expression` exp
        left join axn_chr_repair acr
        on
          acr.variation_id = exp.variation_id
          and
          acr.NCBI_accession = exp.accession
        join `%s.variation_members` vm
        on
          vm.variation_id = exp.variation_id
          and
          IFNULL(acr.NCBI_accession, vm.accession) = exp.accession
        WHERE vm.chr is not null OR acr.derived_chr is not null
        UNION ALL
        select DISTINCT
          exp.variation_id,
          exp.accession,
          'assembly' as name, 
          assembly as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
      from `%s.gk_pilot_pre_catvar_expression` exp
        where exp.assembly is not null
      ), 
      seqref_ext as (
        select
          variation_id,
          accession,
          ARRAY_AGG(
            STRUCT(
              name, 
              value_string, 
              value_boolean, 
              STRUCT(value_system as system, value_code as code, value_label as label) as value_coding
            ) ORDER BY seqref_ext_item.name
          ) as extensions,
        from seqref_ext_item
        group by 
          variation_id,
          accession
      ),
      var_ext_item as (
        SELECT 
          vm.variation_id,
          vm.accession,
          'molecular consequence' as name, 
          CAST(null as STRING) as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          SPLIT(consq_id,":")[OFFSET(0)] as value_system,
          SPLIT(consq_id,":")[OFFSET(1)] as value_code,
          consq_label as value_label
        FROM `%s.variation_members` vm
        WHERE consq_id is not null
        UNION ALL
        SELECT 
          vm.variation_id,
          vm.accession,
          'mane select' as name, 
          CAST(null as STRING) as value_string,
          TRUE as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        FROM `%s.variation_members` vm
        WHERE mane_select
        UNION ALL
        SELECT
          vm.variation_id,
          vm.accession,
          'mane plus' as name, 
          CAST(null as STRING) as value_string,
          TRUE as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        FROM `%s.variation_members` vm
        WHERE mane_plus
        UNION ALL
        SELECT DISTINCT 
          vh.variation_id,
          vh.accession,
          'protein expression' as name, 
          e.protein as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.variation_hgvs` vh
        cross join unnest(expr) as e
        where
          e.protein is not null
        UNION ALL
        SELECT DISTINCT
          vl.variation_id,
          vl.accession,
          'clinvar vcf' as name, 
          format('%%s-%%i-%%s-%%s', vl.chr, vl.position_vcf, IFNULL(vl.reference_allele_vcf,''), IFNULL(vl.alternate_allele_vcf,'')) as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.variation_loc` vl
        where
          vl.position_vcf is not null
        UNION ALL
        select DISTINCT
          exp.variation_id,
          exp.accession,
          'clinvar hgvs type' as name, 
          exp.types[OFFSET(0)] as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.gk_pilot_pre_catvar_expression` exp
        where ARRAY_LENGTH(exp.types) > 0
        UNION ALL
        select DISTINCT
          exp.variation_id,
          exp.accession,
          'pre-processing vrs issue' as name, 
          exp.issues[OFFSET(0)] as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.gk_pilot_pre_catvar_expression` exp
        where ARRAY_LENGTH(exp.issues) > 0
      ),
      var_ext as (
        select
          var_ext_item.variation_id,
          IFNULL(acr.NCBI_accession, var_ext_item.accession) as accession,
          array_agg(
            STRUCT(
              var_ext_item.name as name, 
              var_ext_item.value_string, 
              var_ext_item.value_boolean, 
              STRUCT(var_ext_item.value_system as system, var_ext_item.value_code as code, var_ext_item.value_label as label) as value_coding
            )
          ) as extensions
        from var_ext_item
        left join axn_chr_repair as acr
          on
            acr.variation_id = var_ext_item.variation_id
            and
            acr.accession = var_ext_item.accession
        group by
          var_ext_item.variation_id,
          IFNULL(acr.NCBI_accession, var_ext_item.accession)
      ),
      vm_axn_rep AS (
        select 
          *
        from (
          select 
            vm.*,
            row_number() over (partition by vm.variation_id, IFNULL(acr.NCBI_accession, vm.accession) order by vm.precedence) as rn
          from `%s.variation_members` vm
          left join axn_chr_repair as acr
          on
            acr.variation_id = vm.variation_id
            and
            acr.accession = vm.accession
        )
      )  
      select 
        r.variation_id, 
        r.accession,
        r.precedence,
        STRUCT(
          FORMAT('clinvar:%%s-%%s',r.variation_id, r.accession) as id,
          r.vrs_class as type,
          IF(r.fmt = 'gnomad', FORMAT('%%s (%%s)',r.source, exp.assembly), r.source) as label,
          exp.expressions,
          ext.extensions,
          STRUCT(
            'SequenceLocation' as type,
            STRUCT(
              r.accession as id,
              'SequenceReference' as type,
              'na' as residueAlphabet,
              sqext.extensions
            ) as sequenceReference,
            vl.derived_start as start,
            vl.derived_stop as `end`
          ) as location,
          if(ARRAY_LENGTH(r.range_copies)>0, TO_JSON_STRING(r.range_copies), CAST(r.absolute_copies as STRING)) as copies,
          r.copy_change_type as copyChange
        ) member
      from vm_axn_rep r
      left join var_ext ext
      on 
        ext.variation_id = r.variation_id 
        and 
        ext.accession = r.accession
      left join `%s.gk_pilot_pre_catvar_expression` exp
      on 
        exp.variation_id = r.variation_id 
        and 
        exp.accession = r.accession
      left join seqref_ext sqext
      on 
        sqext.variation_id = r.variation_id 
        and 
        sqext.accession = r.accession
      left join `%s.variation_loc` vl
      on
        vl.variation_id = r.variation_id
        and
        vl.accession = r.accession
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);

    EXECUTE IMMEDIATE FORMAT("""
      -- build pre-merged variation members
      CREATE OR REPLACE TABLE `%s.gk_pilot_pre_catvar`
      AS
      WITH cat_ext_item AS (
        select
          vrs.`in`.variation_id,
          'catVarSubType' as name,
          (
            
            IF(
              vrs.`out`.errors is not null,
              -- if there are any vrs processing errors then use DescribedVariation,
              'DescribedVariation',
              CASE vrs.`in`.vrs_class 
              WHEN 'Allele' THEN 'CanonicalAllele' 
              WHEN 'CopyNumberChange' THEN 'CategoricalCnvChange' 
              WHEN 'CopyNumberCount' THEN 'CategoricalCnvCount' 
              ELSE 'DescribedVariation' END
            )
          ) as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.gk_pilot_vrs` vrs
        union all
        select
          variation_id,
          'variationType' as name,
          vi.variation_type as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.variation_identity` vi
        WHERE vi.variation_type is not null
        union all
        select
          variation_id,
          'subclassType' as name,
          vi.subclass_type as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.variation_identity` vi
        where vi.subclass_type is not null
        union all
        select
          variation_id,
          'cytogeneticLocation' as name,
          vi.cytogenetic as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.variation_identity` vi
        where vi.cytogenetic is not null
        UNION ALL
        select
          vrs.in.variation_id,
          'vrsProcessingErrors' as name,
          vrs.out.errors as value_string,
          CAST(null as BOOLEAN) as value_boolean,
          CAST(null as STRING) as value_system,
          CAST(null as STRING) as value_code,
          CAST(null as STRING) as value_label
        from `%s.gk_pilot_vrs` vrs
        where vrs.out.errors is not null
      ),
      cat_exts AS (
        select
          x.variation_id,
          ARRAY_AGG(
            STRUCT(
              x.name, 
              x.value_string, 
              x.value_boolean, 
              STRUCT(x.value_system as system, x.value_code as code, x.value_label as label) as value_coding
            )
          ) as extensions
        from cat_ext_item x
        group by
          x.variation_id
      ),
      mem_merge AS (
        select
          vrs.in.variation_id,
          vrs.in.accession,
          tvm.precedence,
          STRUCT(
            vrs.`out`.id,
            vrs.`out`.type,
            tvm.member.label,
            vrs.`out`.digest,
            STRUCT(
              vrs.`out`.location.id,
              vrs.`out`.location.type,
              vrs.`out`.location.digest,
              STRUCT(
                tvm.member.location.sequenceReference.id,
                vrs.`out`.location.sequenceReference.type,
                vrs.`out`.location.sequenceReference.refgetAccession,
                'na' as residueAlphabet,
                tvm.member.location.sequenceReference.extensions
              ) as sequenceReference,
              vrs.`out`.location.start,
              vrs.`out`.location.`end`
            ) as location,
            STRUCT(
              vrs.`out`.state.type,
              vrs.`out`.state.sequence,
              vrs.`out`.state.length,
              vrs.`out`.state.repeatSubunitLength
            ) as state,
            CAST(vrs.`out`.copies as STRING) as copies,
            vrs.`out`.copyChange,
            tvm.member.expressions
          ) member,
          tvm.member.copies,
          tvm.member.copyChange
        from `%s.gk_pilot_vrs` vrs
        join `%s.gk_pilot_pre_catvar_member` tvm
        on
          tvm.variation_id = vrs.in.variation_id
          and
          tvm.accession = vrs.in.accession
        WHERE vrs.`out`.id is not null
        UNION ALL
        select
          tvm.variation_id,
          tvm.accession,
          tvm.precedence,
          STRUCT(
            tvm.member.id,
            tvm.member.type,
            tvm.member.label,
            CAST(null as STRING) as digest,
            STRUCT(
              CAST(null as STRING) as id,
              tvm.member.location.type,
              CAST(null as STRING) as digest,
              STRUCT(
                tvm.member.location.sequenceReference.id,
                tvm.member.location.sequenceReference.type,
                CAST(null as STRING) as refgetAccession,
                'na' as residueAlphabet,
                tvm.member.location.sequenceReference.extensions
              ) as sequenceReference,
              tvm.member.location.start,
              tvm.member.location.`end`
            ) as location,
            STRUCT(
              CAST(null as STRING) as type,
              CAST(null as STRING) as sequence,
              CAST(null as INTEGER) as length,
              CAST(null as INTEGER) as repeatSubunitLength
            ) as state,
            tvm.member.copies,
            tvm.member.copyChange,
            tvm.member.expressions
          ) member,
          tvm.member.copies,
          tvm.member.copyChange
        from `%s.gk_pilot_pre_catvar_member` tvm
        left join `%s.gk_pilot_vrs` vrs
        on
          tvm.variation_id = vrs.in.variation_id
          and
          tvm.accession = vrs.in.accession
        where 
          vrs.`in` is null
      ),
     pre_catvars as (
        select
          vi.variation_id,
          vi.name as label,
          ARRAY_AGG(m.member IGNORE NULLS ORDER BY m.precedence) as members
        from `%s.variation_identity` vi
        left join mem_merge m
        on
          m.variation_id = vi.variation_id
        group by
          vi.variation_id,
          vi.name
      ),
      cv_constraint_item AS (

        SELECT
          vrs.`in`.variation_id,
          'DefiningContextConstraint' as type,
          vrs.`out` as definingContext_allele,
          null as definingContext_location,
          ['sequence_liftover','transcript_projection'] as relations,
          null as copies,
          null as copyChange
        from `%s.gk_pilot_vrs` vrs
        WHERE vrs.`out`.type = 'Allele' 
        UNION ALL
        SELECT
          vrs.`in`.variation_id,
          'DefiningContextConstraint' as type,
          null as definingContext_allele,
          vrs.`out`.location as definingContext_location,
          ['sequence_liftover'] as relations,
          null as copies,
          null as copyChange
        from `%s.gk_pilot_vrs` vrs
        WHERE vrs.`out`.type IN ('CopyNumberCount' , 'CopyNumberChange')
        UNION ALL
        SELECT
          vrs.`in`.variation_id,
          'CopyCountConstraint' as type,
          null as definingContext_allele,
          null as definingContext_location,
          null as relations,
          vrs.`out`.copies as copies,
          null as copyChange
        from `%s.gk_pilot_vrs` vrs
        WHERE vrs.`out`.type = 'CopyNumberCount' 
        UNION ALL
        SELECT
          vrs.`in`.variation_id,
          'CopyChangeConstraint' as type,
          null as definingContext_allele,
          null as definingContext_location,
          null as relations,
          null as copies,
          STRUCT(
            'https://www.ebi.ac.uk/ols4/search?ontology=efo&q=' as system,
            vrs.`out`.copyChange as code,
            IF (
              vrs.`out`.copyChange = 'EFO:0030067',
              'Copy Number Loss',
              'Copy Number Gain'
            ) as label
          ) as copyChange
        from `%s.gk_pilot_vrs` vrs
        WHERE vrs.`out`.type = 'CopyNumberChange' 

      ),
      cv_constraints AS (
        SELECT
          ci.variation_id,
          ARRAY_AGG(
            STRUCT(ci.type, ci.definingContext_allele, ci.definingContext_location, relations, copies, copyChange)
          ) as constraints
        FROM cv_constraint_item ci
        GROUP BY
          ci.variation_id
      )

      select
        FORMAT('clinvar:%%s',cv.variation_id) as id,
        'CategoricalVariant' as type,
        cv.label,
        cx.constraints,
        cv.members,
        vi.mappings,
        x.extensions
      from pre_catvars cv
      join `%s.variation_identity` vi
      on
        cv.variation_id = vi.variation_id
      -- -- add extensions
      join cat_exts x 
      on
        x.variation_id = cv.variation_id
      left join cv_constraints cx
      on
        cx.variation_id = cv.variation_id
    """, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name, rec.schema_name);

    EXECUTE IMMEDIATE FORMAT("""
      CREATE OR REPLACE TABLE `%s.gk_pilot_catvar`
      AS
      WITH x as (
        SELECT 
          JSON_STRIP_NULLS(
            TO_JSON(tv),
          remove_empty => TRUE
          ) AS json_data
        FROM `%s.gk_pilot_pre_catvar` tv
      )
      select `clinvar_ingest.normalizeAndKeyById`(x.json_data) as rec from x
    """, rec.schema_name, rec.schema_name);

  END FOR;

END;