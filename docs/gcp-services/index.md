# GCP Services

This project includes two GCP-hosted services that support the ClinVar data pipeline. These services handle reference data ingestion and analytics automation.

## Services

| Service | Type | Status | Description |
|---------|------|--------|-------------|
| [GCS File Ingest Service](gcs-file-ingest.md) | Cloud Run | Active | Ingests reference data files from GCS into BigQuery |
| [Conflict Analytics Trigger](https://github.com/clingen-data-model/clinvar-ingest-bq-tools/tree/main/gcp-services/conflict-analytics-trigger) | Cloud Function + Apps Script | Active | Triggers the conflict resolution analytics pipeline from Google Sheets |

## GCS File Ingest Service

A Python-based Cloud Run service that watches a GCS bucket for reference data file uploads and automatically loads them into BigQuery tables. Handles organization summaries, NCBI genes, HGNC genes, HPO terms, and MONDO terms.

See the [full documentation](gcs-file-ingest.md) for deployment instructions, file formats, and helper scripts.

## Conflict Analytics Trigger

A Cloud Function paired with a Google Apps Script integration that enables running the ClinVar Conflict Resolution Analytics pipeline directly from Google Sheets. It supports:

- Refreshing BigQuery views from a Sheets menu
- Running the full multi-step analytics pipeline
- Scheduling automatic monthly updates via Apps Script triggers
- Monitoring pipeline status

SQL scripts are stored in GCS (`gs://clinvar-ingest/conflict-analytics-sql/`) and loaded at runtime, allowing SQL logic updates without redeployment. The Apps Script component adds a **ClinVar Analytics** menu to the connected Google Sheet.

For setup and usage details, see the [conflict-analytics-trigger README](https://github.com/clingen-data-model/clinvar-ingest-bq-tools/tree/main/gcp-services/conflict-analytics-trigger/README.md).

## Shared Infrastructure

Both services operate within the `clingen-dev` GCP project and interact with the `clinvar_ingest` BigQuery dataset. Authentication and IAM are managed through GCP service accounts.
