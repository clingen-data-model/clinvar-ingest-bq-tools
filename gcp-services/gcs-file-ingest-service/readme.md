# GCS File Ingest Service

This Cloud Function ingests reference data files from a GCS bucket and loads them into BigQuery tables.

## Deployment

### Deploy the Cloud Function

```bash
./scripts/deploy.sh
```

Wait for the build to complete (may take a few minutes).

### Set up GCS triggers

```bash
./scripts/trigger.sh
```

This will delete and recreate the necessary triggers that watch the GCS bucket for file updates.

## Configuration

Based on `deploy.sh` settings:

| Setting    | Value                     |
| ---------- | ------------------------- |
| GCS Bucket | `external-dataset-ingest` |
| BQ Project | `clingen-dev`             |
| BQ Dataset | `clinvar_ingest`          |

## Reference Data Files

Upload files to the GCS bucket to trigger automatic ingestion into BigQuery.

### 1. organization_summary.txt

**Source:** ClinVar FTP
**BigQuery Table:** `clinvar_ingest.submitter_organization`

#### Option A: Use the script (recommended)

```bash
cd scripts
./get-organization-summary.sh
```

This downloads the file and uploads it to GCS automatically.

#### Option B: Manual download

Download from: <https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/organization_summary.txt>

Then upload to GCS:

```bash
gsutil cp organization_summary.txt gs://external-dataset-ingest/
```

---

### 2. ncbi_gene.txt

**Source:** NCBI Gene FTP (filtered to human genes)
**BigQuery Table:** `clinvar_ingest.ncbi_gene`

```bash
cd scripts
./get-ncbi-gene-txt.sh
```

This script:

1. Downloads the full `gene_info.gz` from NCBI (~1.5GB compressed)
2. Extracts only human genes (taxonomy ID 9606)
3. Excludes genes of type 'biological-region'
4. Uploads the filtered result to GCS

Use `--force` to re-download even if the file exists locally.

---

### 3. hgnc_gene.json

**Source:** HGNC (Human Gene Nomenclature Committee)
**BigQuery Table:** `clinvar_ingest.hgnc_gene`

```bash
cd scripts
./get-hgnc-gene.sh
```

This script:

1. Downloads multiple HGNC JSON files (protein-coding genes, non-coding RNA)
2. Merges them into a single `hgnc_gene.json`
3. Uploads to GCS

Use `--force` to re-download even if the file exists locally.

---

### 4. hp.json

**Source:** Human Phenotype Ontology (HPO)
**BigQuery Table:** `clinvar_ingest.hpo_terms`

#### Download hp.json

1. Go to: <https://hpo.jax.org/data/ontology>
2. Click "DOWNLOAD" under "LATEST HP.JSON"
3. Save as `hp.json`

#### Upload hp.json to GCS

```bash
gsutil cp hp.json gs://external-dataset-ingest/
```

---

### 5. mondo.json

**Source:** MONDO Disease Ontology
**BigQuery Table:** `clinvar_ingest.mondo_terms`

#### Download mondo.json

1. Go to: <https://mondo.monarchinitiative.org/pages/download/>
2. Download `mondo.json` from the JSON edition section
3. Save as `mondo.json`

#### Upload mondo.json to GCS

```bash
gsutil cp mondo.json gs://external-dataset-ingest/
```

---

## Verifying Updates

After uploading a file to GCS, the Cloud Function is triggered automatically. To verify the update:

1. Open BigQuery in the GCP Console
2. Navigate to `clingen-dev.clinvar_ingest`
3. Check the table's "Last modified" timestamp in the Details tab

| File                       | BigQuery Table                          |
| -------------------------- | --------------------------------------- |
| `organization_summary.txt` | `clinvar_ingest.submitter_organization` |
| `ncbi_gene.txt`            | `clinvar_ingest.ncbi_gene`              |
| `hgnc_gene.json`           | `clinvar_ingest.hgnc_gene`              |
| `hp.json`                  | `clinvar_ingest.hpo_terms`              |
| `mondo.json`               | `clinvar_ingest.mondo_terms`            |
