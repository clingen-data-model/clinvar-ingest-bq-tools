-- ============================================================================
-- Script: 06-resolution-modification-analytics.sql
--
-- Description:
--   Provides detailed analytics on conflict resolutions and modifications,
--   broken down by reason(s), with support for slicing by month, outlier status,
--   and clinsig state. Designed for Google Sheets visualization with slicers.
--
-- Output Tables:
--   - clinvar_ingest.conflict_vcv_change_detail: VCV-level detail with multi-reason
--       One row per VCV per month (resolved/modified only), showing ALL SCV reasons
--   - clinvar_ingest.conflict_resolution_analytics: Aggregated by primary reason
--       Long format for summary charts and pivot tables
--
-- Output Views:
--   - clinvar_ingest.conflict_resolution_monthly_comparison: Month-over-month
--   - clinvar_ingest.conflict_resolution_reason_totals: Wide format for charting
--   - clinvar_ingest.conflict_resolution_overall_trends: High-level trends
--
-- Source Tables:
--   - clinvar_ingest.monthly_conflict_changes (VCV-level changes)
--   - clinvar_ingest.monthly_conflict_scv_changes (SCV-level changes)
--   - clinvar_ingest.monthly_conflict_vcv_scv_summary (VCV summary with SCV details)
--   - clinvar_ingest.monthly_conflict_snapshots (baseline counts)
--
-- Multi-Reason Tracking:
--   Each VCV can have multiple SCV change reasons in a single month.
--   The conflict_vcv_change_detail table provides:
--   - scv_reasons: ARRAY of reason names (sorted alphabetically)
--       Example: ["scv_added", "scv_flagged", "scv_reclassified"]
--   - scv_reasons_with_counts: STRING with counts per reason
--       Example: "scv_added(3), scv_flagged(12), scv_reclassified(6)"
--   - reason_count: Number of distinct SCV change reasons
--   - primary_reason: Single "most important" reason for legacy compatibility
--
-- Key Dimensions for Slicing:
--   - snapshot_release_date: The current month being analyzed
--   - prev_snapshot_release_date: The prior month for comparison
--   - conflict_type: 'Clinsig' (P/LP vs B/LB) or 'Non-Clinsig' (B/LB vs VUS)
--   - outlier_status: 'With Outlier' or 'No Outlier'
--   - conflict_rank_tier: '0-star', '1-star', or '3-4-star' (the rank tier where conflict exists)
--   - change_category: 'Resolution' or 'Modification'
--   - reason: Specific reason for the change
--
-- Resolution Reasons (why conflicts were resolved):
--   - 'expert_panel_added': Expert panel (3/4-star) submission now masks conflict
--   - 'single_submitter_withdrawn': Only had one submitter who withdrew
--   - 'higher_rank_scv_added': 0-star conflict superseded by new 1-star SCV(s)
--   - 'vcv_rank_changed': 0-star conflict superseded by existing SCV upgraded to 1-star
--   - 'scv_flagged': One or more contributing SCVs were flagged
--   - 'scv_removed': One or more contributing SCVs were deleted/withdrawn
--   - 'scv_rank_downgraded': Contributing SCV demoted out of contributing tier (excludes flagged)
--   - 'scv_reclassified': Contributing SCV changed classification to match others
--   - 'outlier_reclassified': Outlier submitter changed their classification
--
-- Modification-Only Reasons (never apply to resolutions):
--   - 'scv_added': New SCV(s) added to the conflict at contributing tier
--   - 'vcv_rank_changed': VCV rank changed (different SCVs now contribute) - for modifications
--   - 'outlier_status_changed': Outlier status flipped
--   - 'conflict_type_changed': Changed between clinsig and non-clinsig
--   - 'unknown': No identifiable reason (fallback)
--
-- Note: 'scv_added' only applies to modifications because when SCVs are added and a conflict
-- resolves, a higher-priority reason (like 'expert_panel_added' or 'higher_rank_scv_added')
-- always takes precedence.
--
-- Note: Lower-tier reasons have been removed because they don't impact the VCV's
-- classification. Only contributing tier SCV changes are tracked.
--
-- Priority Notes:
--   - For 0-star conflicts: 'higher_rank_scv_added' and 'vcv_rank_changed' are checked
--     BEFORE contributing tier reasons because new 1-star SCVs become the contributing
--     tier, which would incorrectly trigger 'scv_added' otherwise.
--   - For 1-star conflicts: Only 'expert_panel_added' can supersede (no 2-star SCVs exist).
--   - Lower-tier reasons have lowest priority and are informational only.
--
-- Usage:
--   Run via BigQuery Data Connector in Google Sheets.
--   Add slicers for: snapshot_release_date, conflict_type, outlier_status
--   Create pivot tables or charts by change_category and reason.
-- ============================================================================

