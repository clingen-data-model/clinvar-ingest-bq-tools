# CVC Impact Analysis Refresh Procedure

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual TSV-based `batch_accepted_date` workflow with a single BigQuery stored procedure that rebuilds all 14 materialized CVC impact analysis tables in dependency order, callable from Google Apps Script after batch finalization.

**Architecture:** The `cvc_batches_enriched` view will use `batch_end_date` from `cvc_clinvar_batches` directly instead of LEFT JOINing `cvc_batch_accepted_dates`. A new stored procedure `clinvar_curator.refresh_cvc_impact_analysis()` will contain all 14 `CREATE OR REPLACE TABLE` statements in dependency order. The existing Apps Script that finalizes batches will call this procedure via the BigQuery API.

**Tech Stack:** BigQuery SQL (stored procedures), Google Apps Script (BigQuery API)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `scripts/clinvar-curation/cvc-impact-analysis/00-cvc-batch-enriched-view.sql` | Modify | Remove `cvc_batch_accepted_dates` dependency, use `batch_end_date` directly |
| `scripts/clinvar-curation/cvc-impact-analysis/09-refresh-cvc-impact-analysis.sql` | Create | Stored procedure wrapping all 14 table materializations |
| `scripts/clinvar-curation/cvc-impact-analysis/00-run-cvc-impact-analysis.sh` | Modify | Remove TSV loading for batch-accepted-dates, add option to call the stored proc |
| `scripts/clinvar-curation/cvc-impact-analysis/batch-accepted-dates.tsv` | Delete | No longer needed — replaced by `batch_end_date` |
| `scripts/clinvar-curation/cvc-impact-analysis/load-batch-accepted-dates.sh` | Delete | No longer needed |
| `scripts/clinvar-curation/cvc-impact-analysis/appscript-refresh-impact.js` | Create | Apps Script snippet to call the stored procedure after batch finalization |

---

## Chunk 1: Replace batch_accepted_date source

### Task 1: Modify the batch enriched view

**Files:**
- Modify: `scripts/clinvar-curation/cvc-impact-analysis/00-cvc-batch-enriched-view.sql`

The `cvc_batches_enriched` view currently LEFT JOINs `cvc_batch_accepted_dates` to get the accepted date. Replace this with `batch_end_date` from `cvc_clinvar_batches` directly.

- [ ] **Step 1: Rewrite the view SQL**

Replace the entire contents of `00-cvc-batch-enriched-view.sql` with:

```sql
-- =============================================================================
-- CVC Batch Enriched View
-- =============================================================================
--
-- Purpose:
--   Creates a view that enriches cvc_clinvar_batches with:
--   - batch_accepted_date: Derived from batch_end_date (when ClinVar accepted the batch)
--   - grace_period_end_date: 60 days after acceptance (when flags are applied)
--   - first_release_after_grace_period: The next ClinVar release after grace ends
--
-- Dependencies:
--   - clinvar_curator.cvc_clinvar_batches
--   - clinvar_ingest.clinvar_releases
--
-- Note: batch_end_date in cvc_clinvar_batches is the date ClinVar accepted/processed
-- the batch. Previously this was maintained in a separate cvc_batch_accepted_dates
-- table loaded from a TSV file; now uses the source table directly.
--
-- Output:
--   - clinvar_curator.cvc_batches_enriched
--
-- =============================================================================

CREATE OR REPLACE VIEW `clinvar_curator.cvc_batches_enriched`
AS
SELECT
  b.batch_id,
  b.finalized_datetime,
  b.batch_release_date,
  b.batch_start_date,
  b.batch_end_date,
  b.submission,
  -- batch_end_date IS the accepted date (previously from separate TSV table)
  b.batch_end_date AS batch_accepted_date,
  -- 60-day grace period ends on this date
  DATE_ADD(b.batch_end_date, INTERVAL 60 DAY) AS grace_period_end_date,
  -- The first ClinVar release after the grace period ends
  (
    SELECT MIN(release_date)
    FROM `clinvar_ingest.clinvar_releases`
    WHERE release_date > DATE_ADD(b.batch_end_date, INTERVAL 60 DAY)
  ) AS first_release_after_grace_period
FROM `clinvar_curator.cvc_clinvar_batches` b
WHERE b.batch_end_date IS NOT NULL
ORDER BY b.batch_id;
```

