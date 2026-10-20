# General Utility Scripts

The `scripts/general/` directory contains shared utility functions and procedures used across the pipeline. These include BigQuery JavaScript UDFs backed by `bq-utils.js`, schema/release lookup table functions, and validation helper procedures.

## Functions (auto-deployed)

| File | Function Created | Description |
|------|------------------|-------------|
| `bq-createSigType-func.sql` | `clinvar_ingest.createSigType()` | Creates an array of three significance type structs (non-significant, uncertain, significant) with counts and percentages from input counts. Backed by `bq-utils.js`. |
| `bq-deriveHGVS-func.sql` | `clinvar_ingest.deriveHGVS()` | Derives an HGVS expression string from a variation type and sequence location struct when no HGVS expression is directly available. Backed by `bq-utils.js`. |
| `bq-determineMonthBasedOnRange-func.sql` | `clinvar_ingest.determineMonthBasedOnRange()` | Calculates the dominant month for a date range, returning both `yymm` and `monyy` formatted strings. Backed by `bq-utils.js`. |
| `bq-formatNearestMonth-func.sql` | `clinvar_ingest.formatNearestMonth()` | Rounds a date to the nearest month boundary and returns a formatted string. Backed by `bq-utils.js`. |
| `bq-normalizeAndKeyById-func.sql` | `clinvar_ingest.normalizeAndKeyById()` | Normalizes a JSON object by converting string-encoded arrays/nulls to native types and optionally keys nested arrays by their `id` field. Backed by `bq-utils.js`. |
| `bq-normalizeHpId-func.sql` | `clinvar_ingest.normalizeHpId()` | Normalizes HP (Human Phenotype Ontology) identifiers to the standard `HP:0000000` format, handling various input formats. Backed by `bq-utils.js`. |
| `cvc-project-start-date-func.sql` | `clinvar_ingest.cvc_project_start_date()` | Returns the CVC project start date (`2023-01-07`) as a constant. Pure SQL function. |

## Procedures (auto-deployed)

| File | Procedure Created | Description |
|------|-------------------|-------------|
| `check-release-dates-proc.sql` | `clinvar_ingest.check_release_dates()` | Validates that release dates in specified tables match the date encoded in the schema name. Returns an array of validation error messages. |
| `check-required-fields-proc.sql` | `clinvar_ingest.check_required_fields()` | Checks that specified required fields are not null across given tables. Returns an array of validation error messages. |
| `tables-columns-exists-proc.sql` | `clinvar_ingest.check_table_exists()`, `clinvar_ingest.check_column_exists()` | Helper procedures that check whether a table or column exists in a given schema using `INFORMATION_SCHEMA`. |
| `schema-table-functions-proc.sql` | Multiple table functions | Defines the core schema and release lookup functions (see below). |

## Schema and Release Table Functions

The `schema-table-functions-proc.sql` file defines the foundational table functions used throughout the pipeline to discover and navigate ClinVar release schemas:

| Function | Description |
|----------|-------------|
| `clinvar_ingest.all_releases()` | Returns all known release dates (from both active schemas and historic records) with `prev_release_date` and `next_release_date` window columns |
| `clinvar_ingest.release_on(on_date)` | Returns the single release that was current on a given date |
| `clinvar_ingest.all_schemas()` | Returns all active release schemas with their release dates and adjacent release dates |
| `clinvar_ingest.schema_on(on_date)` | Returns the single schema that was current on a given date |
| `clinvar_ingest.schemas_on_or_after(on_or_after_date)` | Returns all schemas from the given date forward |

!!! note "Historic release dates"
    The `all_releases()` function combines schema-derived release dates (from `INFORMATION_SCHEMA`) with a `historic_release_dates` table that covers releases prior to 2023-01-07. This is necessary because only releases from that date forward have standing schemas in BigQuery.

