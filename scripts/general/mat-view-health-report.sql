-- ============================================================================
-- Materialized View Health Report  (READ-ONLY)
--
-- Description:
--   Reports whether the BigQuery MATERIALIZED VIEWS (and, optionally, the
--   "materialized" derived TABLES rebuilt by procedures / scheduled queries) in
--   the covered datasets are behind the tables they are built from. One report
--   covers every dataset that matches `dataset_pattern` (default: clinvar_ingest,
--   variation_tracker and every clinvar_curator* dataset); the source tables
--   they read are checked wherever they live, e.g. in release datasets.
--
--   Result set 1 - Materialized views (real BigQuery MVs, auto-discovered):
--     base tables, base-table last-modified times, last refresh time/watermark,
--     auto-refresh settings, refresh errors, health status and a ready-to-run
--     `CALL BQ.REFRESH_MATERIALIZED_VIEW(...)` for every MV that needs one,
--     ordered so an MV built on another MV refreshes after its base.
--
--   Result set 2 - Derived tables (optional, include_derived = TRUE):
--     tables in the covered datasets whose most recent writer job read from a
--     source table that has been modified since the derived table was last
--     written. Lineage comes from INFORMATION_SCHEMA.JOBS referenced_tables,
--     so it only covers tables written within `derived_lookback_days`.
--     Tables labelled `snapshot: frozen` are kept as they are on purpose; they
--     come back with status DERIVED_FROZEN instead of DERIVED_STALE and do not
--     hold up the rebuild order of other tables. To label one:
--       bq update --set_label snapshot:frozen clingen-dev:<dataset>.<table>
--     and to remove the label: bq update --clear_label snapshot ...
--
-- This script only READS metadata (INFORMATION_SCHEMA + per-dataset
-- __TABLES__). It never refreshes, creates, alters or deletes any persistent
-- object; the only writes are to script-scoped TEMP tables that BigQuery drops
-- when the script ends. Run it with:
--
--   bq query --nouse_legacy_sql --project_id=clingen-dev \
--     < scripts/general/mat-view-health-report.sql
--
-- or use the wrapper `scripts/general/mat-view-health.sh` (see
-- docs/sql-scripts/general.md#materialized-view-health-report).
--
-- Why __TABLES__ and not INFORMATION_SCHEMA.TABLE_STORAGE:
--   TABLE_STORAGE.storage_last_modified_time is refreshed asynchronously and
--   was observed lagging real WRITE_TRUNCATE loads by an hour, which would hide
--   staleness. __TABLES__.last_modified_time is current, but it is per dataset
--   and BigQuery rate-limits concurrent __TABLES__ reads, so only the datasets
--   that matter are read, `tables_chunk_size` at a time.
--
-- NOTE: the file name intentionally does NOT end in -proc.sql / -func.sql so
--       CI does not execute it on push.
--
-- Requires: bigquery.jobs.listAll (for JOBS_BY_PROJECT) and metadata read on
--           the datasets involved. Region is hard-coded to `region-us`; the
--           wrapper rewrites it when --region is given.
-- ============================================================================

-- Datasets covered by both result sets (a regular expression on the dataset name).
DECLARE dataset_pattern STRING DEFAULT r'^(clinvar_ingest|variation_tracker|clinvar_curator.*)$';
-- Minutes allowed beyond an MV's refresh_interval_minutes before a stale MV
-- with auto-refresh enabled is reported as STALE_OVERDUE (auto-refresh is
-- best-effort; BigQuery typically refreshes within one interval of a change).
DECLARE grace_minutes INT64 DEFAULT 30;
-- How far back to look in INFORMATION_SCHEMA.JOBS for MV refresh jobs.
DECLARE mv_lookback_days INT64 DEFAULT 30;
-- Derived-table section.
DECLARE include_derived BOOL DEFAULT TRUE;
DECLARE derived_lookback_days INT64 DEFAULT 180;
-- Datasets whose __TABLES__ are read per statement (rate-limit guard).
DECLARE tables_chunk_size INT64 DEFAULT 15;

-- ----------------------------------------------------------------------------
-- Stage 1: materialized views, their options and refresh-job history
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE mv AS
WITH opts AS (
  SELECT
    table_catalog, table_schema, table_name,
    -- BigQuery only lists options that were set explicitly; defaults below.
    COALESCE(MAX(IF(option_name = 'enable_refresh', option_value, NULL)), 'true') = 'true' AS auto_refresh,
    CAST(COALESCE(MAX(IF(option_name = 'refresh_interval_minutes', option_value, NULL)), '30') AS FLOAT64) AS refresh_interval_minutes,
    MAX(IF(option_name = 'max_staleness', option_value, NULL)) AS max_staleness,
    COALESCE(MAX(IF(option_name = 'allow_non_incremental_definition', option_value, NULL)), 'false') = 'true' AS non_incremental
  FROM `region-us`.INFORMATION_SCHEMA.TABLE_OPTIONS
  GROUP BY 1, 2, 3
)
SELECT
  m.table_catalog AS project_id,
  m.table_schema AS dataset_id,
  m.table_name AS mv_name,
  FORMAT('%s.%s.%s', m.table_catalog, m.table_schema, m.table_name) AS mv_fqn,
  m.last_refresh_time,
  m.refresh_watermark,
  m.last_refresh_status.message AS last_refresh_error,
  t.ddl,
  COALESCE(o.auto_refresh, TRUE) AS auto_refresh,
  COALESCE(o.refresh_interval_minutes, 30) AS refresh_interval_minutes,
  o.max_staleness,
  COALESCE(o.non_incremental, FALSE) AS non_incremental
FROM `region-us`.INFORMATION_SCHEMA.MATERIALIZED_VIEWS AS m
JOIN `region-us`.INFORMATION_SCHEMA.TABLES AS t
  USING (table_catalog, table_schema, table_name)
LEFT JOIN opts AS o
  USING (table_catalog, table_schema, table_name)
WHERE REGEXP_CONTAINS(m.table_schema, dataset_pattern);

-- Refresh jobs: automatic ones run as bigquery-adminbot (job ids
-- `materialized_view_refresh_*`); manual ones are CALL BQ.REFRESH_... too.
CREATE TEMP TABLE refresh_job_stats AS
WITH refresh_jobs AS (
  SELECT
    j.creation_time,
    j.error_result,
    j.referenced_tables,
    j.project_id AS job_project,
    REGEXP_EXTRACT(j.query, r"(?i)REFRESH_MATERIALIZED_VIEW\s*\(\s*['\"`]+([^'\"`]+)") AS target
  FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT AS j
  WHERE j.creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL mv_lookback_days DAY)
    AND j.job_type = 'QUERY'
    AND j.statement_type = 'CALL'
    AND REGEXP_CONTAINS(j.query, r'(?i)REFRESH_MATERIALIZED_VIEW')
),
refresh_jobs_norm AS (
  SELECT
    rj.* EXCEPT (target),
    IF(ARRAY_LENGTH(SPLIT(rj.target, '.')) = 2, CONCAT(rj.job_project, '.', rj.target), rj.target) AS mv_fqn,
    -- "Materialized view is already being refreshed" = two refreshes collided;
    -- harmless, so it is not counted as a failure.
    COALESCE(REGEXP_CONTAINS(rj.error_result.message, r'(?i)already being refreshed'), FALSE) AS is_collision
  FROM refresh_jobs AS rj
  WHERE rj.target IS NOT NULL
)
SELECT
  mv_fqn,
  COUNTIF(NOT is_collision) AS refresh_jobs_in_window,
  COUNTIF(error_result IS NOT NULL AND NOT is_collision) AS failed_refresh_jobs_in_window,
  ARRAY_AGG(IF(is_collision, NULL, STRUCT(creation_time, error_result.message AS error))
            IGNORE NULLS ORDER BY creation_time DESC LIMIT 1)[SAFE_OFFSET(0)] AS latest_job,
  ARRAY_AGG(IF(error_result IS NULL, STRUCT(referenced_tables AS refs), NULL) IGNORE NULLS
            ORDER BY creation_time DESC LIMIT 1)[SAFE_OFFSET(0)].refs AS latest_ok_refs