Key changes:
- Removed `LEFT JOIN clinvar_curator.cvc_batch_accepted_dates`
- Uses `b.batch_end_date` as the source for `batch_accepted_date`
- Added `WHERE b.batch_end_date IS NOT NULL` to prevent NULL dates from silently breaking downstream grace period logic
- Removed `acceptance_notes` column (no longer a separate table with notes)
- Updated header comments

- [ ] **Step 2: Verify the view creates without errors**

Run in BigQuery console:
```sql
-- Run the CREATE OR REPLACE VIEW statement from the file
-- Then verify:
SELECT batch_id, batch_accepted_date, grace_period_end_date
FROM `clinvar_curator.cvc_batches_enriched`
ORDER BY batch_id;
```

Expected: All batches with non-NULL `batch_accepted_date`. Batches where `batch_end_date` is NULL in `cvc_clinvar_batches` are excluded from the view (and therefore from all downstream analysis). Verify no expected batches are missing:

```sql
-- Check for batches excluded due to NULL batch_end_date
SELECT batch_id, finalized_datetime, batch_end_date
FROM `clinvar_curator.cvc_clinvar_batches`
WHERE batch_end_date IS NULL;
```

If any finalized batches show up, their `batch_end_date` must be populated before the pipeline will include them.

- [ ] **Step 3: Commit**

```bash
git add scripts/clinvar-curation/cvc-impact-analysis/00-cvc-batch-enriched-view.sql
git commit -m "refactor: use batch_end_date directly instead of separate accepted dates table"
```

### Task 2: Remove the TSV-based accepted dates pipeline

**Files:**
- Delete: `scripts/clinvar-curation/cvc-impact-analysis/batch-accepted-dates.tsv`
- Delete: `scripts/clinvar-curation/cvc-impact-analysis/load-batch-accepted-dates.sh`

- [ ] **Step 1: Delete the files**

```bash
cd scripts/clinvar-curation/cvc-impact-analysis
git rm batch-accepted-dates.tsv
git rm load-batch-accepted-dates.sh
```

- [ ] **Step 2: Commit**

```bash
git commit -m "remove: batch-accepted-dates.tsv and loader script, replaced by batch_end_date"
```

### Task 3: Update the pipeline shell script

**Files:**
- Modify: `scripts/clinvar-curation/cvc-impact-analysis/00-run-cvc-impact-analysis.sh`

Remove the batch-accepted-dates loading from Phase 1 and the stale-check logic that references it.

- [ ] **Step 1: Remove the batch-accepted-dates stale check**

In the `check_rebuild_needed()` function, remove the block that checks `batch-accepted-dates.tsv` row count vs `cvc_batch_accepted_dates` table (approximately lines 198-210):

```bash
# Delete this block:
    if [ -f "$batch_dates_file" ]; then
        local file_lines=$(grep -v "^#" "$batch_dates_file" | grep -v "^$" | grep -v "^batch_id" | wc -l | tr -d ' ')
        local table_rows=$(bq query --use_legacy_sql=false --format=csv --quiet \
            "SELECT COUNT(*) FROM \`$PROJECT.clinvar_curator.cvc_batch_accepted_dates\`" 2>/dev/null | tail -1)
        if [ "$file_lines" != "$table_rows" ] 2>/dev/null; then
            log_info "batch-accepted-dates.tsv has different row count than table ($file_lines vs $table_rows). Rebuild needed."
            return 0
        fi
    fi
```

Also remove the `local batch_dates_file=...` variable declaration.

- [ ] **Step 2: Remove the batch-accepted-dates loader call from Phase 1**

In the Phase 1 section, remove:
```bash
        # Load batch accepted dates
        run_loader "$SCRIPT_DIR/load-batch-accepted-dates.sh" \
            "Loading batch-accepted-dates.tsv"
        echo ""
```

