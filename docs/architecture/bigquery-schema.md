# BigQuery Schema

This page documents the key BigQuery datasets, tables, and schema conventions used by the ClinVar processing pipeline.

## Datasets

| Dataset | Purpose |
|---------|---------|
| `clinvar_ingest` | Primary dataset containing reference tables, temporal tables, summation tables, and shared procedures/functions |
| `variation_tracker` | Report definitions and generated tracker report tables |
| `clinvar_YYYY_MM_DD_vN_*` | Per-release schemas containing raw ingested ClinVar data and derived tables (e.g., `clinvar_2024_01_26_v2_6_0`) |

## Release Schema Convention

Each ClinVar release is ingested into its own BigQuery dataset following the naming pattern:

```
clinvar_YYYY_MM_DD_vN_major_minor
```

For example: `clinvar_2024_01_26_v2_6_0`

Procedures that operate on a specific release accept a `schema_name` parameter (e.g., `clinvar_2024_01_26_v2_6_0`) and use dynamic SQL with `REPLACE(sql, '@schema', schema_name)` or `FORMAT()` to target the correct dataset.

### Schema Discovery Table Functions

The `scripts/general/schema-table-functions-proc.sql` file defines table functions that enable discovery and navigation of available release schemas:

| Function | Description |
|----------|-------------|
| `clinvar_ingest.all_releases()` | Returns all known release dates with `prev_release_date` and `next_release_date`. Combines live schema detection from `INFORMATION_SCHEMA.TABLES` (looking for schemas with an `scv_summary` table) with a `historic_release_dates` table for pre-2023 releases. |
| `clinvar_ingest.all_schemas()` | Returns all available release schemas with `schema_name`, `release_date`, `prev_release_date`, and `next_release_date`. Only includes schemas where post-processing (scv_summary creation) is complete. |
| `clinvar_ingest.schema_on(on_date)` | Returns the schema that was active on a given date. |
| `clinvar_ingest.schemas_on_or_after(date)` | Returns all schemas from a given date forward. |
| `clinvar_ingest.schemas_on_or_before(date)` | Returns all schemas up to a given date. |
| `clinvar_ingest.release_on(on_date)` | Returns the release that was active on a given date. |

!!! tip
    The `all_schemas()` function checks for the existence of the `scv_summary` table within each schema. This ensures that only fully processed releases are returned, filtering out releases where the dataset-preparation procedures have not yet completed.

## Key Tables in `clinvar_ingest`

### Reference / Translation Tables

These tables are populated by the setup scripts and Cloud Functions. They provide lookup data used throughout the pipeline.

| Table | Description |
|-------|-------------|
| `clinvar_clinsig_types` | Classification type definitions mapping codes to labels, significance levels, proposition types, direction, strength, and GKS attributes. Partitioned by `statement_type` (GermlineClassification, OncogenicityClassification, SomaticClinicalImpact). |
| `scv_clinsig_map` | Maps raw SCV `interpretation_description` strings to normalized `clinvar_clinsig_types` codes. Handles legacy terms like "vous", "mutation", "poly". |
| `clinvar_proposition_types` | Proposition type lookup (path, onco, sci, dr, etc.) with display order and conflict detectability. |
| `status_rules` | Maps review status strings to logical context: SCV vs. aggregate level, rule type (SINGLE, CONFLICT, MULTIPLE_AGREE), and conflict detectability. |
| `status_definitions` | Maps review status strings to star-rating ranks with temporal validity windows (`start_release_date` / `end_release_date`). Handles terminology changes over time (e.g., "conflicting interpretations" vs. "conflicting classifications"). |
| `submission_level` | Maps SCV integer ranks to readable labels and short codes (PG, EP, CP, NOCP, NOCL, FLAG). |
| `submitter_organization` | Submitter metadata from ClinVar FTP (organization name, type, location, submission counts). |
| `ncbi_gene` | NCBI gene records (id, symbol, description, gene type, synonyms). |
| `hgnc_gene` | HGNC gene records with aliases, cross-references, and MANE select transcripts. |
| `hpo_terms` | HPO ontology terms (id, label). |
| `mondo_terms` | MONDO ontology terms with SKOS matches. |
| `historic_release_dates` | Pre-2023 ClinVar release dates used by `all_releases()` to supplement live schema detection. |
| `clinvar_submitter_abbrevs` | Custom submitter abbreviations for display in reports. |

### Temporal Tables

These tables accumulate data across releases, tracking how records change over time.

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `clinvar_vcv_classifications` | VCV-level aggregate classification history | `variation_id`, `vcv_id`, `statement_type`, `rank`, `agg_classification_description`, `start_release_date`, `end_release_date`, `deleted_release_date` |
| `clinvar_rcv_classifications` | RCV-level classification history (condition-specific) | `variation_id`, `rcv_id`, `statement_type`, `rank`, `start_release_date`, `end_release_date`, `deleted_release_date` |
| `clinvar_scvs` | Individual SCV submission history | `variation_id`, `id` (SCV ID), `version`, `statement_type`, `gks_proposition_type`, `rank`, `submitter_id`, `start_release_date`, `end_release_date`, `deleted_release_date` |

!!! note "Temporal Record Lifecycle"
    - **Active record:** `deleted_release_date IS NULL`
    - **Date range:** `start_release_date` to `end_release_date` indicates when the exact combination of attributes was in effect
    - **Deleted record:** `deleted_release_date` is set when the record disappears from a release
    - **Changed record:** The old row gets its `end_release_date` frozen, and a new row is inserted with the new attribute values

### Summation Tables

| Table | Description |
|-------|-------------|
| `clinvar_sum_scvs` | Expanded SCV records joined with rank group data, including outlier percentages and group type labels |
| `clinvar_sum_vsp_rank_group` | Variation/statement/proposition rank groups with significance type distributions (pathogenic/uncertain/benign counts and percentages) |
| `clinvar_sum_variation_scv_change` | Variation-level SCV change events over time |
| `clinvar_sum_vsp_rank_group_change` | Rank group composition changes |
| `clinvar_sum_vsp_top_rank_group_change` | Top-rank group transitions |
| `clinvar_sum_variation_group_change` | Variation-level group change summaries |

## Key Tables in Release Schemas

Each release schema (`clinvar_YYYY_MM_DD_vN_*`) contains both raw ingested tables and derived tables:

### Raw Tables (from ClinVar ingest)

| Table | Description |
|-------|-------------|
| `clinical_assertion` | Individual SCV submissions with `content` JSON field |
| `clinical_assertion_observation` | Observation data linked to SCVs with `content` JSON field |
| `variation_archive` | VCV records (one per variation) |
| `variation_archive_classification` | VCV-level aggregate classifications |
| `rcv_accession` | RCV records linking variations to conditions |
| `rcv_accession_classification` | RCV-level classifications |
| `submitter` | Submitter information for this release |
| `submission` | Submission metadata |
| `variation` | Variation records |
| `trait` / `trait_set` | Condition/phenotype data |

### Derived Tables (built by procedures)

| Table | Description |
|-------|-------------|
| `scv_summary` | Fully denormalized SCV summary joining clinical assertions with parsed content, submitter info, observation data, and classification mappings. Built by the `scv_summary` procedure. |
| `gc_scv_obs` | GC submitter observation-level data. Built by the `gc_scv_obs` procedure. |

## Key Tables in `variation_tracker`

| Table | Description |
|-------|-------------|
| `report` | Report definitions with `id`, `active` flag, and configuration |
| `report_submitter` | Links reports to submitters with a `type` field (e.g., "GC") |
| `report_variation` | Variations associated with each report |
