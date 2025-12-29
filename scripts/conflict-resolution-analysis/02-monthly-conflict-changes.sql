-- ============================================================================
-- Script: 02-monthly-conflict-changes.sql
--
-- GCS SYNC REMINDER:
--   This file is loaded by the Cloud Function from GCS. After making changes,
--   sync to GCS:  gsutil cp scripts/conflict-resolution-analysis/0*.sql \
--                           gs://clinvar-ingest/conflict-analytics-sql/
--
-- Description:
--   Creates a table comparing consecutive monthly conflict snapshots to track
--   how conflicts evolve over time. Identifies new conflicts, resolved conflicts,
--   modified conflicts, and unchanged conflicts between each pair of months.
--
-- Output Table:
--   - clinvar_ingest.monthly_conflict_changes
--
-- Source Table:
--   - clinvar_ingest.monthly_conflict_snapshots (created by 01-get-monthly-conflicts.sql)
--
-- Change Status Categories:
--   - 'new': Conflict exists in current month but not in previous month
--   - 'resolved': Conflict existed in previous month but not in current month
--   - 'modified': Conflict exists in both months but key attributes changed
--   - 'unchanged': Conflict exists in both months with no significant changes
--
-- Key Fields Returned:
--   Identification:
--   - snapshot_release_date: The current month's release date
--   - prev_snapshot_release_date: The previous month's release date
--   - variation_id: The variant identifier
--   - change_status: One of 'new', 'resolved', 'modified', 'unchanged'
--
--   Modified Change Reasons (boolean flags, NULL for 'new' and 'resolved'):
--   - classif_changed: TRUE if agg_classif differs between months
--   - outlier_status_changed: TRUE if has_outlier changed (gained/lost outlier)
--   - conflict_type_changed: TRUE if clinsig_conflict changed (clinsig <-> non-clinsig)
--   - submitter_count_changed: TRUE if number of submitters changed
--   - submission_count_changed: TRUE if number of submissions changed
--
--   Resolved Reason (categorical, only populated for 'resolved' status):
--   - resolved_reason: Heuristic categorization of why conflict resolved
--       'single_submitter': Previous conflict had only 1 submitter (likely withdrawn)
--       'outlier_resolved': Previous conflict had outlier (minority may have changed)
--       'consensus_reached': Multiple submitters likely reached agreement
--     NOTE: This is a heuristic based on previous state. Actual resolution could be:
--       - Variant deleted from ClinVar
--       - Submission(s) withdrawn
--       - Submitter(s) changed classification to match others
--       - Reclassification moved conflict to different tier (e.g., now VUS-only)
--
--   Current Month Values (NULL for 'resolved'):
--   - curr_rank: Star ranking (0-4) in current month
--   - curr_agg_sig_type: Bitmask of classification tiers in current month
--   - curr_agg_classif: Slash-separated classifications in current month
--   - curr_agg_classif_w_count: Classifications with counts in current month
--   - curr_submitter_count: Number of submitters in current month
--   - curr_submission_count: Number of submissions in current month
--   - curr_clinsig_conflict: TRUE if clinsig conflict in current month
--   - curr_has_outlier: TRUE if outlier exists in current month
--   - curr_total_path_variants: Baseline denominator for current month
--
--   Previous Month Values (always populated):
--   - prev_rank, prev_agg_sig_type, prev_agg_classif, prev_agg_classif_w_count,
--     prev_submitter_count, prev_submission_count, prev_clinsig_conflict,
--     prev_has_outlier, prev_total_path_variants
--
-- Algorithm:
--   1. Get ordered list of snapshot dates with LAG to identify consecutive months
--   2. For each month pair:
--      a. LEFT JOIN current month conflicts with previous month by variation_id
--      b. Classify as 'new' if no previous record, 'modified' if key fields differ,
--         'unchanged' otherwise
--      c. Calculate boolean flags for what specifically changed
--   3. UNION ALL with resolved conflicts:
--      a. Start from previous month, LEFT JOIN to current month
--      b. Where current month is NULL, classify as 'resolved'
--      c. Apply heuristic to determine likely resolution reason
--
-- Usage:
--   Run after 01-get-monthly-conflicts.sql to create change tracking table.
--   Use for analyzing conflict resolution trends and curation impact over time.
-- ============================================================================

CREATE OR REPLACE TABLE `clinvar_ingest.monthly_conflict_changes` AS

WITH ordered_snapshots AS (
  SELECT
    snapshot_release_date,
    LAG(snapshot_release_date) OVER (ORDER BY snapshot_release_date) AS prev_snapshot_release_date
  FROM (
    SELECT DISTINCT snapshot_release_date
    FROM `clinvar_ingest.monthly_conflict_snapshots`
  )
),

