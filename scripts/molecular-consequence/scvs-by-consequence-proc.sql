-- CALL `clinvar_ingest.scvs_by_consequence`(CURRENT_DATE(), "missense variant", "significant");
CREATE OR REPLACE PROCEDURE `clinvar_ingest.scvs_by_consequence`(on_date DATE, consq_list STRING, significance STRING)
BEGIN
  -- parse the comma‑delimited string into an ARRAY<STRING>:
  DECLARE consq_arr ARRAY<STRING> DEFAULT SPLIT(consq_list, ',');
  DECLARE sig_val INT64;
  DECLARE rec STRUCT<schema_name STRING, release_date DATE, prev_release_date DATE, next_release_date DATE>;

  -- Declare a cursor to fetch the row
  SET rec = (
    SELECT AS STRUCT
      s.schema_name,
      s.release_date,
      s.prev_release_date,
      s.next_release_date
    FROM clinvar_ingest.schema_on(on_date) AS s
  );

  IF significance IS NULL THEN
    -- allow NULL through
    SET sig_val = NULL;
  ELSE
    -- map the three valid labels (case‑insensitive)
    SET sig_val = CASE
      WHEN LOWER(TRIM(significance)) = 'significant'     THEN 2
      WHEN LOWER(TRIM(significance)) = 'uncertain'       THEN 1
      WHEN LOWER(TRIM(significance)) = 'not significant' THEN 0
      ELSE NULL
    END;

    -- if it wasn’t one of the three, fail
    IF sig_val IS NULL THEN
      RAISE
        USING MESSAGE = FORMAT(
          'Invalid significance value: "%s". Must be one of: significant, uncertain, not significant, or NULL.',
          significance
        );
    END IF;
  END IF;

  -- execute it, binding the procedure’s ARRAY<STRING> to @consequences
  EXECUTE IMMEDIATE FORMAT(
    '''
      SELECT
        g.symbol,
        g.hgnc_id,
        vh.consq_label as consequence,
        IF(@significance IS NULL,'all',['not significant','uncertain','significant'][OFFSET(@significance)]) as significance,
        COUNT(DISTINCT scv.variation_id) as var_count,
        COUNT(scv.id) as scv_count,
        COUNTIF(scv.rank IN (3,4)) as scv_3_4_star_count,
        COUNTIF(scv.rank = 1) as scv_1_star_count,
        COUNTIF(scv.rank = 0) as scv_0_star_count,
        COUNTIF(scv.rank < 0) as no_star_count
        -- vi.name,
        -- vi.variation_type,
        -- IFNULL(vh.consq_label, "<N/A>") as molecular_consequence,
        -- scv.full_scv_id,
        -- scv.review_status,
        -- ["Significant","Uncertain","Not Significant"][OFFSET(significance)] as significance,
        -- scv.classif_type,
        -- scv.classification_label,
        -- scv.date_last_updated,
        -- scv.date_created,
        -- scv.submitter_id,
        -- scv.submitter_name

      FROM `%s.scv_summary` scv
      -- JOIN `s.variation_identity` vi
      -- ON
      --   vi.variation_id = scv.variation_id
      LEFT JOIN `%s.variation_hgvs` vh
      ON
        scv.variation_id = vh.variation_id
        AND
        vh.mane_select
      LEFT JOIN `%s.single_gene_variation` sgv
      ON
        scv.variation_id = sgv.variation_id
      LEFT JOIN `%s.gene` g
      ON
        g.id = sgv.gene_id
      WHERE
        (ARRAY_LENGTH(@consequences)=0 OR vh.consq_label IN UNNEST(@consequences))
        AND
        (@significance IS NULL OR scv.significance = @significance)
      GROUP BY
        g.symbol,
        g.hgnc_id,
        vh.consq_label
    ''',
    rec.schema_name,
    rec.schema_name,
    rec.schema_name,
    rec.schema_name
  )
  USING
    consq_arr AS consequences,
    sig_val AS significance
  ;

END;