- [ ] **Step 3: Update comments referencing the TSV/table**

Update pipeline step comments:
- Phase 1 header comment: remove mention of `cvc_batch_accepted_dates`
- Phase 3 Step 0 comment: change from "depends on cvc_batch_accepted_dates from Phase 1" to "uses batch_end_date from cvc_clinvar_batches directly"

- [ ] **Step 4: Commit**

```bash
git add scripts/clinvar-curation/cvc-impact-analysis/00-run-cvc-impact-analysis.sh
git commit -m "refactor: remove batch-accepted-dates TSV loading from pipeline script"
```

---

## Chunk 2: Create the stored procedure

### Task 4: Create the refresh stored procedure

**Files:**
- Create: `scripts/clinvar-curation/cvc-impact-analysis/09-refresh-cvc-impact-analysis.sql`

This procedure rebuilds all 14 materialized tables in dependency order. Each phase's tables are independent of each other but depend on previous phases.

- [ ] **Step 1: Create the stored procedure SQL file**

Create `scripts/clinvar-curation/cvc-impact-analysis/09-refresh-cvc-impact-analysis.sql` with the following structure:

```sql
-- =============================================================================
-- CVC Impact Analysis Refresh Procedure
-- =============================================================================
--
-- Purpose:
--   Rebuilds all 14 materialized tables in the CVC Impact Analysis pipeline
--   in dependency order. Also recreates the cvc_batches_enriched view to
--   ensure it reflects current batch_end_date values.
--
--   Designed to be called from Google Apps Script after batch finalization,
--   or manually via BigQuery console.
--
--   NOTE: The cvc_batches_enriched VIEW must be deployed separately
--   (via 00-cvc-batch-enriched-view.sql) before this procedure is called.
--   BigQuery stored procedures do not reliably support CREATE OR REPLACE VIEW
--   inside BEGIN/END blocks. The view is schema-stable and only needs to be
--   deployed once — it reads batch_end_date from cvc_clinvar_batches live.
--
-- Usage:
--   CALL `clinvar_curator.refresh_cvc_impact_analysis`();
--
-- Dependency Order:
--   Phase 1 (independent):
--     - 01: cvc_submitted_variants
--     - 04: cvc_flagging_candidate_outcomes, cvc_remove_flagged_outcomes
--     - 05: cvc_version_bumps
--     - 05f: cvc_full_record_version_bumps
--
--   Phase 2 (depends on Phase 1):
--     - 02: cvc_variant_conflict_history, cvc_resolution_attribution
--     - 06: cvc_flagging_version_bump_intersection
--     - 07: cvc_resubmission_candidates
--     - 08: cvc_autoreflag_candidates
--
--   Phase 3 (depends on Phase 2):
--     - 03: cvc_impact_summary, cvc_batch_effectiveness,
--           cvc_reason_effectiveness, cvc_bulk_downgrade_exclusions
--
-- Output:
--   All 14 materialized tables and their dependent views are rebuilt.
--   The procedure returns a status message.
--
-- =============================================================================

CREATE OR REPLACE PROCEDURE `clinvar_curator.refresh_cvc_impact_analysis`()
BEGIN
  DECLARE phase_start TIMESTAMP;
  DECLARE phase_end TIMESTAMP;

  -- =========================================================================
  -- Phase 1: Independent tables (no cross-dependencies)
  -- =========================================================================
  -- NOTE: cvc_batches_enriched VIEW is deployed separately via
  -- 00-cvc-batch-enriched-view.sql. It reads batch_end_date live from
  -- cvc_clinvar_batches, so no refresh is needed here.
  SET phase_start = CURRENT_TIMESTAMP();

  -- Step 01: CVC Submitted Variants
  -- (paste full SQL from 01-cvc-submitted-variants.sql CREATE TABLE statement)

  -- Step 04: Flagging Candidate Outcomes + Remove Flagged Outcomes
  -- (paste full SQL from 04-flagging-candidate-outcomes.sql CREATE TABLE statements)

  -- Step 05: Version Bump Detection
  -- (paste full SQL from 05-version-bump-detection.sql CREATE TABLE statement)

  -- Step 05f: Full Record Version Bump Detection
  -- (paste full SQL from full-record-version-bump-detection.sql CREATE TABLE statement)

  SET phase_end = CURRENT_TIMESTAMP();

  -- =========================================================================
  -- Phase 2: Tables depending on Phase 1
  -- =========================================================================
  SET phase_start = CURRENT_TIMESTAMP();

  -- Step 02: Conflict Attribution
  -- (paste full SQL from 02-cvc-conflict-attribution.sql CREATE TABLE statements)

  -- Step 06: Version Bump Flagging Intersection
  -- (paste full SQL from 06-version-bump-flagging-intersection.sql CREATE TABLE statement)

  -- Step 07: Resubmission Candidates
  -- (paste full SQL from 07-resubmission-candidates.sql CREATE TABLE statement)

  -- Step 08: Auto-Reflag Candidates
  -- (paste full SQL from 08-autoreflag-candidates.sql CREATE TABLE statement)

  SET phase_end = CURRENT_TIMESTAMP();

  -- =========================================================================
  -- Phase 3: Tables depending on Phase 2
  -- =========================================================================
  SET phase_start = CURRENT_TIMESTAMP();

  -- Step 03: Impact Analytics
  -- (paste full SQL from 03-cvc-impact-analytics.sql CREATE TABLE statements)

  SET phase_end = CURRENT_TIMESTAMP();

END;
```

