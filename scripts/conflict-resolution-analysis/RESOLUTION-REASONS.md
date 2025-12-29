# Resolution Reason Taxonomy

This document describes the taxonomy of reasons used to explain why ClinVar variant conflicts are resolved or modified. The system distinguishes between **SCV-level reasons** (what caused the change) and **VCV-level outcomes** (effects of the change).

## Key Concepts

### SCV Reasons vs VCV Outcomes

- **SCV Reasons**: Changes to individual submissions (SCVs) that directly cause a conflict to resolve or modify. These are the *causes* of change.
- **VCV Outcomes**: Effects that manifest at the variant level (like outlier status changing or conflict type changing). These are *effects*, not causes.

Only SCV reasons are used for categorizing what drove a resolution or modification. VCV outcomes are tracked separately for informational purposes.

### Tier-Aware Reason Tracking

SCV-level reasons are tracked only for **contributing tier** SCVs:

- **Contributing tier**: SCVs at the rank tier that determines the VCV's classification
  - For 1-star/2-star VCVs: 1-star SCVs are contributing
  - For 0-star VCVs: 0-star SCVs are contributing
- **Lower tier**: SCVs at a rank tier lower than the conflict's determining tier (not tracked as reasons)

## SCV Reasons (Causes)

These are the reasons that explain what caused a conflict to resolve or be modified.

### For Resolutions

| Reason | Description | SCV Array Field |
|--------|-------------|-----------------|
| `reclassified` | Contributing SCV(s) changed classification | `scvs_reclassified_contributing` |
| `flagged` | ClinVar flagged a contributing SCV (rank changed to -3) | `scvs_flagged_contributing` |
| `removed` | Contributing SCV was withdrawn from ClinVar | `scvs_removed_contributing` |
| `rank_downgraded` | SCV was demoted out of contributing tier | `scvs_rank_downgraded` |
| `expert_panel` | Expert panel (3/4-star) SCV added, superseding the conflict | `scvs_added_higher_rank` |
| `higher_rank` | New 1-star SCV(s) supersede a 0-star conflict | `scvs_added_higher_rank` |

### For Modifications

All resolution reasons above, plus:

| Reason | Description | SCV Array Field |
|--------|-------------|-----------------|
| `added` | New SCV added to contributing tier | `scvs_added_contributing` |

**Note on `added`**: This reason only appears for modifications because when SCVs are added and a conflict resolves, a higher-priority reason (`expert_panel` or `higher_rank`) always takes precedence.

### Multi-Reason Format

When 2+ SCV reasons contribute to a change, we use `{primary}_multi` format:

| Reason | Description |
|--------|-------------|
| `reclassified_multi` | Reclassified was primary, with other SCV reasons |
| `flagged_multi` | Flagged was primary, with other SCV reasons |
| `removed_multi` | Removed was primary, with other SCV reasons |
| `added_multi` | Added was primary, with other SCV reasons |
| `rank_downgraded_multi` | Rank downgraded was primary, with other SCV reasons |
| `expert_panel_multi` | Expert panel was primary, with other SCV reasons |
| `higher_rank_multi` | Higher rank was primary, with other SCV reasons |

## VCV Outcomes (Effects)

These are effects that manifest at the VCV level. They are **not** used as reasons for categorizing resolutions or modifications because they are outcomes, not causes.

| Outcome | Description |
|---------|-------------|
| `outlier_status_changed` | Variant gained or lost outlier status |
| `conflict_type_changed` | Changed between clinsig and non-clinsig conflict |
| `vcv_rank_changed` | VCV rank tier changed (e.g., 0-star to 1-star) |

These outcomes appear in the underlying `primary_reason` field. In the `sheets_reason_combinations` views, they are **resolved to their underlying SCV reason** by looking up the `scv_reasons` array. For example:

- Most `outlier_status_changed` cases are caused by `scv_rank_downgraded` (the outlier SCV was demoted from the contributing tier, causing the variant to lose its outlier status)
- `conflict_type_changed` cases typically have `scv_reclassified` or `scv_added` as the underlying cause

Only when no SCV reason can be identified does the view fall back to `unknown`.

## Special Cases

### single_submitter_withdrawn

This is **not** a separate SCV reason. It's a context descriptor indicating that only one submitter existed on one side of the conflict. The underlying SCV reason (flagged/removed/reclassified) is what actually resolved the conflict.

In the `sheets_reason_combinations` views, `single_submitter_withdrawn` is mapped to the underlying SCV reason found in the `scv_reasons` array.

### expert_panel and higher_rank

These represent cases where new higher-ranked SCVs supersede the existing conflict:

- `expert_panel`: 3/4-star (expert panel) SCV added, which supersedes any 0-star or 1-star conflict
- `higher_rank`: 1-star SCV added to a 0-star conflict, superseding it

