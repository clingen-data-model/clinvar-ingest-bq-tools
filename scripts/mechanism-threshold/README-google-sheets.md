# Mechanism Threshold Analysis - Google Sheets Guide

This document explains the data available in the Mechanism Threshold Google Sheets, which help analyze ClinVar variant evidence for genes with dosage sensitivity curations.

---

## Sheet 1: Per-Gene Variant Counts

**View Name:** `mechanism_threshold_by_gene_view`

This sheet shows variant counts for each gene that has a ClinGen dosage sensitivity curation.

### What's Included

Only variants that meet ALL of these criteria:
- Associated with a single gene (not multi-gene variants)
- Smaller than 1,000 base pairs (excludes large structural variants)
- Have a germline disease classification in ClinVar

### Column Definitions

| Column | Description |
|--------|-------------|
| **release_date** | The ClinVar release date for this data |
| **gene_symbol** | The gene name (e.g., BRCA1, TP53) |
| **gene_id** | ClinVar's internal gene identifier |
| **hi_score** | Haploinsufficiency score from ClinGen Dosage (0-3, or special values) |
| **ts_score** | Triplosensitivity score from ClinGen Dosage (0-3, or special values) |
| **total_variants** | Total number of variants in ClinVar for this gene |
| **one_star_variants** | Variants with 1-star or higher review status |
| **plp_variants** | Variants classified as Pathogenic or Likely Pathogenic (P/LP) |
| **plp_one_star_variants** | P/LP variants with 1-star or higher review status |
| **plof_variants** | Predicted Loss-of-Function variants (see below) |
| **plof_one_star_variants** | pLOF variants with 1-star or higher review status |
| **plp_plof_variants** | Variants that are both P/LP AND pLOF |
| **plp_one_star_plof_variants** | P/LP + pLOF variants with 1-star or higher review status |
| **sample_variation_ids** | Up to 10 example ClinVar Variation IDs (for reference) |

### Understanding pLOF (Predicted Loss-of-Function)

A variant is considered pLOF if its molecular consequence is one of:
- **Nonsense** - Creates a premature stop codon
- **Frameshift** - Shifts the reading frame
- **Splice donor variant** - Disrupts the splice donor site
- **Splice acceptor variant** - Disrupts the splice acceptor site

### Understanding Star Ratings

ClinVar's review status star ratings indicate the level of review:
- **0 stars** - No assertion criteria provided, or conflicting interpretations
- **1 star** - Single submitter with assertion criteria
- **2 stars** - Two or more submitters with assertion criteria, no conflicts
- **3 stars** - Reviewed by expert panel
- **4 stars** - Practice guideline

---

## Sheet 2: Summary Statistics

**View Name:** `mechanism_threshold_summary_view`

This sheet provides aggregated statistics across all genes, grouped by dosage sensitivity scores.

### Column Definitions

| Column | Description |
|--------|-------------|
| **release_date** | The ClinVar release date for this data |
| **report_type** | The grouping category (see below) |
| **score_category** | The specific score value within that category |
| **gene_count** | Number of genes in this category |
| **total_variants** | Sum of all variants across genes in this category |
| **one_star_variants** | Sum of 1-star+ variants |
| **plp_variants** | Sum of P/LP variants |
| **plp_one_star_variants** | Sum of P/LP 1-star+ variants |
| **plof_variants** | Sum of pLOF variants |
| **plof_one_star_variants** | Sum of pLOF 1-star+ variants |
| **plp_plof_variants** | Sum of P/LP + pLOF variants |
| **plp_one_star_plof_variants** | Sum of P/LP + pLOF + 1-star+ variants |
| **avg_variants_per_gene** | Average total variants per gene |
| **avg_plp_1star_plof_per_gene** | Average P/LP 1-star pLOF variants per gene |

### Report Types

The summary is broken down into three report types:

1. **HI Score Summary** - Grouped by Haploinsufficiency score
2. **TS Score Summary** - Grouped by Triplosensitivity score
3. **Overall Total** - Combined totals across all dosage genes

### Understanding Dosage Scores

ClinGen Dosage Sensitivity scores range from 0-3:

| Score | Meaning |
|-------|---------|
| **3** | Sufficient evidence for dosage sensitivity |
| **2** | Some evidence for dosage sensitivity |
| **1** | Little evidence for dosage sensitivity |
| **0** | No evidence for dosage sensitivity |
| **40** | Dosage sensitivity unlikely |
| **30** | Gene associated with autosomal recessive phenotype |

---

## Key Metrics for Threshold Analysis

The most relevant column for mechanism curation thresholds is typically:

**`plp_one_star_plof_variants`** - This represents the count of high-confidence pathogenic loss-of-function variants (P/LP classification + pLOF mechanism + at least 1-star review status).

This metric helps establish whether a gene has sufficient evidence of pathogenic loss-of-function variants to support mechanism curation decisions.

---

## Data Refresh

The data shown is from the most recent ClinVar release that has been processed. The `release_date` column indicates which release the data represents.

To view the ClinVar page for a specific variant, use the variation IDs in the `sample_variation_ids` column:
```
https://www.ncbi.nlm.nih.gov/clinvar/variation/[VARIATION_ID]
```