FROM refresh_jobs_norm
GROUP BY mv_fqn;

-- Base tables: preferred source is the most recent successful refresh job's
-- referenced_tables (exactly what BigQuery read); fallback is a parse of the
-- MV DDL's FROM / JOIN targets for MVs with no refresh job in the window.
CREATE TEMP TABLE mv_bases AS
WITH from_jobs AS (
  SELECT DISTINCT
    s.mv_fqn,
    FORMAT('%s.%s.%s', r.project_id, r.dataset_id, r.table_id) AS base_fqn,
    'refresh job' AS lineage_source
  FROM refresh_job_stats AS s
  CROSS JOIN UNNEST(s.latest_ok_refs) AS r
  WHERE FORMAT('%s.%s.%s', r.project_id, r.dataset_id, r.table_id) != s.mv_fqn
    AND NOT STARTS_WITH(r.table_id, 'INFORMATION_SCHEMA')
)
SELECT * FROM from_jobs
UNION ALL
SELECT DISTINCT
  mv.mv_fqn,
  IF(ARRAY_LENGTH(SPLIT(ref, '.')) = 2, CONCAT(mv.project_id, '.', ref), ref) AS base_fqn,
  'ddl parse' AS lineage_source
FROM mv
CROSS JOIN UNNEST(REGEXP_EXTRACT_ALL(
  REGEXP_REPLACE(REPLACE(mv.ddl, '`', ''), r'--[^\n]*', ''),
  r'(?i)\b(?:FROM|JOIN)\s+([A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+){1,2})'
)) AS ref
WHERE mv.mv_fqn NOT IN (SELECT mv_fqn FROM from_jobs);

