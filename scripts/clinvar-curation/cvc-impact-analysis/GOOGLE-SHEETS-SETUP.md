# Google Sheets Dashboard Setup Guide

This guide explains how to set up Google Sheets dashboards using the visualization views created by the CVC Impact Analysis pipeline.

---

## Dashboard Overview (README Sheet)

Use the table below as a README sheet in your Google Sheets file. Replace `[Link]` with actual hyperlinks to each chart's sheet.

| Chart | Name | Purpose | BigQuery View | Link |
|-------|------|---------|---------------|------|
| 1a | Flagging Candidate Attrition Funnel | Compares total submitted flagging candidates with their outcome breakdown as a stacked bar | `sheets_flagging_candidate_funnel_pivoted` | [Link] |
| 1b | Flagging Candidate Outcome Pie | Shows the proportion of each outcome category as a pie chart | `sheets_flagging_candidate_pie` | [Link] |
| 2 | Version Bump Impact by Submitter | Per-submitter breakdown of flagging candidate outcomes showing which submitters are version-bumping | `sheets_version_bump_impact_by_submitter` | [Link] |
| 3 | Version Bump Timing Distribution | Shows WHEN version bumps occur relative to the 60-day grace period to detect strategic timing | `sheets_version_bump_timing` | [Link] |
| 4 | CVC Monthly Impact Summary | Monthly trends in CVC-attributed vs organic conflict resolutions (filtered to exclude bulk downgrades) | `sheets_cvc_impact_monthly_filtered` | [Link] |
| 5 | CVC Attribution Breakdown | Detailed monthly breakdown of resolution attribution types (filtered to exclude bulk downgrades) | `sheets_cvc_attribution_breakdown_filtered` | [Link] |
| 6A | Batch Effectiveness: Rates | Grouped bar chart comparing resolution rate vs flag rate across CVC batches | `sheets_cvc_batch_effectiveness` | [Link] |
| 6B | Batch Effectiveness: Volume | Stacked bar showing variants resolved vs unresolved for each batch | `sheets_cvc_batch_effectiveness` | [Link] |
| 6C | Batch Effectiveness: Maturity | Bubble chart showing batch age (X) vs resolution rate (Y) with bubble size = submission volume | `sheets_cvc_batch_effectiveness` | [Link] |
| 7 | Cumulative Impact | Cumulative growth of CVC submissions, flags, and resolutions over time | `sheets_cvc_cumulative_impact` | [Link] |

### Key Insights by Chart

| Chart | Key Question Answered |
|-------|----------------------|
| 1a/1b | What happens to flagging candidate submissions? How many get flagged vs other outcomes? |
| 2 | Which submitters are avoiding flags through version bumps? |
| 3 | Are submitters strategically timing version bumps to avoid the 60-day grace period deadline? |
| 4 | How do CVC-attributed resolutions compare to organic resolutions over time? |
| 5 | What's driving CVC-attributed resolutions—flags, prompted deletions, or prompted reclassifications? |
| 6A/B/C | Which CVC batches have been most effective at driving conflict resolutions? |
| 7 | How has CVC's cumulative impact grown since the program started? |

### Data Refresh

- **Source**: BigQuery `clinvar_curator` dataset
- **Refresh frequency**: After each ClinVar release (~monthly) or when new CVC batches are submitted
- **Last pipeline run**: Check `cvc_impact_summary` table for latest `snapshot_release_date`

---

## Outcome Category Reference

All flagging candidate submissions are categorized into exactly one of the following mutually exclusive outcome categories. Categories are numbered for consistent ordering across charts.

| # | Category | Column Name | Description |
|---|----------|-------------|-------------|
| 00 | Total Submitted | `00_Total_Submitted` | Total count of all flagging candidate submissions (used only in funnel chart) |
| 01 | Flagged | `01_Flagged` | CVC flag was successfully applied to the SCV (primary success) |
| 02 | Reclassified | `02_Reclassified` | Submitter changed their classification before/instead of being flagged (submitter success) |
| 03 | Removed | `03_Removed` | Submitter deleted their SCV before/instead of being flagged (submitter success) |
| 04 | Substantive Changes | `04_Substantive_Changes` | Submitter made real changes (rank, last_evaluated, trait) but kept the same classification |
| 05 | Within Grace Pending | `05_Within_Grace_Pending` | Recent submissions still within the 60-day grace period; outcome not yet determined |
| 06 | Version Bump During Grace | `06_Version_Bump_During_Grace` | Submitter resubmitted during grace period with no substantive changes (resets the clock) |
| 07 | Version Bump After Grace | `07_Version_Bump_After_Grace` | Submitter resubmitted after grace period with no substantive changes (avoided flag) |
| 08 | Stale at Submission | `08_Stale_at_Submission` | Submitted version was already outdated when NCBI accepted the batch (NCBI validation gap) |
| 09 | Anomaly - Should Flag | `09_Anomaly_Should_Flag` | Past grace period, same version, still pending—should have been flagged (needs investigation) |
| 10 | Rejected by NCBI | `10_Rejected_by_NCBI` | NCBI rejected the submission before processing (excluded from outcome analysis) |
| 11 | Other/Unknown | `11_Other_Unknown` | Edge cases not fitting other categories |

