
-- agg_sig_type sig|unc|nosig as 2|1|0 so
---  7 = 111  or yes to all 3. (sig conflict)
---  6 = 110  or yes to sig and unc only (sig conflict)
---  5 = 101  or yes to sig and nosig only (sig conflict)
---  4 = 100  or yes to sig only. (no conflict - sig)
---  3 = 011  or yes to unc and no sig (nosig conflict*)
---  2 = 010. or yes to unc only (no conflict - nosig)
---  1 = 001. or yes to nosig only (no conflict - nosig)




CREATE FUNCTION `clinvar_ingest.createSigType`(nosig_count INTEGER, unc_count INTEGER, sig_count INTEGER)
RETURNS ARRAY<STRUCT<count INTEGER, percent NUMERIC>>
AS (
  IF(
    (nosig_count + unc_count + sig_count ) = 0,
    ARRAY[STRUCT<count INTEGER, percent NUMERIC>(0,0),STRUCT<count INTEGER, percent NUMERIC>(0,0),STRUCT<count INTEGER, percent NUMERIC>(0,0)],
    -- order is significant, OFFSET 0=no-sig, 1=uncertain, 2=sig
    ARRAY[ 
      STRUCT<count INTEGER, percent NUMERIC>( nosig_count, CAST(ROUND(nosig_count/(sig_count + unc_count + nosig_count ),3) as NUMERIC)),
      STRUCT<count INTEGER, percent NUMERIC>( unc_count, CAST(ROUND(unc_count/(sig_count + unc_count + nosig_count ),3) as NUMERIC)),
      STRUCT<count INTEGER, percent NUMERIC>( sig_count, CAST(ROUND(sig_count/(sig_count + unc_count + nosig_count ),3) as NUMERIC))
      ]
  )
);