-- ----------------------------------------------------------------------------
-- Stage 2: writer jobs for derived tables (empty when include_derived = FALSE)
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE derived_jobs AS
SELECT
  j.job_id,
  j.parent_job_id,
  j.end_time,
  j.query,
  j.referenced_tables,
  FORMAT('%s.%s.%s', j.destination_table.project_id, j.destination_table.dataset_id,
         j.destination_table.table_id) AS dest_fqn
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT AS j
WHERE include_derived
  AND j.creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL derived_lookback_days DAY)
  AND j.job_type = 'QUERY'
  AND j.state = 'DONE'
  AND j.error_result IS NULL
  AND REGEXP_CONTAINS(j.destination_table.dataset_id, dataset_pattern)
  AND j.statement_type IN ('SELECT', 'CREATE_TABLE_AS_SELECT', 'INSERT', 'MERGE', 'UPDATE');

CREATE TEMP TABLE derived_latest AS
SELECT
  dest_fqn,
  ARRAY_AGG(STRUCT(job_id, parent_job_id, end_time, query)
            ORDER BY end_time DESC LIMIT 1)[OFFSET(0)] AS w
FROM derived_jobs
GROUP BY dest_fqn;

-- All writes to the table from the same script/procedure run (or the single
-- job) contribute sources; e.g. CTAS followed by UPDATE.
CREATE TEMP TABLE derived_sources AS
SELECT DISTINCT
  lw.dest_fqn,
  FORMAT('%s.%s.%s', r.project_id, r.dataset_id, r.table_id) AS src_fqn
FROM derived_latest AS lw
JOIN derived_jobs AS j
  ON j.dest_fqn = lw.dest_fqn
 AND COALESCE(j.parent_job_id, j.job_id) = COALESCE(lw.w.parent_job_id, lw.w.job_id)
CROSS JOIN UNNEST(j.referenced_tables) AS r
WHERE NOT STARTS_WITH(r.table_id, 'INFORMATION_SCHEMA')
  AND NOT STARTS_WITH(r.dataset_id, '_')
  AND FORMAT('%s.%s.%s', r.project_id, r.dataset_id, r.table_id) != lw.dest_fqn;

