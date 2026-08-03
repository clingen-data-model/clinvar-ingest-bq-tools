# ClinVar Submitter Contacts

Extract the **Personnel** contacts (name / role / phone / email) from each
ClinVar submitter page and load them into a BigQuery table.

Each submitter has a public page at
`https://www.ncbi.nlm.nih.gov/clinvar/submitters/<submitter_id>/`
(e.g. Labcorp Genetics = `500031`). The Personnel section is server-rendered
static HTML — one `<li>` per contact — so a simple fetch + parse is all that's
needed (no API/JS reverse-engineering).

## Files

| File | Purpose |
|------|---------|
| `extract_submitter_contacts.py` | Stdlib-only scraper: submitter ids → NDJSON contacts |
| `submitter_contacts.sql` | Target table DDL, worklist queries, and `bq load` commands |

## Quick start (flagging-candidate submitters first)

```bash
# 1. Worklist: submitters that have had >= 1 flagging candidate submitted
bq query --nouse_legacy_sql --format=csv \
  'SELECT DISTINCT a.submitter_id
     FROM `clinvar_curator.cvc_clinvar_submissions` s
     JOIN `clinvar_curator.cvc_annotations_view` a ON s.annotation_id = a.annotation_id
    WHERE a.action = "flagging candidate"
    ORDER BY 1' \
  | tail -n +2 > flagging_candidate_submitter_ids.txt

# 2. Scrape (politely: ~1 req/sec, retries on 429/5xx)
python3 extract_submitter_contacts.py --ids flagging_candidate_submitter_ids.txt \
  > contacts.ndjson

# 3a. Create the table once (pins the schema; required before bq load)
bq query --project_id=clingen-dev --nouse_legacy_sql '
CREATE TABLE IF NOT EXISTS `clinvar_curator.submitter_contacts` (
  submitter_id STRING, submitter_name STRING, contact_index INT64,
  contact_name STRING, contact_role STRING, phone STRING, email STRING,
  status STRING, source_url STRING, retrieved_at TIMESTAMP
)'

# 3b. Load the scraped NDJSON (uses the table schema; no --autodetect needed)
bq load --project_id=clingen-dev --source_format=NEWLINE_DELIMITED_JSON --replace \
  clinvar_curator.submitter_contacts contacts.ndjson
# (skipping 3a? add --autodetect to let bq infer the schema)
```

Test a single submitter without BigQuery:

```bash
python3 extract_submitter_contacts.py 500031
```

## Output schema (NDJSON → `clinvar_curator.submitter_contacts`)

`submitter_id, submitter_name, contact_index, contact_name, contact_role,
phone, email, status, source_url, retrieved_at`

- One row per Personnel `<li>`. `contact_index` is its position in the list.
- A submitter with no Personnel section yields one row with null contact fields
  and `status = 'no_personnel'`; an unreachable page yields `status = 'fetch_failed'`.
  This keeps a record of what was actually checked.
- Emails are often **shared inboxes** (one address for several coordinators) —
  dedupe downstream (see the views in `submitter_contacts.sql`).

## Scaling to all submitters

Use Worklist B in `submitter_contacts.sql` (all current submitters — thousands).
Run with a larger delay during off-peak hours:

```bash
python3 extract_submitter_contacts.py --ids all_submitter_ids.txt --delay 2 \
  > contacts_all.ndjson
```

For a recurring capture, this scraper is a good fit for a scheduled Cloud
Function / Cloud Run job writing NDJSON to GCS and loading to BigQuery (mirrors
the pattern in `gcp-services/gcs-file-ingest-service/`). Ask if you want that
wired up.

## Etiquette / caveats

- The scraper sends a descriptive `User-Agent` with a contact address, throttles
  requests, and backs off on `429`/`5xx`. Keep the delay conservative for large
  runs — these are NCBI web pages, not E-utilities endpoints.
- Personnel/emails are **not** available via ClinVar E-utilities or the FTP bulk
  files; the submitter web page is the only source, which is why we scrape.
- These are publicly listed professional contacts. Use them consistently with
  NCBI's usage policies and your own outreach norms; don't redistribute in bulk.