-- ============================================================================
-- Part 1a: VCV-Level Change Detail Table (Comprehensive - All Change Statuses)
-- ============================================================================
-- This table provides one row per VCV per month for ALL change statuses:
--   - new: Conflict appeared this month
--   - resolved: Conflict disappeared this month
--   - modified: Conflict changed but still exists
--   - unchanged: Conflict exists in both months with no significant changes
--
-- Each row includes:
--   - A single primary_reason for the change (for aggregation/charting)
--   - Multi-reason arrays showing all contributing SCV changes
--   - Slicing dimensions: conflict_type, outlier_status, conflict_rank_tier

CREATE OR REPLACE TABLE `clinvar_ingest.conflict_vcv_change_detail` AS

WITH vcv_changes AS (
  SELECT
    mc.snapshot_release_date,
    mc.prev_snapshot_release_date,
    mc.variation_id,
    mc.change_status,
    mc.resolved_reason AS vcv_resolved_reason,
    mc.classif_changed,
    mc.outlier_status_changed,
    mc.conflict_type_changed,
    mc.submitter_count_changed,
    mc.submission_count_changed,
    -- Current month values
    mc.curr_rank,
    mc.curr_clinsig_conflict,
    mc.curr_has_outlier,
    mc.curr_total_path_variants,
    -- Previous month values
    mc.prev_rank,
    mc.prev_clinsig_conflict,
    mc.prev_has_outlier,
    mc.prev_total_path_variants,
    mc.prev_submitter_count,
    -- Use COALESCE for slicing dimensions (prefer current, fall back to previous)
    COALESCE(mc.curr_clinsig_conflict, mc.prev_clinsig_conflict) AS is_clinsig,
    COALESCE(mc.curr_has_outlier, mc.prev_has_outlier) AS has_outlier,
    -- Rank tier for slicing (prefer current, fall back to previous)
    COALESCE(mc.curr_rank, mc.prev_rank) AS conflict_rank
  FROM `clinvar_ingest.monthly_conflict_changes` mc
),

scv_summary AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    variation_id,
    vcv_change_status,
    -- All SCVs (regardless of tier)
    scvs_added_count,
    scvs_removed_count,
    scvs_flagged_count,
    scvs_first_time_flagged_count,
    scvs_classification_changed_count,
    scvs_rank_changed_count,
    -- Contributing tier counts
    contributing_scvs_added_count,
    contributing_scvs_removed_count,
    contributing_scvs_flagged_count,
    contributing_scvs_first_time_flagged_count,
    contributing_scvs_classification_changed_count,
    contributing_scvs_rank_downgraded_count,
    -- Derived fields
    vcv_rank_changed,
    has_expert_panel,
    underlying_0star_conflict,
    underlying_1star_conflict,
    curr_vcv_rank,
    prev_vcv_rank,
    -- Multi-reason fields from 05
    scv_reasons,
    scv_reasons_with_counts
  FROM `clinvar_ingest.monthly_conflict_vcv_scv_summary`
)

