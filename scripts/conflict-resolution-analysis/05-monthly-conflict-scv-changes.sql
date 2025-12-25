-- ============================================================================
-- Script: 05-monthly-conflict-scv-changes.sql
--
-- Description:
--   Creates tables tracking how individual SCVs change between consecutive monthly
--   snapshots, and summarizes these changes at the VCV level. This enables detailed
--   analysis of what specific submissions caused conflicts to be created, modified,
--   or resolved.
--
-- Output Tables:
--   - clinvar_ingest.monthly_conflict_scv_changes - Individual SCV changes
--   - clinvar_ingest.monthly_conflict_vcv_scv_summary - VCV-level summary with SCV details
--
-- Source Tables:
--   - clinvar_ingest.monthly_conflict_scv_snapshots (from 04-monthly-conflict-scv-snapshots.sql)
--
-- SCV Change Status Categories:
--   - 'new': SCV exists in current month but not in previous month for this VCV
--   - 'removed': SCV existed in previous month but no longer exists at all in current
--   - 'flagged': SCV was active (not flagged) in previous month, now has is_flagged=TRUE
--   - 'classification_changed': Same SCV but clinsig_type differs
--   - 'rank_changed': Same SCV but scv_rank changed (e.g., 0→1 or 1→0)
--   - 'unchanged': SCV present in both with no significant changes
--
-- Note: 'unflagged' is not currently tracked as a separate status
--
-- First-Time Flagged Tracking:
--   An SCV+version should only count as "newly flagged" the first time it transitions
--   to flagged status. If it's unflagged and re-flagged later, the same version should
--   NOT count as newly flagged again. The is_first_time_flagged field tracks this.
--
--   IMPORTANT: This first-occurrence tracking ONLY applies to the 'flagged' event type.
--   All other event types (new, removed, classification_changed, rank_changed, unflagged)
--   use standard month-to-month comparison logic without cumulative history tracking.
--
-- VCV Change Determination:
--   A VCV is considered 'modified' if any of these are true:
--   - Different set of contributing SCV IDs (any new, removed, or flagged)
--   - Same SCV IDs but any classification changed
--   - VCV rank changed (exposing different SCV tier)
--
--   A VCV is 'resolved' if:
--   - Was conflicting in previous month, not conflicting in current
--   - Or no longer has any SCVs in current month
--
--   A VCV is 'new' if:
--   - Not present (or not conflicting) in previous month, conflicting in current
--
-- Key Fields in monthly_conflict_scv_changes:
--   - snapshot_release_date, prev_snapshot_release_date: Month pair
--   - variation_id: VCV identifier
--   - scv_id: SCV identifier
--   - scv_change_status: One of the categories above
--   - curr_*/prev_*: Current and previous month values for comparison
--   - is_first_time_flagged: BOOLEAN (NULL for non-flagged events)
--       TRUE = This is the first time this SCV+version has ever been flagged
--       FALSE = This SCV+version was flagged before, unflagged, and re-flagged
--
-- Key Fields in monthly_conflict_vcv_scv_summary:
--   - VCV-level change status and rank tracking
--   - Counts of each SCV change type:
--       * scvs_flagged_count: ALL flagged events in this month
--       * scvs_first_time_flagged_count: Only FIRST-TIME flagged events per SCV+version
--       * (other counts: added, removed, classification_changed, etc.)
--   - Arrays of SCV IDs for each change category:
--       * scvs_flagged: ALL flagged SCVs
--       * scvs_first_time_flagged: Only SCVs flagged for the first time
--   - Masked conflict detection (when expert panels exist)
--
-- Usage:
--   Run after 04-monthly-conflict-scv-snapshots.sql to create change tracking tables.
-- ============================================================================

-- ============================================================================
-- Part 1: Individual SCV Changes
-- ============================================================================

CREATE OR REPLACE TABLE `clinvar_ingest.monthly_conflict_scv_changes` AS

WITH ordered_snapshots AS (
  SELECT
    snapshot_release_date,
    LAG(snapshot_release_date) OVER (ORDER BY snapshot_release_date) AS prev_snapshot_release_date
  FROM (
    SELECT DISTINCT snapshot_release_date
    FROM `clinvar_ingest.monthly_conflict_scv_snapshots`
  )
),