**IMPORTANT implementation note:** Each `-- (paste full SQL ...)` placeholder must be replaced with the actual `CREATE OR REPLACE TABLE ... AS ...` statement from the corresponding script file. Only the TABLE statements — not the VIEW statements — need to be included, since views update automatically. However, the views in scripts 05, 06, 07, and 08 should also be included since they are `CREATE OR REPLACE VIEW` statements that may have been updated.

The procedure file will be large (~1500-2000 lines) since it contains all the SQL inline. This is intentional — a single self-contained procedure is easier to maintain than one that calls sub-procedures.

- [ ] **Step 2: Populate Phase 1 SQL**

Copy the `CREATE OR REPLACE TABLE` statements (and their CTEs) from:
- `01-cvc-submitted-variants.sql` (1 table)
- `04-flagging-candidate-outcomes.sql` (2 tables: `cvc_flagging_candidate_outcomes`, `cvc_remove_flagged_outcomes`)
- `05-version-bump-detection.sql` (1 table: `cvc_version_bumps`)
- `full-record-version-bump-detection.sql` (1 table: `cvc_full_record_version_bumps`)

- [ ] **Step 3: Populate Phase 2 SQL**

Copy the `CREATE OR REPLACE TABLE` statements from:
- `02-cvc-conflict-attribution.sql` (2 tables: `cvc_variant_conflict_history`, `cvc_resolution_attribution`)
- `06-version-bump-flagging-intersection.sql` (1 table: `cvc_flagging_version_bump_intersection`)
- `07-resubmission-candidates.sql` (1 table: `cvc_resubmission_candidates`)
- `08-autoreflag-candidates.sql` (1 table: `cvc_autoreflag_candidates`)

- [ ] **Step 4: Populate Phase 3 SQL**

Copy the `CREATE OR REPLACE TABLE` statements from:
- `03-cvc-impact-analytics.sql` (4 tables: `cvc_impact_summary`, `cvc_batch_effectiveness`, `cvc_reason_effectiveness`, `cvc_bulk_downgrade_exclusions`)

- [ ] **Step 5: Deploy the procedure to BigQuery**

```bash
bq query --use_legacy_sql=false < scripts/clinvar-curation/cvc-impact-analysis/09-refresh-cvc-impact-analysis.sql
```

Expected: Procedure created successfully.

- [ ] **Step 6: Test the procedure**

```sql
CALL `clinvar_curator.refresh_cvc_impact_analysis`();
```

