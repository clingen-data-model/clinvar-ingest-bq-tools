# Historical ClinVar Data Schema Documentation

This document describes the schema for three key tables from the historical ClinVar dataset (`clinvar_2019_06_01_v0`), which contains data extracted from ClinVar RCV XML files prior to July 2019.

## Important Notes

- **release_date**: All tables contain a `release_date` column indicating the date of the RCV XML ClinVar file from the [NCBI FTP archive](https://ftp.ncbi.nlm.nih.gov/pub/clinvar/xml/RCV_xml_old_format/archive/).

- **Data Limitations**: These tables do not include disease/condition information or aggregated RCV variant-disease classifications. The `scv_summary` table is the source of all submissions from historical datasets prior to July 2019, when ClinVar first started producing variant-level aggregate (VCV) XML files.

- **Missing Submitter Data**: Some submitter names could not be recovered from historical records and use placeholder values like `<OrgID 99999>`.

---

## Table: submitter

Submitter organization information for each release.

| Column | Type | Description |
|--------|------|-------------|
| `release_date` | DATE | Date of the ClinVar RCV XML release |
| `id` | STRING | Unique submitter organization identifier |
| `current_name` | STRING | Current full name of the submitting organization (may be placeholder if unavailable) |
| `current_abbrev` | STRING | Abbreviated organization name |
| `org_category` | STRING | Organization category classification |

---

## Table: variation

Variant information for each release. This historical table has a minimal schema compared to modern ClinVar datasets.

| Column | Type | Description |
|--------|------|-------------|
| `release_date` | DATE | Date of the ClinVar RCV XML release |
| `id` | STRING | ClinVar variation identifier |
| `name` | STRING | Human-readable variant name/description (e.g., "NM_000059.3(BRCA2):c.5946del (p.Ser1982fs)")

---

## Table: scv_summary

Summary of all SCV (clinical assertion) submissions with normalized classification fields.

| Column | Type | Description |
|--------|------|-------------|
| `release_date` | DATE | Date of the ClinVar RCV XML release |
| `id` | STRING | SCV accession identifier (e.g., SCV000012345) |
| `version` | INT64 | SCV version number |
| `variation_id` | STRING | Reference to the associated variation |
| `local_key` | STRING | Submitter's local identifier for the submission |
| `last_evaluated` | DATE | Date the classification was last evaluated by the submitter |
| `rank` | INT64 | Normalized numeric representation of review status (higher = more stars/confidence) |
| `review_status` | STRING | Original ClinVar review status text (e.g., "criteria provided, single submitter") |
| `clinvar_stmt_type` | STRING | ClinVar statement type determining aggregation compatibility (see below) |
| `cvc_stmt_type` | STRING | ClinGen Variant Curation (CVC) statement type classification |
| `submitted_classification` | STRING | Original classification text as submitted |
| `classif_type` | STRING | Normalized classification type derived from submitted_classification |
| `significance` | INT64 | Pathogenicity significance level: `0` = B/LB (benign), `1` = VUS (uncertain), `2` = P/LP (pathogenic) |
| `submitter_id` | STRING | Reference to the submitting organization |
| `submission_date` | DATE | Date the submission was made to ClinVar |

---

## Understanding Statement Types and Conflict Analysis

### clinvar_stmt_type

The `clinvar_stmt_type` column determines which submission records are "comparable" or "aggregatable". ClinVar only aggregates submissions with the same `clinvar_stmt_type`.

- **`path`** (pathogenicity): The primary statement type subject to conflict analysis. ClinVar aggregates these based on their classification level of significance.
- **Other types**: Considered "special" statement types that do not undergo conflict analysis.

### Significance Values

The `significance` column indicates the pathogenicity direction:

| Value | Meaning | Classifications |
|-------|---------|-----------------|
| `0` | Not significant | Benign (B), Likely Benign (LB) |
| `1` | Uncertain significance | VUS (Variant of Uncertain Significance) |
| `2` | Significant | Pathogenic (P), Likely Pathogenic (LP) |

### Conflict Detection

ClinVar aggregates statements with:
- The same `clinvar_stmt_type`
- The same review status (or `rank`)

If the `significance` values differ among aggregated statements, a **conflict in pathogenicity** exists.

---

## Normalized Column Pairs

The `scv_summary` table contains normalized paired columns for easier analysis:

| Original Column | Normalized Column | Description |
|-----------------|-------------------|-------------|
| `review_status` | `rank` | Text review status normalized to numeric rank |
| `submitted_classification` | `classif_type` | Free-text classification normalized to standard type |

---

## Data Source

These tables were derived from historical RCV XML files available at:
- https://ftp.ncbi.nlm.nih.gov/pub/clinvar/xml/RCV_xml_old_format/archive/

For detailed SCV and RCV content beyond these summary fields, the original XML files would need to be consulted. Gene information can be provided separately if needed.