-- Track the FIRST time each SCV+version was ever flagged (across all months)
-- This is used to determine if a flagged event is the "first time" for that SCV+version
first_flagged_dates AS (
  SELECT
    scv_id,
    scv_version,
    MIN(snapshot_release_date) AS first_flagged_date
  FROM `clinvar_ingest.monthly_conflict_scv_snapshots`
  WHERE is_flagged = TRUE
  GROUP BY scv_id, scv_version
),

-- Get current month SCVs
current_scvs AS (
  SELECT
    os.snapshot_release_date AS comparison_date,
    os.prev_snapshot_release_date,
    s.variation_id,
    s.vcv_rank,
    s.vcv_agg_sig_type,
    s.vcv_is_conflicting,
    s.contributing_scv_tier,
    s.scv_id,
    s.scv_version,
    s.full_scv_id,
    s.scv_rank,
    s.clinsig_type,
    s.submitted_classification,
    s.submitter_id,
    s.submitter_name,
    s.last_evaluated,
    s.submission_date,
    s.review_status,
    s.is_flagged,
    s.is_contributing,
    s.scv_rank_tier
  FROM ordered_snapshots os
  INNER JOIN `clinvar_ingest.monthly_conflict_scv_snapshots` s
    ON s.snapshot_release_date = os.snapshot_release_date
  WHERE os.prev_snapshot_release_date IS NOT NULL
),

-- Get previous month SCVs
previous_scvs AS (
  SELECT
    os.snapshot_release_date AS comparison_date,
    os.prev_snapshot_release_date,
    s.variation_id,
    s.vcv_rank,
    s.vcv_agg_sig_type,
    s.vcv_is_conflicting,
    s.contributing_scv_tier,
    s.scv_id,
    s.scv_version,
    s.full_scv_id,
    s.scv_rank,
    s.clinsig_type,
    s.submitted_classification,
    s.submitter_id,
    s.submitter_name,
    s.last_evaluated,
    s.submission_date,
    s.review_status,
    s.is_flagged,
    s.is_contributing,
    s.scv_rank_tier
  FROM ordered_snapshots os
  INNER JOIN `clinvar_ingest.monthly_conflict_scv_snapshots` s
    ON s.snapshot_release_date = os.prev_snapshot_release_date
  WHERE os.prev_snapshot_release_date IS NOT NULL
),

