# Dataset Preparation

The dataset preparation scripts form the first stage of the ClinVar processing pipeline. They take a raw ingested ClinVar release dataset (residing in a schema like `clinvar_2024_01_07_v2_0_0`) and normalize, validate, and summarize it into a form that downstream temporal collection and reporting stages can consume.

## Orchestrator

The entire preparation pipeline is coordinated by a single orchestrator procedure:

**`dataset-preparation-proc.sql`** defines `clinvar_ingest.dataset_preparation(in_schema_name)`, which:

1. Validates that the dataset exists and the schema name matches the expected format (`clinvar_YYYY_MM_DD_vX_X_X`)
2. Extracts the release date from the schema name
3. Calls each sub-procedure in order:
    - `normalize_dataset`
    - `validate_dataset`
    - `scv_summary`
    - `single_gene_variation`
    - `gc_scv_obs`
    - `refresh_scv_lookup`

## Scripts

| # | File | Procedure/Object Created | Description |
|---|------|--------------------------|-------------|
| 00 | `00-setup-translation-tables.sql` | Multiple tables | Creates and populates lookup/translation tables: `clinvar_statement_categories`, `clinvar_statement_types`, `clinvar_clinsig_types`, `scv_clinsig_map`, `status_rules`, `status_definitions` |
| 01 | `01-normalize-dataset-proc.sql` | `clinvar_ingest.normalize_dataset()` | Normalizes the raw dataset to a consistent v2 schema -- adds `statement_type` column to `clinical_assertion`, reconciles `rcv_accession_classification`, and handles `variation_archive_classification` |
| 02 | `02-validate-dataset-proc.sql` | `clinvar_ingest.validate_dataset()` | Validates the normalized dataset by checking for unknown classification terms, missing mappings in `scv_clinsig_map` and `clinvar_clinsig_types`, unknown review statuses, required field nulls, and release date consistency |
| 03 | `03-scv-summary-proc.sql` | `clinvar_ingest.scv_summary()` | Builds the `scv_summary` table -- the central denormalized view of all SCVs in a release, parsing content JSON fields using UDF parsing functions, joining submitter and classification metadata |
| 04 | `04-single-gene-variation-proc.sql` | `clinvar_ingest.single_gene_variation()` | Creates the `single_gene_variation` table that maps each variation to its single representative gene, prioritizing MANE Select transcripts, then variation name gene symbols, then gene-variation associations |
| 05 | `05-gc_scv_obs-proc.sql` | `clinvar_ingest.gc_scv_obs()` | Builds the `gc_scv_obs` table for GenomeConnect (GC) submitter SCVs, joining SCV observations with parsed sample, method, trait, and citation data |
| 06 | `06-refresh_scv_lookup-proc.sql` | `clinvar_ingest.refresh_scv_lookup()` | Refreshes the `clinvar_qa.scv_lookup` table with UUID-formatted local keys for SCV lookups from the VCI submission service |
| -- | `dataset-preparation-proc.sql` | `clinvar_ingest.dataset_preparation()` | Orchestrator procedure that calls all of the above in sequence |

## Execution Order

The numeric prefixes define the required execution order. Each step depends on the output of prior steps:

```
00-setup-translation-tables (manual, run once)
    |
01-normalize-dataset
    |
02-validate-dataset (raises errors if validation fails)
    |
03-scv-summary (depends on normalized clinical_assertion + translation tables)
    |
04-single-gene-variation (depends on variation, gene tables)
    |
05-gc_scv_obs (depends on scv_summary + single_gene_variation)
    |
06-refresh_scv_lookup (depends on clinical_assertion)
```

!!! note "Setup script is manual"
    `00-setup-translation-tables.sql` is a one-time setup script that creates and populates the lookup tables used by validation and normalization. It must be re-run manually whenever new classification terms or review statuses appear in ClinVar data. The `validate_dataset` procedure will flag when this is needed.

## Key Tables Read

- `{schema}.clinical_assertion` -- Raw SCV records from ClinVar ingest
- `{schema}.variation`, `{schema}.gene` -- Variation and gene data
- `{schema}.clinical_assertion_observation` -- SCV observation records
- `{schema}.submitter` -- Submitter metadata
- `{schema}.variation_archive`, `{schema}.variation_archive_classification` -- VCV-level data
- `{schema}.rcv_accession`, `{schema}.rcv_accession_classification` -- RCV-level data
- `clinvar_ingest.clinvar_clinsig_types` -- Clinical significance type mappings
- `clinvar_ingest.scv_clinsig_map` -- SCV classification term mappings
- `clinvar_ingest.status_rules`, `clinvar_ingest.status_definitions` -- Review status mappings
- `clinvar_ingest.entrez_gene`, `clinvar_ingest.mane_select` -- Gene and MANE transcript data

## Key Tables Written

- `{schema}.scv_summary` -- Denormalized SCV summary (central output)
- `{schema}.single_gene_variation` -- Variation-to-gene mapping
- `{schema}.gc_scv_obs` -- GenomeConnect SCV observations
- `clinvar_qa.scv_lookup` -- UUID-based SCV lookup for VCI

!!! info "The `scv_summary` table"
    The `scv_summary` table is the most important output of dataset preparation. It is the prerequisite for the temporal data collection stage -- the `all_schemas()` function specifically checks for the existence of `scv_summary` to determine whether a release has been fully processed.