month_comparisons AS (
  -- Capture new, modified, and unchanged conflicts
  SELECT
    os.snapshot_release_date,
    os.prev_snapshot_release_date,
    COALESCE(c.variation_id, p.variation_id) AS variation_id,
    CASE
      WHEN p.variation_id IS NULL THEN 'new'
      WHEN c.agg_classif != p.agg_classif
        OR c.has_outlier != p.has_outlier
        OR c.clinsig_conflict != p.clinsig_conflict THEN 'modified'
      ELSE 'unchanged'
    END AS change_status,

    -- Modified change reasons (what specifically changed)
    CASE WHEN p.variation_id IS NOT NULL THEN c.agg_classif != p.agg_classif END AS classif_changed,
    CASE WHEN p.variation_id IS NOT NULL THEN c.has_outlier != p.has_outlier END AS outlier_status_changed,
    CASE WHEN p.variation_id IS NOT NULL THEN c.clinsig_conflict != p.clinsig_conflict END AS conflict_type_changed,
    CASE WHEN p.variation_id IS NOT NULL THEN c.submitter_count != p.submitter_count END AS submitter_count_changed,
    CASE WHEN p.variation_id IS NOT NULL THEN c.submission_count != p.submission_count END AS submission_count_changed,

    -- Resolved reason placeholder (NULL for non-resolved, will be populated in resolved section)
    CAST(NULL AS STRING) AS resolved_reason,

    -- Current month values
    c.rank AS curr_rank,
    c.agg_sig_type AS curr_agg_sig_type,
    c.agg_classif AS curr_agg_classif,
    c.agg_classif_w_count AS curr_agg_classif_w_count,
    c.submitter_count AS curr_submitter_count,
    c.submission_count AS curr_submission_count,
    c.clinsig_conflict AS curr_clinsig_conflict,
    c.has_outlier AS curr_has_outlier,
    c.total_path_variants AS curr_total_path_variants,

    -- Previous month values
    p.rank AS prev_rank,
    p.agg_sig_type AS prev_agg_sig_type,
    p.agg_classif AS prev_agg_classif,
    p.agg_classif_w_count AS prev_agg_classif_w_count,
    p.submitter_count AS prev_submitter_count,
    p.submission_count AS prev_submission_count,
    p.clinsig_conflict AS prev_clinsig_conflict,
    p.has_outlier AS prev_has_outlier,
    p.total_path_variants AS prev_total_path_variants
  FROM ordered_snapshots os
  LEFT JOIN `clinvar_ingest.monthly_conflict_snapshots` c
    ON c.snapshot_release_date = os.snapshot_release_date
  LEFT JOIN `clinvar_ingest.monthly_conflict_snapshots` p
    ON p.snapshot_release_date = os.prev_snapshot_release_date
    AND p.variation_id = c.variation_id
  WHERE os.prev_snapshot_release_date IS NOT NULL

  UNION ALL

  -- Capture resolved conflicts (in previous month but not in current)
  SELECT
    os.snapshot_release_date,
    os.prev_snapshot_release_date,
    p.variation_id,
    'resolved' AS change_status,

    -- Modified change reasons (all NULL for resolved)
    NULL AS classif_changed,
    NULL AS outlier_status_changed,
    NULL AS conflict_type_changed,
    NULL AS submitter_count_changed,
    NULL AS submission_count_changed,

    -- Resolved reason: Check if variant still exists but is no longer in conflict
    -- or if variant was removed entirely (would need to check against full variant table)
    CASE
      WHEN p.submitter_count = 1 THEN 'single_submitter'
      WHEN p.has_outlier THEN 'outlier_resolved'
      ELSE 'consensus_reached'
    END AS resolved_reason,

    -- Current month values (all NULL for resolved)
    NULL AS curr_rank,
    NULL AS curr_agg_sig_type,
    NULL AS curr_agg_classif,
    NULL AS curr_agg_classif_w_count,
    NULL AS curr_submitter_count,
    NULL AS curr_submission_count,
    NULL AS curr_clinsig_conflict,
    NULL AS curr_has_outlier,
    NULL AS curr_total_path_variants,

    -- Previous month values
    p.rank AS prev_rank,
    p.agg_sig_type AS prev_agg_sig_type,
    p.agg_classif AS prev_agg_classif,
    p.agg_classif_w_count AS prev_agg_classif_w_count,
    p.submitter_count AS prev_submitter_count,
    p.submission_count AS prev_submission_count,
    p.clinsig_conflict AS prev_clinsig_conflict,
    p.has_outlier AS prev_has_outlier,
    p.total_path_variants AS prev_total_path_variants
  FROM ordered_snapshots os
  INNER JOIN `clinvar_ingest.monthly_conflict_snapshots` p
    ON p.snapshot_release_date = os.prev_snapshot_release_date
  LEFT JOIN `clinvar_ingest.monthly_conflict_snapshots` c
    ON c.snapshot_release_date = os.snapshot_release_date
    AND c.variation_id = p.variation_id
  WHERE os.prev_snapshot_release_date IS NOT NULL
    AND c.variation_id IS NULL  -- Not in current month = resolved
)

SELECT * FROM month_comparisons
ORDER BY snapshot_release_date, variation_id;
