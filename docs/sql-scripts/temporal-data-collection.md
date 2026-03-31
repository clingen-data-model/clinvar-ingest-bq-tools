# Temporal Data Collection

The temporal data collection scripts compare successive ClinVar release datasets to build time-series records that track how entities (genes, variations, submitters, VCVs, RCVs, SCVs) change across releases. Each entity record carries `start_release_date` and `end_release_date` fields representing the range of releases during which a particular state was observed, along with a `deleted_release_date` for entities that disappear from ClinVar.

## Orchestrator

**`temporal-data-collection-proc.sql`** defines `clinvar_ingest.temporal_data_collection(on_date)`, which:

1. Resolves the release schema for the given date using `clinvar_ingest.schema_on()`
2. Validates that the previous release was fully processed by checking `clinvar_scvs` (the last table in the chain)
3. Calls each sub-procedure in order, collecting result messages

## Scripts

| # | File | Procedure/Object Created | Description |
|---|------|--------------------------|-------------|
| 00 | `00-setup-temporal-tables.sql` | Multiple tables | Creates the temporal tracking tables: `clinvar_genes`, `clinvar_single_gene_variations`, `clinvar_submitters`, `clinvar_variations`, `clinvar_vcvs`, `clinvar_vcv_classifications`, `clinvar_rcvs`, `clinvar_rcv_classifications`, `clinvar_scvs` |
| 01 | `01-clinvar-genes-proc.sql` | `clinvar_ingest.clinvar_genes()` | Tracks gene records across releases -- detects deleted, updated, and new genes |
| 02 | `02-clinvar-single-gene-variations-proc.sql` | `clinvar_ingest.clinvar_single_gene_variations()` | Tracks variation-to-gene mappings across releases |
| 03 | `03-clinvar-submitters-proc.sql` | `clinvar_ingest.clinvar_submitters()` | Tracks submitter records, including name/abbreviation changes and accumulating `all_names`/`all_abbrevs` arrays |
| 04 | `04-clinvar-variations-proc.sql` | `clinvar_ingest.clinvar_variations()` | Tracks variation records with latest gene assignment and MANE Select status |
| 05 | `05-clinvar-vcvs-proc.sql` | `clinvar_ingest.clinvar_vcvs()` | Tracks VCV (Variant-Condition-Variation) accession records across releases |
| 06 | `06-clinvar-vcv-classifications-proc.sql` | `clinvar_ingest.clinvar_vcv_classifications()` | Tracks VCV-level aggregate classifications, including review status and rank |
| 07 | `07-clinvar-rcvs-proc.sql` | `clinvar_ingest.clinvar_rcvs()` | Tracks RCV (Reference ClinVar) accession records across releases |
| 08 | `08-clinvar-rcv-classifications-proc.sql` | `clinvar_ingest.clinvar_rcv_classifications()` | Tracks RCV-level classifications with statement type and significance data |
| 09 | `09-clinvar-scvs-proc.sql` | `clinvar_ingest.clinvar_scvs()` | Tracks individual SCV (Submitted Clinical Variant) records -- the most detailed temporal table |
| A | `A-roll-back-proc.sql` | `clinvar_ingest.rollback_temporal_release()` | Utility to roll back a temporal release from all tables, with dry-run support and logging to `rollback_log` |
| -- | `temporal-data-collection-proc.sql` | `clinvar_ingest.temporal_data_collection()` | Orchestrator procedure that calls 01 through 09 in sequence |

## Execution Order

```
00-setup-temporal-tables (manual, run once to create tables)
    |
01-clinvar-genes
    |
02-clinvar-single-gene-variations
    |
03-clinvar-submitters
    |
04-clinvar-variations
    |
05-clinvar-vcvs
    |
06-clinvar-vcv-classifications
    |
07-clinvar-rcvs
    |
08-clinvar-rcv-classifications
    |
09-clinvar-scvs (must be last -- used as completion marker)
```

## Common Pattern

All nine temporal procedures (01-09) follow the same structural pattern:

1. **Validate** -- Call `clinvar_ingest.validate_last_release()` to confirm the previous release was processed
2. **Delete** -- Mark entities as deleted (`SET deleted_release_date`) if they no longer exist in the current release
3. **Update** -- Extend `end_release_date` for entities that still exist unchanged, or close the old range and insert a new record when values change
4. **Insert** -- Add new entity records with `start_release_date = release_date`

Each procedure accepts `schema_name`, `release_date`, `previous_release_date`, and an `OUT result_message` parameter.

!!! note "The `clinvar_scvs` table as completion marker"
    The `clinvar_scvs` temporal table is processed last (step 09). The orchestrator uses `max(end_release_date)` from this table to determine whether a release has been fully processed. This is also used by the `all_releases()` table function to gate which releases are available downstream.

## Key Dependencies

**Reads from (per-release schema):**

- `{schema}.gene`, `{schema}.single_gene_variation`
- `{schema}.submitter`
- `{schema}.variation`
- `{schema}.variation_archive`, `{schema}.variation_archive_classification`
- `{schema}.rcv_accession`, `{schema}.rcv_accession_classification`
- `{schema}.scv_summary`

**Reads from (shared tables):**

- `clinvar_ingest.clinvar_submitter_abbrevs` -- Submitter abbreviation mappings
- `clinvar_ingest.status_rules`, `clinvar_ingest.status_definitions` -- Review status mappings
- `clinvar_ingest.clinvar_clinsig_types` -- Classification type metadata

**Writes to:**

- `clinvar_ingest.clinvar_genes`
- `clinvar_ingest.clinvar_single_gene_variations`
- `clinvar_ingest.clinvar_submitters`
- `clinvar_ingest.clinvar_variations`
- `clinvar_ingest.clinvar_vcvs`
- `clinvar_ingest.clinvar_vcv_classifications`
- `clinvar_ingest.clinvar_rcvs`
- `clinvar_ingest.clinvar_rcv_classifications`
- `clinvar_ingest.clinvar_scvs`

## Rollback Support

The `A-roll-back-proc.sql` script provides `clinvar_ingest.rollback_temporal_release(last_release_date, prev_release_date, dry_run)` which:

- Creates backup tables before modifying data
- Restores records that were marked as deleted during the target release
- Restores records whose `end_release_date` was extended
- Removes records that were inserted during the target release
- Logs all actions to the `clinvar_ingest.rollback_log` table
- Supports `dry_run` mode for previewing changes without applying them
