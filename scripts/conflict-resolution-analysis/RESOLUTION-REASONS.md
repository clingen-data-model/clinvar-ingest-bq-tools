# Resolution Reason Taxonomy

This document describes the taxonomy of reasons used to explain why ClinVar variant conflicts are resolved or modified. Each conflicting variant (VCV) that changes status receives a `primary_reason` for aggregation, while all contributing factors are captured in the `scv_reasons` array.

## Tier-Aware Reason Tracking

**Important**: SCV-level reasons are tracked separately for **contributing tier** SCVs vs **lower tier** SCVs.

- **Contributing tier**: SCVs at the rank tier that determines the VCV's classification
  - For 1-star/2-star VCVs: 1-star SCVs are contributing
  - For 0-star VCVs: 0-star SCVs are contributing
- **Lower tier**: SCVs at a rank tier lower than the conflict's determining tier
  - For 1-star VCV conflicts: 0-star SCVs are "lower tier"

Contributing tier reasons have **high priority** in the primary_reason assignment because they directly impact the conflict. Lower tier reasons are **informational** and have lowest priority.

## Reason Categories

The resolution reasons fall into distinct categories based on how they're derived and whether they're tied to specific SCVs.

### 1. SCV-Specific Reasons (Contributing Tier)

These reasons are tied to individual SCV changes at the **contributing tier** and have associated `scv_ids` that can be queried to see exactly which submissions changed.

| Reason | Description | SCV Array Field | Applies To |
|--------|-------------|-----------------|------------|
| `scv_flagged` | ClinVar flagged a contributing SCV (rank changed to -3) | `scvs_flagged_contributing` | Resolution, Modification |
| `scv_removed` | Contributing SCV was withdrawn from ClinVar | `scvs_removed_contributing` | Resolution, Modification |
| `scv_reclassified` | Contributing SCV changed classification | `scvs_reclassified_contributing` | Resolution, Modification |
| `scv_added` | New SCV added to contributing tier | `scvs_added_contributing` | Modification only |
| `scv_rank_downgraded` | SCV was demoted out of contributing tier (excludes flagged SCVs) | `scvs_rank_downgraded` | Resolution, Modification |

These are the most impactful reasons because they affect SCVs that determine the VCV's classification.

**Note on `scv_added`**: This reason only applies to modifications because when SCVs are added and a conflict resolves, a higher-priority reason (like `expert_panel_added` or `higher_rank_scv_added`) always takes precedence.

**Note**: `scv_rank_downgraded` excludes SCVs that were flagged (rank changed to -3), since flagging is tracked separately via `scv_flagged`. This prevents double-counting when an SCV is flagged.

**Note on Co-occurring Changes**: An SCV can have multiple changes simultaneously (e.g., both a classification change AND a rank change). The `scv_change_status` field captures only the primary change type, but the system uses boolean flags (`has_classification_change`, `has_rank_change`) to detect all co-occurring changes.

**Note on Lower-Tier Reasons**: Lower-tier SCV changes (changes to SCVs below the contributing tier) are not tracked as reasons because they don't impact the VCV's classification. Only contributing tier SCV changes are included in `scv_reasons` and `primary_reason` assignment.

### 2. VCV-Level Derived Reasons

These reasons are inferred from changes in the VCV's overall state, often involving new SCVs that supersede the existing conflict. They operate at the variant level rather than tracking individual SCV changes.

| Reason | Description | Detection Logic | SCV Array |
|--------|-------------|-----------------|-----------|
| `expert_panel_added` | Expert panel (3/4-star) submission now determines classification | VCV rank changed to ≥3 (was <3) | `scvs_added_higher_rank` |
| `higher_rank_scv_added` | New 1-star SCV(s) supersede a 0-star conflict | Previous VCV rank was 0, current rank ≥1, AND new SCVs were added | `scvs_added_higher_rank` |
| `vcv_rank_changed` | Existing SCV upgraded from 0-star to 1-star, superseding the conflict | Previous VCV rank was 0, current rank ≥1, but no new SCVs added | `scvs_rank_upgraded` |
| `outlier_reclassified` | Outlier submitter changed their classification | `vcv_resolved_reason = 'outlier_resolved'` | N/A |

