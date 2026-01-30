-- CALL `clinvar_ingest.vcvs_by_consequence`(CURRENT_DATE(), "missense variant,genic upstream transcript variant", "significant");
CREATE OR REPLACE PROCEDURE `clinvar_ingest.vcvs_by_consequence`(on_date DATE, consq_list STRING, significance STRING)
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
    SET sig_val =
      CASE
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
        COUNT(svrg.variation_id) as vcv_count,
        COUNTIF(svrg.rank IN (3,4)) as vcv_3_4_star_count,
        COUNTIF(svrg.rank = 2) as vcv_2_star_count,
        COUNTIF(svrg.rank = 1) as vcv_1_star_count,
        COUNTIF(svrg.rank = 0) as vcv_0_star_count,
        COUNTIF(svrg.rank < 0) as no_star_count,
        '%t' as release_date,
        FORMAT("At least 1 of: [ \'%%s\' ]", ARRAY_TO_STRING(@consequences,"\'; \'")) as consequences,
        @significance as significance
      FROM `clinvar_ingest.clinvar_sum_vsp_rank_group` svrg
      LEFT JOIN `%s.variation_hgvs` vh
      ON
        svrg.variation_id = vh.variation_id
        AND
        vh.mane_select
      LEFT JOIN `%s.single_gene_variation` sgv
      ON
        svrg.variation_id = sgv.variation_id
      LEFT JOIN `%s.gene` g
      ON
        g.id = sgv.gene_id
      WHERE
        svrg.gks_proposition_type = 'path'
        AND
        DATE'%t' BETWEEN svrg.start_release_date AND IFNULL(svrg.end_release_date, CURRENT_DATE())
        AND
        (
          -- if no filter values, include all
          ARRAY_LENGTH(@consequences) = 0
          OR
          -- otherwise, require that at least one of the @consequences
          -- appears as an item in the comma‑delimited vh.consq_label
          EXISTS (
            SELECT 1
            FROM UNNEST(@consequences) AS desired
            WHERE
              desired IN UNNEST( SPLIT(vh.consq_label, ',') )
          )
        )
        AND
        (
          CASE @significance
          WHEN 'significant' THEN (svrg.agg_sig_type >= 4)
          WHEN 'uncertain' THEN (svrg.agg_sig_type IN (2,3))
          WHEN 'not significant' THEN (svrg.agg_sig_type = 1)
          ELSE TRUE
          END
        )
      GROUP BY
        g.symbol,
        g.hgnc_id
      ORDER BY
        3 DESC, 4 DESC, 5 DESC, 6 DESC, 7 DESC, 8 DESC
    ''',
    rec.release_date,
    rec.schema_name,
    rec.schema_name,
    rec.schema_name,
    rec.release_date
  )
  USING
    consq_arr AS consequences,
    significance AS significance
  ;

END;