-- Snapshots that are meant to stay as they are (label snapshot=frozen).
CREATE TEMP TABLE frozen_tables AS
SELECT FORMAT('%s.%s.%s', table_catalog, table_schema, table_name) AS fqn
FROM `region-us`.INFORMATION_SCHEMA.TABLE_OPTIONS
WHERE include_derived
  AND option_name = 'labels'
  AND REGEXP_CONTAINS(table_schema, dataset_pattern)
  AND REGEXP_CONTAINS(option_value, r'STRUCT\("snapshot", "frozen"\)');

-- ----------------------------------------------------------------------------
-- Stage 3: current last-modified time of every table involved (__TABLES__)
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE table_mod (fqn STRING, table_type INT64, last_modified TIMESTAMP);

FOR chunk IN (
  WITH fqns AS (
    SELECT mv_fqn AS fqn FROM mv
    UNION ALL SELECT base_fqn FROM mv_bases
    UNION ALL SELECT dest_fqn FROM derived_latest
    UNION ALL SELECT src_fqn FROM derived_sources
  ),
  ds AS (
    SELECT DISTINCT s.catalog_name AS p, s.schema_name AS d
    FROM fqns
    JOIN `region-us`.INFORMATION_SCHEMA.SCHEMATA AS s
      ON s.catalog_name = SPLIT(fqns.fqn, '.')[SAFE_OFFSET(0)]
     AND s.schema_name = SPLIT(fqns.fqn, '.')[SAFE_OFFSET(1)]
  ),
  numbered AS (
    SELECT p, d, DIV(ROW_NUMBER() OVER (ORDER BY p, d) - 1, tables_chunk_size) AS n
    FROM ds
  )
  SELECT
    n,
    STRING_AGG(FORMAT(
      "SELECT CONCAT('%s.%s.', table_id), type, TIMESTAMP_MILLIS(last_modified_time) FROM `%s.%s.__TABLES__`",
      p, d, p, d), ' UNION ALL ') AS q
  FROM numbered
  GROUP BY n
)
DO
  EXECUTE IMMEDIATE CONCAT('INSERT INTO table_mod ', chunk.q);
END FOR;

