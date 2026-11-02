# ClinVar Curation

The ClinVar Curation (CvC) SQL no longer lives in this repository. It moved from `scripts/clinvar-curation/` to [`bigquery/curator/`](https://github.com/clingen-data-model/clinvar-curation-input-tool/tree/main/bigquery/curator) in the `clinvar-curation-input-tool` repository, which is now its single home.

## What Moved

| Moved content | Location in `bigquery/curator/` |
|---------------|---------------------------------|
| CvC tables, views and table functions | `00-initialize-cvc-tables.sql` through `05-cvc-outlier-clinsig-func.sql` |
| Impact analysis scripts and guides | `cvc-impact-analysis/` |
| Manuscript figure queries | `manuscript-figures/` |
| Ad-hoc reports | `cvc-annotation-history-report.sql`, `cvc-submitted-outcomes-stats.sql` |

See the [`bigquery/curator` README](https://github.com/clingen-data-model/clinvar-curation-input-tool/blob/main/bigquery/curator/README.md) for the layout and deployment steps.

!!! note "Deployment"
    The CI/CD workflow in this repository no longer deploys the CvC functions, because it only runs `-func.sql` and `-proc.sql` files under `scripts/`. Deploy them from `bigquery/curator/` with its `deploy.sh`.

## What Stays Here

The CvC SQL depends on this repository one way. Changes to these objects can affect it:

- `clinvar_ingest.clinvar_scvs` -- Temporal SCV data
- `clinvar_ingest.clinvar_sum_scvs` -- Summarized SCV data
- `clinvar_ingest.clinvar_sum_vsp_rank_group_change` -- Rank group changes
- `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` -- Top rank group changes
- `clinvar_ingest.release_on()` -- Release date lookup
- `variation_tracker.report_submitter` -- Report submitter configuration

The Google Sheets external table definitions for CvC annotations, reviews, submissions and batches are still in [`scripts/external-table-setup/`](external-table-setup.md).
