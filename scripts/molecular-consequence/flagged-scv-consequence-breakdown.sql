SELECT
    scv.variation_id,
    vi.name,
    vi.variation_type,
    IFNULL(vh.consq_label, "<N/A>") as molecular_consequence,
    scv.full_scv_id,
    scv.review_status,
    scv.classif_type,
    scv.classification_label,
    scv.date_last_updated,
    scv.date_created,
    scv.submitter_id,
    scv.submitter_name

  FROM `clinvar_2025_06_23_v2_3_1.scv_summary` scv
  JOIN `clinvar_2025_06_23_v2_3_1.variation_identity` vi
  ON
    vi.variation_id = scv.variation_id
  LEFT JOIN `clinvar_2025_06_23_v2_3_1.variation_hgvs` vh
  ON
    scv.variation_id = vh.variation_id
    AND
    vh.mane_select
  WHERE
    scv.review_status like 'flagg%'
  ORDER BY 4
