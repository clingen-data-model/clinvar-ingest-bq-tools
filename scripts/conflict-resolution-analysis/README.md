# ClinVar Conflict Resolution Analytics

## Background

ClinVar is a public archive of reports on relationships between human genetic variants and conditions. When multiple clinical laboratories submit classifications for the same variant, disagreements can occur—one lab might classify a variant as "Pathogenic" while another classifies it as "Benign." These disagreements are called **conflicts** and are critical to track because they can impact clinical decision-making.

### What is a Conflict?

A conflict occurs when submissions for the same variant fall into different clinical significance tiers:

| Conflict Type | Description | `agg_sig_type` Values |
|---------------|-------------|----------------------|
| **Clinsig (Clinical Significance)** | Pathogenic/Likely Pathogenic vs VUS/Benign/Likely Benign | 5, 6, 7 |
| **Non-Clinsig** | Benign/Likely Benign vs VUS (Variant of Uncertain Significance) | 3 |

Clinsig conflicts are more clinically impactful because they represent fundamental disagreement about whether a variant causes disease.

### What is an Outlier?

An **outlier** exists when one classification tier represents a small minority (≤33%) of submissions. For example, if 10 labs say "Benign" and 2 say "Pathogenic," the Pathogenic submissions are outliers. Outlier conflicts are often easier to resolve because they may indicate a single lab using outdated criteria.

### Star Rankings

ClinVar uses a star ranking system (0-4 stars) based on the review status of submissions:
- **0-star**: No assertion criteria provided
- **1-star**: Criteria provided, single submitter or conflicting interpretations
- **2-star**: Criteria provided, multiple submitters, no conflicts
- **3-star**: Reviewed by expert panel
- **4-star**: Practice guideline

Higher-ranked submissions take precedence. An expert panel (3 star) submission can "mask" underlying conflicts at lower tiers.

## Purpose

This analytics pipeline tracks how ClinVar conflicts **evolve over time** by:

1. **Capturing monthly snapshots** of all conflicting variants
2. **Comparing consecutive months** to detect changes
3. **Tracking individual submissions (SCVs)** to understand what caused changes
4. **Categorizing resolutions and modifications** by reason

The goal is to answer questions like:
- How many conflicts exist, and is the number growing or shrinking?
- What percentage of conflicts have outliers?
- Why do conflicts get resolved? (reclassification, flagging, withdrawal, expert panels)
- Which submitters are involved in conflict changes?

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Source Tables                                        │
│  clinvar_sum_vsp_rank_group  │  clinvar_scvs  │  all_schemas()              │
└──────────────┬───────────────┴────────┬───────┴─────────────────────────────┘
               │                        │
               ▼                        ▼
┌──────────────────────────┐  ┌──────────────────────────────────┐
│ 01-get-monthly-conflicts │  │ 04-monthly-conflict-scv-snapshots│
│                          │  │                                  │
│ monthly_conflict_snapshots│  │ monthly_conflict_scv_snapshots   │
│ (VCV-level, one per      │  │ (SCV-level, all submissions for  │
│  variant per month)      │  │  conflicting variants)           │
└──────────────┬───────────┘  └──────────────┬───────────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────┐  ┌──────────────────────────────────┐
│ 02-monthly-conflict-     │  │ 05-monthly-conflict-scv-changes  │
│    changes               │  │                                  │
│                          │  │ monthly_conflict_scv_changes     │
│ monthly_conflict_changes │  │ monthly_conflict_vcv_scv_summary │
│ (VCV changes between     │  │ (SCV changes + VCV aggregates    │
│  consecutive months)     │  │  with multi-reason tracking)     │
└──────────────┬───────────┘  └──────────────┬───────────────────┘
               │                              │
               └──────────────┬───────────────┘
                              ▼
               ┌──────────────────────────────┐
               │ 06-resolution-modification-  │
               │    analytics                 │
               │                              │
               │ conflict_vcv_change_detail   │
               │ conflict_resolution_analytics│
               │ + 3 views for charting       │
               └──────────────────────────────┘