SELECT
  v.snapshot_release_date,
  v.prev_snapshot_release_date,
  v.variation_id,
  -- Slicing dimensions
  CASE WHEN v.is_clinsig THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
  CASE WHEN v.has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
  CASE
    WHEN v.conflict_rank >= 3 THEN '3-4-star'
    WHEN v.conflict_rank = 1 THEN '1-star'
    WHEN v.conflict_rank = 0 THEN '0-star'
    ELSE 'flagged'
  END AS conflict_rank_tier,
  v.change_status AS vcv_change_status,
  -- Determine primary reason (single reason for each change status)
  CASE
    WHEN v.change_status = 'new' THEN 'new_conflict'
    WHEN v.change_status = 'unchanged' THEN 'no_change'
    WHEN v.change_status = 'resolved' THEN
      CASE
        WHEN s.has_expert_panel AND COALESCE(s.prev_vcv_rank, 0) < 3 THEN 'expert_panel_added'
        WHEN v.prev_submitter_count = 1 THEN 'single_submitter_withdrawn'
        -- Higher-rank SCV added: 0-star conflict superseded by new 1-star SCV(s)
        -- Must check BEFORE contributing tier reasons because new 1-star SCVs become
        -- the contributing tier, which would incorrectly trigger 'scv_added'
        -- Note: 1-star conflicts superseded by 3/4-star are handled by 'expert_panel_added' above
        WHEN COALESCE(s.prev_vcv_rank, 0) = 0
          AND COALESCE(s.curr_vcv_rank, 0) >= 1
          AND s.scvs_added_count > 0 THEN 'higher_rank_scv_added'
        -- VCV rank changed from 0-star for other reasons (e.g., existing SCV upgraded to 1-star)
        WHEN COALESCE(s.prev_vcv_rank, 0) = 0
          AND COALESCE(s.curr_vcv_rank, 0) >= 1 THEN 'vcv_rank_changed'
        -- Contributing tier reasons (high priority)
        -- scv_flagged takes precedence over scv_removed
        WHEN s.contributing_scvs_first_time_flagged_count > 0 THEN 'scv_flagged'
        WHEN s.contributing_scvs_removed_count > 0 THEN 'scv_removed'
        -- Rank downgrade before reclassification: downgrade effectively removes SCV from contributing tier
        WHEN s.contributing_scvs_rank_downgraded_count > 0 THEN 'scv_rank_downgraded'
        WHEN s.contributing_scvs_classification_changed_count > 0 THEN 'scv_reclassified'
        -- Note: scv_added is not checked here because when SCVs are added and conflict resolves,
        -- a higher-priority reason (like expert_panel_added or higher_rank_scv_added) always applies
        WHEN v.vcv_resolved_reason = 'outlier_resolved' THEN 'outlier_reclassified'
        ELSE 'unknown'
      END
    WHEN v.change_status = 'modified' THEN
      -- For modifications, use the most impactful reason as primary
      -- Contributing tier reasons take precedence
      CASE
        WHEN s.contributing_scvs_classification_changed_count > 0 THEN 'scv_reclassified'
        WHEN s.contributing_scvs_first_time_flagged_count > 0 THEN 'scv_flagged'
        WHEN s.contributing_scvs_removed_count > 0 THEN 'scv_removed'
        WHEN s.contributing_scvs_added_count > 0 THEN 'scv_added'
        WHEN s.vcv_rank_changed THEN 'vcv_rank_changed'
        WHEN v.outlier_status_changed THEN 'outlier_status_changed'
        WHEN v.conflict_type_changed THEN 'conflict_type_changed'
        ELSE 'unknown'
      END
    ELSE 'unknown'
  END AS primary_reason,
  -- Multi-reason fields: ALL SCV change reasons for this VCV
  s.scv_reasons,
  s.scv_reasons_with_counts,
  COALESCE(ARRAY_LENGTH(s.scv_reasons), 0) AS reason_count,
  -- SCV change counts for reference
  COALESCE(s.scvs_added_count, 0) AS scvs_added_count,
  COALESCE(s.scvs_removed_count, 0) AS scvs_removed_count,
  COALESCE(s.scvs_flagged_count, 0) AS scvs_flagged_count,
  COALESCE(s.scvs_first_time_flagged_count, 0) AS scvs_first_time_flagged_count,
  COALESCE(s.scvs_classification_changed_count, 0) AS scvs_classification_changed_count,
  COALESCE(s.vcv_rank_changed, FALSE) AS vcv_rank_changed,
  COALESCE(v.outlier_status_changed, FALSE) AS outlier_status_changed,
  COALESCE(v.conflict_type_changed, FALSE) AS conflict_type_changed,
  COALESCE(s.has_expert_panel, FALSE) AS has_expert_panel,
  v.prev_submitter_count,
  -- Include rank values for debugging/analysis
  v.curr_rank,
  v.prev_rank