-- ----------------------------------------------------------------------------
-- Result set 1: materialized views
-- ----------------------------------------------------------------------------
WITH RECURSIVE
base_status AS (
  SELECT
    b.mv_fqn,
    b.base_fqn,
    b.lineage_source,
    CASE tm.table_type WHEN 1 THEN 'TABLE' WHEN 2 THEN 'VIEW' WHEN 3 THEN 'EXTERNAL' END AS base_type,
    tm.last_modified AS base_last_modified,
    tm.fqn IS NULL AS base_missing,
    COALESCE(tm.last_modified > COALESCE(mv.refresh_watermark, mv.last_refresh_time), FALSE) AS changed_since_refresh,
    mv2.mv_fqn IS NOT NULL AS base_is_mv
  FROM mv_bases AS b
  JOIN mv ON mv.mv_fqn = b.mv_fqn
  LEFT JOIN table_mod AS tm ON tm.fqn = b.base_fqn
  LEFT JOIN mv AS mv2 ON mv2.mv_fqn = b.base_fqn
),
-- MV -> MV dependency closure (an MV built on another MV).
mv_ancestors AS (
  SELECT mv_fqn, base_fqn AS ancestor_fqn, 1 AS depth
  FROM base_status
  WHERE base_is_mv
  UNION ALL
  SELECT a.mv_fqn, bs.base_fqn, a.depth + 1
  FROM mv_ancestors AS a
  JOIN base_status AS bs ON bs.mv_fqn = a.ancestor_fqn AND bs.base_is_mv
  WHERE a.depth < 20
),
base_agg AS (
  SELECT
    mv_fqn,
    ARRAY_AGG(STRUCT(
      base_fqn AS base_table,
      base_type,
      base_last_modified,
      changed_since_refresh,
      base_missing
    ) ORDER BY base_last_modified DESC) AS base_tables,
    ANY_VALUE(lineage_source) AS lineage_source,
    MAX(base_last_modified) AS newest_base_change,
    MIN(IF(changed_since_refresh, base_last_modified, NULL)) AS stale_since,
    COUNTIF(changed_since_refresh) AS changed_base_count,
    COUNTIF(base_missing) AS missing_base_count
  FROM base_status
  GROUP BY mv_fqn
),
depth_agg AS (
  SELECT mv_fqn, MAX(depth) AS refresh_order
  FROM mv_ancestors
  GROUP BY mv_fqn
),
mv_eval AS (
  SELECT
    mv.*,
    rs.refresh_jobs_in_window,
    rs.failed_refresh_jobs_in_window,
    COALESCE(mv.last_refresh_error, rs.latest_job.error) AS refresh_error,
    ba.base_tables,
    ba.lineage_source,
    ba.newest_base_change,
    ba.stale_since,
    COALESCE(ba.changed_base_count, 0) AS changed_base_count,
    COALESCE(ba.missing_base_count, 0) AS missing_base_count,
    COALESCE(da.refresh_order, 0) AS refresh_order
  FROM mv
  LEFT JOIN refresh_job_stats AS rs ON rs.mv_fqn = mv.mv_fqn
  LEFT JOIN base_agg AS ba ON ba.mv_fqn = mv.mv_fqn
  LEFT JOIN depth_agg AS da ON da.mv_fqn = mv.mv_fqn
),
mv_status AS (
  SELECT
    e.*,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), e.stale_since, MINUTE) AS minutes_stale,
    CASE
      WHEN e.missing_base_count > 0 THEN 'BROKEN'
      WHEN e.refresh_error IS NOT NULL THEN 'REFRESH_FAILED'
      WHEN e.changed_base_count > 0 AND NOT e.auto_refresh THEN 'STALE_MANUAL'
      WHEN e.changed_base_count > 0
        AND TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), e.stale_since, MINUTE)
            > e.refresh_interval_minutes + grace_minutes THEN 'STALE_OVERDUE'
      WHEN e.changed_base_count > 0 THEN 'STALE'
      ELSE 'OK'
    END AS own_status
  FROM mv_eval AS e
),
upstream_agg AS (
  -- An MV whose upstream MV needs a refresh needs one too (afterwards).
  SELECT a.mv_fqn, ARRAY_AGG(DISTINCT a.ancestor_fqn) AS stale_upstream_mvs
  FROM mv_ancestors AS a
  JOIN mv_status AS up ON up.mv_fqn = a.ancestor_fqn
  WHERE up.own_status NOT IN ('OK', 'BROKEN')
  GROUP BY a.mv_fqn
),
mv_final AS (
  SELECT
    s.*,
    COALESCE(u.stale_upstream_mvs, []) AS stale_upstream_mvs
  FROM mv_status AS s
  LEFT JOIN upstream_agg AS u ON u.mv_fqn = s.mv_fqn
)
SELECT
  CASE
    WHEN own_status = 'OK' AND ARRAY_LENGTH(stale_upstream_mvs) > 0 THEN 'STALE_UPSTREAM'
    ELSE own_status
  END AS status,
  refresh_order,
  mv_fqn AS materialized_view,
  last_refresh_time,
  refresh_watermark,
  newest_base_change,
  stale_since,
  minutes_stale,
  changed_base_count,
  auto_refresh,
  refresh_interval_minutes,
  max_staleness,
  non_incremental,
  refresh_jobs_in_window,
  failed_refresh_jobs_in_window,
  refresh_error,
  stale_upstream_mvs,
  lineage_source,
  base_tables,
  CASE
    WHEN own_status = 'BROKEN' THEN '-- base table missing: re-create the MV from its source script'
    WHEN own_status != 'OK' OR ARRAY_LENGTH(stale_upstream_mvs) > 0
      THEN FORMAT("CALL BQ.REFRESH_MATERIALIZED_VIEW('%s');", mv_fqn)
  END AS refresh_sql
