# ClinVar Miner Breakdowns

SQL scripts that produce BigQuery stored procedures replicating the datasets behind [ClinVar Miner](https://clinvarminer.genetics.utah.edu/) summary pages. Each procedure accepts an array of release dates and returns a single result set covering all requested snapshots — suitable for Google Sheets Connected Sheets donut/pie chart visualizations and dashboards.

## Scope

All procedures are scoped to **GermlineClassification** variants for each ClinVar release date passed in the `release_dates ARRAY<DATE>` argument. Each release date is snapshotted independently (distinguished by the `release_date` output column), and `pct` is computed within each release. Variant selection uses the `clinvar_sum_vsp_top_rank_group_change` table to identify each variant's determining rank, prioritizing `path` over `oth` `proposition_type` when both exist for a given `variation_id`. Pass a single date (e.g. the latest release) for a single-snapshot breakdown.

## Scripts

| Script | Procedure | Description |
|--------|-----------|-------------|
| `01-pathogenicity-breakdown.sql` | `clinvar_miner_pathogenicity_breakdown(release_dates ARRAY<DATE>)` | Variant counts by aggregate classification category (Pathogenic, Likely pathogenic, VUS, Likely benign, Benign, conflicts, not provided/other). |
| `02-concordance-breakdown.sql` | `clinvar_miner_concordance_breakdown(release_dates ARRAY<DATE>)` | Variant counts by submission agreement status (conflicts, confidence differences, expert panel, concordant multi-submission, single submission). |

## Usage

```sql
-- Multiple releases in one call
CALL `clinvar_ingest.clinvar_miner_pathogenicity_breakdown`(
  [DATE'2024-01-07', DATE'2024-02-01']);

CALL `clinvar_ingest.clinvar_miner_concordance_breakdown`(
  [DATE'2024-01-07', DATE'2024-02-01']);

-- Latest release only (look it up first)
DECLARE latest DATE DEFAULT (SELECT MAX(release_date) FROM `clinvar_ingest.all_schemas`());
CALL `clinvar_ingest.clinvar_miner_pathogenicity_breakdown`([latest]);
```

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
