# Temporal Data Summation

The temporal data summation scripts aggregate the raw temporal records from the collection stage into higher-level summary tables. These summaries track how SCV groupings change over time at increasing levels of abstraction -- from individual SCV changes up to variation-level classification group changes.

## Orchestrator

**`temporal-data-summation-proc.sql`** defines `clinvar_ingest.temporal_data_summation()`, which calls all six sub-procedures in sequence with no arguments.

## Scripts

| # | File | Procedure Created | Output Table | Description |
|---|------|-------------------|--------------|-------------|
| 01 | `01-clinvar-sum-variation-scv-change-proc.sql` | `clinvar_ingest.clinvar_sum_variation_scv_change()` | `clinvar_sum_variation_scv_change` | Identifies date ranges where the set of SCVs for a variation changed in any way (new, updated, deleted, or reassigned) |
| 02 | `02-clinvar-sum-vsp-rank-group-proc.sql` | `clinvar_ingest.clinvar_sum_vsp_rank_group()` | `clinvar_sum_vsp_rank_group` | Groups SCVs by variation/statement-type/proposition-type/rank and calculates significance type counts and percentages within each group |
| 03 | `03-clinvar-sum-scvs-proc.sql` | `clinvar_ingest.clinvar_sum_scvs()` | `clinvar_sum_scvs` | Joins individual SCVs with their rank group context to produce labeled SCV records with outlier percentages and group classifications |
| 04 | `04-clinvar-sum-vsp-rank-group-change-proc.sql` | `clinvar_ingest.clinvar_sum_vsp_rank_group_change()` | `clinvar_sum_vsp_rank_group_change` | Computes date ranges when a rank group's composition changed, collapsing consecutive identical states |
| 05 | `05-clinvar-sum-vsp-top-rank-group-change-proc.sql` | `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change()` | `clinvar_sum_vsp_top_rank_group_change` | Tracks changes in the top (highest) rank group per variation/statement-type/proposition-type combination |
| 06 | `06-clinvar-sum-variation-group-change-proc.sql` | `clinvar_ingest.clinvar_sum_variation_group_change()` | `clinvar_sum_variation_group_change` | Final variation-level summary of group changes across all statement types and proposition types |
| -- | `temporal-data-summation-proc.sql` | `clinvar_ingest.temporal_data_summation()` | -- | Orchestrator that calls 01 through 06 in sequence |

## Execution Order and Data Flow

The summation procedures must run in order because each builds on the output of the previous:

```
01 - variation_scv_change (from clinvar_scvs)
    |
02 - vsp_rank_group (from clinvar_scvs + variation_scv_change)
    |
03 - sum_scvs (from clinvar_scvs + vsp_rank_group)
    |
04 - vsp_rank_group_change (from vsp_rank_group)
    |
05 - vsp_top_rank_group_change (from vsp_rank_group)
    |
06 - variation_group_change (from vsp_top_rank_group_change)
```

## Key Concepts

### Significance Types
The `createSigType` function produces an array of three elements representing the count and percentage of SCVs in each significance category:

- Index 0: Non-significant (BLB -- Benign/Likely Benign)
- Index 1: Uncertain (VUS)
- Index 2: Significant (PLP -- Pathogenic/Likely Pathogenic)

### Rank Groups
SCVs are grouped by `variation_id`, `statement_type`, `gks_proposition_type`, and `rank`. The `rank` value comes from the classification's review status and determines the weight of that classification in aggregate assessments.

### Change Detection
The change detection pattern used in steps 01, 04, 05, and 06 works by:

1. Collecting all `start_release_date` boundaries (both from record starts and from the next release after record ends)
2. Computing corresponding `end_release_date` boundaries
3. Collapsing consecutive identical states into single date ranges

!!! info "These summary tables feed the tracker reports"
    The `clinvar_sum_scvs`, `clinvar_sum_vsp_rank_group_change`, `clinvar_sum_vsp_top_rank_group_change`, and `clinvar_sum_variation_group_change` tables are the primary inputs to the tracker report generation stage.

## Key Dependencies

**Reads from:**

- `clinvar_ingest.clinvar_scvs` -- The core temporal SCV table
- `clinvar_ingest.all_releases()` -- Release date metadata

**Writes to:**

- `clinvar_ingest.clinvar_sum_variation_scv_change`
- `clinvar_ingest.clinvar_sum_vsp_rank_group`
- `clinvar_ingest.clinvar_sum_scvs`
- `clinvar_ingest.clinvar_sum_vsp_rank_group_change`
- `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change`
- `clinvar_ingest.clinvar_sum_variation_group_change`