FROM mv_final
ORDER BY
  CASE status
    WHEN 'BROKEN' THEN 0 WHEN 'REFRESH_FAILED' THEN 1 WHEN 'STALE_OVERDUE' THEN 2
    WHEN 'STALE_MANUAL' THEN 3 WHEN 'STALE' THEN 4 WHEN 'STALE_UPSTREAM' THEN 4 ELSE 5 END,
  refresh_order,
  materialized_view;

-- ----------------------------------------------------------------------------
-- Result set 2: derived ("materialized") tables rebuilt by procedures /
-- scheduled queries
-- ----------------------------------------------------------------------------
IF include_derived THEN

  WITH RECURSIVE
  src_status AS (
    SELECT
      s.dest_fqn,
      s.src_fqn,
      ss.last_modified AS src_last_modified,
      ds.last_modified AS dest_last_modified,
      COALESCE(ss.last_modified > ds.last_modified, FALSE) AS changed_since_build
    FROM derived_sources AS s
    JOIN table_mod AS ds ON ds.fqn = s.dest_fqn AND ds.table_type = 1
    LEFT JOIN table_mod AS ss ON ss.fqn = s.src_fqn
  ),
  stale AS (
    SELECT
      dest_fqn,
      dest_fqn IN (SELECT fqn FROM frozen_tables) AS frozen,
      ANY_VALUE(dest_last_modified) AS last_built,
      MAX(src_last_modified) AS newest_source_change,
      ARRAY_AGG(STRUCT(src_fqn AS source_table, src_last_modified AS source_last_modified)
                ORDER BY src_last_modified DESC) AS changed_sources
    FROM src_status
    WHERE changed_since_build
    GROUP BY dest_fqn
  ),
  -- Rebuild order among stale derived tables (a table whose changed source
  -- is itself a stale derived table is rebuilt after it). A frozen table will
  -- not be rebuilt, so nothing waits on it.
  edges AS (
    SELECT DISTINCT s.dest_fqn, cs.source_table AS upstream_fqn
    FROM stale AS s
    CROSS JOIN UNNEST(s.changed_sources) AS cs
    JOIN stale AS up ON up.dest_fqn = cs.source_table AND NOT up.frozen
  ),
  depth AS (
    SELECT dest_fqn, upstream_fqn, 1 AS d FROM edges
    UNION ALL
    SELECT dp.dest_fqn, e.upstream_fqn, dp.d + 1
    FROM depth AS dp
    JOIN edges AS e ON e.dest_fqn = dp.upstream_fqn
    WHERE dp.d < 10
  ),
  depth_agg AS (
    SELECT dest_fqn, MAX(d) AS rebuild_order FROM depth GROUP BY dest_fqn
  ),
  parent_jobs AS (
    SELECT job_id, query
    FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
    WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL derived_lookback_days DAY)
      AND statement_type = 'SCRIPT'
      AND job_id IN (SELECT w.parent_job_id FROM derived_latest)
  )
  SELECT
    IF(s.frozen, 'DERIVED_FROZEN', 'DERIVED_STALE') AS status,
    COALESCE(da.rebuild_order, 0) AS rebuild_order,
    s.dest_fqn AS derived_table,
    s.last_built,
    s.newest_source_change,
    TIMESTAMP_DIFF(s.newest_source_change, s.last_built, HOUR) AS hours_behind,
    s.changed_sources,
    CASE
      WHEN STARTS_WITH(lw.w.job_id, 'scheduled_query_') THEN 'scheduled query (runs automatically)'
      WHEN lw.w.parent_job_id IS NOT NULL
        THEN CONCAT('script/proc: ', LEFT(REGEXP_REPLACE(pj.query, r'\s+', ' '), 160))
      ELSE CONCAT('query: ', LEFT(REGEXP_REPLACE(lw.w.query, r'\s+', ' '), 160))
    END AS last_built_by
  FROM stale AS s
  JOIN derived_latest AS lw ON lw.dest_fqn = s.dest_fqn
  LEFT JOIN depth_agg AS da ON da.dest_fqn = s.dest_fqn
  LEFT JOIN parent_jobs AS pj ON pj.job_id = lw.w.parent_job_id
  ORDER BY s.frozen, rebuild_order, derived_table;

END IF;