FROM vcv_changes v
LEFT JOIN scv_summary s
  ON s.snapshot_release_date = v.snapshot_release_date
  AND s.variation_id = v.variation_id
ORDER BY v.snapshot_release_date, v.variation_id;


-- ============================================================================
-- Part 1b: Resolution Analytics (Long Format) - Aggregated by Primary Reason
-- ============================================================================

CREATE OR REPLACE TABLE `clinvar_ingest.conflict_resolution_analytics` AS

WITH vcv_changes AS (
  SELECT
    mc.snapshot_release_date,
    mc.prev_snapshot_release_date,
    mc.variation_id,
    mc.change_status,
    mc.resolved_reason AS vcv_resolved_reason,
    mc.classif_changed,
    mc.outlier_status_changed,
    mc.conflict_type_changed,
    mc.submitter_count_changed,
    mc.submission_count_changed,
    -- Current month values
    mc.curr_rank,
    mc.curr_clinsig_conflict,
    mc.curr_has_outlier,
    mc.curr_total_path_variants,
    -- Previous month values
    mc.prev_rank,
    mc.prev_clinsig_conflict,
    mc.prev_has_outlier,
    mc.prev_total_path_variants,
    mc.prev_submitter_count,
    -- Use COALESCE for slicing dimensions
    COALESCE(mc.curr_clinsig_conflict, mc.prev_clinsig_conflict) AS is_clinsig,
    COALESCE(mc.curr_has_outlier, mc.prev_has_outlier) AS has_outlier,
    -- Rank tier for slicing (prefer current, fall back to previous)
    COALESCE(mc.curr_rank, mc.prev_rank) AS conflict_rank
  FROM `clinvar_ingest.monthly_conflict_changes` mc
),

scv_summary AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    variation_id,
    vcv_change_status,
    -- All SCVs (regardless of tier)
    scvs_added_count,
    scvs_removed_count,
    scvs_flagged_count,
    scvs_first_time_flagged_count,
    scvs_classification_changed_count,
    scvs_rank_changed_count,
    -- Contributing tier counts
    contributing_scvs_added_count,
    contributing_scvs_removed_count,
    contributing_scvs_flagged_count,
    contributing_scvs_first_time_flagged_count,
    contributing_scvs_classification_changed_count,
    contributing_scvs_rank_downgraded_count,
    -- Derived fields
    vcv_rank_changed,
    has_expert_panel,
    underlying_0star_conflict,
    underlying_1star_conflict,
    curr_vcv_rank,
    prev_vcv_rank,
    -- Multi-reason fields from 05
    scv_reasons,
    scv_reasons_with_counts
  FROM `clinvar_ingest.monthly_conflict_vcv_scv_summary`
),

