# Google Sheets Dashboard Setup Guide

This guide explains how to set up Google Sheets dashboards using the visualization views created by the CVC Impact Analysis pipeline.

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

## Chart 4: CVC Monthly Impact Summary

**View:** `sheets_cvc_impact_monthly`

**Purpose:** Shows monthly trends in CVC impact on conflict resolution.

### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_impact_monthly`
2. Select all data
3. Insert → Chart
4. Choose **Line chart** or **Area chart**

### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Line or Stacked Area |
| X-axis | `month_label` |
| Series | `cvc_attributed_resolutions`, `organic_resolutions` |

### Interpretation

- Compare CVC-attributed resolutions to organic resolutions over time
- Look for trends as CVC submission volume increases

---

## Chart 5: CVC Attribution Breakdown

**View:** `sheets_cvc_attribution_breakdown`

**Purpose:** Shows detailed breakdown of how resolutions are attributed.

### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_attribution_breakdown`
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

---

## Chart 4 & 5 (Filtered): Excluding Bulk Downgrade Events

**Views:** `sheets_cvc_impact_monthly_filtered` and `sheets_cvc_attribution_breakdown_filtered`

**Purpose:** Alternative versions of Charts 4 and 5 that exclude conflict resolutions caused by bulk SCV star rating downgrades, providing a cleaner baseline for analyzing organic resolution trends.

### Background

Two major bulk downgrade events significantly impacted resolution counts:

| Date         | Submitter                      | Event                              | Resolutions Excluded |
|--------------|--------------------------------|------------------------------------|----------------------|
| October 2024 | PreventionGenetics (ID 239772) | ~15,000 SCVs downgraded 1→0 stars  | 2,831                |
| July 2025    | Counsyl (ID 320494)            | ~4,000 SCVs downgraded 1→0 stars   | 800                  |

These bulk events can mask underlying trends in the data. The filtered views allow you to:

- See organic resolution trends without outlier spikes
- Compare CVC impact against a cleaner baseline
- Identify whether resolution patterns are driven by systematic submitter behavior

### Exclusion Method

A resolution is excluded if:

1. `primary_reason = 'scv_rank_downgraded'`
2. The snapshot is in an affected month (Oct 2024, Jul 2025)
3. At least one SCV in that resolution was from the bulk downgrade submitter

### Additional Column

Both filtered views include an `excluded_bulk_downgrades` column showing how many resolutions were filtered out for that month. This provides transparency about the filtering impact.

### Setup Steps

Same as Charts 4 and 5, but connect to the `_filtered` views:

- `clinvar_curator.sheets_cvc_impact_monthly_filtered`
- `clinvar_curator.sheets_cvc_attribution_breakdown_filtered`

### When to Use Filtered vs Unfiltered

| Use Case                                    | Recommended View          |
|---------------------------------------------|---------------------------|
| Full picture of all resolutions             | Unfiltered (Charts 4 & 5) |
| Analyzing CVC impact vs organic trends      | Filtered                  |
| Understanding submitter behavior patterns   | Unfiltered                |
| Manuscript figures showing typical patterns | Filtered                  |
| Comparing monthly resolution rates          | Filtered                  |

---

## Chart 6: Batch Effectiveness

**View:** `sheets_cvc_batch_effectiveness`

**Purpose:** Compare effectiveness metrics across CVC batches.

### Setup Steps

1. Connect to `clinvar_curator.sheets_cvc_batch_effectiveness`
2. Select all data
3. Insert → Chart
4. Choose **Bar chart** or **Table**

### Key Metrics

| Metric | Description |
|--------|-------------|
| `resolution_rate_pct` | % of targeted variants that resolved |
| `flag_rate_pct` | % of submissions that resulted in flags |
| `days_since_submission` | Batch maturity (older batches have more time to show results) |

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
