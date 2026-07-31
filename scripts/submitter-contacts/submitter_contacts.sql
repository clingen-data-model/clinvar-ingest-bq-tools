-- =============================================================================
-- ClinVar Submitter Contacts (Personnel scrape) -- BigQuery table + worklists
-- =============================================================================
--
-- Companion to extract_submitter_contacts.py, which scrapes the Personnel
-- section of each ClinVar submitter page into NDJSON.
--
-- Workflow:
--   1. Pick a worklist of submitter ids (see queries below) and export to a file.
--   2. Run the scraper to produce NDJSON.
--   3. Load the NDJSON into clinvar_curator.submitter_contacts.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Target table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `clinvar_curator.submitter_contacts`
(
  submitter_id   STRING,     -- ClinVar/Organization ID, e.g. '500031'
  submitter_name STRING,     -- name from the submitter page title
  contact_index  INT64,      -- 0-based position within the Personnel list
  contact_name   STRING,     -- e.g. 'Yuya Kobayashi'
  contact_role   STRING,     -- e.g. 'Coordinator' (may be NULL)
  phone          STRING,     -- e.g. '800-436-3037' (may be NULL)
  email          STRING,     -- e.g. 'clinconsult@invitae.com' (may be NULL)
  status         STRING,     -- 'ok' | 'no_personnel' | 'fetch_failed'
  source_url     STRING,
  retrieved_at   TIMESTAMP
);


-- -----------------------------------------------------------------------------
-- Worklist A (do this first): submitters with >= 1 flagging candidate submitted
-- -----------------------------------------------------------------------------
-- Export the bare ids to a file, e.g.:
--   bq query --nouse_legacy_sql --format=csv \
--     'SELECT DISTINCT a.submitter_id
--        FROM `clinvar_curator.cvc_clinvar_submissions` s
--        JOIN `clinvar_curator.cvc_annotations_view` a ON s.annotation_id = a.annotation_id
--       WHERE a.action = "flagging candidate"
--       ORDER BY 1' \
--   | tail -n +2 > flagging_candidate_submitter_ids.txt
--
SELECT DISTINCT a.submitter_id
FROM `clinvar_curator.cvc_clinvar_submissions` s
JOIN `clinvar_curator.cvc_annotations_view` a
  ON s.annotation_id = a.annotation_id
WHERE a.action = 'flagging candidate'
ORDER BY 1;


-- -----------------------------------------------------------------------------
-- Worklist B (eventually): all current submitters
-- -----------------------------------------------------------------------------
-- Thousands of ids -- run the scraper with a larger --delay during off-peak hours.
--
-- SELECT DISTINCT id AS submitter_id
-- FROM `clinvar_ingest.clinvar_submitters`
-- WHERE deleted_release_date IS NULL
-- ORDER BY 1;


-- -----------------------------------------------------------------------------
-- Load the scraped NDJSON (run in the shell, not BigQuery):
-- -----------------------------------------------------------------------------
-- IMPORTANT: create the table FIRST (run the CREATE TABLE above, e.g.
--   bq query --project_id=clingen-dev --nouse_legacy_sql \
--     "$(sed -n '/CREATE TABLE/,/);/p' submitter_contacts.sql)"
-- ), otherwise `bq load` fails with "No schema specified on job or table".
--
-- First run (replace) -- uses the existing table's schema, no --autodetect needed:
--   bq load --project_id=clingen-dev --source_format=NEWLINE_DELIMITED_JSON --replace \
--     clinvar_curator.submitter_contacts contacts.ndjson
--
-- If you skip the CREATE TABLE step, you MUST let bq infer a schema:
--   bq load --project_id=clingen-dev --source_format=NEWLINE_DELIMITED_JSON --replace --autodetect \
--     clinvar_curator.submitter_contacts contacts.ndjson
--
-- Incremental (append a new batch of submitters):
--   bq load --project_id=clingen-dev --source_format=NEWLINE_DELIMITED_JSON \
--     clinvar_curator.submitter_contacts contacts.ndjson


-- -----------------------------------------------------------------------------
-- Handy views once loaded
-- -----------------------------------------------------------------------------
-- Distinct email per submitter (shared inboxes collapsed):
--   SELECT submitter_id, submitter_name, email, COUNT(*) AS listed_contacts
--   FROM `clinvar_curator.submitter_contacts`
--   WHERE email IS NOT NULL
--   GROUP BY submitter_id, submitter_name, email;
--
-- Submitters we scraped but found no contact email for:
--   SELECT submitter_id, submitter_name, status
--   FROM `clinvar_curator.submitter_contacts`
--   WHERE email IS NULL;