-- Combine VCV-level and SCV-level information for resolutions
resolution_details AS (
  SELECT
    v.snapshot_release_date,
    v.prev_snapshot_release_date,
    v.variation_id,
    v.is_clinsig,
    v.has_outlier,
    v.conflict_rank,
    v.prev_submitter_count,
    v.vcv_resolved_reason,
    -- All SCVs
    s.scvs_added_count,
    s.scvs_removed_count,
    s.scvs_flagged_count,
    s.scvs_first_time_flagged_count,
    s.scvs_classification_changed_count,
    -- Contributing tier
    s.contributing_scvs_added_count,
    s.contributing_scvs_removed_count,
    s.contributing_scvs_flagged_count,
    s.contributing_scvs_first_time_flagged_count,
    s.contributing_scvs_classification_changed_count,
    s.contributing_scvs_rank_downgraded_count,
    -- Derived
    s.has_expert_panel,
    s.vcv_rank_changed,
    s.curr_vcv_rank,
    s.prev_vcv_rank,
    -- Multi-reason fields (list of all SCV change reasons for this VCV)
    s.scv_reasons,
    s.scv_reasons_with_counts,
    -- Determine primary resolution reason based on SCV changes
    CASE
      -- Expert panel added (masks the conflict)
      WHEN s.has_expert_panel AND COALESCE(s.prev_vcv_rank, 0) < 3 THEN 'expert_panel_added'
      -- Single submitter withdrew
      WHEN v.prev_submitter_count = 1 THEN 'single_submitter_withdrawn'
      -- Higher-rank SCV added: 0-star conflict superseded by new 1-star SCV(s)
      -- Must check BEFORE contributing tier reasons because new 1-star SCVs become
      -- the contributing tier, which would incorrectly trigger 'scv_added'
      -- Note: 1-star conflicts superseded by 3/4-star are handled by 'expert_panel_added' above
      WHEN COALESCE(s.prev_vcv_rank, 0) = 0
        AND COALESCE(s.curr_vcv_rank, 0) >= 1
        AND s.scvs_added_count > 0 THEN 'higher_rank_scv_added'
      -- VCV rank changed from 0-star for other reasons (e.g., existing SCV upgraded to 1-star)
      WHEN COALESCE(s.prev_vcv_rank, 0) = 0
        AND COALESCE(s.curr_vcv_rank, 0) >= 1 THEN 'vcv_rank_changed'
      -- Contributing tier reasons (high priority)
      -- scv_flagged takes precedence over scv_removed
      WHEN s.contributing_scvs_first_time_flagged_count > 0 THEN 'scv_flagged'
      WHEN s.contributing_scvs_removed_count > 0 THEN 'scv_removed'
      -- Rank downgrade before reclassification
      WHEN s.contributing_scvs_rank_downgraded_count > 0 THEN 'scv_rank_downgraded'
      WHEN s.contributing_scvs_classification_changed_count > 0 THEN 'scv_reclassified'
      -- Note: scv_added is not checked here because when SCVs are added and conflict resolves,
      -- a higher-priority reason (like expert_panel_added or higher_rank_scv_added) always applies
      -- Fallback to VCV-level heuristic
      WHEN v.vcv_resolved_reason = 'outlier_resolved' THEN 'outlier_reclassified'
      ELSE 'unknown'
    END AS resolution_reason
  FROM vcv_changes v
  LEFT JOIN scv_summary s
    ON s.snapshot_release_date = v.snapshot_release_date
    AND s.variation_id = v.variation_id
  WHERE v.change_status = 'resolved'
),

-- Combine VCV-level and SCV-level information for modifications
modification_details AS (
  SELECT
    v.snapshot_release_date,
    v.prev_snapshot_release_date,
    v.variation_id,
    v.is_clinsig,
    v.has_outlier,
    v.conflict_rank,
    v.classif_changed,
    v.outlier_status_changed,
    v.conflict_type_changed,
    -- All SCVs
    s.scvs_added_count,
    s.scvs_removed_count,
    s.scvs_flagged_count,
    s.scvs_first_time_flagged_count,
    s.scvs_classification_changed_count,
    -- Contributing tier
    s.contributing_scvs_added_count,
    s.contributing_scvs_removed_count,
    s.contributing_scvs_first_time_flagged_count,
    s.contributing_scvs_classification_changed_count,
    -- Derived
    s.vcv_rank_changed,
    -- Multi-reason fields (list of all SCV change reasons for this VCV)
    s.scv_reasons,
    s.scv_reasons_with_counts
  FROM vcv_changes v
  LEFT JOIN scv_summary s
    ON s.snapshot_release_date = v.snapshot_release_date
    AND s.variation_id = v.variation_id
  WHERE v.change_status = 'modified'
),

