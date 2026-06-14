-- =============================================================
-- Migration: Rename proposition columns in clinvar_ingest.clinvar_scvs
--
-- 1. Rename original_proposition_type → proposition_type
--    (the proc now writes to this column)
-- 2. Rename gks_proposition_type → _bak_gks_proposition_type
--    (preserves historical data; prefixed with _bak_ so any
--    downstream query still referencing it will break loudly
--    rather than silently returning stale data)
--
-- The proc (09-clinvar-scvs-proc.sql) now writes only to
-- proposition_type. _bak_gks_proposition_type can be dropped
-- once all downstream consumers are verified.
-- =============================================================

ALTER TABLE `clinvar_ingest.clinvar_scvs`
  RENAME COLUMN original_proposition_type TO proposition_type;

ALTER TABLE `clinvar_ingest.clinvar_scvs`
  RENAME COLUMN gks_proposition_type TO _bak_gks_proposition_type;
