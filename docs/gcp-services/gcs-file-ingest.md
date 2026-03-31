# GCS File Ingest Service

A Python-based Cloud Run service that ingests reference data files from a Google Cloud Storage (GCS) bucket and loads them into BigQuery tables. The service is triggered automatically by Eventarc when files are uploaded to the monitored bucket.

## Purpose

The ClinVar analysis pipeline depends on several external reference datasets that must be periodically refreshed. This service automates the ingestion of those files: when a recognized file lands in the GCS bucket, the service reads it, transforms it as needed, and overwrites the corresponding BigQuery table.

## Configuration

| Setting    | Value                     |
|------------|---------------------------|
| GCS Bucket | `external-dataset-ingest` |
| BQ Project | `clingen-dev`             |
| BQ Dataset | `clinvar_ingest`          |
| Region     | `us-east1`                |
| Memory     | 2 GiB                     |

## Reference Files

The following files are recognized by the service. Uploading any of these to the GCS bucket triggers automatic ingestion.

| File | BigQuery Table | Source |
|------|---------------|--------|
| `organization_summary.txt` | `clinvar_ingest.submitter_organization` | ClinVar FTP |
| `ncbi_gene.txt` | `clinvar_ingest.ncbi_gene` | NCBI Gene FTP (human only) |
| `hgnc_gene.json` | `clinvar_ingest.hgnc_gene` | HGNC |
| `hp.json` | `clinvar_ingest.hpo_terms` | Human Phenotype Ontology |
| `mondo.json` | `clinvar_ingest.mondo_terms` | MONDO Disease Ontology |

!!! note "Organization summary special behavior"
    When `organization_summary.txt` is uploaded, the service ignores the uploaded file content and instead fetches the latest version directly from the ClinVar FTP. The upload merely serves as a trigger signal.

### Downloading Reference Files

Helper scripts in `gcp-services/gcs-file-ingest-service/scripts/` automate downloading and uploading each file.

#### organization_summary.txt

```bash
cd gcp-services/gcs-file-ingest-service/scripts
./get-organization-summary.sh
```

Downloads from the ClinVar FTP and uploads to GCS automatically.

#### ncbi_gene.txt

```bash
cd gcp-services/gcs-file-ingest-service/scripts
./get-ncbi-gene-txt.sh
```

This script:

1. Downloads the full `gene_info.gz` from NCBI (~1.5 GB compressed)
2. Extracts only human genes (taxonomy ID 9606)
3. Excludes genes of type `biological-region`
4. Uploads the filtered result to GCS

Use `--force` to re-download even if the file exists locally.

#### hgnc_gene.json

```bash
cd gcp-services/gcs-file-ingest-service/scripts
./get-hgnc-gene.sh
```

This script:

1. Downloads multiple HGNC JSON files (protein-coding genes, non-coding RNA)
2. Merges them into a single `hgnc_gene.json`
3. Uploads to GCS

Use `--force` to re-download even if the file exists locally.

#### hp.json

Manual download required:

1. Go to [HPO Downloads](https://hpo.jax.org/data/ontology)
2. Download the latest `hp.json`
3. Upload to GCS:
```bash
gsutil cp hp.json gs://external-dataset-ingest/
```

#### mondo.json

Manual download required:

1. Go to [MONDO Downloads](https://mondo.monarchinitiative.org/pages/download/)
2. Download `mondo.json` from the JSON edition section
3. Upload to GCS:
```bash
gsutil cp mondo.json gs://external-dataset-ingest/
```

## Code Structure

The service source lives in `gcp-services/gcs-file-ingest-service/`.

```
gcs-file-ingest-service/
├── src/
│   ├── main.py           # Flask app, entry points, BQ schemas
│   └── utils.py          # TSV processing, column normalization
├── scripts/
│   ├── deploy.sh         # Cloud Run deployment
│   ├── trigger.sh        # Eventarc trigger setup
│   ├── get-organization-summary.sh
│   ├── get-ncbi-gene-txt.sh
│   └── get-hgnc-gene.sh
├── tests/
│   └── test_utils.py     # Unit tests for utils
├── data/                 # Local data cache (gitignored)
└── readme.md
```

### main.py

The Flask application that handles incoming Eventarc HTTP events. Key components:

- **`handle_gcs_event()`** -- POST endpoint that dispatches to the appropriate processor based on the uploaded file name
- **`process_json_from_gcs()`** -- Extracts nodes from `hp.json` and `mondo.json` ontology files
- **`extract_hgnc_genes()`** -- Parses HGNC gene records from JSON
- **`process_tsv_from_gcs()`** -- Loads TSV files (NCBI genes) using configurable table schemas
- **`process_organization_summary_from_ftp()`** -- Fetches organization data directly from ClinVar FTP
- **`load_to_bigquery()`** -- Writes a DataFrame to BigQuery with `WRITE_TRUNCATE` disposition

Each table has a defined BigQuery schema in `main.py` that controls column names, types, and repeated fields.

### utils.py

Helper functions for TSV processing:

- **`to_snake_case()`** -- Converts column headers to snake_case
- **`convert_to_bigquery_date()`** -- Normalizes date strings to `YYYY-MM-DD` format
- **`process_tsv_data()`** -- Reads TSV data, renames columns, and applies type conversions based on the table schema configuration (handles REPEATED fields, DATE parsing, INTEGER coercion)

## Deployment

### Deploy the Cloud Run Service

```bash
cd gcp-services/gcs-file-ingest-service/scripts
./deploy.sh
```

This runs `gcloud run deploy` with the following settings:

- Source: `../src`
- Region: `us-east1`
- Platform: managed (Cloud Run)
- Access: unauthenticated
- Memory: 2 GiB
- Environment variables: `GCS_BUCKET`, `BQ_PROJECT`, `BQ_DATASET`

Wait for the build to complete (may take a few minutes).

### Set Up GCS Event Triggers

```bash
cd gcp-services/gcs-file-ingest-service/scripts
./trigger.sh
```

This script:

1. Deletes any existing `gcs-ingest-trigger` Eventarc trigger
2. Creates a new trigger that watches for `google.cloud.storage.object.v1.finalized` events on the `external-dataset-ingest` bucket
3. Routes events to the Cloud Run service using the `eventarc-invoker` service account

!!! warning "Prerequisites"
    The `trigger.sh` script includes commented-out commands for initial IAM setup. On first deployment, you may need to create the `eventarc-invoker` service account and grant the required roles (`eventarc.eventReceiver`, `run.invoker`, `pubsub.publisher`).

## Verifying Updates

After uploading a file to GCS, the Cloud Function triggers automatically. To verify:

1. Open BigQuery in the GCP Console
2. Navigate to `clingen-dev.clinvar_ingest`
3. Check the target table's **Last modified** timestamp in the Details tab
