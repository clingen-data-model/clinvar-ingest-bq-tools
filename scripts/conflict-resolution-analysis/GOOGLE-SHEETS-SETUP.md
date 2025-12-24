# Google Sheets Analytics Setup Guide

This guide explains how to create a Google Sheet with interactive charts for ClinVar conflict resolution analytics.

## Overview

The analytics pipeline produces 7 optimized views for Google Sheets visualization:

| View | Purpose | Best For |
|------|---------|----------|
| `sheets_conflict_summary` | Monthly totals with net change | Trend lines, KPIs |
| `sheets_conflict_changes` | Change status breakdown (long format) | Pivot tables, custom aggregations |
| `sheets_change_reasons` | Primary reason for changes (long format) | Pivot tables, custom aggregations |
| `sheets_multi_reason_detail` | All contributing reasons | Deep-dive analysis |
| `sheets_monthly_overview` | Single row per month | Simple dashboards without slicers |
| `sheets_change_status_wide` | Change status as columns | Stacked bar charts with slicers |
| `sheets_change_reasons_wide` | Reasons as columns | Stacked bar charts with slicers |

### Wide vs Long Format Views

Google Sheets charts require **wide format** data for stacked/grouped bar charts (each series must be a separate column). Use the `_wide` views for charts:

| Long Format View | Wide Format View | Use Case |
|------------------|------------------|----------|
| `sheets_conflict_changes` | `sheets_change_status_wide` | Chart 3: Change Status Breakdown |
| `sheets_change_reasons` | `sheets_change_reasons_wide` | Chart 4: Resolution Reasons |

## Step 1: Connect to BigQuery

1. Open Google Sheets
2. Go to **Data** → **Data connectors** → **Connect to BigQuery**
3. Select your GCP project (e.g., `clingen-dev`)
4. In the query editor, enter one of the view queries below

### Recommended Initial Query

Start with the summary view for the main dashboard:

```sql
SELECT * FROM `clinvar_ingest.sheets_conflict_summary`
ORDER BY snapshot_release_date
```

## Step 2: Create Slicers

Add slicers for interactive filtering. Go to **Data** → **Add a slicer**.

### Recommended Slicers

| Slicer | Column | Purpose |
|--------|--------|---------|
| Date Range | `snapshot_month` | Filter by time period (use "Filter by values" for best results) |
| Conflict Type | `conflict_type` | Clinsig vs Non-Clinsig |
| Outlier Status | `outlier_status` | With Outlier vs No Outlier |

**Note on Date Slicers**: The `snapshot_month` column (formatted as `YYYY-MM`) works better with slicers than `snapshot_release_date`. Use "Filter by values" rather than "Filter by condition" to avoid issues with date formatting.

Place slicers at the top of your sheet. All charts on the sheet will respond to slicer selections.

## Step 3: Create Charts

### Chart 1: Conflict Trend Over Time

**Purpose**: Show total conflicts trending month-over-month

**Data Source**: `sheets_conflict_summary`

**Chart Type**: Line chart

**Configuration**:
- X-axis: `snapshot_month`
- Y-axis: `conflict_count`
- Series: Group by `conflict_type` (optional)

**Alternative**: Use `pct_of_path_variants` for percentage view

---

### Chart 2: Net Change Bar Chart (Two-Color)

**Purpose**: Show whether conflicts are increasing or decreasing each month with color coding

**Data Source**: `sheets_conflict_summary` or `sheets_monthly_overview`

**Chart Type**: Column chart (combo chart)

**Configuration**:
- X-axis: `snapshot_month`
- Series 1: `net_increase` → set color to **red** (more conflicts = bad)
- Series 2: `net_decrease` → set color to **green** (fewer conflicts = good)

**How it works**: Each month has a value in only ONE of the two columns (the other is NULL):
- Positive months: `net_increase` has the value, `net_decrease` is NULL → red bar
- Negative months: `net_decrease` has the value, `net_increase` is NULL → green bar

**Tip**: Negative net change = more resolutions than new conflicts (good!)

---

### Chart 3: Change Status Breakdown

**Purpose**: Show composition of changes each month (new, resolved, modified, unchanged)

**Data Source**: `sheets_change_status_wide`

**Chart Type**: Stacked column chart

**Query**:
```sql
SELECT * FROM `clinvar_ingest.sheets_change_status_wide`
ORDER BY snapshot_release_date
```