### Category Groupings

| Group | Categories | Interpretation |
|-------|------------|----------------|
| **Success** | 01-03 (Flagged, Reclassified, Removed) | Conflict was addressed—either by CVC flag or submitter action |
| **Neutral** | 04 (Substantive Changes) | Submitter made real changes but maintained their classification |
| **In Progress** | 05 (Within Grace Pending) | Too early to determine outcome |
| **Concerning** | 06-07 (Version Bumps) | Submitter avoided flag without making substantive changes |
| **Process Issues** | 08-10 (Stale, Anomaly, Rejected) | Issues requiring investigation or outside normal workflow |
| **Edge Cases** | 11 (Other/Unknown) | Rare situations not covered by other categories |

---

## Prerequisites

1. Access to BigQuery with the `clinvar_curator` dataset
2. Google Sheets with Connected Sheets enabled (requires Workspace account)
3. Pipeline has been run to populate the views

## Connecting BigQuery to Google Sheets

1. Open a new Google Sheet
2. Go to **Data** → **Data connectors** → **Connect to BigQuery**
3. Select the project `clingen-dev`
4. Navigate to `clinvar_curator` dataset
5. Select the view you want to visualize

---

## Chart 1a: Flagging Candidate Attrition Funnel

**View:** `sheets_flagging_candidate_funnel_pivoted`

**Purpose:** Compares total submitted flagging candidates with their outcome breakdown.

### Data Format

The view outputs two rows:
| sort_order | label | Total_Submitted | Flagged | Reclassified | ... |
|------------|-------|-----------------|---------|--------------|-----|
| 1 | Total Submitted | 5632 | 0 | 0 | ... |
| 2 | Breakdown | 0 | 2218 | 1002 | ... |

- **Row 1 (Total Submitted)**: Shows the total count in a single column, creating a solid bar
- **Row 2 (Breakdown)**: Shows each category as a stacked segment, summing to the same total

### Setup Steps