**Important**: `higher_rank_scv_added` only applies to **0-star conflicts** being superseded by 1-star SCVs. For 1-star conflicts, only `expert_panel_added` can supersede them because there are no 2-star SCVs in ClinVar's ranking system.

**SCV Arrays for VCV-Level Reasons**:

- `scvs_added_higher_rank`: New SCVs added at a rank higher than the previous VCV rank (used for `higher_rank_scv_added` and `expert_panel_added`)
- `scvs_rank_upgraded`: Existing SCVs that were upgraded to a higher rank (used for `vcv_rank_changed`)

### 4. Heuristic/Fallback Reasons

These are used when no specific SCV change explains the resolution. They represent either special cases or catch-all categories.

| Reason                       | Description                                      | When Used                       |
|------------------------------|--------------------------------------------------|---------------------------------|
| `single_submitter_withdrawn` | The only submitter withdrew (conflict dissolved) | Previous submitter count was 1  |
| `unknown`                    | Cannot determine reason                          | No identifiable SCV explanation |

### 5. Modification-Only Reasons

These apply only to variants with `change_status = 'modified'` (conflict still exists but changed in nature).

| Reason | Description |
|--------|-------------|
| `outlier_status_changed` | Variant gained or lost outlier status |
| `conflict_type_changed` | Changed between clinsig and non-clinsig conflict |

## Priority Order

The `primary_reason` is assigned using a CASE statement that checks conditions in priority order. Higher-priority reasons are checked first:

### For Resolutions (`change_status = 'resolved'`)

1. `expert_panel_added` - Expert panel (3/4-star) supersedes all other considerations
2. `single_submitter_withdrawn` - Special case: only one submitter existed
3. **0-star conflict superseded by 1-star (checked before contributing tier reasons)**:
   - `higher_rank_scv_added` - New 1-star SCV(s) added that supersede the 0-star conflict
   - `vcv_rank_changed` - Existing SCV upgraded from 0-star to 1-star
4. **Contributing tier SCV reasons (high priority)**:
   - `scv_flagged` - ClinVar flagged a contributing SCV
   - `scv_removed` - Contributing SCV was withdrawn
   - `scv_rank_downgraded` - Contributing SCV was demoted out of tier
   - `scv_reclassified` - Contributing SCV changed classification
5. `outlier_reclassified` - Outlier-specific resolution
6. `unknown` - Fallback: no identifiable reason

**Note on priority for 0-star conflicts**: `higher_rank_scv_added` and `vcv_rank_changed` must be checked BEFORE contributing tier reasons. This is because when 1-star SCVs are added to a 0-star conflict, those new SCVs become the contributing tier.

**Note on `scv_added`**: This reason is not in the resolution priority list because when SCVs are added and a conflict resolves, a higher-priority reason always applies (like `expert_panel_added` or `higher_rank_scv_added`).

**Note on 1-star conflicts**: For 1-star conflicts, only `expert_panel_added` can supersede them. There are no 2-star SCVs in ClinVar's ranking system, so `higher_rank_scv_added` does not apply to 1-star conflicts.

**Note on rank downgrade**: `scv_rank_downgraded` takes precedence over `scv_reclassified` because a rank downgrade effectively removes the SCV from the contributing tier (similar to removal), whereas a reclassification keeps the SCV in the contributing set.

### For Modifications (`change_status = 'modified'`)

1. **Contributing tier SCV reasons (high priority)**:
   - `scv_reclassified` - Classification change is most impactful
   - `scv_flagged` - ClinVar flagged a contributing submission
   - `scv_removed` - Contributing submission withdrawn
   - `scv_added` - New submission added to contributing tier
2. `vcv_rank_changed` - VCV rank changed
3. `outlier_status_changed` - Outlier status changed
4. `conflict_type_changed` - Conflict type changed
5. `unknown` - Fallback

## Visual Summary

