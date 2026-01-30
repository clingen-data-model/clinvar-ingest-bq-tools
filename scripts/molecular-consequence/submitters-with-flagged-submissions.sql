select
  so.id,
  so.organization,
  so.country,
  so.institution_type,
  ARRAY_TO_STRING(so.collection_methods,',') as methods,
  so.number_of_clinvar_submissions,
  so.number_of_submissions_from_clinical_testing,
  so.number_of_submissions_from_curation,
  so.number_of_submissions_from_literature_only,
  so.number_of_submissions_from_phenotyping,
  so.number_of_submissions_from_research,
  anno.clinvar_review_status,
  COUNT(anno.scv_id) as number_of_flagged_submissions



from `clinvar_curator.cvc_annotations`("REVIEWED") anno
join `clinvar_ingest.submitter_organization` so
on
  so.id = anno.submitter_id
where
  anno.is_latest_annotation
  and
  anno.action = 'flagging candidate'
group by
  so.id,
  so.organization,
  so.country,
  so.institution_type,
  so.collection_methods,
  so.number_of_clinvar_submissions,
  so.number_of_submissions_from_clinical_testing,
  so.number_of_submissions_from_curation,
  so.number_of_submissions_from_literature_only,
  so.number_of_submissions_from_phenotyping,
  so.number_of_submissions_from_research,
  anno.clinvar_review_status