!!! info "Completion gating"
    The `all_releases()` and `all_schemas()` functions check for the existence of the `scv_summary` table in each schema. A release is only considered fully processed (and therefore available to downstream stages) if its dataset-preparation step has completed and produced `scv_summary`.

## Shell Scripts (not auto-deployed)

| File | Description |
|------|-------------|
| `copy-datasets-to-dev.sh` | Copies datasets between BigQuery projects |
| `service-account-permission-setup.sh` | Sets up service account permissions for BigQuery and GCS access |
| `transfer-table.sh` | Transfers individual tables between BigQuery projects |
| `fetch_gene_pubmed.sh` | Fetches PubMed article counts for a list of gene symbols |
| `mat-view-health.sh` + `mat-view-health-report.sql` | Read-only health report for materialized views and derived tables (see [below](#materialized-view-health-report)) |

## Materialized View Health Report

`mat-view-health.sh` (a wrapper around `mat-view-health-report.sql`) tells you which materialized views, and which "materialized" tables rebuilt by procedures, are behind the tables they are built from. It only reads `INFORMATION_SCHEMA` metadata. Nothing is refreshed unless you pass `--refresh`.

One report covers every dataset in scope. By default that is `clinvar_ingest`, `variation_tracker` and every dataset whose name starts with `clinvar_curator` (today `clinvar_curator`, `clinvar_curator_v4` and `clinvar_curator_v4_dev`). A new `clinvar_curator*` dataset is picked up automatically. The tables these views and snapshots are built from are checked wherever they live, including release datasets. `--datasets` changes the scope for the whole report.

```bash
# Readable report (default project clingen-dev, region us)
scripts/general/mat-view-health.sh

# Only the real BigQuery materialized views
scripts/general/mat-view-health.sh --mv-only

# Cover a different set of datasets (* matches any characters; quote it so the shell
# leaves it alone), with a shorter JOBS lookback
scripts/general/mat-view-health.sh --datasets 'clinvar_ingest,clinvar_curator*,clinvar_2026_10_11_v2_6_0' --lookback 60

# Raw result sets as JSON
scripts/general/mat-view-health.sh --format json

# Report, then refresh every MV that needs it (asks for confirmation first)
scripts/general/mat-view-health.sh --refresh
```

The SQL file also runs on its own, with no wrapper: `bq query --nouse_legacy_sql --project_id=clingen-dev < scripts/general/mat-view-health-report.sql`. Its settings are the `DECLARE` defaults at the top of the file. The file name does not end in `-proc.sql`/`-func.sql`, so CI does not deploy it.

You need `bigquery.jobs.listAll` on the project, because the report reads `INFORMATION_SCHEMA.JOBS_BY_PROJECT`. A full run takes about 40 seconds and scans up to about 13 GB of job metadata. `--mv-only` or a smaller `--lookback` reduces both.

!!! info "Why `__TABLES__` and not `TABLE_STORAGE`"
    `INFORMATION_SCHEMA.TABLE_STORAGE.storage_last_modified_time` is updated asynchronously. It was seen lagging an hourly `WRITE_TRUNCATE` load by about an hour, long enough to hide staleness. So the script reads `__TABLES__.last_modified_time` from each dataset involved. BigQuery rate-limits concurrent `__TABLES__` reads, so the script reads only the datasets it needs, a few at a time. The only things it writes are script-scoped temp tables, which BigQuery drops when the run ends. Note that `__TABLES__.last_modified_time` also changes on metadata-only edits, such as a new description.

### Section 1: Materialized views

The report finds every BigQuery materialized view in the covered datasets automatically. Today that is just `clinvar_curator.cvc_annotations_base_mv`. For each view it shows the following.

| Field | Meaning |
|-------|---------|
| `last refresh` / `watermark` | When BigQuery last refreshed the MV, and the base-table point in time the MV reflects |
| `base tables` | Each base table and when it last changed (`__TABLES__.last_modified_time`). `*` = changed after the watermark, `!` = table no longer exists. This list comes from the most recent successful refresh job's `referenced_tables`. If no refresh job is in the window, it comes from a parse of the MV's DDL. |
| `auto-refresh` | `enable_refresh` and `refresh_interval_minutes` (plus `max_staleness` if set) |
| `refresh jobs` | Refresh jobs in the last 30 days, and how many failed. "Materialized view is already being refreshed" collisions are harmless and not counted. |
| `fix` | A ready-to-run `CALL BQ.REFRESH_MATERIALIZED_VIEW('project.dataset.view');` |

Status values:

| Status | Meaning | Action |
|--------|---------|--------|
| `OK` | No base table changed after the refresh watermark | None |
| `STALE` | A base table changed after the watermark, and the next auto-refresh is still within `refresh_interval_minutes` + grace (default 30 min) | Usually none; BigQuery will refresh it. Queries still return current results, but read the base tables to do it. |
| `STALE_OVERDUE` | Stale for longer than the refresh interval + grace | Run the `fix` statement and find out why auto-refresh is not keeping up |
| `STALE_MANUAL` | Stale, and auto-refresh is disabled | Run the `fix` statement |
| `STALE_UPSTREAM` | The MV is current, but an MV it is built on needs a refresh | Refresh after the upstream MV |
| `REFRESH_FAILED` | `last_refresh_status` or the latest refresh job reports an error | Read `refresh error`, fix the cause, then refresh |
| `BROKEN` | A base table is missing | Re-create the MV from its source script |

The **MV REFRESH PLAN** lists the refresh statements in dependency order: an MV built on another MV comes after it. `--refresh` runs exactly these statements, in that order, after a confirmation prompt (`--yes` skips the prompt).

!!! note "Why `cvc_annotations_base_mv` is often briefly STALE"
    Scheduled queries rewrite two of its base tables every hour with `WRITE_TRUNCATE`: `clinvar_curator.clinvar_annotations_native` (from the curation Google Sheet) and `clinvar_ingest.all_releases_materialized` (from `all_releases()`). Each rewrite leaves the MV stale until the next 30-minute auto-refresh, which does a full recompute. A short `STALE` window is normal. Only `STALE_OVERDUE` or `REFRESH_FAILED` needs attention.

### Section 2: Stale derived tables

Many tables in the covered datasets are snapshots built with `CREATE OR REPLACE TABLE ... AS SELECT` by procedures such as `clinvar_curator.refresh_cvc_impact_analysis()`, `clinvar_ingest.refresh_mechanism_threshold()`, the tracker report rebuilds and the release pipeline. They work like materialized views, but BigQuery does not track them. For every table in the covered datasets written within `--lookback` days, the report:

1. Finds the most recent successful job that wrote the table, plus any other writes to it from the same script run.
2. Takes that job's `referenced_tables` as the table's sources. `INFORMATION_SCHEMA` and temp tables are ignored.
3. Marks the table `DERIVED_STALE` if any source has changed since the table was last written.

For each stale table the report shows the sources that changed, and `last built by`: the procedure `CALL` or script that built it last, or "scheduled query". The **DERIVED REBUILD PLAN** groups the stale tables by that builder. Run builders with a lower `order` first: order 1 means one of the table's changed sources is itself a stale derived table.

!!! warning "Heuristic"
    Section 2 relies on job history, so:

    - Tables last written more than `--lookback` days ago (180 max, the JOBS retention) do not appear.
    - Sources with no storage, such as external Google Sheet tables and logical views, cannot be checked.
    - "Stale" means *a source changed after the build*. It does not mean the table is wrong. A snapshot that should stay frozen will still show as stale.

## Key Dependencies

The schema/release table functions are foundational -- they are used by:

- `temporal-data-collection-proc.sql` to resolve which schema to process
- `temporal-data-summation` procedures to look up adjacent releases
- `tracker-report-update` procedures to find the current release
- `clinvar-curation` functions to determine release context