1. Connect to `clinvar_curator.sheets_flagging_candidate_funnel_pivoted`
2. Click **Extract** to pull the data into a regular sheet (this enables full charting options)
3. **Important**: Delete the `sort_order` column from your extracted data (it's only for ordering)
4. Select the extracted data range (all columns including header row, excluding sort_order)
5. Insert → Chart
6. Choose **Stacked bar chart**
7. In Chart Editor **Setup** tab:
   - Set **X-axis** to `label` column
   - Add all numeric columns as **Series** (Total_Submitted, Flagged, Reclassified, Removed, etc.)

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Stacked Bar (horizontal) |
| Stacking | Stacked |
| Data range | All columns from the pivoted view (except sort_order) |

### Customizing Series Colors

1. Click on the chart → **Edit chart**
2. Go to **Customize** tab → **Series**
3. Select each series from the dropdown and set its color:

| Series (Column) | Color | Hex Code |
|-----------------|-------|----------|
| `Total_Submitted` | Blue | #4285F4 |
| `Flagged` | Dark Green | #1B7F37 |
| `Reclassified` | Light Green | #6AA84F |
| `Removed` | Light Green | #93C47D |
| `Substantive_Changes` | Yellow | #F1C232 |
| `Within_Grace_Pending` | Light Gray | #B7B7B7 |
| `Version_Bump_During_Grace` | Red | #CC0000 |
| `Version_Bump_After_Grace` | Orange | #E69138 |
| `Stale_at_Submission` | Light Purple | #B4A7D6 |
| `Anomaly_Should_Flag` | Purple | #674EA7 |
| `Rejected_by_NCBI` | Gray | #666666 |
| `Other_Unknown` | Dark Gray | #999999 |

### Recommended Series Order (left to right in stacked bar)

For best visual impact, order the series so the total bar is first, then success outcomes on the left (start of bar):

1. `Total_Submitted` (blue) - Total count (only shows on "Total Submitted" row)
2. `Flagged` (dark green) - Primary success
3. `Reclassified` (light green) - Submitter success
4. `Removed` (light green) - Submitter success
5. `Substantive_Changes` (yellow) - Neutral
6. `Within_Grace_Pending` (light gray) - In progress
7. `Version_Bump_During_Grace` (red) - Concerning
8. `Version_Bump_After_Grace` (orange) - Concerning
9. `Stale_at_Submission` (light purple) - Process issue
10. `Anomaly_Should_Flag` (purple) - Needs investigation
11. `Rejected_by_NCBI` (gray) - Out of scope
12. `Other_Unknown` (dark gray) - Edge cases

To reorder series in Google Sheets:
1. Go to **Customize** → **Series**
2. Use the series dropdown and adjust order in the legend, or
3. Reorder columns in the source data extract

### Category Descriptions

| Category | Description |
|----------|-------------|
| Flagged | Flag was applied (success) |
| Reclassified | Submitter changed the classification (success) |
| Removed | Submitter deleted the SCV (success) |
| Substantive_Changes | Real changes made (rank, last_evaluated, etc.) but classification unchanged |
| Within_Grace_Pending | Recent batches still within 60-day grace period |
| Version_Bump_During_Grace | Version bumps with no substantive changes during 60-day grace period |
| Version_Bump_After_Grace | Version bumps with no substantive changes after grace period ended |
| Stale_at_Submission | Submitted version was already outdated when batch was accepted |
| Anomaly_Should_Flag | Past grace period, same version, but not flagged (needs investigation) |
| Rejected_by_NCBI | SCVs rejected by NCBI before processing |
| Other_Unknown | Edge cases not fitting other categories |

### Interpretation

- **Green segments** (Flagged, Reclassified, Removed): Success outcomes - either CVC flag applied or submitter took appropriate action
- **Red/Orange segments** (Version Bumps): Concerning pattern - submitters avoiding flags without making substantive changes
- **Yellow segment** (Substantive Changes): Neutral - submitters made real changes but kept the same classification
- **Light Purple segment** (Stale at Submission): Process issue where NCBI accepted a stale version reference
- **Purple segment** (Anomaly): SCVs that should have been flagged but weren't - needs investigation
- The total bar width represents all submitted flagging candidates (100%)

---

## Chart 1b: Flagging Candidate Outcome Pie Chart

**View:** `sheets_flagging_candidate_pie`

**Purpose:** Shows the proportion of each outcome category.

### Setup Steps

1. Connect to `clinvar_curator.sheets_flagging_candidate_pie`
2. Click **Extract** to pull the data into a regular sheet
3. Select the data range (all rows and columns)
4. Insert → Chart
5. Choose **Pie chart**
6. In Chart Editor **Setup** tab:
   - Set **Labels** to `category`
   - Set **Values** to `count`

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Pie |
| Labels | category |
| Values | count |

### Slice Colors

| Category | Color | Hex Code |
|----------|-------|----------|
| Flagged | Dark Green | #1B7F37 |
| Reclassified | Light Green | #6AA84F |
| Removed | Medium Green | #93C47D |
| Substantive Changes | Yellow | #F1C232 |
| Within Grace Pending | Light Gray | #B7B7B7 |
| Version Bump During Grace | Red | #CC0000 |
| Version Bump After Grace | Orange | #E69138 |
| Stale at Submission | Light Purple | #B4A7D6 |
| Anomaly - Should Flag | Purple | #674EA7 |
| Rejected by NCBI | Gray | #666666 |
| Other/Unknown | Dark Gray | #999999 |

---

## Chart 2: Version Bump Impact by Submitter

**View:** `sheets_version_bump_impact_by_submitter`

**Purpose:** Shows per-submitter breakdown of what happened to their flagging candidates.

### Setup Steps

1. Connect to `clinvar_curator.sheets_version_bump_impact_by_submitter`
2. Select all data
3. Insert → Chart
4. Choose **Stacked Bar chart**

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Stacked Bar (horizontal) |
| X-axis | `submitter_name` |
| Series | All columns except `submitter_name` and `total_flagging_candidates` |
| Stacking | Stacked |

### Recommended Series Order (bottom to top)

1. `Flagged` (green)
2. `Reclassified` (blue)
3. `Removed` (light blue)
4. `Pending_Other` (gray)
5. `Version_Bump_During_Grace` (orange)
6. `Version_Bump_After_Grace` (red)

### Interpretation

- Submitters with large orange/red segments are avoiding flags through version bumps
- Compare the green (flagged) portion across submitters
- Submitters with mostly green/blue segments are responding appropriately

---

## Chart 3: Version Bump Timing Distribution

**View:** `sheets_version_bump_timing`

**Purpose:** Shows WHEN version bumps occur relative to the grace period to detect strategic timing.

### Setup Steps

1. Connect to `clinvar_curator.sheets_version_bump_timing`
2. Select all data
3. Insert → Chart
4. Choose **Column chart** or **Grouped Bar chart**

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Column or Bar |
| X-axis | `days_bucket` |
| Series 1 | `version_bumps_no_change` (red/orange) |
| Series 2 | `version_changes_substantive` (blue) |
| Sort by | `sort_order` (ascending) |

### Time Buckets

| Bucket | Days | Grace Period Status |
|--------|------|---------------------|
| Before Acceptance | < 0 | N/A |
| Days 0-14 | 0-14 | Within grace |
| Days 15-30 | 15-30 | Within grace |
| Days 31-45 | 31-45 | Within grace |
| Days 46-60 (End of Grace) | 46-60 | End of grace period |
| Days 61-90 | 61-90 | After grace |
| Days 91-180 | 91-180 | After grace |
| Days 180+ | > 180 | Long after grace |

### Indicating the Grace Period Boundary

Google Sheets does not support reference lines on stacked column charts. Alternatives:

1. **Use color coding**: The "04. Days 46-60 (End of Grace)" bucket label indicates the boundary
2. **Add a text box**: Insert → Drawing → Text box with "← Within Grace | After Grace →" and position it above the chart between buckets 04 and 05
3. **Conditional formatting**: In the extracted data, highlight the row for bucket 04 to visually distinguish it

### Interpretation

- Spikes in the "Days 46-60" bucket suggest strategic timing to avoid flags
- Compare red (no change) vs blue (substantive) to see if changes are meaningful
- Activity after Day 60 shows continued pattern of bumping

---

## Chart 4: CVC Monthly Impact Summary (Filtered)

**View:** `sheets_cvc_impact_monthly_filtered`

**Purpose:** Shows monthly trends in CVC impact on conflict resolution, excluding bulk SCV downgrade events for cleaner trend analysis.

### Background: Why Filtered?

Two major bulk downgrade events significantly impacted resolution counts:

| Date         | Submitter                      | Event                              | Resolutions Excluded |
|--------------|--------------------------------|------------------------------------|----------------------|
| October 2024 | PreventionGenetics (ID 239772) | ~15,000 SCVs downgraded 1→0 stars  | 2,831                |
| July 2025    | Counsyl (ID 320494)            | ~4,000 SCVs downgraded 1→0 stars   | 800                  |

These bulk events can mask underlying trends in the data. The filtered view excludes resolutions where:

1. `primary_reason = 'scv_rank_downgraded'`
2. The snapshot is in an affected month (Oct 2024, Jul 2025)
3. At least one SCV in that resolution was from the bulk downgrade submitter

### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_impact_monthly_filtered`
2. Select all data
3. Insert → Chart
4. Choose **Line chart** or **Area chart**

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Line or Stacked Area |
| X-axis | `month_label` |
| Series | `cvc_attributed_resolutions`, `organic_resolutions` |

### Additional Column

The view includes an `excluded_bulk_downgrades` column showing how many resolutions were filtered out for that month. This provides transparency about the filtering impact.

### Interpretation

- Compare CVC-attributed resolutions to organic resolutions over time
- Look for trends as CVC submission volume increases
- Filtered view shows cleaner baseline without outlier spikes

> **Note:** An unfiltered view (`sheets_cvc_impact_monthly`) is also available if you need the full picture including bulk downgrade events.

---

## Chart 5: CVC Attribution Breakdown (Filtered)

**View:** `sheets_cvc_attribution_breakdown_filtered`

**Purpose:** Shows detailed breakdown of how resolutions are attributed, excluding bulk SCV downgrade events for cleaner trend analysis.

### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_attribution_breakdown_filtered`
2. Select all data
3. Insert → Chart
4. Choose **Stacked Area chart** or **Stacked Bar chart**

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Stacked Area or Stacked Bar |
| X-axis | `month_label` |
| Series | `CVC_Flagged`, `Submitter_Deleted_CVC_Prompted`, `Submitter_Reclassified_CVC_Prompted`, `Organic`, `CVC_Submitted_Organic_Outcome` |

### Attribution Categories

| Category | Description |
|----------|-------------|
| CVC_Flagged | CVC flag directly caused resolution |
| Submitter_Deleted_CVC_Prompted | Submitter deleted SCV after CVC submission |
| Submitter_Reclassified_CVC_Prompted | Submitter reclassified after CVC submission |
| Organic | Resolution unrelated to CVC |
| CVC_Submitted_Organic_Outcome | CVC submitted but outcome was organic |

### Transparency Column

The view includes an `excluded_bulk_downgrades` column showing how many resolutions were filtered out for that month.

> **Note:** An unfiltered view (`sheets_cvc_attribution_breakdown`) is also available if you need the full picture including bulk downgrade events.

---

## Chart 6: Batch Effectiveness

**View:** `sheets_cvc_batch_effectiveness`

**Purpose:** Compare effectiveness metrics across CVC batches to see which batches have been most successful at driving resolutions.

**Implementation:** The dashboard uses all three chart options (A, B, and C) to provide different perspectives on batch effectiveness.

### Data Columns

| Column | Description |
|--------|-------------|
| `batch_id` | CVC batch identifier (101, 102, etc.) |
| `batch_month` | Month/year label for the batch (e.g., "Aug '23") |
| `scvs_submitted` | Total SCVs submitted in this batch |
| `variants_targeted` | Unique variants targeted by this batch |
| `variants_resolved` | Number of targeted variants that have since resolved |
| `resolution_rate_pct` | % of targeted variants that resolved |
| `flag_rate_pct` | % of submissions that resulted in flags being applied |
| `days_since_submission` | Days since batch was submitted (older = more mature) |

---

### Chart 6A: Grouped Bar Chart (Comparing Rates)

**Best for:** Comparing resolution and flag rates across batches

#### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_batch_effectiveness`
2. Click **Extract** to pull data into a regular sheet
3. Select columns: `batch_month`, `resolution_rate_pct`, `flag_rate_pct`
4. Insert → Chart → **Bar chart**

#### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Bar chart (vertical) |
| X-axis | `batch_month` |
| Series 1 | `resolution_rate_pct` (Blue) |
| Series 2 | `flag_rate_pct` (Green) |
| Stacking | None (grouped bars side by side) |

#### Customize Tab Settings

- **Chart & axis titles**: Title = "Batch Effectiveness: Resolution vs Flag Rates"
- **Series**: Set Resolution Rate to blue (#4285F4), Flag Rate to green (#1B7F37)
- **Legend**: Position = Bottom

---

### Chart 6B: Stacked Bar Chart (Volume Breakdown)

**Best for:** Showing submission volume and how many resolved

#### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_batch_effectiveness`
2. Click **Extract** to pull data into a regular sheet
3. Select columns: `batch_month`, `variants_resolved`, `variants_targeted`
4. **Important**: Create a calculated column `variants_unresolved` = `variants_targeted` - `variants_resolved`
5. Select: `batch_month`, `variants_resolved`, `variants_unresolved`
6. Insert → Chart → **Stacked bar chart**

#### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Stacked bar chart (vertical) |
| X-axis | `batch_month` |
| Series 1 | `variants_resolved` (Green - bottom of stack) |
| Series 2 | `variants_unresolved` (Gray - top of stack) |

---

### Chart 6C: Bubble Chart (Maturity vs Effectiveness) ⭐ Recommended

**Best for:** Seeing if older batches have higher resolution rates, with bubble size showing batch volume

> **This is the primary implementation** used in the dashboard for visualizing batch maturity vs effectiveness.

#### Setup Steps (Bubble Chart)

Google Sheets bubble charts require columns in a specific order. Follow these steps exactly:

1. Connect to `clinvar_curator.sheets_cvc_batch_effectiveness`
2. Click **Extract** to pull data into a regular sheet
3. **Rearrange columns in this exact order** (left to right):
   - Column A: `batch_month` (this becomes the ID/Label)
   - Column B: `days_since_submission` (this becomes X-axis)
   - Column C: `resolution_rate_pct` (this becomes Y-axis)
   - Column D: `scvs_submitted` (this becomes bubble Size)
4. Select all four columns (A through D, including headers)
5. Insert → Chart → Choose **Bubble chart**

Google Sheets auto-assigns columns based on position:
- 1st column → ID (label)
- 2nd column → X-axis
- 3rd column → Y-axis
- 4th column → Size (optional)

#### Bubble Chart Setup Tab Configuration

After inserting the chart, verify in the **Setup** tab:

| Field | Should Be Set To |
|-------|------------------|
| ID | `batch_month` (Column A) |
| X-axis | `days_since_submission` (Column B) |
| Y-axis | `resolution_rate_pct` (Column C) |
| Size | `scvs_submitted` (Column D) |

If the Size field shows "None" or wrong column:

1. Click the **Size** dropdown
2. Select `scvs_submitted`
3. If it's not listed, your columns may not be in the correct order—rearrange and recreate the chart

#### Showing Labels on Bubbles

1. **Customize** tab → **Bubble** section
2. Check **Show bubble labels**
3. Labels will display the `batch_month` value on each bubble

---

### Interpretation (All Chart 6 Options)

- **Resolution rate** shows what % of variants CVC targeted have since resolved (by any means)
- **Flag rate** shows what % of SCVs actually got flagged (direct CVC success)
- Older batches (`days_since_submission` > 365) should have higher resolution rates as more time has passed
- If flag rate is high but resolution rate is low, flags may not be driving resolutions
- Batch 107 (Apr '24) shows unusually low resolution rate (13.5%) despite high flag rate (43.4%) - see [BATCH-107-ANALYSIS.md](BATCH-107-ANALYSIS.md) for investigation

---

## Chart 7: Cumulative Impact

**View:** `sheets_cvc_cumulative_impact`

**Purpose:** Shows cumulative growth in CVC activity and impact over time.

### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_cumulative_impact`
2. Select all data
3. Insert → Chart
4. Choose **Line chart**

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Line |
| X-axis | `month_label` |
| Series | `cumulative_scvs_submitted`, `cumulative_cvc_resolutions`, `cumulative_organic_resolutions` |

---

## Tips for Google Sheets Dashboards

### Performance

- Use **Extract** mode instead of **Live** for large datasets
- Set up scheduled refreshes (Data → Data connectors → Refresh options)
- Consider filtering to recent batches for faster loading

### Formatting

- Use consistent color schemes across charts
- Add chart titles that explain the insight, not just the data
- Include the data freshness date in a header cell

### Interactivity

- Add slicers for filtering by:
  - Batch ID
  - Submitter
  - Date range
- Link slicers across multiple charts for coordinated filtering

### Sharing

- Viewers need BigQuery access to see connected data
- Consider exporting static copies for broader distribution
- Use **Publish to web** for embedding in other tools

---

## Refresh Schedule

The underlying BigQuery views are refreshed when:

1. New ClinVar release is processed (~monthly)
2. New CVC batch is submitted
3. Pipeline is manually run with `./00-run-cvc-impact-analysis.sh --force`

Recommended Google Sheets refresh: **Weekly** or **After each ClinVar release**

---

## Troubleshooting

### "No data" in chart

- Verify the pipeline has been run: check that `cvc_flagging_version_bump_intersection` table exists
- Check BigQuery permissions
- Ensure the Connected Sheets connection is active

### Slow loading

- Switch from Live to Extract mode
- Add filters to reduce data volume
- Check if the underlying views need optimization

### Missing submitter names

- Some submitters may have NULL names if they were deleted
- The views filter for `deleted_release_date IS NULL` to show current names

### Funnel doesn't balance

- All categories should be mutually exclusive and sum to 100%
- If the math doesn't add up, check for NULL values in the source data
- The "Other/Unknown" category catches edge cases

### Anomaly SCVs showing up

- The "Anomaly - Should Be Flagged" category identifies SCVs that:
  - Are past the grace period
  - Have the same version as when submitted
  - Are still marked as "pending"
- These need manual investigation in the ClinVar system

### Stale at Submission SCVs

- The "Stale at Submission (NCBI missed)" category identifies SCVs where:
  - The submitter updated their SCV before the CVC batch was accepted by NCBI
  - NCBI should have rejected these submissions because the version was outdated
  - Instead, NCBI accepted the stale version reference
- These represent a gap in NCBI's validation process
- The submitted version in CVC is older than what was current in ClinVar at batch acceptance time