-- Full outer join to capture all changes
scv_comparisons AS (
  -- SCVs in current month (may or may not be in previous)
  SELECT
    c.comparison_date AS snapshot_release_date,
    c.prev_snapshot_release_date,
    COALESCE(c.variation_id, p.variation_id) AS variation_id,
    COALESCE(c.scv_id, p.scv_id) AS scv_id,

    -- Determine change status (primary change type)
    -- Note: When multiple changes occur (e.g., classification AND rank), this picks one.
    -- Use the boolean flags below for complete change detection.
    CASE
      WHEN p.scv_id IS NULL THEN 'new'
      WHEN c.is_flagged AND NOT COALESCE(p.is_flagged, FALSE) THEN 'flagged'
      WHEN c.clinsig_type != p.clinsig_type THEN 'classification_changed'
      WHEN c.scv_rank != p.scv_rank THEN 'rank_changed'
      ELSE 'unchanged'
    END AS scv_change_status,

    -- Boolean flags for each change type (can be TRUE simultaneously)
    -- These allow detecting co-occurring changes (e.g., rank + classification)
    (c.clinsig_type != p.clinsig_type) AS has_classification_change,
    (c.scv_rank != p.scv_rank) AS has_rank_change,

    -- Current month values
    c.vcv_rank AS curr_vcv_rank,
    c.vcv_agg_sig_type AS curr_vcv_agg_sig_type,
    c.vcv_is_conflicting AS curr_vcv_is_conflicting,
    c.contributing_scv_tier AS curr_contributing_scv_tier,
    c.scv_version AS curr_scv_version,
    c.scv_rank AS curr_scv_rank,
    c.clinsig_type AS curr_clinsig_type,
    c.submitted_classification AS curr_submitted_classification,
    c.submitter_id AS curr_submitter_id,
    c.submitter_name AS curr_submitter_name,
    c.review_status AS curr_review_status,
    c.is_flagged AS curr_is_flagged,
    c.is_contributing AS curr_is_contributing,
    c.scv_rank_tier AS curr_scv_rank_tier,

    -- Previous month values
    p.vcv_rank AS prev_vcv_rank,
    p.vcv_agg_sig_type AS prev_vcv_agg_sig_type,
    p.vcv_is_conflicting AS prev_vcv_is_conflicting,
    p.contributing_scv_tier AS prev_contributing_scv_tier,
    p.scv_version AS prev_scv_version,
    p.scv_rank AS prev_scv_rank,
    p.clinsig_type AS prev_clinsig_type,
    p.submitted_classification AS prev_submitted_classification,
    p.submitter_id AS prev_submitter_id,
    p.submitter_name AS prev_submitter_name,
    p.review_status AS prev_review_status,
    p.is_flagged AS prev_is_flagged,
    p.is_contributing AS prev_is_contributing,
    p.scv_rank_tier AS prev_scv_rank_tier

  FROM current_scvs c
  LEFT JOIN previous_scvs p
    ON p.comparison_date = c.comparison_date  -- Same comparison period
    AND p.variation_id = c.variation_id
    AND p.scv_id = c.scv_id

  UNION ALL

  -- SCVs only in previous month that are truly REMOVED (not just flagged)
  -- NOTE: Flagged transitions are captured in the first part of the UNION when
  -- curr.is_flagged=TRUE AND prev.is_flagged=FALSE. This part only captures
  -- SCVs that no longer exist at all in the current month's snapshots.
  SELECT
    p.comparison_date AS snapshot_release_date,
    p.prev_snapshot_release_date,
    p.variation_id,
    p.scv_id,

    -- Only 'removed' status - flagged is handled in first part of UNION
    'removed' AS scv_change_status,

    -- Boolean flags for change types (both FALSE for removed SCVs)
    FALSE AS has_classification_change,
    FALSE AS has_rank_change,

    -- Current month values (all NULL for removed SCVs)
    NULL AS curr_vcv_rank,
    NULL AS curr_vcv_agg_sig_type,
    NULL AS curr_vcv_is_conflicting,
    NULL AS curr_contributing_scv_tier,
    NULL AS curr_scv_version,
    NULL AS curr_scv_rank,
    NULL AS curr_clinsig_type,
    NULL AS curr_submitted_classification,
    NULL AS curr_submitter_id,
    NULL AS curr_submitter_name,
    NULL AS curr_review_status,
    NULL AS curr_is_flagged,
    NULL AS curr_is_contributing,
    NULL AS curr_scv_rank_tier,

    -- Previous month values
    p.vcv_rank AS prev_vcv_rank,
    p.vcv_agg_sig_type AS prev_vcv_agg_sig_type,
    p.vcv_is_conflicting AS prev_vcv_is_conflicting,
    p.contributing_scv_tier AS prev_contributing_scv_tier,
    p.scv_version AS prev_scv_version,
    p.scv_rank AS prev_scv_rank,
    p.clinsig_type AS prev_clinsig_type,
    p.submitted_classification AS prev_submitted_classification,
    p.submitter_id AS prev_submitter_id,
    p.submitter_name AS prev_submitter_name,
    p.review_status AS prev_review_status,
    p.is_flagged AS prev_is_flagged,
    p.is_contributing AS prev_is_contributing,
    p.scv_rank_tier AS prev_scv_rank_tier

  FROM previous_scvs p
  -- Exclude SCVs that exist in current month (in any form - active or flagged)
  LEFT JOIN current_scvs c
    ON c.comparison_date = p.comparison_date
    AND c.variation_id = p.variation_id
    AND c.scv_id = p.scv_id
  WHERE c.scv_id IS NULL  -- Truly not in current month at all
    AND NOT COALESCE(p.is_flagged, FALSE)  -- Was not already flagged in previous
)

-- Join with first_flagged_dates to determine if this is the first time this SCV+version was flagged
SELECT
  sc.*,
  -- is_first_time_flagged: TRUE only when:
  -- 1. The scv_change_status is 'flagged', AND
  -- 2. This is the first month this SCV+version was ever flagged
  -- For non-flagged events, this is always NULL (not applicable)
  CASE
    WHEN sc.scv_change_status = 'flagged' THEN
      sc.snapshot_release_date = ffd.first_flagged_date
    ELSE NULL
  END AS is_first_time_flagged
FROM scv_comparisons sc
LEFT JOIN first_flagged_dates ffd
  ON ffd.scv_id = sc.scv_id
  AND ffd.scv_version = COALESCE(sc.curr_scv_version, sc.prev_scv_version)
ORDER BY snapshot_release_date, variation_id, scv_id;


-- ============================================================================
-- Part 2: VCV-Level Summary with SCV Change Details
-- ============================================================================

