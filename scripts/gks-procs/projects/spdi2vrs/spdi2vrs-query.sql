SELECT
  `in`.variation_id,
  `in`.name,
  `in`.vrs_class,
  `in`.fmt,
  `in`.source,
  `in`.variation_type,
  `out`.state.type as vrs_state_type,
  `out`.state.sequence as vrs_state_sequence,
  `out`.state.length as vrs_state_length,
  `out`.state.repeatSubunitLength as vrs_state_repeatSubunitLength,
  `out`.location.id as vrs_location_id,
  `out`.location.type as vrs_location_type,
  `out`.location.start as vrs_location_start,
  `out`.location.end as vrs_location_end,
  `out`.type as vrs_type,
  `out`.id as vrs_id
FROM `clingen-dev.clinvar_2026_05_10_v2_5_0.gks_vrs`
WHERE `in`.fmt = 'spdi'
AND `in`.source IS NOT NULL
