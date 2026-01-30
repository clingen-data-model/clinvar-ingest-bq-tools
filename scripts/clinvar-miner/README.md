# ClinVar Miner Views

SQL scripts that produce BigQuery views replicating the datasets behind [ClinVar Miner](https://clinvarminer.genetics.utah.edu/) summary pages. Each view is designed for direct use in Google Sheets Connected Sheets for donut/pie chart visualizations and dashboards.

## Scope

All views are scoped to **GermlineClassification** variants from the latest ClinVar release. Variant selection uses the `clinvar_sum_vsp_top_rank_group_change` table to identify each variant's determining rank, prioritizing `path` over `oth` `gks_proposition_type` when both exist for a given `variation_id`.

## Scripts

| Script | View | Description |
|--------|------|-------------|
| `01-pathogenicity-breakdown.sql` | `clinvar_miner_pathogenicity_breakdown` | Variant counts by aggregate classification category (Pathogenic, Likely pathogenic, VUS, Likely benign, Benign, conflicts, not provided/other). |
| `02-concordance-breakdown.sql` | `clinvar_miner_concordance_breakdown` | Variant counts by submission agreement status (conflicts, confidence differences, expert panel, concordant multi-submission, single submission). |

## Common Data Sources

- **`clinvar_ingest.clinvar_sum_vsp_top_rank_group_change`** — Top rank per variant/proposition type across release windows.
- **`clinvar_ingest.clinvar_sum_vsp_rank_group`** — SCV-level aggregation providing `agg_sig_type` bitmask, `agg_classif` (slash-separated classification codes), and `submission_count`.
- **`clinvar_ingest.all_schemas()`** — Table function returning all available release dates.

## Key Concepts

### agg_sig_type Bitmask

Encodes which classification tiers are present among SCVs at the determining rank:

| Value | Tiers Present | Interpretation |
|-------|---------------|----------------|
| 1 | Benign/Likely benign only | Concordant B/LB |
| 2 | VUS only | Concordant VUS |
| 4 | Pathogenic/Likely pathogenic only | Concordant P/LP |
| 3 (1+2) | B/LB + VUS | Non-clinsig conflict |
| 5 (1+4) | B/LB + P/LP | Clinsig conflict |
| 6 (2+4) | VUS + P/LP | Clinsig conflict |
| 7 (1+2+4) | All three tiers | Clinsig conflict |

### agg_classif Term Matching

The `agg_classif` field is a slash-separated string of classification codes (e.g., `lp/p`). Views split on `/` and check individual terms against group mappings. The **first matching group wins** in priority order, with likely classifications checked before definitive ones:

- **Likely pathogenic**: `lp`, `lp-lp`, `lra`
- **Pathogenic**: `p`, `p-lp`, `era`
- **VUS**: `vus`, `ura`
- **Likely benign**: `lb`
- **Benign**: `b`

## Output Format

All views return the same column structure for consistency:

| Column | Description |
|--------|-------------|
| category label | Classification or concordance group name |
| `variants` | Count of distinct `variation_id` values |
| `pct` | Percentage of total variants |
| `release_date` | ClinVar release date used for the snapshot |