Expected: All 14 tables rebuilt without errors. Verify by checking row counts:

```sql
SELECT 'cvc_submitted_variants' AS t, COUNT(*) AS rows FROM `clinvar_curator.cvc_submitted_variants`
UNION ALL SELECT 'cvc_flagging_candidate_outcomes', COUNT(*) FROM `clinvar_curator.cvc_flagging_candidate_outcomes`
UNION ALL SELECT 'cvc_remove_flagged_outcomes', COUNT(*) FROM `clinvar_curator.cvc_remove_flagged_outcomes`
UNION ALL SELECT 'cvc_version_bumps', COUNT(*) FROM `clinvar_curator.cvc_version_bumps`
UNION ALL SELECT 'cvc_full_record_version_bumps', COUNT(*) FROM `clinvar_curator.cvc_full_record_version_bumps`
UNION ALL SELECT 'cvc_variant_conflict_history', COUNT(*) FROM `clinvar_curator.cvc_variant_conflict_history`
UNION ALL SELECT 'cvc_resolution_attribution', COUNT(*) FROM `clinvar_curator.cvc_resolution_attribution`
UNION ALL SELECT 'cvc_flagging_version_bump_intersection', COUNT(*) FROM `clinvar_curator.cvc_flagging_version_bump_intersection`
UNION ALL SELECT 'cvc_resubmission_candidates', COUNT(*) FROM `clinvar_curator.cvc_resubmission_candidates`
UNION ALL SELECT 'cvc_autoreflag_candidates', COUNT(*) FROM `clinvar_curator.cvc_autoreflag_candidates`
UNION ALL SELECT 'cvc_impact_summary', COUNT(*) FROM `clinvar_curator.cvc_impact_summary`
UNION ALL SELECT 'cvc_batch_effectiveness', COUNT(*) FROM `clinvar_curator.cvc_batch_effectiveness`
UNION ALL SELECT 'cvc_reason_effectiveness', COUNT(*) FROM `clinvar_curator.cvc_reason_effectiveness`
UNION ALL SELECT 'cvc_bulk_downgrade_exclusions', COUNT(*) FROM `clinvar_curator.cvc_bulk_downgrade_exclusions`;
```

- [ ] **Step 7: Commit**

```bash
git add scripts/clinvar-curation/cvc-impact-analysis/09-refresh-cvc-impact-analysis.sql
git commit -m "feat: add stored procedure to refresh all CVC impact analysis tables"
```

---

## Chunk 3: Apps Script integration

### Task 5: Create the Apps Script snippet for calling the procedure

**Files:**
- Create: `scripts/clinvar-curation/cvc-impact-analysis/appscript-refresh-impact.js`

This is a reference snippet to be added to the existing Apps Script that finalizes batches. It uses the BigQuery API (Advanced Service) to call the stored procedure.

- [ ] **Step 1: Create the Apps Script file**

Create `scripts/clinvar-curation/cvc-impact-analysis/appscript-refresh-impact.js`:

