# SQL Scripts Overview

The `scripts/` directory contains the SQL stored procedures, functions, and setup scripts that power the ClinVar data processing pipeline in BigQuery. These scripts handle everything from raw data normalization through temporal tracking to final report generation.

## Organization

Scripts are organized into subdirectories by functional area. Each directory focuses on a distinct stage of the pipeline or a supporting concern.

| Directory | File Count | Purpose |
|-----------|-----------|---------|
| [`dataset-preparation/`](dataset-preparation.md) | 8 proc/setup files | Core normalization of each ClinVar release dataset |
| [`temporal-data-collection/`](temporal-data-collection.md) | 11 proc/setup files | Time-series extraction comparing releases over time |
| [`temporal-data-summation/`](temporal-data-summation.md) | 7 proc files | Aggregation and summarization of temporal data |
| [`tracker-report-update/`](tracker-report-update.md) | 5 proc/setup files | Variation tracker report generation |
| [`parsing-funcs/`](parsing-funcs.md) | 12 func files | SQL wrappers for TypeScript/JS parsing libraries |
| [`general/`](general.md) | 10 func/proc files | Shared utility functions and procedures |
| [`clinvar-curation/`](clinvar-curation.md) | 12+ files | ClinVar Variant Curation (CVC) workflow support |
| [`external-table-setup/`](external-table-setup.md) | 15+ def/script files | BigQuery external table definitions backed by Google Sheets |

## Naming Conventions

| Convention | Meaning | Example |
|-----------|---------|---------|
| Numeric prefix (`00-`, `01-`, ...) | Execution order within the directory | `01-normalize-dataset-proc.sql` |
| `-proc.sql` suffix | Stored procedure definition -- auto-deployed by CI/CD | `03-scv-summary-proc.sql` |
| `-func.sql` suffix | Function definition -- auto-deployed by CI/CD | `bq-createSigType-func.sql` |
| Plain `.sql` | One-off queries, setup scripts, or manual operations | `00-setup-translation-tables.sql` |
| `.def` | BigQuery external table definition file | `clinvar_releases_ext.def` |
| `.sh` | Shell scripts for deployment or setup | `setup-external-tables.sh` |

## CI/CD Auto-Deployment

Files ending in `-proc.sql` or `-func.sql` are automatically deployed to BigQuery when changes are merged to the `main` branch. This means:

- Procedure and function definitions are always kept in sync with the repository
- Renaming or removing a `-proc.sql` / `-func.sql` file requires manual cleanup of the old object in BigQuery
- Setup scripts (like `00-setup-translation-tables.sql`) and one-off queries must be run manually

!!! warning "Manual-only scripts"
    Files without the `-proc.sql` or `-func.sql` suffix are **not** auto-deployed. Table creation scripts (prefixed `00-`) and ad-hoc queries must be executed manually in the BigQuery console.

## Pipeline Flow

The scripts form a multi-stage pipeline. The most critical path through the system is:

```
dataset-preparation  -->  temporal-data-collection  -->  temporal-data-summation  -->  tracker-report-update
```

1. **Dataset Preparation** -- Normalizes a single ClinVar release dataset, validates it, and produces the `scv_summary` and `single_gene_variation` tables that downstream stages depend on.
2. **Temporal Data Collection** -- Compares the prepared dataset against previously processed releases to build temporal (start/end date range) records for genes, variations, submitters, VCVs, RCVs, and SCVs.
3. **Temporal Data Summation** -- Aggregates the temporal records into summary tables that track how SCV groupings, rank groups, and variation-level classifications change over time.
4. **Tracker Report Update** -- Generates the final variation tracker reports consumed by curation teams.

Supporting stages include:

- **Parsing Functions** -- Called by dataset-preparation procedures to extract structured data from raw ClinVar JSON/XML content fields.
- **General Utilities** -- Shared functions for date formatting, significance type creation, schema/release lookups, and validation helpers.
- **External Table Setup** -- Defines the Google Sheets-backed external tables that feed configuration and report definitions into the system.
- **ClinVar Curation** -- Supports the CVC (ClinVar Variant Curation) workflow with annotation tracking, impact analysis, and outlier detection.

## BigQuery Datasets

The scripts operate across three BigQuery datasets:

| Dataset | Purpose |
|---------|---------|
| `clinvar_ingest` | Core data processing -- normalized tables, temporal tables, parsing functions, and utility procedures |
| `variation_tracker` | Report configuration and output -- tracker reports, report definitions, and variation tracking |
| `clinvar_curator` | CVC curation workflow -- annotation views, impact analysis, and outlier tracking |
