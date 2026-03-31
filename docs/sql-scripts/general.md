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

## Key Dependencies

The schema/release table functions are foundational -- they are used by:

- `temporal-data-collection-proc.sql` to resolve which schema to process
- `temporal-data-summation` procedures to look up adjacent releases
- `tracker-report-update` procedures to find the current release
- `clinvar-curation` functions to determine release context