```javascript
/**
 * CVC Impact Analysis Refresh — Apps Script Integration
 *
 * Add this to the existing Apps Script that finalizes batches.
 * Call refreshCvcImpactAnalysis() after the batch is finalized
 * and cvc_clinvar_batches is updated.
 *
 * SETUP:
 * 1. In the Apps Script editor, go to Services > Add a service > BigQuery API (v2)
 * 2. Add this code to the existing script
 * 3. Call refreshCvcImpactAnalysis() after batch finalization
 *
 * The procedure takes 2-5 minutes to run. It rebuilds all 14 materialized
 * tables in the CVC Impact Analysis pipeline in dependency order.
 *
 * Uses Jobs.insert (async) instead of Jobs.query (sync) since the procedure
 * runs longer than the Apps Script UI timeout. The job is submitted, then
 * polled for completion.
 */

const IMPACT_CONFIG = {
  PROJECT_ID: 'clingen-dev',
  PROCEDURE: 'CALL `clinvar_curator.refresh_cvc_impact_analysis`()'
};

/**
 * Calls the BigQuery stored procedure to refresh all CVC impact analysis tables.
 * Designed to be called after batch finalization.
 *
 * Submits the job asynchronously and polls for completion.
 *
 * @returns {boolean} true if successful, false if failed
 */
function refreshCvcImpactAnalysis() {
  const ui = SpreadsheetApp.getUi();

  try {
    const confirm = ui.alert(
      'Refresh Impact Analysis?',
      'This will rebuild all CVC impact analysis tables (2-5 minutes).\n\n' +
      'Continue?',
      ui.ButtonSet.YES_NO
    );

    if (confirm !== ui.Button.YES) return false;

    // Submit the job asynchronously via Jobs.insert
    const job = {
      configuration: {
        query: {
          query: IMPACT_CONFIG.PROCEDURE,
          useLegacySql: false
        }
      }
    };

    const response = BigQuery.Jobs.insert(job, IMPACT_CONFIG.PROJECT_ID);
    const jobId = response.jobReference.jobId;

    Logger.log('Submitted impact analysis refresh job: ' + jobId);

    // Poll for completion
    return pollForCompletion(jobId);

  } catch (error) {
    ui.alert(
      'Refresh Failed',
      'Error refreshing impact analysis tables:\n\n' + error.message +
      '\n\nTry running manually in BigQuery console:\n' +
      IMPACT_CONFIG.PROCEDURE,
      ui.ButtonSet.OK
    );
    Logger.log('Impact analysis refresh error: ' + error.message);
    return false;
  }
}

/**
 * Polls a BigQuery job until completion.
 * @param {string} jobId - The BigQuery job ID to poll
 * @returns {boolean} true if job completed successfully
 */
function pollForCompletion(jobId) {
  const ui = SpreadsheetApp.getUi();
  const maxAttempts = 60; // 10 minutes at 10-second intervals

  for (let i = 0; i < maxAttempts; i++) {
    Utilities.sleep(10000); // 10 seconds

    const job = BigQuery.Jobs.get(IMPACT_CONFIG.PROJECT_ID, jobId);
    const status = job.status;

    if (status.state === 'DONE') {
      if (status.errorResult) {
        ui.alert(
          'Refresh Failed',
          'BigQuery job completed with error:\n\n' + status.errorResult.message,
          ui.ButtonSet.OK
        );
        return false;
      }

      ui.alert(
        'Refresh Complete',
        'All CVC impact analysis tables have been rebuilt successfully.\n\n' +
        'Google Sheets charts will reflect the new data after refreshing ' +
        'the data connector (Data > Data connectors > Refresh data).',
        ui.ButtonSet.OK
      );
      return true;
    }
  }

  ui.alert(
    'Refresh Timeout',
    'The refresh job is still running after 10 minutes.\n' +
    'Check BigQuery console for job status: ' + jobId,
    ui.ButtonSet.OK
  );
  return false;
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/clinvar-curation/cvc-impact-analysis/appscript-refresh-impact.js
git commit -m "feat: add Apps Script snippet to call impact analysis refresh procedure"
```

---

## Chunk 4: Update documentation

### Task 6: Update documentation references

**Files:**
- Modify: `scripts/clinvar-curation/cvc-impact-analysis/GOOGLE-SHEETS-SETUP.md`
- Modify: `scripts/clinvar-curation/cvc-impact-analysis/CVC-SUBMISSION-LIFECYCLE.md`
- Modify: `scripts/clinvar-curation/cvc-impact-analysis/README.md`

- [ ] **Step 1: Update GOOGLE-SHEETS-SETUP.md**

In the "Keeping Data Current" section (around line 56), update Step 2 to mention both the stored procedure and the shell script:

Replace the re-run instructions with:

```markdown
### Step 2: Re-run the CVC Impact Analysis pipeline

Once upstream data is current, rebuild the materialized tables by either:

**Option A: Call the stored procedure (recommended after batch finalization)**
```sql
CALL `clinvar_curator.refresh_cvc_impact_analysis`();
```
This rebuilds all 14 materialized tables in dependency order. Takes 2-5 minutes.
Can also be triggered from the batch finalization Apps Script.

**Option B: Run the shell script**
```bash
cd scripts/clinvar-curation/cvc-impact-analysis
./00-run-cvc-impact-analysis.sh --force
```
```