```

## Output Tables

### Core Tables

| Table | Description | Grain |
|-------|-------------|-------|
| `monthly_conflict_snapshots` | All conflicting variants for each monthly release | One row per variant per month |
| `monthly_conflict_changes` | How conflicts changed between consecutive months | One row per variant per month-pair |
| `monthly_conflict_scv_snapshots` | All SCVs for conflicting variants | One row per SCV per month |
| `monthly_conflict_scv_changes` | How individual SCVs changed | One row per SCV per month-pair |
| `monthly_conflict_vcv_scv_summary` | VCV-level summary with SCV change details | One row per VCV per month-pair |
| `conflict_vcv_change_detail` | All VCV changes with primary_reason and multi-reason tracking (covers new, resolved, modified, unchanged) | One row per VCV per month-pair |
| `conflict_resolution_analytics` | Aggregated counts by reason for charting | One row per reason category per month |

### Views for Visualization

| View | Description |
|------|-------------|
| `conflict_resolution_monthly_comparison` | Month-over-month comparison with prior values |
| `conflict_resolution_reason_totals` | Wide format with columns for each reason |
| `conflict_resolution_overall_trends` | High-level trend summary |

### Google Sheets Optimized Views

| View | Description |
|------|-------------|
| `sheets_conflict_summary` | Monthly totals with net change, percentages, sliceable by type/outlier |
| `sheets_conflict_changes` | Change status breakdown (new/resolved/modified/unchanged) |
| `sheets_change_reasons` | Primary reason for each change, for reason comparison charts |
| `sheets_multi_reason_detail` | All contributing reasons (not just primary), for deep-dive analysis |
| `sheets_monthly_overview` | Single row per month, pre-aggregated for simple dashboards |
| `sheets_change_status_wide` | Change status as columns, for stacked bar charts with slicers |
| `sheets_change_reasons_wide` | Reasons as columns, for stacked bar charts with slicers |
| `sheets_reason_combinations` | Reason combinations (e.g., "reclassified + removed"), for pattern analysis |
| `sheets_reason_combinations_wide` | Reason combinations as columns, for stacked charts over time |

## Key Metrics

### Change Status Categories

| Status | Description |
|--------|-------------|
| `new` | Conflict appeared this month (wasn't conflicting before) |
| `resolved` | Conflict disappeared (was conflicting, now isn't) |
| `modified` | Still conflicting but something changed |
| `unchanged` | Conflicting in both months with no significant changes |

### Conflict Rank Tier

Conflicts can be sliced by the star rank tier that determines the VCV's classification:

| Tier | Description |
|------|-------------|
| `0-star` | Conflicts among SCVs with no assertion criteria (rank=0) |
| `1-star` | Conflicts among SCVs with assertion criteria (rank=1). Most common tier. |
| `3-4-star` | Conflicts at expert panel or practice guideline level (rare) |
| `flagged` | SCVs that have been flagged by ClinVar (rank=-3) |

The `conflict_rank_tier` dimension enables analysis of whether conflicts at different quality tiers behave differently—for example, whether 1-star conflicts resolve faster than 0-star conflicts.

### Resolution and Modification Reasons

The pipeline tracks **SCV-level reasons** (what caused the change) separately from **VCV-level outcomes** (effects of the change). Only SCV reasons are used for categorizing resolutions and modifications.

**SCV Reasons (Causes):**

| Reason | Description | Applies To |
|--------|-------------|------------|
| `reclassified` | Contributing SCV changed classification | Resolution, Modification |
| `flagged` | ClinVar flagged a contributing SCV | Resolution, Modification |
| `removed` | Contributing SCV was withdrawn | Resolution, Modification |
| `rank_downgraded` | SCV demoted from contributing tier | Resolution, Modification |
| `expert_panel` | Expert panel (3/4-star) SCV added | Resolution |
| `higher_rank` | 1-star SCV supersedes 0-star conflict | Resolution |
| `added` | New SCV added to contributing tier | Modification only |

**VCV Outcomes (Effects - tracked but not used as reasons):**

- `outlier_status_changed`, `conflict_type_changed`, `vcv_rank_changed`
- These are resolved to their underlying SCV reason in the `sheets_reason_combinations` views

For detailed documentation including multi-reason tracking, special cases, and example queries, see **[RESOLUTION-REASONS.md](RESOLUTION-REASONS.md)**.

### Multi-Reason Tracking

A single VCV can have multiple SCV change reasons in one month. For example, a resolution might involve both flagging and reclassification:

```
scv_reasons: ["scv_flagged", "scv_reclassified"]
scv_reasons_with_counts: "scv_flagged(4), scv_reclassified(2)"
```

This allows analysis of complex resolution patterns where multiple factors contribute.

### First-Time Flagged Tracking

The `scv_flagged` reason uses first-occurrence tracking per SCV+version. If an SCV is flagged, unflagged, and re-flagged, only the first flagging event counts. This prevents double-counting the same submission's flagging.

## Usage

### Running the Pipeline

```bash
# Run all scripts in order
./00-run-all-analytics.sh

