# SCV-Level Conflict Tracking Design

## Overview

This document describes the design for detailed SCV-level tracking of ClinVar conflicts,
enabling precise understanding of how individual submissions change month-to-month and
contribute to VCV-level conflict status changes.

## Requirements

### 1. SCV-Level Tracking by Rank Tier

- Track contributing SCVs separately by rank tier (0-star vs 1-star)
- A VCV's contributing SCVs are determined by the VCV's rank:
  - 2-star or 1-star VCV → 1-star SCVs contribute (these are "contributing tier")
  - 0-star VCV → 0-star SCVs contribute (these are "contributing tier")
- SCVs can move between rank tiers month-to-month (but only one tier at a time)
- Only track VCVs and SCVs with `gks_proposition_type = 'path'`

### 1a. Tier-Aware Reason Tracking

SCV-level reasons are tracked for **contributing tier** SCVs only:

- **Contributing tier**: SCVs at the rank tier that determines the VCV's classification
  - For 1-star/2-star VCVs: 1-star SCVs are contributing
  - For 0-star VCVs: 0-star SCVs are contributing
- **Lower tier**: SCVs at a rank tier lower than the conflict's determining tier
  - For 1-star VCV conflicts: 0-star SCVs are "lower tier"
  - Lower tier changes are captured in the data model but **not used for reason assignment**

This distinction affects reason assignment:
- Contributing tier changes drive `primary_reason` and `scv_reasons` (e.g., `scv_flagged`, `scv_removed`, `scv_reclassified`)
- Lower tier changes are captured for reference but don't impact reason assignment