Also update the "Data Refresh" section to mention the stored procedure.

- [ ] **Step 2: Update CVC-SUBMISSION-LIFECYCLE.md**

Search for any references to `batch-accepted-dates.tsv` or `cvc_batch_accepted_dates` and update to reference `batch_end_date` from `cvc_clinvar_batches`.

- [ ] **Step 3: Update README.md**

In `scripts/clinvar-curation/cvc-impact-analysis/README.md`, make three updates:

1. **Loader scripts table** (around line 194): Remove the `load-batch-accepted-dates.sh` row:
   ```
   | `load-batch-accepted-dates.sh` | Loads `batch-accepted-dates.tsv` into BigQuery |
   ```

2. **Data files table** (around line 211): Remove the `batch-accepted-dates.tsv` row:
   ```
   | `batch-accepted-dates.tsv` | Maps batch IDs to ClinVar acceptance dates (determines grace period start) |
   ```

3. **Architecture diagram** (around line 379): Replace the `batch-accepted-dates.tsv` reference:
   ```
   # Old:
   batch-accepted-dates.tsv ─→ 00 ─→ cvc_batches_enriched

   # New:
   cvc_clinvar_batches.batch_end_date ─→ 00 ─→ cvc_batches_enriched
   ```

4. **Add the stored procedure** to the scripts table and mention `09-refresh-cvc-impact-analysis.sql` and `appscript-refresh-impact.js`.

- [ ] **Step 4: Commit**

```bash
git add scripts/clinvar-curation/cvc-impact-analysis/GOOGLE-SHEETS-SETUP.md
git add scripts/clinvar-curation/cvc-impact-analysis/CVC-SUBMISSION-LIFECYCLE.md
git add scripts/clinvar-curation/cvc-impact-analysis/README.md
git commit -m "docs: update references from TSV-based accepted dates to batch_end_date and stored proc"
```

---

## Chunk 5: File audit and cleanup

### Task 7: Audit all files in cvc-impact-analysis for relevance

**Purpose:** After the TSV removal and stored procedure addition, review every file in the directory to confirm it is still relevant, up to date, and correctly referenced. Flag anything obsolete or orphaned for cleanup.

- [ ] **Step 1: Inventory all files and assess status**

Review each file in `scripts/clinvar-curation/cvc-impact-analysis/` against this checklist:

