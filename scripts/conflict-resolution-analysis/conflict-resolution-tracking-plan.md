/*
 start tracking curation impact on resolving clinsig conflicts
 */
 select
  cs.variation_id,
  count(cs.id) as scv_count


 from `clingen-dev.clinvar_ingest.clinvar_scvs` cs

 where
  cs.deleted_release_date is null
 group by
  cs.variation_id
 order by 2 desc


how many unique variants (denominator) - to provide a percentage
the number of clinsig conflicts for each month (based on exposed at the vcv level of 1 vs 0 stars)
  Q: do we care about the number of clinsig resolves happen - what if conflicts resolve due to submitters and not because of flagging?
the number we have clinsig resolved (so even if it is still nonclinsig conflict)

how to deal with things changing (formerly resolved )
  - we curated and now its conflicting again (repeat resolve)
  - vs new resolves

new vs re-conflicts


we want to track the clinsig resolutions occurred.

-- only clinsig conflicts
New conflict
Conflict still int unresoved state ()
VCEP resolved (is this just vcep things that cover medsig conflicts)
Lab resolved
Unresolved or no change conflict
cvc msr
cvc fully resolved


-- a separate vcep report to deal with finer look into vcep reports.
(new conflicts on vcep vars.)
-- prep an SC report for quarterly updates (see Danielle)