-- Explode modification reasons (one row per reason that applies)
-- Tier-aware: contributing tier reasons separate from lower-tier reasons
modification_reasons AS (
  -- Contributing tier reasons
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'scv_added' AS modification_reason
  FROM modification_details WHERE contributing_scvs_added_count > 0
  UNION ALL
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'scv_removed' AS modification_reason
  FROM modification_details WHERE contributing_scvs_removed_count > 0
  UNION ALL
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'scv_flagged' AS modification_reason
  FROM modification_details WHERE contributing_scvs_first_time_flagged_count > 0
  UNION ALL
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'scv_reclassified' AS modification_reason
  FROM modification_details WHERE contributing_scvs_classification_changed_count > 0
  UNION ALL
  -- VCV-level reasons
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'vcv_rank_changed' AS modification_reason
  FROM modification_details WHERE vcv_rank_changed
  UNION ALL
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'outlier_status_changed' AS modification_reason
  FROM modification_details WHERE outlier_status_changed
  UNION ALL
  SELECT snapshot_release_date, prev_snapshot_release_date, variation_id,
         is_clinsig, has_outlier, conflict_rank, 'conflict_type_changed' AS modification_reason
  FROM modification_details WHERE conflict_type_changed
),

-- Aggregate resolution counts by reason (including conflict_rank_tier)
resolution_summary AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    is_clinsig,
    has_outlier,
    conflict_rank,
    'Resolution' AS change_category,
    resolution_reason AS reason,
    COUNT(DISTINCT variation_id) AS variant_count
  FROM resolution_details
  GROUP BY snapshot_release_date, prev_snapshot_release_date, is_clinsig, has_outlier, conflict_rank, resolution_reason
),

-- Aggregate modification counts by reason (including conflict_rank_tier)
modification_summary AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    is_clinsig,
    has_outlier,
    conflict_rank,
    'Modification' AS change_category,
    modification_reason AS reason,
    COUNT(DISTINCT variation_id) AS variant_count
  FROM modification_reasons
  GROUP BY snapshot_release_date, prev_snapshot_release_date, is_clinsig, has_outlier, conflict_rank, modification_reason
),

-- Get baseline totals for percentage calculations
baseline_totals AS (
  SELECT
    snapshot_release_date,
    ANY_VALUE(total_path_variants) AS total_path_variants,
    COUNT(*) AS total_conflicts,
    COUNTIF(clinsig_conflict) AS total_clinsig_conflicts,
    COUNTIF(NOT clinsig_conflict) AS total_nonclinsig_conflicts,
    COUNTIF(has_outlier) AS total_with_outlier,
    COUNTIF(NOT has_outlier) AS total_no_outlier
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date
),

-- Combine all summaries
combined_summary AS (
  SELECT * FROM resolution_summary
  UNION ALL
  SELECT * FROM modification_summary
)

SELECT
  c.snapshot_release_date,
  c.prev_snapshot_release_date,
  CASE WHEN c.is_clinsig THEN 'Clinsig' ELSE 'Non-Clinsig' END AS conflict_type,
  CASE WHEN c.has_outlier THEN 'With Outlier' ELSE 'No Outlier' END AS outlier_status,
  CASE
    WHEN c.conflict_rank >= 3 THEN '3-4-star'
    WHEN c.conflict_rank = 1 THEN '1-star'
    WHEN c.conflict_rank = 0 THEN '0-star'
    ELSE 'flagged'
  END AS conflict_rank_tier,
  c.change_category,
  c.reason,
  c.variant_count,
  -- Add baseline context
  b.total_path_variants,
  b.total_conflicts AS total_active_conflicts,
  -- Calculate percentages
  ROUND(100.0 * c.variant_count / NULLIF(b.total_conflicts, 0), 3) AS pct_of_active_conflicts,
  ROUND(100.0 * c.variant_count / NULLIF(b.total_path_variants, 0), 4) AS pct_of_all_variants
FROM combined_summary c
LEFT JOIN baseline_totals b
  ON b.snapshot_release_date = c.prev_snapshot_release_date  -- Use prev month as baseline for resolved
ORDER BY c.snapshot_release_date, conflict_type, outlier_status, conflict_rank_tier, change_category, reason;