| File | Type | Expected Status | Action Needed |
|------|------|-----------------|---------------|
| `00-cvc-batch-enriched-view.sql` | SQL | Modified in Task 1 | Verify deployed |
| `00-run-cvc-impact-analysis.sh` | Shell | Modified in Task 3 | Verify TSV refs removed |
| `01-cvc-submitted-variants.sql` | SQL | Active | None |
| `02-cvc-conflict-attribution.sql` | SQL | Active | None |
| `03-cvc-impact-analytics.sql` | SQL | Active | None |
| `04-flagging-candidate-outcomes.sql` | SQL | Active | None |
| `05-version-bump-detection.sql` | SQL | Active | None |
| `06-version-bump-flagging-intersection.sql` | SQL | Active (modified earlier this session) | None |
| `07-resubmission-candidates.sql` | SQL | Active | None |
| `08-autoreflag-candidates.sql` | SQL | Active | None |
| `09-refresh-cvc-impact-analysis.sql` | SQL | Created in Task 4 | Verify deployed |
| `full-record-version-bump-detection.sql` | SQL | Active | None |
| `batch-accepted-dates.tsv` | Data | **Deleted in Task 2** | Confirm removed |
| `load-batch-accepted-dates.sh` | Shell | **Deleted in Task 2** | Confirm removed |
| `load-rejected-scvs.sh` | Shell | Active | None — still loads rejected SCVs |
| `rejected-scvs.tsv` | Data | Active | None — still manually maintained |
| `resubmission-queue-appscript.js` | JS | Active | None — resubmission queue Apps Script |
| `appscript-refresh-impact.js` | JS | Created in Task 5 | Verify added |
| `query-accepted-vs-rejected.sql` | SQL | **Review** | Ad-hoc query — check if still useful or references deleted tables |
| `query-pending-rejected-scvs.sh` | Shell | **Review** | Ad-hoc query script — check if still useful |
| `query-submission-flagging-status.sql` | SQL | **Review** | Ad-hoc query — check if still useful |
| `README.md` | Docs | Modified in Task 6 | Verify updated |
| `GOOGLE-SHEETS-SETUP.md` | Docs | Modified in Task 6 | Verify updated |
| `GOOGLE-SHEET-README.md` | Docs | Active | Resubmission queue readme for Google Sheet |
| `CVC-SUBMISSION-LIFECYCLE.md` | Docs | Modified in Task 6 | Verify updated |
| `OUTCOME-CATEGORIES-README.md` | Docs | Active (created this session) | None |
| `AUTOREFLAG-TRACKING-GUIDE.md` | Docs | **Review** | Check for `batch_accepted_date` / TSV references |
| `RESUBMISSION-TRACKING-GUIDE.md` | Docs | **Review** | Check for `batch_accepted_date` / TSV references |
| `BATCH-107-ANALYSIS.md` | Docs | **Review** | One-time investigation — may be historical artifact |
| `NON-CONTRIBUTING-SCV-ANALYSIS.md` | Docs | **Review** | Check if analysis is still relevant or superseded |

- [ ] **Step 2: Check ad-hoc query files for stale references**

For each file marked **Review**, check if it references deleted tables or files:

```bash
cd scripts/clinvar-curation/cvc-impact-analysis
grep -l 'cvc_batch_accepted_dates\|batch-accepted-dates' \
  query-accepted-vs-rejected.sql \
  query-pending-rejected-scvs.sh \
  query-submission-flagging-status.sql \
  AUTOREFLAG-TRACKING-GUIDE.md \
  RESUBMISSION-TRACKING-GUIDE.md \
  BATCH-107-ANALYSIS.md \
  NON-CONTRIBUTING-SCV-ANALYSIS.md 2>/dev/null
```

Any files that match need their references updated or the file flagged for removal.

- [ ] **Step 3: Present findings and ask for cleanup direction**

For each file marked **Review**, report:
1. Whether it references deleted tables/files
2. Whether it appears to be a one-time investigation or ongoing reference
3. Whether it duplicates information now covered elsewhere

Then ask: "Which of these files should be kept, updated, or removed?"

Do NOT delete or modify any files in this step — only report findings and wait for direction.

- [ ] **Step 4: Execute agreed cleanup and commit**

After receiving direction, execute the agreed changes:

```bash
# Example — actual files will depend on the review findings
git rm <files-to-remove>
git add <files-to-update>
git commit -m "chore: clean up obsolete files in cvc-impact-analysis"
```

---

## Post-Implementation Verification

After all tasks are complete:

1. **Verify the enriched view works without the TSV table:**
   ```sql
   SELECT batch_id, batch_accepted_date, grace_period_end_date
   FROM `clinvar_curator.cvc_batches_enriched`
   WHERE batch_id IN ('128', '129', '130', '131')
   ORDER BY batch_id;
   ```
   Expected: Non-NULL dates for all batches that have `batch_end_date` populated.

2. **Run the stored procedure end-to-end:**
   ```sql
   CALL `clinvar_curator.refresh_cvc_impact_analysis`();
   ```

3. **Verify the funnel numbers match previous results:**
   ```sql
   SELECT * FROM `clinvar_curator.sheets_flagging_candidate_funnel`
   ORDER BY sort_order;
   ```

4. **Optionally drop the now-unused table:**
   ```sql
   DROP TABLE IF EXISTS `clinvar_curator.cvc_batch_accepted_dates`;
   ```
   Only do this after confirming everything works correctly.