**Note**: `higher_rank` only applies to 0-star conflicts. For 1-star conflicts, only `expert_panel` can supersede them (there are no 2-star SCVs in ClinVar's ranking system).

## Visual Summary

```text
┌─────────────────────────────────────────────────────────────┐
│  SCV REASONS (Causes - used for categorization)             │
│                                                             │
│  Resolution + Modification:                                 │
│  ├── reclassified      - Contributing SCV reclassified      │
│  ├── flagged           - ClinVar flagged contributing SCV   │
│  ├── removed           - Contributing SCV withdrawn         │
│  ├── rank_downgraded   - SCV demoted from contributing tier │
│  ├── expert_panel      - Expert panel (3/4-star) added      │
│  └── higher_rank       - 1-star SCV supersedes 0-star       │
│                                                             │
│  Modification only:                                         │
│  └── added             - New SCV at contributing tier       │
├─────────────────────────────────────────────────────────────┤
│  MULTI-REASON FORMAT (2+ SCV reasons)                       │
│  └── {reason}_multi    - Primary reason with others         │
│      e.g., flagged_multi, reclassified_multi                │
├─────────────────────────────────────────────────────────────┤
│  VCV OUTCOMES (Effects - NOT used as reasons)               │
│  ├── outlier_status_changed                                 │
│  ├── conflict_type_changed                                  │
│  └── vcv_rank_changed                                       │
├─────────────────────────────────────────────────────────────┤
│  SPECIAL CASES                                              │
│  ├── single_submitter_withdrawn → maps to underlying reason │
│  ├── VCV outcomes → resolved to underlying SCV reason       │
│  │   (outlier_status_changed, conflict_type_changed, etc.)  │
│  └── unknown → rare fallback when no SCV reason found       │
└─────────────────────────────────────────────────────────────┘

Note: higher_rank only applies to 0-star conflicts being
superseded by 1-star SCVs. For 1-star conflicts, only
expert_panel can supersede (no 2-star SCVs exist in ClinVar).

Note: added only appears for modifications because when SCVs
are added and a conflict resolves, expert_panel or higher_rank
takes precedence.
```

## Data Sources

### Tables with Reason Data

| Table/View | Key Fields |
|------------|------------|
| `conflict_resolution_analytics` | `primary_reason`, `change_status`, `change_category` |
| `conflict_vcv_change_detail` | `primary_reason`, `scv_reasons`, `vcv_change_status` |
| `monthly_conflict_vcv_scv_summary` | SCV arrays (contributing tier), count fields |
| `sheets_change_reasons` | `primary_reason` with counts for charting |
| `sheets_change_reasons_wide` | Reasons as columns for stacked charts |
| `sheets_reason_combinations` | SCV reasons with `_multi` suffix for multi-reason changes |
| `sheets_reason_combinations_wide` | SCV reasons as columns for stacked charts |

### Querying SCVs for a Specific Reason

To get the list of SCVs associated with each reason for resolved variants:

```sql
SELECT
  d.variation_id,
  d.conflict_type,
  d.outlier_status,
  d.primary_reason,
  -- Contributing tier arrays
  ARRAY_TO_STRING(s.scvs_added_contributing, ', ') AS scvs_added,
  ARRAY_TO_STRING(s.scvs_removed_contributing, ', ') AS scvs_removed,
  ARRAY_TO_STRING(s.scvs_flagged_contributing, ', ') AS scvs_flagged,
  ARRAY_TO_STRING(s.scvs_reclassified_contributing, ', ') AS scvs_reclassified,
  ARRAY_TO_STRING(s.scvs_rank_downgraded, ', ') AS scvs_rank_downgraded
FROM `clinvar_ingest.conflict_vcv_change_detail` d
LEFT JOIN `clinvar_ingest.monthly_conflict_vcv_scv_summary` s
  ON s.variation_id = d.variation_id
  AND s.snapshot_release_date = d.snapshot_release_date
WHERE d.snapshot_release_date = DATE '2024-10-09'  -- Change as needed
  AND d.vcv_change_status = 'resolved'
ORDER BY d.primary_reason, d.variation_id;
```

### Querying SCV Reason Trends

To see the distribution of SCV reasons over time:

```sql
SELECT
  snapshot_month,
  scv_reason,
  change_status,
  SUM(variant_count) AS total_variants
FROM `clinvar_ingest.sheets_reason_combinations`
GROUP BY snapshot_month, scv_reason, change_status
ORDER BY snapshot_month, change_status, total_variants DESC;
```

## Related Documentation

- [DESIGN-scv-level-tracking.md](DESIGN-scv-level-tracking.md) - Design document for SCV-level tracking
- [GOOGLE-SHEETS-SETUP.md](GOOGLE-SHEETS-SETUP.md) - How to build dashboards with reason charts
- [README.md](README.md) - Pipeline overview and table descriptions
- [06-resolution-modification-analytics.sql](06-resolution-modification-analytics.sql) - Primary reason assignment logic
- [05-monthly-conflict-scv-changes.sql](05-monthly-conflict-scv-changes.sql) - SCV change tracking and reason arrays