-- ============================================================================
-- Part 2: Monthly Comparison View (Wide Format)
-- For direct month-over-month comparison
-- ============================================================================

CREATE OR REPLACE VIEW `clinvar_ingest.conflict_resolution_monthly_comparison` AS

WITH monthly_totals AS (
  SELECT
    snapshot_release_date,
    prev_snapshot_release_date,
    conflict_type,
    outlier_status,
    conflict_rank_tier,
    change_category,
    reason,
    SUM(variant_count) AS variant_count
  FROM `clinvar_ingest.conflict_resolution_analytics`
  GROUP BY snapshot_release_date, prev_snapshot_release_date, conflict_type, outlier_status, conflict_rank_tier, change_category, reason
),

-- Get prior month's values for comparison
with_prior_month AS (
  SELECT
    m.*,
    LAG(m.variant_count) OVER (
      PARTITION BY m.conflict_type, m.outlier_status, m.conflict_rank_tier, m.change_category, m.reason
      ORDER BY m.snapshot_release_date
    ) AS prior_month_count
  FROM monthly_totals m
)

SELECT
  snapshot_release_date,
  prev_snapshot_release_date,
  conflict_type,
  outlier_status,
  conflict_rank_tier,
  change_category,
  reason,
  variant_count AS current_count,
  prior_month_count,
  variant_count - COALESCE(prior_month_count, 0) AS count_change,
  CASE
    WHEN prior_month_count > 0
    THEN ROUND(100.0 * (variant_count - prior_month_count) / prior_month_count, 1)
    ELSE NULL
  END AS pct_change
FROM with_prior_month
ORDER BY snapshot_release_date, conflict_type, outlier_status, conflict_rank_tier, change_category, reason;


-- ============================================================================
-- Part 3: Resolution Reason Totals (Wide Format for Charting)
-- One row per month with columns for each reason
-- Includes conflict_rank_tier for slicing by 0-star, 1-star, 3-4-star
-- ============================================================================

CREATE OR REPLACE VIEW `clinvar_ingest.conflict_resolution_reason_totals` AS

SELECT
  snapshot_release_date,
  prev_snapshot_release_date,
  conflict_type,
  outlier_status,
  conflict_rank_tier,

  -- Resolution counts by reason
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'scv_removed' THEN variant_count ELSE 0 END) AS resolved_scv_removed,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'scv_flagged' THEN variant_count ELSE 0 END) AS resolved_scv_flagged,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'scv_reclassified' THEN variant_count ELSE 0 END) AS resolved_scv_reclassified,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'expert_panel_added' THEN variant_count ELSE 0 END) AS resolved_expert_panel,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'single_submitter_withdrawn' THEN variant_count ELSE 0 END) AS resolved_single_submitter,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'outlier_reclassified' THEN variant_count ELSE 0 END) AS resolved_outlier_reclassified,
  SUM(CASE WHEN change_category = 'Resolution' THEN variant_count ELSE 0 END) AS resolved_total,

  -- Modification counts by reason
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_added' THEN variant_count ELSE 0 END) AS modified_scv_added,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_removed' THEN variant_count ELSE 0 END) AS modified_scv_removed,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_flagged' THEN variant_count ELSE 0 END) AS modified_scv_flagged,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_reclassified' THEN variant_count ELSE 0 END) AS modified_scv_reclassified,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'vcv_rank_changed' THEN variant_count ELSE 0 END) AS modified_vcv_rank_changed,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'outlier_status_changed' THEN variant_count ELSE 0 END) AS modified_outlier_changed,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'conflict_type_changed' THEN variant_count ELSE 0 END) AS modified_conflict_type_changed,
  SUM(CASE WHEN change_category = 'Modification' THEN variant_count ELSE 0 END) AS modified_total

FROM `clinvar_ingest.conflict_resolution_analytics`
GROUP BY snapshot_release_date, prev_snapshot_release_date, conflict_type, outlier_status, conflict_rank_tier
ORDER BY snapshot_release_date, conflict_type, outlier_status, conflict_rank_tier;