CREATE OR REPLACE TABLE `clinvar_ingest.monthly_conflict_vcv_scv_summary` AS

WITH scv_changes_raw AS (
  SELECT * FROM `clinvar_ingest.monthly_conflict_scv_changes`
),

-- Enrich with VCV-level prev_vcv_rank for all rows (including new SCVs where per-row value is NULL)
-- This is needed for scvs_added_higher_rank to correctly compare new SCV rank against previous VCV rank
scv_changes AS (
  SELECT
    sc.*,
    -- Get the VCV-level prev_vcv_rank by taking MAX across all SCVs for this VCV
    -- New SCVs have NULL prev_vcv_rank, but existing SCVs have the correct value
    MAX(sc.prev_vcv_rank) OVER (PARTITION BY sc.snapshot_release_date, sc.variation_id) AS vcv_level_prev_vcv_rank
  FROM scv_changes_raw sc
),

-- Aggregate SCV changes at VCV level
vcv_scv_aggregates AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    variation_id,

    -- VCV-level info (take from any row, should be same for all SCVs of same VCV)
    ANY_VALUE(curr_vcv_rank) AS curr_vcv_rank,
    ANY_VALUE(prev_vcv_rank) AS prev_vcv_rank,
    ANY_VALUE(curr_vcv_agg_sig_type) AS curr_vcv_agg_sig_type,
    ANY_VALUE(prev_vcv_agg_sig_type) AS prev_vcv_agg_sig_type,
    ANY_VALUE(curr_vcv_is_conflicting) AS curr_vcv_is_conflicting,
    ANY_VALUE(prev_vcv_is_conflicting) AS prev_vcv_is_conflicting,
    ANY_VALUE(curr_contributing_scv_tier) AS curr_contributing_scv_tier,
    ANY_VALUE(prev_contributing_scv_tier) AS prev_contributing_scv_tier,

    -- SCV change counts
    COUNTIF(scv_change_status = 'new') AS scvs_added_count,
    COUNTIF(scv_change_status = 'removed') AS scvs_removed_count,
    -- scvs_flagged_count: ALL flagged events (for reference)
    COUNTIF(scv_change_status = 'flagged') AS scvs_flagged_count,
    -- scvs_first_time_flagged_count: Only first-time flagged events per SCV+version
    COUNTIF(scv_change_status = 'flagged' AND is_first_time_flagged = TRUE) AS scvs_first_time_flagged_count,
    -- Use boolean flags to capture ALL classification/rank changes (even when co-occurring)
    COUNTIF(has_classification_change) AS scvs_classification_changed_count,
    COUNTIF(has_rank_change) AS scvs_rank_changed_count,
    COUNTIF(scv_change_status = 'unchanged') AS scvs_unchanged_count,

    -- SCV change counts for CONTRIBUTING SCVs only
    -- For 'added': SCV is contributing in current month
    COUNTIF(scv_change_status = 'new' AND COALESCE(curr_is_contributing, FALSE)) AS contributing_scvs_added_count,
    COUNTIF(scv_change_status = 'new' AND NOT COALESCE(curr_is_contributing, FALSE)) AS lower_tier_scvs_added_count,
    -- For 'removed': SCV was contributing in previous month
    COUNTIF(scv_change_status = 'removed' AND COALESCE(prev_is_contributing, FALSE)) AS contributing_scvs_removed_count,
    COUNTIF(scv_change_status = 'removed' AND NOT COALESCE(prev_is_contributing, FALSE)) AS lower_tier_scvs_removed_count,
    -- For 'flagged': SCV was contributing in previous month (since flagging removes it)
    -- contributing_scvs_flagged_count: ALL flagged contributing events
    COUNTIF(scv_change_status = 'flagged' AND COALESCE(prev_is_contributing, FALSE)) AS contributing_scvs_flagged_count,
    -- contributing_scvs_first_time_flagged_count: Only first-time flagged for contributing SCVs
    COUNTIF(scv_change_status = 'flagged' AND is_first_time_flagged = TRUE AND COALESCE(prev_is_contributing, FALSE)) AS contributing_scvs_first_time_flagged_count,
    -- Lower-tier SCVs flagged: SCVs flagged that were NOT at the contributing tier in prior month
    -- (e.g., 0-star SCV flagged when conflict was at 1-star tier)
    COUNTIF(scv_change_status = 'flagged' AND is_first_time_flagged = TRUE AND NOT COALESCE(prev_is_contributing, FALSE)) AS lower_tier_scvs_first_time_flagged_count,
    -- For 'classification_changed': SCV is contributing in either month
    COUNTIF(has_classification_change AND COALESCE(curr_is_contributing, prev_is_contributing)) AS contributing_scvs_classification_changed_count,
    COUNTIF(has_classification_change AND NOT COALESCE(curr_is_contributing, FALSE) AND NOT COALESCE(prev_is_contributing, FALSE)) AS lower_tier_scvs_classification_changed_count,
    -- Contributing SCVs that were rank-downgraded (was contributing, now not contributing due to rank change)
    -- Uses has_rank_change flag instead of scv_change_status to catch cases where classification also changed
    -- Excludes flagged SCVs (rank changed to -3) since flagging is tracked separately via scv_flagged
    COUNTIF(has_rank_change AND scv_change_status != 'flagged' AND COALESCE(prev_is_contributing, FALSE) AND NOT COALESCE(curr_is_contributing, FALSE)) AS contributing_scvs_rank_downgraded_count,

    -- SCV ID arrays for detailed analysis
    -- All SCVs (regardless of tier)
    ARRAY_AGG(CASE WHEN scv_change_status = 'new' THEN scv_id END IGNORE NULLS) AS scvs_added,
    ARRAY_AGG(CASE WHEN scv_change_status = 'removed' THEN scv_id END IGNORE NULLS) AS scvs_removed,
    -- scvs_flagged: ALL flagged SCVs
    ARRAY_AGG(CASE WHEN scv_change_status = 'flagged' THEN scv_id END IGNORE NULLS) AS scvs_flagged,
    -- scvs_first_time_flagged: Only SCVs flagged for the first time (per SCV+version)
    ARRAY_AGG(CASE WHEN scv_change_status = 'flagged' AND is_first_time_flagged = TRUE THEN scv_id END IGNORE NULLS) AS scvs_first_time_flagged,
    -- Use boolean flags to capture ALL classification/rank changes (even when co-occurring)
    ARRAY_AGG(CASE WHEN has_classification_change THEN scv_id END IGNORE NULLS) AS scvs_classification_changed,
    ARRAY_AGG(CASE WHEN has_rank_change THEN scv_id END IGNORE NULLS) AS scvs_rank_changed,

    -- Tier-aware SCV ID arrays (contributing tier)
    ARRAY_AGG(CASE WHEN scv_change_status = 'new' AND COALESCE(curr_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_added_contributing,
    ARRAY_AGG(CASE WHEN scv_change_status = 'removed' AND COALESCE(prev_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_removed_contributing,
    ARRAY_AGG(CASE WHEN scv_change_status = 'flagged' AND is_first_time_flagged = TRUE AND COALESCE(prev_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_flagged_contributing,
    ARRAY_AGG(CASE WHEN has_classification_change AND COALESCE(curr_is_contributing, prev_is_contributing) THEN scv_id END IGNORE NULLS) AS scvs_reclassified_contributing,
    -- SCVs that were rank-downgraded out of contributing tier (uses has_rank_change to catch co-occurring changes)
    -- Excludes flagged SCVs (rank changed to -3) since flagging is tracked separately via scvs_flagged_contributing
    ARRAY_AGG(CASE WHEN has_rank_change AND scv_change_status != 'flagged' AND COALESCE(prev_is_contributing, FALSE) AND NOT COALESCE(curr_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_rank_downgraded,

    -- Tier-aware SCV ID arrays (lower tier - NOT contributing)
    ARRAY_AGG(CASE WHEN scv_change_status = 'new' AND NOT COALESCE(curr_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_added_lower_tier,
    ARRAY_AGG(CASE WHEN scv_change_status = 'removed' AND NOT COALESCE(prev_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_removed_lower_tier,
    ARRAY_AGG(CASE WHEN scv_change_status = 'flagged' AND is_first_time_flagged = TRUE AND NOT COALESCE(prev_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_flagged_lower_tier,
    ARRAY_AGG(CASE WHEN has_classification_change AND NOT COALESCE(curr_is_contributing, FALSE) AND NOT COALESCE(prev_is_contributing, FALSE) THEN scv_id END IGNORE NULLS) AS scvs_reclassified_lower_tier,

    -- VCV-level reason arrays: SCVs involved in tier supersession
    -- scvs_added_higher_rank: New SCVs added at a higher rank than the previous VCV rank
    -- Used for 'higher_rank_scv_added' reason (e.g., 1-star SCVs added to 0-star conflict)
    -- NOTE: Uses vcv_level_prev_vcv_rank (computed via window function) instead of per-row prev_vcv_rank,
    -- because new SCVs have NULL for prev_vcv_rank (they didn't exist in previous month)
    ARRAY_AGG(CASE WHEN scv_change_status = 'new' AND COALESCE(curr_scv_rank, 0) > COALESCE(vcv_level_prev_vcv_rank, 0) THEN scv_id END IGNORE NULLS) AS scvs_added_higher_rank,
    -- scvs_rank_upgraded: Existing SCVs that were upgraded to a higher rank
    -- Used for 'vcv_rank_changed' reason (e.g., 0-star SCV upgraded to 1-star)
    ARRAY_AGG(CASE WHEN has_rank_change AND COALESCE(curr_scv_rank, 0) > COALESCE(prev_scv_rank, 0) THEN scv_id END IGNORE NULLS) AS scvs_rank_upgraded,

    -- Track 0-star and 1-star SCVs separately for masked conflict detection
    COUNTIF(curr_scv_rank_tier = '0-star' AND curr_is_contributing) AS curr_0star_contributing_count,
    COUNTIF(curr_scv_rank_tier = '1-star' AND curr_is_contributing) AS curr_1star_contributing_count,
    COUNTIF(prev_scv_rank_tier = '0-star' AND prev_is_contributing) AS prev_0star_contributing_count,
    COUNTIF(prev_scv_rank_tier = '1-star' AND prev_is_contributing) AS prev_1star_contributing_count,

    -- Count distinct clinsig_types at each tier (for detecting underlying conflicts)
    COUNT(DISTINCT CASE WHEN curr_scv_rank_tier = '0-star' THEN curr_clinsig_type END) AS curr_0star_unique_clinsig_count,
    COUNT(DISTINCT CASE WHEN curr_scv_rank_tier = '1-star' THEN curr_clinsig_type END) AS curr_1star_unique_clinsig_count

  FROM scv_changes
  GROUP BY snapshot_release_date, prev_snapshot_release_date, variation_id
)

-- Build reason arrays with counts for each VCV
-- Reasons are sorted alphabetically for consistency
-- Tier-aware: contributing tier reasons separate from lower-tier reasons
, reason_components AS (
  SELECT
    v.*,
    -- Build array of (reason, count) structs for non-zero counts
    -- Only includes contributing tier reasons since lower-tier changes don't affect VCV classification
    ARRAY_CONCAT(
      IF(v.contributing_scvs_added_count > 0, [STRUCT('scv_added' AS reason, v.contributing_scvs_added_count AS cnt)], []),
      IF(v.contributing_scvs_first_time_flagged_count > 0, [STRUCT('scv_flagged' AS reason, v.contributing_scvs_first_time_flagged_count AS cnt)], []),
      IF(v.contributing_scvs_removed_count > 0, [STRUCT('scv_removed' AS reason, v.contributing_scvs_removed_count AS cnt)], []),
      IF(v.contributing_scvs_classification_changed_count > 0, [STRUCT('scv_reclassified' AS reason, v.contributing_scvs_classification_changed_count AS cnt)], []),
      IF(v.contributing_scvs_rank_downgraded_count > 0, [STRUCT('scv_rank_downgraded' AS reason, v.contributing_scvs_rank_downgraded_count AS cnt)], [])
    ) AS reason_structs
  FROM vcv_scv_aggregates v
)

SELECT
  v.snapshot_release_date,
  v.prev_snapshot_release_date,
  v.variation_id,
  v.curr_vcv_rank,
  v.prev_vcv_rank,
  v.curr_vcv_agg_sig_type,
  v.prev_vcv_agg_sig_type,
  v.curr_vcv_is_conflicting,
  v.prev_vcv_is_conflicting,
  v.curr_contributing_scv_tier,
  v.prev_contributing_scv_tier,
  v.scvs_added_count,
  v.scvs_removed_count,
  v.scvs_flagged_count,
  v.scvs_first_time_flagged_count,
  v.scvs_classification_changed_count,
  v.scvs_rank_changed_count,
  v.scvs_unchanged_count,
  -- Contributing tier counts
  v.contributing_scvs_added_count,
  v.contributing_scvs_removed_count,
  v.contributing_scvs_flagged_count,
  v.contributing_scvs_first_time_flagged_count,
  v.contributing_scvs_classification_changed_count,
  v.contributing_scvs_rank_downgraded_count,
  -- Lower tier counts
  v.lower_tier_scvs_added_count,
  v.lower_tier_scvs_removed_count,
  v.lower_tier_scvs_first_time_flagged_count,
  v.lower_tier_scvs_classification_changed_count,
  -- All SCV arrays (regardless of tier)
  v.scvs_added,
  v.scvs_removed,
  v.scvs_flagged,
  v.scvs_first_time_flagged,
  v.scvs_classification_changed,
  v.scvs_rank_changed,
  -- Contributing tier arrays
  v.scvs_added_contributing,
  v.scvs_removed_contributing,
  v.scvs_flagged_contributing,
  v.scvs_reclassified_contributing,
  v.scvs_rank_downgraded,
  -- Lower tier arrays
  v.scvs_added_lower_tier,
  v.scvs_removed_lower_tier,
  v.scvs_flagged_lower_tier,
  v.scvs_reclassified_lower_tier,
  -- VCV-level reason arrays (for higher_rank_scv_added and vcv_rank_changed)
  v.scvs_added_higher_rank,
  v.scvs_rank_upgraded,
  v.curr_0star_contributing_count,
  v.curr_1star_contributing_count,
  v.prev_0star_contributing_count,
  v.prev_1star_contributing_count,
  v.curr_0star_unique_clinsig_count,
  v.curr_1star_unique_clinsig_count,

  -- Derived: VCV rank changed
  (COALESCE(v.curr_vcv_rank, -999) != COALESCE(v.prev_vcv_rank, -999)) AS vcv_rank_changed,

  -- Derived: Conflict status changed
  (COALESCE(v.curr_vcv_is_conflicting, FALSE) != COALESCE(v.prev_vcv_is_conflicting, FALSE)) AS conflict_status_changed,

  -- Derived: VCV change status
  CASE
    -- New conflict: wasn't conflicting before, is now
    WHEN NOT COALESCE(v.prev_vcv_is_conflicting, FALSE)
      AND COALESCE(v.curr_vcv_is_conflicting, FALSE) THEN 'new_conflict'

    -- Resolved: was conflicting, isn't now
    WHEN COALESCE(v.prev_vcv_is_conflicting, FALSE)
      AND NOT COALESCE(v.curr_vcv_is_conflicting, FALSE) THEN 'resolved'

    -- Modified: still conflicting but something changed
    WHEN COALESCE(v.curr_vcv_is_conflicting, FALSE)
      AND (v.scvs_added_count > 0
        OR v.scvs_removed_count > 0
        OR v.scvs_flagged_count > 0
        OR v.scvs_classification_changed_count > 0
        OR v.curr_vcv_rank != v.prev_vcv_rank) THEN 'modified'

    -- Unchanged: still conflicting, no SCV changes
    WHEN COALESCE(v.curr_vcv_is_conflicting, FALSE) THEN 'unchanged'

    -- Not tracked (non-conflicting in both months)
    ELSE 'non_conflicting'
  END AS vcv_change_status,

  -- Masked conflict detection
  -- Has expert panel if 3-4-star tier is contributing
  (v.curr_contributing_scv_tier = '3-4-star') AS has_expert_panel,

  -- Underlying 0-star conflict exists if multiple clinsig types at 0-star tier
  (v.curr_0star_unique_clinsig_count > 1) AS underlying_0star_conflict,

  -- Underlying 1-star conflict exists if multiple clinsig types at 1-star tier
  (v.curr_1star_unique_clinsig_count > 1) AS underlying_1star_conflict,

  -- Multi-reason tracking: Array of SCV change reasons (sorted alphabetically)
  -- Only includes reasons with non-zero counts
  ARRAY(
    SELECT reason FROM UNNEST(v.reason_structs) ORDER BY reason
  ) AS scv_reasons,

  -- Multi-reason tracking: Formatted string with counts
  -- Format: "scv_added(3), scv_flagged(2), scv_reclassified(1)"
  (
    SELECT STRING_AGG(CONCAT(reason, '(', CAST(cnt AS STRING), ')'), ', ' ORDER BY reason)
    FROM UNNEST(v.reason_structs)
  ) AS scv_reasons_with_counts

FROM reason_components v
ORDER BY snapshot_release_date, variation_id;
