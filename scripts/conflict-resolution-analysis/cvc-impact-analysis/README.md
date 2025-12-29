# CVC Impact Analysis

## Purpose

This pipeline tracks the impact of **ClinVar Curation (CVC) project submissions** on conflict resolution. It answers the key question: **What percentage of conflict resolutions are attributable to CVC curation vs organic changes?**

## Background

The CVC project began in August 2023 with the goal of improving ClinVar data quality by flagging SCVs that meet specific criteria (see [CURATION_CRITERIA_GUIDE.md](../../clinvar-curation/CURATION_CRITERIA_GUIDE.md)). When an SCV is flagged and the submitter doesn't respond within 60 days, the flag is applied and that SCV is excluded from conflict calculations.

### CVC Submission Timeline

```
[Curation Period]     [Batch Submission]    [60-Day Grace Period]    [Flag Applied]
    ~1 month                  |                   60 days                  |
├─────────────────┤          │             ├───────────────────┤          │
                             │                                            │
  Curators flag SCVs   Batch finalized     Submitters can              Flagged SCVs
  as "flagging         and submitted to    respond (remove/            excluded from
  candidates"          ClinVar             update their SCV)           conflict calc
```

### Key Data Sources

| Table | Dataset | Purpose |
|-------|---------|---------|
| `cvc_clinvar_batches` | clinvar_curator | Batch metadata with finalization dates |
| `cvc_clinvar_submissions` | clinvar_curator | Maps annotations to SCV submissions |
| `cvc_submitted_outcomes_view` | clinvar_curator | Outcomes of submitted annotations |
| `monthly_conflict_scv_changes` | clinvar_ingest | SCV-level changes in conflict resolution |
| `conflict_vcv_change_detail` | clinvar_ingest | VCV-level changes with reason categorization |

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CVC Curation Data                                   │
│  cvc_clinvar_batches  │  cvc_clinvar_submissions  │  cvc_submitted_outcomes │
└──────────────┬────────┴────────────┬──────────────┴─────────────────────────┘
               │                     │
               ▼                     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ 01-cvc-submitted-variants.sql                                               │
│                                                                              │
│ cvc_submitted_variants                                                       │
│ (All CVC-submitted SCVs with batch dates, outcomes, and variation_id)       │
└──────────────────────────────────────────┬─────────────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Conflict Resolution Data                                 │
│  monthly_conflict_scv_changes  │  conflict_vcv_change_detail                │
└──────────────┬─────────────────┴────────────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ 02-cvc-conflict-attribution.sql                                             │
│                                                                              │
│ cvc_variant_conflict_status                                                  │
│ (CVC variants joined with their conflict status over time)                   │
│                                                                              │
│ cvc_resolution_attribution                                                   │
│ (Resolutions categorized as CVC-attributed vs organic)                       │
└──────────────────────────────────────────┬─────────────────────────────────┘
                                           │
                                           ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ 03-cvc-impact-analytics.sql                                                 │
│                                                                              │
│ cvc_impact_summary                                                           │
│ (Monthly summary of CVC impact on resolutions)                               │
│                                                                              │
│ cvc_attribution_rates                                                        │
│ (Attribution rates: CVC vs organic resolutions)                              │
└────────────────────────────────────────────────────────────────────────────┘
```

## Attribution Logic

### Resolution Attribution Categories

| Category | Description | Detection Logic |
|----------|-------------|-----------------|
| **CVC Flagged** | Resolution occurred because CVC flagged contributing SCV(s) | `scv_id` in CVC submissions AND `outcome = 'flagged'` AND SCV appears in `monthly_conflict_scv_changes` with `is_first_time_flagged = TRUE` |
| **CVC Prompted** | Resolution occurred because submitter responded to CVC flag (deleted/reclassified during grace period) | `scv_id` in CVC submissions AND `outcome IN ('deleted', 'resubmitted, reclassified')` AND timing aligns with grace period |
| **Organic** | Resolution occurred without CVC involvement | No CVC submission for any contributing SCV, or CVC submission was invalid/pending |

### SCV Outcome Categories (from cvc_submitted_outcomes_view)

| Outcome | Description | Impact on Attribution |
|---------|-------------|----------------------|
| `flagged` | SCV was successfully flagged by ClinVar | Direct CVC attribution |
| `deleted` | Submitter deleted their SCV (during grace period) | CVC-prompted attribution |
| `resubmitted, reclassified` | Submitter changed classification (during grace period) | CVC-prompted attribution |
| `resubmitted, same classification` | Submitter updated but kept classification | No resolution impact |
| `pending (or rejected)` | Awaiting ClinVar processing or rejected | Not yet attributable |
| `invalid submission` | SCV version mismatch at submission time | Not attributable |

## Key Metrics

### Attribution Rate

```
CVC Attribution Rate = (CVC Flagged + CVC Prompted) / Total Resolutions
```

### Breakdown Dimensions

- **By Batch**: Track effectiveness of each curation batch
- **By Flagging Reason**: Which curation criteria lead to most resolutions?
- **By Conflict Type**: ClinSig vs Non-ClinSig resolution rates
- **By Time Since Submission**: How long until CVC curations lead to resolution?

## Output Tables

All tables and views are created in the `clinvar_curator` dataset.

| Table | Description | Grain |
|-------|-------------|-------|
| `cvc_submitted_variants` | All CVC-submitted SCVs with outcomes | One row per SCV submission |
| `cvc_variant_conflict_history` | CVC variants with monthly conflict status | One row per variant per month |
| `cvc_resolution_attribution` | Resolutions with attribution category | One row per resolved variant |
| `cvc_impact_summary` | Monthly aggregated impact metrics | One row per month |
| `cvc_batch_effectiveness` | Per-batch effectiveness metrics | One row per batch |
| `cvc_reason_effectiveness` | Per-curation-reason effectiveness | One row per reason |

## Usage

### Running the Pipeline

```bash
# Run all CVC impact analysis scripts
./00-run-cvc-impact-analysis.sh

# Or run individual scripts
bq query < 01-cvc-submitted-variants.sql
bq query < 02-cvc-conflict-attribution.sql
bq query < 03-cvc-impact-analytics.sql
```

### Example Queries

**Get overall attribution rate:**
```sql
SELECT
  snapshot_release_date,
  total_resolutions,
  cvc_flagged_resolutions,
  cvc_prompted_deletion + cvc_prompted_reclassification AS cvc_prompted_resolutions,
  organic_resolutions,
  cvc_attribution_rate_pct
FROM `clinvar_curator.cvc_impact_summary`
ORDER BY snapshot_release_date DESC;
```

**Find CVC-attributed resolutions by batch:**
```sql
SELECT
  batch_id,
  COUNT(*) AS resolutions,
  COUNTIF(primary_attribution = 'cvc_flagged') AS flagged,
  COUNTIF(primary_attribution LIKE 'cvc_prompted%') AS prompted
FROM `clinvar_curator.cvc_resolution_attribution`
WHERE variant_attribution = 'cvc_attributed'
GROUP BY batch_id
ORDER BY batch_id;
```

## Data Freshness

- **CVC submissions**: Updated when new batches are finalized (~monthly)
- **Conflict resolution data**: Updated when parent pipeline runs (after new monthly ClinVar release)
- **First batch date**: September 7, 2023
- **Total batches through Dec 2025**: 27 batches, 5,694 SCV submissions

## Related Documentation

- [Conflict Resolution Tracking Context](../conflict-resolution-tracking-context.md)
- [Curation Criteria Guide](../../clinvar-curation/CURATION_CRITERIA_GUIDE.md)
- [Resolution Reasons](../RESOLUTION-REASONS.md)