**Configuration**:
1. Add slicers for `conflict_type` and `outlier_status`
2. Insert → Chart → Stacked column chart
3. X-axis: `snapshot_month`
4. Series: `new_conflicts`, `resolved_conflicts`, `modified_conflicts`, `unchanged_conflicts`

**Tip**: Exclude `unchanged_conflicts` from the series for a clearer view of active changes.

---

### Chart 4: Resolution Reasons

**Purpose**: Understand WHY conflicts are being resolved

**Data Source**: `sheets_change_reasons_wide`

**Chart Type**: Stacked column chart

**Query**:
```sql
SELECT * FROM `clinvar_ingest.sheets_change_reasons_wide`
WHERE change_status = 'resolved'
ORDER BY snapshot_release_date
```

**Configuration**:
1. Add slicers for `conflict_type` and `outlier_status`
2. Insert → Chart → Stacked column chart
3. X-axis: `snapshot_month`
4. Series: `scv_flagged`, `scv_removed`, `scv_reclassified`, `expert_panel_added`, `consensus_reached`, etc.

**Available Reason Columns**:

*VCV-Level Reasons (Highest Priority)*:

- `expert_panel_added`: Expert panel (3/4-star) resolved the conflict
- `higher_rank_scv_added`: New 1-star SCV(s) superseded a 0-star conflict
- `vcv_rank_changed`: Existing SCV upgraded from 0-star to 1-star, superseding the conflict
- `outlier_reclassified`: An outlier submitter changed their classification
- `single_submitter_withdrawn`: Single submitter withdrew (conflict dissolved)
- `consensus_reached`: Submitters converged (no single SCV change explains resolution)

*Contributing Tier Reasons (High Priority)*:

- `scv_flagged`: ClinVar flagged a contributing-tier SCV
- `scv_removed`: Contributing-tier submission was withdrawn
- `scv_rank_downgraded`: A contributing SCV was downgraded (no longer contributes due to lower rank)
- `scv_reclassified`: Contributing-tier lab changed their classification
- `scv_added`: New submission added to contributing tier

*Lower Tier Flagging (ClinVar flagging is important to track)*:

- `scv_flagged_on_lower_tier`: ClinVar flagged a lower-tier SCV (e.g., 0-star SCV on 1-star conflict)

*Modification-Only Reasons*:

- `outlier_status_changed`: Gained or lost outlier status
- `conflict_type_changed`: Changed between clinsig and non-clinsig
- `unknown`: No identifiable reason (fallback)

**Note on Tiers**: "Contributing tier" refers to SCVs at the rank tier that determines the VCV's classification (1-star SCVs for 1-star conflicts, 0-star for 0-star conflicts). "Lower tier" refers to SCVs below that tier (e.g., 0-star SCVs on a 1-star conflict).

**Note**: Other lower-tier reasons (`scv_added_on_lower_tier`, `scv_removed_on_lower_tier`, `scv_reclassified_on_lower_tier`) have been removed because they don't impact the VCV's classification. However, `scv_flagged_on_lower_tier` is retained because ClinVar flagging is an important action worth tracking.

