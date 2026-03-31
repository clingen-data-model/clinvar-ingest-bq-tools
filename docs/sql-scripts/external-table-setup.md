# External Table Setup

The `scripts/external-table-setup/` directory contains BigQuery external table definition files and scripts that connect Google Sheets to BigQuery tables. These external tables serve as the configuration layer for the pipeline, providing report definitions, submitter abbreviations, release metadata, and curation workflow data.

## Setup Script

**`setup-external-tables.sh`** is the main deployment script. It:

1. Authenticates with Google Cloud (including Google Drive access for Sheets)
2. Iterates over a list of table/dataset pairs
3. Creates or updates each external table using its corresponding `.def` file
4. Uses `bq mk --external_table_definition` for new tables and `bq update` for existing ones

## External Table Definitions

Each `.def` file defines a BigQuery external table backed by a Google Sheet. The tables span three datasets:

### `clinvar_curator` Dataset

| Definition File | External Table | Description |
|----------------|----------------|-------------|
| `clinvar_annotations.def` | `clinvar_curator.clinvar_annotations` | ClinVar curation annotation records from the curation Google Sheet |
| `cvc_clinvar_outlier_tracking.def` | `clinvar_curator.cvc_clinvar_outlier_tracking` | Outlier tracking data for CVC workflow |
| `cvc_clinvar_reviews_sheet.def` | `clinvar_curator.cvc_clinvar_reviews_sheet` | Review records from the curation sheet |
| `cvc_clinvar_submissions_sheet.def` | `clinvar_curator.cvc_clinvar_submissions_sheet` | Submission records from the curation sheet |
| `cvc_clinvar_batches_sheet.def` | `clinvar_curator.cvc_clinvar_batches_sheet` | Batch records from the curation sheet |
| `cvc_clinvar_clinsig_outlier_tracker.def` | `clinvar_curator.cvc_clinvar_clinsig_outlier_tracker` | Clinical significance outlier tracker |

### `clinvar_ingest` Dataset

| Definition File | External Table | Description |
|----------------|----------------|-------------|
| `clinvar_releases_ext.def` | `clinvar_ingest.clinvar_releases_ext` | ClinVar release metadata managed in Google Sheets |
| `clinvar_submitter_abbrevs_ext.def` | `clinvar_ingest.clinvar_submitter_abbrevs_ext` | Submitter abbreviation mappings managed in Google Sheets |

### `variation_tracker` Dataset

| Definition File | External Table | Description |
|----------------|----------------|-------------|
| `report_ext.def` | `variation_tracker.report_ext` | Report definitions (ID, name, active status) |
| `report_gene_ext.def` | `variation_tracker.report_gene_ext` | Gene associations per report |
| `report_option_ext.def` | `variation_tracker.report_option_ext` | Report configuration options |
| `report_submitter_ext.def` | `variation_tracker.report_submitter_ext` | Submitter associations per report (VCEP, GC, etc.) |
| `report_variant_list_ext.def` | `variation_tracker.report_variant_list_ext` | Explicit variant lists per report |

## Refresh Procedure

**`refresh-external-table-copies-proc`** (a `-proc.sql` file without a directory prefix) defines `clinvar_ingest.refresh_external_table_copies()`, which copies data from all external tables into native BigQuery tables. This materialization step is necessary because:

- External Google Sheets tables have query performance limitations
- Native table copies allow the pipeline to run without requiring Google Drive access at query time
- Scheduled refresh keeps the copies current

The procedure creates or replaces native tables including:

- `clinvar_ingest.clinvar_submitter_abbrevs`
- `clinvar_ingest.clinvar_releases`
- `variation_tracker.report`
- `variation_tracker.report_gene`
- `variation_tracker.report_option`
- `variation_tracker.report_submitter`
- `variation_tracker.report_variant_list`

!!! warning "Refresh before report generation"
    After modifying report configuration in Google Sheets, you must run `refresh_external_table_copies()` before running `tracker_report_update()` to ensure the pipeline picks up the latest configuration.

## Other Files

| File | Description |
|------|-------------|
| `BQ external table update script.md` | Documentation on updating external table definitions |
| `readme.md` | Directory-level documentation |