# Check if rebuild is needed (detects new monthly data)
./00-run-all-analytics.sh --check-only

# Force rebuild even without new data
./00-run-all-analytics.sh --force

# Dry run (show commands without executing)
./00-run-all-analytics.sh --dry-run
```

### Querying Results

**Get current conflict counts by type:**
```sql
SELECT
  snapshot_release_date,
  COUNTIF(clinsig_conflict) AS clinsig_conflicts,
  COUNTIF(NOT clinsig_conflict) AS nonclinsig_conflicts,
  COUNTIF(has_outlier) AS with_outlier,
  COUNT(*) AS total_conflicts
FROM `clinvar_ingest.monthly_conflict_snapshots`
GROUP BY snapshot_release_date
ORDER BY snapshot_release_date DESC
LIMIT 12;
```

**Get resolution breakdown by reason:**
```sql
SELECT
  snapshot_release_date,
  conflict_type,
  reason,
  variant_count
FROM `clinvar_ingest.conflict_resolution_analytics`
WHERE change_category = 'Resolution'
ORDER BY snapshot_release_date DESC, variant_count DESC;
```

**Find VCVs with multiple resolution reasons:**
```sql
SELECT
  snapshot_release_date,
  variation_id,
  vcv_change_status,
  scv_reasons_with_counts,
  reason_count
FROM `clinvar_ingest.conflict_vcv_change_detail`
WHERE reason_count >= 2
ORDER BY snapshot_release_date DESC;
```

**Get conflict breakdown by rank tier:**
```sql
SELECT
  snapshot_release_date,
  conflict_rank_tier,
  COUNT(*) AS total_conflicts,
  SUM(CASE WHEN vcv_change_status = 'resolved' THEN 1 ELSE 0 END) AS resolved,
  SUM(CASE WHEN vcv_change_status = 'new' THEN 1 ELSE 0 END) AS new_conflicts