-- ============================================================================
-- Part 4: Aggregated Totals (Overall Summary with Rank Tier Breakdown)
-- For high-level trend charts with optional rank tier slicing
-- ============================================================================

CREATE OR REPLACE VIEW `clinvar_ingest.conflict_resolution_overall_trends` AS

WITH baseline AS (
  SELECT
    snapshot_release_date,
    ANY_VALUE(total_path_variants) AS total_path_variants,
    COUNT(*) AS total_conflicts,
    -- Breakdown by rank tier
    COUNTIF(rank = 0) AS conflicts_0_star,
    COUNTIF(rank = 1) AS conflicts_1_star,
    COUNTIF(rank >= 3) AS conflicts_3_4_star
  FROM `clinvar_ingest.monthly_conflict_snapshots`
  GROUP BY snapshot_release_date
)

SELECT
  a.snapshot_release_date,
  a.prev_snapshot_release_date,
  b.total_path_variants,
  b.total_conflicts AS total_active_conflicts,
  b.conflicts_0_star,
  b.conflicts_1_star,
  b.conflicts_3_4_star,

  -- Resolution totals across all categories
  SUM(CASE WHEN change_category = 'Resolution' THEN variant_count ELSE 0 END) AS total_resolved,
  SUM(CASE WHEN change_category = 'Modification' THEN variant_count ELSE 0 END) AS total_modified,

  -- Resolution by rank tier
  SUM(CASE WHEN change_category = 'Resolution' AND conflict_rank_tier = '0-star' THEN variant_count ELSE 0 END) AS resolved_0_star,
  SUM(CASE WHEN change_category = 'Resolution' AND conflict_rank_tier = '1-star' THEN variant_count ELSE 0 END) AS resolved_1_star,
  SUM(CASE WHEN change_category = 'Resolution' AND conflict_rank_tier = '3-4-star' THEN variant_count ELSE 0 END) AS resolved_3_4_star,

  -- Modification by rank tier
  SUM(CASE WHEN change_category = 'Modification' AND conflict_rank_tier = '0-star' THEN variant_count ELSE 0 END) AS modified_0_star,
  SUM(CASE WHEN change_category = 'Modification' AND conflict_rank_tier = '1-star' THEN variant_count ELSE 0 END) AS modified_1_star,
  SUM(CASE WHEN change_category = 'Modification' AND conflict_rank_tier = '3-4-star' THEN variant_count ELSE 0 END) AS modified_3_4_star,

  -- Resolution reason breakdown (overall)
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'scv_removed' THEN variant_count ELSE 0 END) AS resolved_scv_removed,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'scv_flagged' THEN variant_count ELSE 0 END) AS resolved_scv_flagged,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'scv_reclassified' THEN variant_count ELSE 0 END) AS resolved_scv_reclassified,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'expert_panel_added' THEN variant_count ELSE 0 END) AS resolved_expert_panel,
  SUM(CASE WHEN change_category = 'Resolution' AND reason = 'single_submitter_withdrawn' THEN variant_count ELSE 0 END) AS resolved_single_submitter,

  -- Modification reason breakdown (overall)
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_added' THEN variant_count ELSE 0 END) AS modified_scv_added,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_removed' THEN variant_count ELSE 0 END) AS modified_scv_removed,
  SUM(CASE WHEN change_category = 'Modification' AND reason = 'scv_reclassified' THEN variant_count ELSE 0 END) AS modified_scv_reclassified,

  -- Resolution rate
  ROUND(100.0 * SUM(CASE WHEN change_category = 'Resolution' THEN variant_count ELSE 0 END) / NULLIF(b.total_conflicts, 0), 2) AS resolution_rate_pct

FROM `clinvar_ingest.conflict_resolution_analytics` a
LEFT JOIN baseline b ON b.snapshot_release_date = a.prev_snapshot_release_date
GROUP BY a.snapshot_release_date, a.prev_snapshot_release_date, b.total_path_variants, b.total_conflicts, b.conflicts_0_star, b.conflicts_1_star, b.conflicts_3_4_star
ORDER BY a.snapshot_release_date;