**Note on 0-star vs 1-star conflicts**: `higher_rank_scv_added` and `vcv_rank_changed` only apply to 0-star conflicts being superseded by 1-star SCVs. For 1-star conflicts, only `expert_panel_added` can supersede them (there are no 2-star SCVs in ClinVar's ranking system).

**Tip**: Use `WHERE change_status = 'modified'` to see modification reasons instead.

---

### Chart 5: Resolution Rate Over Time

**Purpose**: Track the percentage of conflicts being resolved each month

**Data Source**: `sheets_conflict_changes`

**Chart Type**: Line chart

**Query**:
```sql
SELECT * FROM `clinvar_ingest.sheets_conflict_changes`
WHERE change_status = 'resolved'
ORDER BY snapshot_release_date
```

**Configuration**:
- X-axis: `snapshot_month`
- Y-axis: `pct_of_prev_conflicts`

---

### Chart 6: Primary vs Contributing Reasons

**Purpose**: Compare how often a reason is the primary driver vs a contributing factor

**Data Source**: `sheets_multi_reason_detail`

**Chart Type**: Grouped bar chart

**Configuration**:
- X-axis: `reason`
- Y-axis: `as_primary_count` and `as_secondary_count` (side by side)
- Filter: Apply date range slicer

---

### Chart 7: Conflict Percentage Dashboard (KPIs)

**Purpose**: Show current conflict rate as percentage of all variants

**Data Source**: `sheets_monthly_overview`

**Chart Type**: Scorecard or single-value chart

**Configuration**:
- Value: `pct_total_conflicts` (latest month)
- Comparison: Previous month value

**Additional KPIs**:
- `pct_clinsig_conflicts`: Clinically significant conflict rate
- `net_change`: Monthly net change
- `resolved_conflicts`: Resolutions this month

## Step 4: Dashboard Layout

### Recommended Layout

```
┌─────────────────────────────────────────────────────────────┐
│  [Date Slicer]  [Conflict Type Slicer]  [Outlier Slicer]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐          │
│  │  Conflict Rate KPI  │  │  Net Change KPI     │          │
│  │  (Scorecard)        │  │  (Scorecard)        │          │
│  └─────────────────────┘  └─────────────────────┘          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Conflict Trend Over Time (Line Chart)               │  │
│  │  - Shows total conflicts or percentage by month      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Net Change by Month (Two-Color Bar Chart)           │  │
│  │  - Red = growing conflicts, Green = shrinking        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────┐  │
│  │  Change Status          │  │  Resolution Reasons     │  │
│  │  (Stacked Bar)          │  │  (Stacked Bar)          │  │
│  └─────────────────────────┘  └─────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Key Metrics Explained

### Conflict Metrics

| Metric | Description |
|--------|-------------|
| `conflict_count` | Total conflicting variants |
| `total_path_variants` | All variants with pathogenicity assertions (denominator) |
| `pct_of_path_variants` | Conflicts as % of total variants |
| `variants_with_conflict_potential` | Variants with 2+ SCVs at their contributing tier (better denominator) |

### Change Metrics

| Metric | Description |
|--------|-------------|
| `new_conflicts` | Conflicts appearing for the first time |
| `resolved_conflicts` | Conflicts that are no longer conflicting |
| `modified_conflicts` | Conflicts that changed but still exist |
| `unchanged_conflicts` | Conflicts with no changes |
| `net_change` | new - resolved (negative = improving) |
| `net_increase` | Positive net_change values only (for red bars) |
| `net_decrease` | Negative net_change values only (for green bars) |

### Percentage Calculations

| Metric | Numerator | Denominator |
|--------|-----------|-------------|
| `pct_of_path_variants` | conflict_count | total_path_variants |
| `pct_of_prev_conflicts` | variant_count | prev_month_total_conflicts |
| `pct_of_conflict_potential` | conflict_count | variants_with_conflict_potential |

## Slicer Combinations

### Analysis Scenarios

| Scenario | Slicers to Apply |
|----------|------------------|
| Focus on clinical impact | `conflict_type = 'Clinsig'` |
| Identify easy resolutions | `outlier_status = 'With Outlier'` |
| Recent trends | Select recent months in `snapshot_month` slicer |
| All high-impact conflicts | `conflict_type = 'Clinsig'` + `outlier_status = 'With Outlier'` |

## Refreshing Data

The underlying BigQuery views are updated when the pipeline runs (typically monthly).

To refresh your Google Sheet:
1. Click on any connected data range
2. Go to **Data** → **Data connectors** → **Refresh data**
3. Or set up automatic refresh in connector settings

## Troubleshooting

### No Data Showing

1. Check that the pipeline has been run (`./00-run-all-analytics.sh`)
2. Verify BigQuery connection is authenticated
3. Ensure you have access to the `clinvar_ingest` dataset

### Slicers Not Filtering Charts

1. Ensure charts are using the same data source as slicers
2. Check that chart ranges include the slicer columns
3. Rebuild the chart if necessary

### Date Slicer Shows Milliseconds

When using "Filter by condition" → "is between" on date columns, Google Sheets converts dates to milliseconds. **Workaround**: Use `snapshot_month` column (formatted as `YYYY-MM`) with "Filter by values" instead.

### Can't Create Stacked Bar Charts

Google Sheets requires wide-format data for stacked charts. Use the `_wide` views:
- `sheets_change_status_wide` for change status breakdown
- `sheets_change_reasons_wide` for resolution/modification reasons

### Performance Issues

If queries are slow:
1. Use date range slicers to limit data
2. Use `sheets_monthly_overview` for simple dashboards (pre-aggregated)
3. Create extracts for frequently accessed date ranges
