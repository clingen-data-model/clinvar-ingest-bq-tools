#!/usr/bin/env python3
"""
Extract ClinVar submitter Personnel contacts (name / role / phone / email).

Each submitter has a public page at:
    https://www.ncbi.nlm.nih.gov/clinvar/submitters/<submitter_id>/

The "Personnel" section is server-rendered static HTML: one <li> per contact
inside <div data-section="personnel"> ... <ul class="... personal_list"> ...
    <li>Name, Role<br/>Phone: 800-...<br/>Email: <a href="mailto:x@y">x@y</a></li>

This script reads a list of submitter ids, fetches each page (politely, with
retries), parses the personnel list, and writes newline-delimited JSON (NDJSON)
suitable for `bq load`.

Zero third-party dependencies (Python 3 standard library only).

Usage:
    # ids from a file (one submitter id per line) -> NDJSON on stdout
    python3 extract_submitter_contacts.py --ids submitter_ids.txt > contacts.ndjson

    # ids from stdin
    bq query --nouse_legacy_sql --format=csv 'SELECT ...' | tail -n +2 \
        | python3 extract_submitter_contacts.py --ids - > contacts.ndjson

    # a few ids on the command line
    python3 extract_submitter_contacts.py 500031 500026 --out contacts.ndjson

Notes:
    * Be a good NCBI citizen: default 1.0s delay between requests, descriptive
      User-Agent, exponential backoff on 429/5xx. For the full submitter set
      (thousands) run during off-peak hours and consider a larger --delay.
    * Emails are frequently shared inboxes (e.g. one address for several
      coordinators). Dedupe downstream if needed.
    * A submitter with no Personnel section yields ONE row with null contact
      fields and status='no_personnel', so coverage is recorded.
"""

import argparse
import html
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

BASE_URL = "https://www.ncbi.nlm.nih.gov/clinvar/submitters/{id}/"
USER_AGENT = (
    "clinvar-curation-submitter-contacts/1.0 "
    "(+https://github.com/clingen-data-model; contact: lbabb@broadinstitute.org)"
)

# The personnel <ul> block and its <li> rows.
RE_PERSONNEL_BLOCK = re.compile(
    r'data-section="personnel".*?<ul[^>]*personal_list[^>]*>(?P<items>.*?)</ul>',
    re.IGNORECASE | re.DOTALL,
)
RE_LI = re.compile(r"<li[^>]*>(?P<li>.*?)</li>", re.IGNORECASE | re.DOTALL)
RE_MAILTO = re.compile(r'mailto:([^"\'>\s]+)', re.IGNORECASE)
RE_PHONE = re.compile(r"Phone:\s*([^<]+)", re.IGNORECASE)
RE_TITLE = re.compile(r"<title[^>]*>(.*?)</title>", re.IGNORECASE | re.DOTALL)
RE_TAG = re.compile(r"<[^>]+>")


def clean(text: str) -> str:
    """Strip tags, unescape entities, collapse whitespace."""
    text = RE_TAG.sub(" ", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def submitter_name(page: str) -> str | None:
    m = RE_TITLE.search(page)
    if not m:
        return None
    # Titles look like "Labcorp Genetics (formerly Invitae) - Submitter - ClinVar - NCBI"
    name = clean(m.group(1))
    name = re.sub(r"\s*-\s*(Submitter|ClinVar|NCBI)\b.*$", "", name, flags=re.IGNORECASE)
    return name or None


def parse_personnel(page: str):
    """Yield dicts of {name, role, phone, email} for each personnel <li>."""
    block = RE_PERSONNEL_BLOCK.search(page)
    if not block:
        return
    for li_match in RE_LI.finditer(block.group("items")):
        li = li_match.group("li")
        email_m = RE_MAILTO.search(li)
        email = html.unescape(email_m.group(1)).strip() if email_m else None
        phone_m = RE_PHONE.search(li)
        phone = clean(phone_m.group(1)) if phone_m else None
        # Name/role are the text before the first <br>.
        head = re.split(r"<br\s*/?>", li, maxsplit=1, flags=re.IGNORECASE)[0]
        head = clean(head)
        if "," in head:
            name, role = head.split(",", 1)
            name, role = name.strip(), role.strip()
        else:
            name, role = head.strip() or None, None
        yield {"name": name or None, "role": role, "phone": phone, "email": email}


def fetch(url: str, retries: int, delay: float) -> str | None:
    backoff = delay
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < retries:
                wait = e.headers.get("Retry-After")
                sleep_s = float(wait) if (wait and wait.isdigit()) else backoff
                sys.stderr.write(f"  {url} -> HTTP {e.code}, retry in {sleep_s:.1f}s\n")
                time.sleep(sleep_s)
                backoff *= 2
                continue
            sys.stderr.write(f"  {url} -> HTTP {e.code} (giving up)\n")
            return None
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt < retries:
                sys.stderr.write(f"  {url} -> {e}, retry in {backoff:.1f}s\n")
                time.sleep(backoff)
                backoff *= 2
                continue
            sys.stderr.write(f"  {url} -> {e} (giving up)\n")
            return None
    return None


def read_ids(args) -> list[str]:
    ids: list[str] = []
    if args.ids == "-":
        ids += [ln.strip() for ln in sys.stdin]
    elif args.ids:
        with open(args.ids) as fh:
            ids += [ln.strip() for ln in fh]
    ids += list(args.submitter_ids)
    # keep only bare numeric ids, preserve order, dedupe
    seen, out = set(), []
    for x in ids:
        x = x.strip().strip('"')
        if x and x.isdigit() and x not in seen:
            seen.add(x)
            out.append(x)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("submitter_ids", nargs="*", help="submitter ids on the command line")
    ap.add_argument("--ids", help="file with one submitter id per line, or '-' for stdin")
    ap.add_argument("--out", help="write NDJSON here instead of stdout")
    ap.add_argument("--delay", type=float, default=1.0, help="seconds between requests (default 1.0)")
    ap.add_argument("--retries", type=int, default=3, help="retries per page on 429/5xx (default 3)")
    args = ap.parse_args()

    ids = read_ids(args)
    if not ids:
        ap.error("no submitter ids provided (use positional ids, --ids FILE, or --ids -)")

    out = open(args.out, "w") if args.out else sys.stdout
    retrieved_at = datetime.now(timezone.utc).isoformat()
    n_contacts = 0

    try:
        for i, sid in enumerate(ids, 1):
            url = BASE_URL.format(id=sid)
            sys.stderr.write(f"[{i}/{len(ids)}] submitter {sid}\n")
            page = fetch(url, args.retries, args.delay)
            name = submitter_name(page) if page else None
            contacts = list(parse_personnel(page)) if page else []

            if page is None:
                rows = [{"status": "fetch_failed"}]
            elif not contacts:
                rows = [{"status": "no_personnel"}]
            else:
                rows = [{**c, "status": "ok"} for c in contacts]

            for idx, row in enumerate(rows):
                record = {
                    "submitter_id": sid,
                    "submitter_name": name,
                    "contact_index": idx,
                    "contact_name": row.get("name"),
                    "contact_role": row.get("role"),
                    "phone": row.get("phone"),
                    "email": row.get("email"),
                    "status": row.get("status"),
                    "source_url": url,
                    "retrieved_at": retrieved_at,
                }
                out.write(json.dumps(record, ensure_ascii=False) + "\n")
                if record["email"]:
                    n_contacts += 1

            if i < len(ids):
                time.sleep(args.delay)
    finally:
        if args.out:
            out.close()

    sys.stderr.write(f"done: {len(ids)} submitters, {n_contacts} contact emails\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