The tier is determined by checking `prev_is_contributing` and `curr_is_contributing` flags:
- For `added` SCVs: Use `curr_is_contributing` (new SCV's tier in current month)
- For `removed`/`flagged` SCVs: Use `prev_is_contributing` (SCV's tier when it was removed)
- For `reclassified` SCVs: Use `curr_is_contributing OR prev_is_contributing` (either month)

### 2. Modified Definition

A VCV is "modified" if ANY of these differ from previous to current month:
- Different set of contributing SCV IDs
- Same SCV IDs but different classifications on any SCV

### 3. Tracking Fields Needed

#### SCV Status Changes
- **Flagged SCVs**: SCVs where `review_status = 'flagged submission'` (rank becomes -3)
- **Deleted SCVs**: SCVs removed from contributing list (no longer in current month)
- **New SCVs**: SCVs added to contributing list (not in previous month)
- **Classification Changed**: SCVs present in both months but with different `clinsig_type`

#### VCV-Level Tracking
- **Rank Changes**: When VCV moves between 0-star and 1-star tiers
- **Conflict Status Changes**: non-conflicting → conflicting or vice versa
- **Masked Conflicts**: When 3/4-star SCVs mask underlying 0/1-star conflicts

## Data Model

### Table: `monthly_conflict_scv_snapshots`

Captures the individual SCVs contributing to each VCV's conflict state for each monthly snapshot.

```
Fields:
- snapshot_release_date: DATE - Monthly release date
- variation_id: INT64 - VCV identifier
- vcv_rank: INT64 - The VCV's rank (determines which SCVs contribute)
- scv_id: STRING - SCV identifier
- scv_version: INT64 - SCV version
- scv_rank: INT64 - SCV's own rank (0, 1, or -3 for flagged)
- clinsig_type: INT64 - Classification type (0=BLB, 1=VUS, 2=PLP)
- submitted_classification: STRING - Original classification text
- submitter_id: STRING - Submitter identifier
- submitter_name: STRING - Submitter name
- last_evaluated: DATE - When SCV was last evaluated
- submission_date: DATE - When SCV was submitted
- review_status: STRING - Review status (for flagged detection)
- is_contributing: BOOL - TRUE if this SCV contributes to the VCV's aggregate
- contributing_rank_tier: STRING - '0-star', '1-star', or NULL if not contributing
```

### Table: `monthly_conflict_scv_changes`

Tracks how individual SCVs change between consecutive months for tracked VCVs.

```
Fields:
- snapshot_release_date: DATE - Current month
- prev_snapshot_release_date: DATE - Previous month
- variation_id: INT64 - VCV identifier
- scv_id: STRING - SCV identifier

# SCV Change Status
- scv_change_status: STRING - 'new', 'deleted', 'flagged', 'classification_changed',
                              'rank_changed', 'unchanged'

# Current month values (NULL if deleted/flagged)
- curr_scv_rank: INT64
- curr_clinsig_type: INT64
- curr_submitted_classification: STRING
- curr_review_status: STRING
- curr_contributing_rank_tier: STRING

# Previous month values (NULL if new)
- prev_scv_rank: INT64
- prev_clinsig_type: INT64
- prev_submitted_classification: STRING
- prev_review_status: STRING
- prev_contributing_rank_tier: STRING
```

### Table: `monthly_conflict_vcv_scv_summary`

Aggregates SCV changes at the VCV level for easier analysis.

```
Fields:
- snapshot_release_date: DATE
- prev_snapshot_release_date: DATE
- variation_id: INT64

# VCV-level status
- vcv_change_status: STRING - 'new', 'resolved', 'modified', 'unchanged'
- vcv_rank_changed: BOOL - TRUE if VCV rank changed between months
- curr_vcv_rank: INT64
- prev_vcv_rank: INT64
- conflict_status_changed: BOOL - conflicting <-> non-conflicting
- curr_is_conflicting: BOOL
- prev_is_conflicting: BOOL

# SCV change counts (tier-aware)
## Contributing tier counts (high priority reasons)
- contributing_scvs_added_count: INT64 - New SCVs added to contributing tier
- contributing_scvs_removed_count: INT64 - Contributing SCVs no longer present
- contributing_scvs_first_time_flagged_count: INT64 - Contributing SCVs that became flagged
- contributing_scvs_classification_changed_count: INT64 - Contributing SCVs with different classification
- contributing_scvs_rank_downgraded_count: INT64 - SCVs demoted out of contributing tier

## Lower tier counts (informational, low priority reasons)
- lower_tier_scvs_added_count: INT64 - New SCVs added to lower tier
- lower_tier_scvs_removed_count: INT64 - Lower tier SCVs no longer present
- lower_tier_scvs_first_time_flagged_count: INT64 - Lower tier SCVs that became flagged
- lower_tier_scvs_classification_changed_count: INT64 - Lower tier SCVs with different classification

## Legacy counts (all SCVs regardless of tier)
- scvs_added_count: INT64 - New SCVs in current month (any tier)
- scvs_removed_count: INT64 - SCVs no longer present (any tier)
- scvs_flagged_count: INT64 - SCVs that became flagged (any tier)
- scvs_classification_changed_count: INT64 - SCVs with different classification (any tier)
- scvs_unchanged_count: INT64 - SCVs with no changes

# SCV ID arrays (tier-aware)
## Contributing tier arrays
- scvs_added_contributing: ARRAY<STRING> - New SCVs at contributing tier
- scvs_removed_contributing: ARRAY<STRING> - Removed contributing SCVs
- scvs_flagged_contributing: ARRAY<STRING> - Flagged contributing SCVs
- scvs_reclassified_contributing: ARRAY<STRING> - Reclassified contributing SCVs
- scvs_rank_downgraded: ARRAY<STRING> - SCVs demoted from contributing tier

## Lower tier arrays
- scvs_added_lower_tier: ARRAY<STRING> - New SCVs at lower tier
- scvs_removed_lower_tier: ARRAY<STRING> - Removed lower tier SCVs
- scvs_flagged_lower_tier: ARRAY<STRING> - Flagged lower tier SCVs
- scvs_reclassified_lower_tier: ARRAY<STRING> - Reclassified lower tier SCVs

## Legacy arrays (all SCVs regardless of tier)
- scvs_added: ARRAY<STRING> - List of new SCV IDs
- scvs_removed: ARRAY<STRING> - List of removed SCV IDs
- scvs_flagged: ARRAY<STRING> - List of flagged SCV IDs
- scvs_classification_changed: ARRAY<STRING> - List of SCVs with changed classification

# Masked conflict tracking (when 3/4-star exists)
- has_expert_panel: BOOL - TRUE if 3+ star SCV exists
- underlying_0star_conflict: BOOL - TRUE if 0-star SCVs would conflict without expert panel
- underlying_1star_conflict: BOOL - TRUE if 1-star SCVs would conflict without expert panel
```

## Algorithm

### Step 1: Build SCV Snapshots (`04-monthly-conflict-scv-snapshots.sql`)

For each monthly release date:
1. Get all VCVs with `gks_proposition_type = 'path'` from `clinvar_sum_vsp_rank_group`
2. For each VCV, determine its rank and which SCVs contribute:
   - If VCV rank >= 1: 1-star SCVs contribute
   - If VCV rank = 0: 0-star SCVs contribute
3. Join to `clinvar_scvs` to get individual SCV details
4. Mark each SCV's contributing status and tier

### Step 2: Build SCV Changes (`05-monthly-conflict-scv-changes.sql`)

For each consecutive month pair:
1. FULL OUTER JOIN current and previous month SCV snapshots by (variation_id, scv_id)
2. Classify each SCV:
   - `new`: In current, not in previous
   - `deleted`: In previous, not in current (and not flagged)
   - `flagged`: In previous, current has review_status = 'flagged submission'
   - `classification_changed`: clinsig_type differs
   - `rank_changed`: scv_rank differs (e.g., 0→1 or 1→0)
   - `unchanged`: All fields match

### Step 3: Build VCV Summary (`05-monthly-conflict-scv-changes.sql` - second part)

Aggregate SCV changes by variation_id:
1. Count changes by type, separated by tier (contributing vs lower tier)
2. Collect SCV ID arrays for each tier
3. Determine VCV-level change status based on SCV changes
4. Check for masked conflicts by examining lower-rank aggregations

### Step 4: Assign Tier-Aware Reasons (`06-resolution-modification-analytics.sql`)

Assign `primary_reason` using a priority-ordered CASE statement:

**For Resolutions (`change_status = 'resolved'`):**

1. `expert_panel_added` - Expert panel (3/4-star) supersedes all other considerations
2. `single_submitter_withdrawn` - Special case: only one submitter existed
3. **0-star conflict superseded by 1-star (checked BEFORE contributing tier reasons):**
   - `higher_rank_scv_added` - New 1-star SCV(s) supersede the 0-star conflict
   - `vcv_rank_changed` - Existing SCV upgraded from 0-star to 1-star
4. **Contributing tier SCV reasons (high priority):**
   - `scv_flagged` - ClinVar flagged a contributing SCV
   - `scv_removed` - Contributing SCV was withdrawn
   - `scv_rank_downgraded` - Contributing SCV was demoted out of tier
   - `scv_reclassified` - Contributing SCV changed classification
   - `scv_added` - New SCV added to contributing tier
5. `outlier_reclassified` - Outlier-specific resolution
6. `unknown` - Fallback: no identifiable reason

**Key Design Decisions:**

1. **0-star supersession priority:** `higher_rank_scv_added` and `vcv_rank_changed` must be checked BEFORE contributing tier reasons for 0-star conflicts. When 1-star SCVs are added to a 0-star conflict, those new SCVs become the contributing tier. Without this ordering, the system would incorrectly assign `scv_added` instead of `higher_rank_scv_added`.

2. **1-star conflicts:** For 1-star conflicts, only `expert_panel_added` can supersede them. There are no 2-star SCVs in ClinVar's ranking system, so `higher_rank_scv_added` does not apply to 1-star conflicts.

3. **Contributing tier only:** Only contributing tier SCV changes are tracked because they directly impact the conflict. Lower tier changes are not tracked since they don't affect the VCV's classification.

## Key Considerations

### Rank Tier Separation

When a VCV changes rank (e.g., 0-star → 1-star), the contributing SCVs change entirely.
This is tracked by:
1. Storing `contributing_rank_tier` for each SCV
2. Flagging `vcv_rank_changed` at VCV level
3. Comparing SCVs within the same tier only

### Flagged Submissions

When an SCV becomes flagged:
- Its rank changes to -3
- It no longer contributes to the VCV aggregate
- We track it as `scv_change_status = 'flagged'`
- The `scvs_flagged` array preserves the IDs for analysis

### Masked Conflicts (3/4-star Expert Panels)

When an expert panel submission exists:
- The VCV shows the expert panel's classification
- Lower-rank conflicts may still exist but are "masked"
- We separately aggregate 0-star and 1-star SCVs to detect underlying conflicts
- `underlying_0star_conflict` and `underlying_1star_conflict` flags indicate this

## Migration from Existing Tables

The new tables supplement (not replace) existing tables:
- `monthly_conflict_snapshots` - VCV-level conflict snapshots (unchanged)
- `monthly_conflict_changes` - VCV-level change tracking (unchanged)
- `monthly_conflict_scv_snapshots` - NEW: SCV-level detail
- `monthly_conflict_scv_changes` - NEW: SCV-level changes
- `monthly_conflict_vcv_scv_summary` - NEW: VCV summary with SCV change counts

The existing trend queries (`03-outlier-trends-*.sql`) continue to work with the
original tables. New queries can join to the SCV-level tables for deeper analysis.
