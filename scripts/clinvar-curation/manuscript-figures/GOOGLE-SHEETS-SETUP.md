# Manuscript Figures - Google Sheets Setup Guide

This guide explains how to set up Google Sheets dashboards using BigQuery Data Connector sheets to visualize the datasets produced by the manuscript figure scripts. Each figure in the forthcoming ClinVar Curation manuscript is backed by a query in this folder, with the results connected to Google Sheets for charting.

---

## Dashboard Overview (README Sheet)

Use the table below as a README sheet in your Google Sheets file. Replace `[Link]` with actual hyperlinks to each chart's sheet.

| Figure | Name | View | Script | Chart Type | Link |
|--------|------|------|--------|------------|------|
| 1a | ClinVar Landscape (Conflict Count) | `clinvar_ingest.manuscript_clinvar_landscape` | `01-clinvar-landscape.sql` | Scatter Plot | [Link] |
| 1b | ClinVar Landscape (Conflict Rate) | `clinvar_ingest.manuscript_clinvar_landscape` | `01-clinvar-landscape.sql` | Scatter Plot | [Link] |

---

## Prerequisites

1. Access to BigQuery with the `clinvar_ingest` dataset (project: `clingen-dev`)
2. Google Sheets with Connected Sheets enabled (requires Google Workspace account)
3. Manuscript figure queries have been run to populate the source tables/views

## Connecting BigQuery to Google Sheets

1. Open a new Google Sheet
2. Go to **Data** > **Data connectors** > **Connect to BigQuery**
3. Select the project `clingen-dev`
4. Navigate to the `clinvar_ingest` dataset
5. Select the table or view, or use **Custom Query** to paste the SQL directly

---

## Figure 1: ClinVar Landscape

**View:** `clinvar_ingest.manuscript_clinvar_landscape`
**Script:** `01-clinvar-landscape.sql`

**Purpose:** Visualizes the ClinVar Germline Variant Pathogenicity Classification landscape across GenCC Definitive/Strong/Moderate (DSM) genes. Each gene is plotted as a point to show the relationship between submission volume and clinically significant conflicts. Two versions of the scatter plot show different perspectives: absolute conflict count (1a) and conflict rate as a percentage of total variants (1b).

### Data Source

Connect to the view `clinvar_ingest.manuscript_clinvar_landscape` in BigQuery. The view is created by running `01-clinvar-landscape.sql`. Both charts use the same extracted data.

### Setup Steps (shared)

1. Connect to `clinvar_ingest.manuscript_clinvar_landscape` via Data Connector
2. Click **Extract** to pull the data into a regular sheet
3. Create two charts from the same extracted data (see 1a and 1b below)

### Showing Gene Labels

Gene labels can be shown selectively to avoid clutter on both charts:

1. **Option A - Top N genes only**: Filter the extracted data to the top 20-30 genes by `clinsig_scv_count`, then enable point labels
2. **Option B - On hover**: Google Sheets scatter charts show data on hover by default
3. **Option C - Manual annotations**: Add text boxes for notable genes (e.g., BRCA1, BRCA2, TP53)

To enable point labels:
1. In Chart Editor > **Setup** tab
2. Set **Label** to `gene_symbol`
3. In **Customize** > **Series**, check **Data labels**

### Shared Customize Tab Settings

1. **Series**:
   - Point size: 4-6px
   - Point color: #4285F4 (blue)
   - Point opacity: 70% (helps when dots overlap)
2. **Gridlines and ticks**:
   - X-axis: Consider logarithmic scale if data range is wide
3. **Legend**: None (single series)

---

### Figure 1a: Conflict Count

**Chart type:** Scatter plot showing absolute number of clinically significant conflict variants per gene.

#### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Scatter |
| X-axis | `total_scvs` |
| Y-axis | `total_clinsig_conflict_variants` |
| Point labels | `gene_symbol` (optional) |

#### Axis Configuration

| Axis | Label | Notes |
|------|-------|-------|
| X-axis | Total Pathogenicity SCVs | Log scale recommended |
| Y-axis | Clinically Significant Conflict Variants | Count of variants with agg_sig_type >= 5 |

#### Chart & Axis Titles