```text
┌─────────────────────────────────────────────────────────────┐
│  VCV-DERIVED (checked first for tier supersession)          │
│  ├── expert_panel_added     - 3/4-star supersedes any tier  │
│  ├── higher_rank_scv_added  - New 1-star supersedes 0-star  │
│  ├── vcv_rank_changed       - Existing SCV upgraded 0→1     │
│  └── outlier_reclassified   - Outlier-specific resolution   │
├─────────────────────────────────────────────────────────────┤
│  CONTRIBUTING TIER SCV REASONS (resolution + modification)  │
│  ├── scv_flagged         - ClinVar flagged contributing SCV │
│  ├── scv_removed         - Contributing SCV withdrawn       │
│  ├── scv_rank_downgraded - SCV demoted from contributing    │
│  └── scv_reclassified    - Contributing SCV reclassified    │
├─────────────────────────────────────────────────────────────┤
│  HEURISTIC/FALLBACK (no specific SCV identified)            │
│  ├── single_submitter_withdrawn - Context-based             │
│  └── unknown                    - Data gap                  │
├─────────────────────────────────────────────────────────────┤
│  MODIFICATION-ONLY (conflict persists)                      │
│  ├── scv_added              - New SCV at contributing tier  │
│  ├── outlier_status_changed                                 │
│  └── conflict_type_changed                                  │
└─────────────────────────────────────────────────────────────┘

Note: higher_rank_scv_added and vcv_rank_changed only apply to
0-star conflicts. For 1-star conflicts, only expert_panel_added
can supersede (no 2-star SCVs exist in ClinVar).

Note: scv_added only appears for modifications because when SCVs
are added and a conflict resolves, a higher-priority reason
(like expert_panel_added or higher_rank_scv_added) always applies.
```

## Data Sources

### Tables with Reason Data

| Table/View | Key Fields |
|------------|------------|
| `conflict_resolution_analytics` | `primary_reason`, `change_status`, `change_category` |
| `conflict_vcv_change_detail` | `primary_reason`, `scv_reasons_with_counts`, `vcv_change_status` |
| `monthly_conflict_vcv_scv_summary` | SCV arrays (contributing + lower tier), count fields |
| `sheets_change_reasons` | `primary_reason` with counts for charting |
| `sheets_change_reasons_wide` | Reasons as columns for stacked charts |

### Querying SCVs for a Specific Reason

To get the list of SCVs associated with each reason for resolved variants:

```sql
SELECT
  d.variation_id,
  d.conflict_type,
  d.outlier_status,
  d.primary_reason,
  d.scv_reasons_with_counts,
  -- Contributing tier arrays
  ARRAY_TO_STRING(s.scvs_added_contributing, ', ') AS scvs_added,
  ARRAY_TO_STRING(s.scvs_removed_contributing, ', ') AS scvs_removed,
  ARRAY_TO_STRING(s.scvs_flagged_contributing, ', ') AS scvs_flagged,
  ARRAY_TO_STRING(s.scvs_reclassified_contributing, ', ') AS scvs_reclassified,
  ARRAY_TO_STRING(s.scvs_rank_downgraded, ', ') AS scvs_rank_downgraded,
  -- Lower tier arrays
  ARRAY_TO_STRING(s.scvs_added_lower_tier, ', ') AS scvs_added_lower_tier,
  ARRAY_TO_STRING(s.scvs_removed_lower_tier, ', ') AS scvs_removed_lower_tier,
  ARRAY_TO_STRING(s.scvs_flagged_lower_tier, ', ') AS scvs_flagged_lower_tier,
  ARRAY_TO_STRING(s.scvs_reclassified_lower_tier, ', ') AS scvs_reclassified_lower_tier
FROM `clinvar_ingest.conflict_vcv_change_detail` d
LEFT JOIN `clinvar_ingest.monthly_conflict_vcv_scv_summary` s
  ON s.variation_id = d.variation_id
  AND s.snapshot_release_date = d.snapshot_release_date
WHERE d.snapshot_release_date = DATE '2024-10-09'  -- Change as needed
  AND d.vcv_change_status = 'resolved'
ORDER BY d.primary_reason, d.variation_id;
```

## Related Documentation

- [DESIGN-scv-level-tracking.md](DESIGN-scv-level-tracking.md) - Design document for SCV-level tracking
- [GOOGLE-SHEETS-SETUP.md](GOOGLE-SHEETS-SETUP.md) - How to build dashboards with reason charts
- [README.md](README.md) - Pipeline overview and table descriptions
- [06-resolution-modification-analytics.sql](06-resolution-modification-analytics.sql) - Primary reason assignment logic
- [05-monthly-conflict-scv-changes.sql](05-monthly-conflict-scv-changes.sql) - SCV change tracking and reason arrays
