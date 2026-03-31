# Tracker Report Update

The tracker report update scripts generate the variation tracker reports consumed by curation teams (VCEPs and GenomeConnect). These reports combine temporal summary data with report configuration (loaded from Google Sheets-backed external tables) to produce detailed per-report, per-variation tracking data.

## Orchestrator

**`tracker-report-update-proc.sql`** defines `clinvar_ingest.tracker_report_update()`, which calls three procedures in sequence:

1. `variation_tracker.report_variation(null)` -- Refresh the variation list for all active reports
2. `variation_tracker.tracker_reports_rebuild(null)` -- Rebuild all active tracker reports
3. `variation_tracker.gc_tracker_report_rebuild(null)` -- Rebuild GenomeConnect tracker reports

Passing `null` to each procedure causes it to process all active reports.

## Scripts

| # | File | Procedure/Object Created | Description |
|---|------|--------------------------|-------------|
| 00 | `00-initialize-tracker-tables.sql` | Multiple tables | Creates the tracker output tables: `gc_variation`, `gc_case`, and supporting structures in the `variation_tracker` dataset |
| 01 | `01-report-variation-proc.sql` | `variation_tracker.report_variation()` | Refreshes the `report_variation` table by collecting all variations associated with a report's submitters and genes from the temporal SCV data |
| 02 | `02-tracker-reports-rebuild-proc.sql` | `variation_tracker.tracker_reports_rebuild()` | The main report builder -- uses a batch-first architecture to build shared temp tables once, then generates per-report tracker data with SCV priorities, alerts, and classification summaries |
| 03 | `03-gc-tracker-report-proc.sql` | `variation_tracker.gc_tracker_report_rebuild()` | Builds GenomeConnect-specific tracker reports including `gc_variation` and `gc_case` tables with VCEP cross-references and case-level observation data |
| -- | `tracker-report-update-proc.sql` | `clinvar_ingest.tracker_report_update()` | Orchestrator that calls all three procedures |

## Execution Order

```
00-initialize-tracker-tables (manual, run once)
    |
01-report-variation (identifies which variations belong to which reports)
    |
02-tracker-reports-rebuild (builds the main tracker report data)
    |
03-gc-tracker-report (builds GenomeConnect-specific reports)
```

## Report Architecture

### Report Variation (Step 01)

Collects variations for each active report by:

- Finding all variations submitted by the report's submitters (from `clinvar_scvs`)
- Adding all variations associated with the report's gene list (from `clinvar_single_gene_variations`)
- Adding any explicitly listed variants from the report configuration

### Tracker Reports Rebuild (Step 02)

Uses a batch-first architecture to avoid redundant scans of large temporal tables:

1. **Batch Phase** -- Pre-materializes shared temp tables (`_all_releases`, `_scv_ranges`, `_scv_priorities`, `_alerts`) once for all reports
2. **Per-Report Phase** -- Loops through active report IDs, filtering the pre-built temp tables and merging with report-specific configuration
3. Produces SCV priority rankings, out-of-date alerts, and classification change tracking

### GC Tracker Report (Step 03)

Builds GenomeConnect-specific output by:

- Cross-referencing GC submitter SCVs with VCEP classifications
- Parsing observation-level data (samples, methods, traits) from the `gc_scv_obs` table
- Generating `gc_variation` (variant-level summary) and `gc_case` (case-level detail) tables

!!! note "Report configuration from Google Sheets"
    The report definitions (`report`, `report_submitter`, `report_gene`, `report_option`, `report_variant_list`) are loaded from Google Sheets via external tables. Changes to report configuration take effect after running `refresh_external_table_copies` and then `tracker_report_update`.

## Key Dependencies

**Reads from:**

- `clinvar_ingest.clinvar_scvs` -- Temporal SCV data
- `clinvar_ingest.clinvar_sum_scvs` -- Summarized SCV data
- `clinvar_ingest.clinvar_sum_vsp_rank_group_change` -- Rank group changes
- `clinvar_ingest.clinvar_sum_vsp_top_rank_group_change` -- Top rank group changes
- `clinvar_ingest.clinvar_sum_variation_group_change` -- Variation-level changes
- `clinvar_ingest.clinvar_variations` -- Temporal variation records
- `clinvar_ingest.all_releases()` -- Release metadata
- `variation_tracker.report`, `report_submitter`, `report_gene`, `report_option` -- Report configuration
- `{schema}.scv_summary`, `{schema}.gc_scv_obs` -- Current release data (for GC reports)

**Writes to:**

- `variation_tracker.report_variation` -- Variation-to-report mappings
- `variation_tracker.tracker_report_*` -- Tracker report output tables
- `variation_tracker.gc_variation` -- GC variant-level tracker
- `variation_tracker.gc_case` -- GC case-level tracker