- Chart title: "ClinVar Conflict Burden by Gene"
- Chart subtitle: "GenCC Definitive/Strong/Moderate Genes"
- X-axis title: "Total Pathogenicity SCVs"
- Y-axis title: "Clinically Significant Conflict Variants"

#### Key Columns Used

| Column | Chart Role | Description |
|--------|-----------|-------------|
| `gene_symbol` | Label | Gene symbol (e.g., BRCA1) |
| `total_scvs` | X-axis | All pathogenicity SCVs for this gene |
| `total_clinsig_conflict_variants` | Y-axis | Variants with agg_sig_type >= 5 |

#### Interpretation

- **Upper-right quadrant**: Genes with many submissions AND many conflict variants (high-volume, high absolute conflict burden)
- **Lower-right quadrant**: Genes with many submissions but few conflict variants (high-volume, concordant)
- **Upper-left quadrant**: Genes with few submissions but many conflicts (unexpected — worth investigating)
- **Lower-left quadrant**: Genes with few submissions and few conflicts

---

### Figure 1b: Conflict Rate

**Chart type:** Scatter plot showing the percentage of variants in clinically significant conflict per gene.

#### Chart Configuration

| Setting | Value |
|---------|-------|
| Chart type | Scatter |
| X-axis | `total_scvs` |
| Y-axis | `clinsig_conflict_pct` |
| Point labels | `gene_symbol` (optional) |

#### Axis Configuration

| Axis | Label | Notes |
|------|-------|-------|
| X-axis | Total Pathogenicity SCVs | Log scale recommended |
| Y-axis | Clinically Significant Conflict Rate (%) | `total_clinsig_conflict_variants / total_variants * 100` |

#### Chart & Axis Titles

- Chart title: "ClinVar Conflict Rate by Gene"
- Chart subtitle: "GenCC Definitive/Strong/Moderate Genes"
- X-axis title: "Total Pathogenicity SCVs"
- Y-axis title: "% Variants in Clinically Significant Conflict"

#### Key Columns Used

| Column | Chart Role | Description |
|--------|-----------|-------------|
| `gene_symbol` | Label | Gene symbol (e.g., BRCA1) |
| `total_scvs` | X-axis | All pathogenicity SCVs for this gene |
| `clinsig_conflict_pct` | Y-axis | `total_clinsig_conflict_variants / total_variants * 100` |

#### Interpretation

- **Upper-right quadrant**: Genes with many submissions AND a high conflict rate (high-volume, contentious)
- **Lower-right quadrant**: Genes with many submissions but a low conflict rate (high-volume, concordant)
- **Upper-left quadrant**: Genes with few submissions but a high conflict rate (low-volume, contentious)
- **Lower-left quadrant**: Genes with few submissions and low conflict rate

---

### Additional Scatter Plot Variants

The same dataset can support alternative views:

| Variant | X-axis | Y-axis | Insight |
|---------|--------|--------|---------|
| Conflict burden | `total_clinsig_variants` | `total_clinsig_conflict_variants` | Which genes have the most conflicting variants relative to their P/LP count? |
| Concordance rate | `total_scvs` | `concordant_clinsig_variants / total_clinsig_variants * 100` | Which high-volume genes have the highest P/LP concordance? |

---

## Data Refresh

- **Source**: BigQuery `clinvar_ingest` dataset
- **Refresh frequency**: After each ClinVar release (~monthly)
- **To refresh**: Data > Data connectors > Refresh options

---

## Tips for Manuscript Figures

### Export Quality

- Use **Download** > **PNG** or **SVG** from the chart menu for publication-quality exports
- For higher resolution, increase chart size before exporting
- Consider using Google Slides for final figure assembly (copy chart > paste into slide > export)

### Consistent Styling

Maintain consistent styling across all manuscript figures:

| Element | Standard |
|---------|----------|
| Font | Arial or Helvetica |
| Point color (primary) | #4285F4 (blue) |
| Point color (highlight) | #EA4335 (red) |
| Axis label size | 12pt |
| Title size | 14pt |
| Grid lines | Light gray (#E0E0E0) |

### Reproducibility

All figures are fully reproducible from the SQL scripts in this folder. Record the ClinVar release date used for each figure run (returned as `release_date` in query output) to ensure manuscript figures can be regenerated.
