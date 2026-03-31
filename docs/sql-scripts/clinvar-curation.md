# ClinVar Curation

The `scripts/clinvar-curation/` directory contains SQL scripts that support the ClinVar Variant Curation (CVC) workflow. This includes table initialization, annotation tracking via table functions, impact analysis, and outlier detection. The CVC workflow allows curators to flag and track clinical significance outliers in ClinVar submissions.

## Core Scripts

| # | File | Object Created | Description |
|---|------|----------------|-------------|
| 00 | `00-initialize-cvc-tables.sql` | Multiple tables and views | Creates CVC infrastructure tables (`cvc_clinvar_reviews`, `cvc_clinvar_submissions`, `cvc_clinvar_batches`) and the `cvc_annotations_base_mv` materialized view in the `clinvar_curator` dataset |
| 01 | `01-cvc-baseline-annotations-func.sql` | `clinvar_curator.cvc_baseline_annotations()` | Table function that returns baseline annotations filtered by scope (e.g., "REVIEWED", "SUBMITTED"), joining annotation data with review status and batch information |
| 02 | `02-cvc-annotations-func.sql` | `clinvar_curator.cvc_annotations()` | Table function that enriches baseline annotations with SCV temporal data (statement type, rank, classification type) and tracks current vs. original SCV states |
| 03 | `03-cvc-submitter-annotations-func.sql` | `clinvar_curator.cvc_submitter_annotations()` | Table function that aggregates annotation data per submitter, counting flagging candidates, outdated SCVs, and resolved annotations |
| 04 | `04-cvc-annotations-impact-func.sql` | `clinvar_curator.cvc_annotations_impact()` | Table function that analyzes the impact of CVC-submitted annotations by tracking whether flagged variations have changed classification after submission |
| 05 | `05-cvc-outlier-clinsig-func.sql` | `clinvar_curator.cvc_outlier_clinsig()` | Table function that identifies clinical significance outliers -- SCVs where the outlier percentage is at or below 33% of the top rank group |
| -- | `cvc-submitted-outcomes-stats.sql` | Ad-hoc query | Analysis query for submitted annotation outcomes |
| -- | `00-initialize-scheduled-jobs.sh` | Shell script | Sets up BigQuery scheduled jobs for CVC refresh operations |

!!! note "Table functions vs. procedures"
    The CVC scripts use BigQuery **table functions** (`CREATE OR REPLACE TABLE FUNCTION`) rather than stored procedures. This means they return result sets that can be queried directly with `SELECT * FROM function_name(args)` rather than writing to tables.

## CVC Impact Analysis Subdirectory

The `cvc-impact-analysis/` subdirectory contains scripts for analyzing the outcomes and impact of CVC curation batches:

| # | File | Description |
|---|------|-------------|
| 00 | `00-cvc-batch-enriched-view.sql` | Creates a view enriching batch data with accepted dates and grace period end dates |
| 01 | `01-cvc-submitted-variants.sql` | Tracks all CVC-submitted SCVs with outcomes and batch timelines |
| 02 | `02-cvc-conflict-attribution.sql` | Attributes conflict resolutions to CVC curation vs. organic changes |
| 03 | `03-cvc-impact-analytics.sql` | Aggregated impact analytics across batches |
| 04 | `04-flagging-candidate-outcomes.sql` | Tracks outcomes of flagging candidate annotations |
| 05 | `05-version-bump-detection.sql` | Detects SCV version bumps that may indicate submitter responses |
| 06 | `06-version-bump-flagging-intersection.sql` | Cross-references version bumps with flagging activity |
| 07 | `07-resubmission-candidates.sql` | Identifies annotations that are candidates for resubmission |

The `00-run-cvc-impact-analysis.sh` script orchestrates running these analyses in order.

## Manuscript Figures Subdirectory

The `manuscript-figures/` subdirectory contains queries that generate data for publication figures:

| File | Description |
|------|-------------|
| `01-clinvar-landscape.sql` | ClinVar landscape overview data |
| `02-submitter-landscape.sql` | Submitter landscape analysis |
| `03-flagged-scv-by-consequence.sql` | Flagged SCVs broken down by consequence group |

## Key Dependencies

**Reads from:**

- `clinvar_curator.cvc_annotations_base_mv` -- Materialized view of annotation data
- `clinvar_curator.cvc_clinvar_reviews` -- Review tracking
- `clinvar_curator.cvc_clinvar_submissions` -- Submission tracking
- `clinvar_curator.cvc_clinvar_batches` -- Batch tracking
- `clinvar_ingest.clinvar_scvs` -- Temporal SCV data
- `clinvar_ingest.clinvar_sum_scvs` -- Summarized SCV data
- `clinvar_ingest.clinvar_sum_vsp_rank_group_change` -- Rank group changes
- `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` -- Top rank group changes
- `clinvar_ingest.release_on()` -- Release date lookup
- `variation_tracker.report_submitter` -- Report submitter configuration

**Data sources (external):**

- Google Sheets-backed tables for annotation data, reviews, submissions, and batches (loaded via external table setup)
