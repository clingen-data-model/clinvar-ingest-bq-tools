# Schema Differences: Pre-2019-07-01 vs 2019-07-01+ Exports

## Overview

Both exports produce GZIP-compressed JSON shards to GCS under `gs://clingen-public/upenn/`. They share the same set of output columns but differ in their source tables and how certain fields are derived.

## Source Tables

| Export | Source |
|---|---|
| **pre_2019_07_01** | `clingen-stage.clinvar_2019_06_01_v0.scv_summary` joined with `.submitter` |
| **2019_07_01** | `clingen-dev.clingen_stage.historic_voi_scv_copy` (single pre-joined table) |

## Key Differences

### Columns present only in the pre-2019 export
- **`release_date`** — the per-record release date from the source snapshot. Not included in the post-2019 export.

### Columns present only in the post-2019 export
- **`start_release_date`** — first release date the SCV appeared.
- **`end_release_date`** — last release date the SCV was present.
- **`deleted_release_date`** — release date the SCV was removed.
- **`deleted_count`** — number of times the SCV was deleted.

In the pre-2019 export these four fields (`start_release_date`, `end_release_date`, `deleted_release_date`, `deleted_count`) are projected as `NULL` placeholders to keep the schema compatible.

### Column aliasing
The pre-2019 export renames several source columns to match the post-2019 schema:
- `s.cvc_stmt_type` → `rpt_stmt_type`
- `s.significance` → `clinsig_type`
- `sub.current_name` → `submitter_name`
- `sub.current_abbrev` → `submitter_abbrev`
- `CONCAT(s.id, '.', CAST(s.version AS STRING))` → `full_scv_id` (computed)
- `classification_label` and `classification_abbrev` are cast as `NULL` (not available in the older dataset)

The post-2019 export selects these columns directly by their final names, indicating the `historic_voi_scv_copy` table already has the normalized schema.

### Ordering
- **pre_2019_07_01** — explicitly ordered by `variation_id, id, release_date`.
- **2019_07_01** — no ordering specified.