FROM `clinvar_ingest.conflict_vcv_change_detail`
GROUP BY snapshot_release_date, conflict_rank_tier
ORDER BY snapshot_release_date DESC, conflict_rank_tier;
```

### Google Sheets Integration

These tables are designed to work with BigQuery Data Connector in Google Sheets:

1. **Connect to BigQuery** via Data > Data connectors > Connect to BigQuery
2. **Run queries** against the analytics tables
3. **Add slicers** for: `snapshot_release_date`, `conflict_type`, `outlier_status`, `conflict_rank_tier`
4. **Create pivot tables** grouping by `change_category` and `reason`
5. **Build charts** using the wide-format views for time-series visualization

## File Descriptions

| File | Purpose |
|------|---------|
| `00-run-all-analytics.sh` | Shell script to execute all SQL files in order |
| `00-create-all-analytics.sql` | Documentation file with dependency diagram and status check query |
| `01-get-monthly-conflicts.sql` | Creates monthly snapshots of all conflicting variants |
| `02-monthly-conflict-changes.sql` | Compares consecutive months to track VCV-level changes |
| `03-outlier-trends-long.sql` | Ad-hoc query for outlier trends (long format) |
| `03-outlier-trends-wide.sql` | Ad-hoc query for outlier trends (wide format) |
| `04-monthly-conflict-scv-snapshots.sql` | Creates SCV-level snapshots for conflicting variants |
| `05-monthly-conflict-scv-changes.sql` | Tracks SCV-level changes and aggregates to VCV summary |
| `06-resolution-modification-analytics.sql` | Creates final analytics tables with reason categorization |
| `07-google-sheets-analytics.sql` | Creates optimized views for Google Sheets with slicers |
| `scv-reason-breakdown-queries.sql` | Example queries for exploring resolved variants with their SCVs |
| `GOOGLE-SHEETS-SETUP.md` | Guide for building Google Sheets dashboards with charts and slicers |
| `RESOLUTION-REASONS.md` | Detailed documentation of all resolution and modification reasons |
| `DESIGN-scv-level-tracking.md` | Technical design document for SCV-level change tracking |

## Data Flow Example

Consider a variant with 3 submissions: 2 say "Pathogenic" and 1 says "Benign" (a clinsig conflict with outlier).

**Month 1:** Captured in `monthly_conflict_snapshots` with `clinsig_conflict=TRUE`, `has_outlier=TRUE`

**Month 2:** The Benign submitter changes to "Pathogenic"
- `monthly_conflict_changes`: Status = `resolved`, reason = `scv_reclassified`
- `monthly_conflict_scv_changes`: One SCV has `scv_change_status='classification_changed'`
- `conflict_vcv_change_detail`: `scv_reasons_with_counts = "scv_reclassified(1)"`

The variant is no longer in conflict because all submitters now agree.

## Technical Notes

- **Temporal tables**: Uses `start_release_date`/`end_release_date` for point-in-time queries
- **Monthly granularity**: Takes first release of each month starting January 2023
- **Conflict potential denominator**: `variants_with_conflict_potential` counts variants with 2+ SCVs at their contributing tier (1-star SCVs for 1-star+ VCVs, 0-star SCVs for 0-star VCVs) - this is the meaningful baseline for conflict rates since only these variants could potentially have a conflict
- **Bitmask for classification tiers**: `agg_sig_type` uses bits: 1=B/LB, 2=VUS, 4=P/LP
- **Dual-condition conflict detection**: A variant is only counted as conflicting when BOTH conditions are met:
  1. `clinvar_vcv_classifications.agg_classification_description LIKE 'Conflicting%'` (authoritative VCV status)
  2. `clinvar_sum_vsp_rank_group.agg_sig_type IN (3, 5, 6, 7)` (SCVs actually conflict at determining rank)

  This excludes edge cases where the VCV classification is stale (e.g., SCVs were removed/flagged but VCV not yet updated).
- **Primary reason assignment**: Each VCV change receives a single `primary_reason` for aggregation, while `scv_reasons` array captures all contributing factors.
- **No double-counting across categories**: Each variant appears exactly once per month in `monthly_conflict_changes`, ensuring accurate sums across `conflict_type` and `outlier_status` dimensions. The categorization uses `COALESCE(curr_X, prev_X)` logic:

  | Change Status | Category Source | Rationale                              |
  |---------------|-----------------|----------------------------------------|
  | `new`         | `curr_` values  | `prev_` is NULL (wasn't conflicting)   |
  | `resolved`    | `prev_` values  | `curr_` is NULL (no longer conflicting)|
  | `modified`    | `curr_` values  | Both exist; uses current state         |
  | `unchanged`   | `curr_` values  | Both exist and are equal               |

  This means a variant that transitions from "With Outlier" to "No Outlier" (a modification) is counted once under "No Outlier"—not double-counted as both a resolution from one category and a new conflict in another. Summing counts across all `conflict_type` × `outlier_status` combinations gives accurate totals.
