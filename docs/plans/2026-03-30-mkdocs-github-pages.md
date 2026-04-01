# MkDocs GitHub Pages Documentation Site Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated MkDocs documentation site deployed via GitHub Pages that helps contributors and stakeholders navigate the purpose, content, and structure of the clinvar-ingest-bq-tools repository.

**Architecture:** MkDocs with Material theme, configured for GitHub Pages auto-deployment via GitHub Actions. Documentation source lives in `docs/` and covers all major subsystems: TypeScript utilities, SQL script pipelines, GCP services, and CI/CD. Navigation mirrors the logical data pipeline rather than raw directory structure.

**Tech Stack:** MkDocs, mkdocs-material theme, GitHub Actions, Python (mkdocs runtime only)

---

## File Structure

### New Files
```
mkdocs.yml                              # MkDocs configuration (project root)
docs/
├── index.md                            # Landing page / project overview
├── getting-started.md                  # Prerequisites, install, build, test
├── architecture/
│   ├── index.md                        # Architecture overview + pipeline diagram
│   ├── data-pipeline.md               # End-to-end pipeline walkthrough
│   └── bigquery-schema.md             # Key BQ datasets/tables reference
├── typescript/
│   ├── index.md                        # TypeScript utilities overview
│   ├── bq-utils.md                    # bq-utils.ts function reference
│   └── parse-utils.md                # parse-utils.ts function reference
├── sql-scripts/
│   ├── index.md                        # SQL scripts overview + naming conventions
│   ├── dataset-preparation.md         # Dataset preparation procedures
│   ├── temporal-data-collection.md    # Temporal collection procedures
│   ├── temporal-data-summation.md     # Temporal summation procedures
│   ├── tracker-report-update.md       # Tracker report procedures
│   ├── parsing-funcs.md              # SQL parsing function wrappers
│   ├── clinvar-curation.md           # Curation workflow scripts
│   ├── external-table-setup.md       # External table definitions
│   └── general.md                     # General utility functions
├── gcp-services/
│   ├── index.md                        # GCP services overview
│   └── gcs-file-ingest.md            # GCS file ingest Cloud Function
├── ci-cd.md                           # CI/CD pipeline documentation
├── contributing.md                     # Contributing guide (migrated from README)
└── assets/
    └── stylesheets/
        └── extra.css                   # Minor style overrides (if needed)
```

### Modified Files
```
.github/workflows/docs.yml             # NEW: GitHub Actions workflow for MkDocs deploy
.gitignore                              # Add: site/ directory
README.md                              # Add link to docs site
```

---

## Chunk 1: Project Scaffolding

### Task 1: Initialize MkDocs configuration

**Files:**
- Create: `mkdocs.yml`
- Modify: `.gitignore`

- [ ] **Step 1: Create `mkdocs.yml` at project root**

```yaml
site_name: ClinVar Ingest BQ Tools
site_description: Documentation for the ClinVar Ingest BigQuery Tools repository
site_url: https://clingen-data-model.github.io/clinvar-ingest-bq-tools/
repo_url: https://github.com/clingen-data-model/clinvar-ingest-bq-tools
repo_name: clingen-data-model/clinvar-ingest-bq-tools

theme:
  name: material
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.highlight
    - content.code.copy

markdown_extensions:
  - admonitions
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.details
  - toc:
      permalink: true
  - attr_list
  - md_in_html

plugins:
  - search

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Architecture:
    - Overview: architecture/index.md
    - Data Pipeline: architecture/data-pipeline.md
    - BigQuery Schema: architecture/bigquery-schema.md
  - TypeScript Utilities:
    - Overview: typescript/index.md
    - BQ Utils: typescript/bq-utils.md
    - Parse Utils: typescript/parse-utils.md
  - SQL Scripts:
    - Overview: sql-scripts/index.md
    - Dataset Preparation: sql-scripts/dataset-preparation.md
    - Temporal Collection: sql-scripts/temporal-data-collection.md
    - Temporal Summation: sql-scripts/temporal-data-summation.md
    - Tracker Reports: sql-scripts/tracker-report-update.md
    - Parsing Functions: sql-scripts/parsing-funcs.md
    - ClinVar Curation: sql-scripts/clinvar-curation.md
    - External Tables: sql-scripts/external-table-setup.md
    - General Utilities: sql-scripts/general.md
  - GCP Services:
    - Overview: gcp-services/index.md
    - GCS File Ingest: gcp-services/gcs-file-ingest.md
  - CI/CD: ci-cd.md
  - Contributing: contributing.md
```

- [ ] **Step 2: Add `site/` to `.gitignore`**

Append to `.gitignore`:
```
# MkDocs build output
site/
```

- [ ] **Step 3: Verify MkDocs builds locally**

```bash
pip install mkdocs-material
mkdocs build --strict
```
Expected: Build succeeds (will warn about missing docs pages — that's fine for now)

- [ ] **Step 4: Commit**

```bash
git add mkdocs.yml .gitignore
git commit -m "chore: initialize mkdocs configuration with material theme"
```

---

### Task 2: Create GitHub Actions docs deployment workflow

**Files:**
- Create: `.github/workflows/docs.yml`

- [ ] **Step 1: Create the workflow file**

```yaml
name: Deploy Docs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install MkDocs and dependencies
        run: pip install mkdocs-material

      - name: Build and deploy
        run: mkdocs gh-deploy --force
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/docs.yml
git commit -m "ci: add GitHub Actions workflow for MkDocs deployment"
```

---

## Chunk 2: Core Documentation Pages

### Task 3: Landing page and getting started

**Files:**
- Create: `docs/index.md`
- Create: `docs/getting-started.md`

- [ ] **Step 1: Write `docs/index.md`**

Content should include:
- Project name and one-paragraph description (what ClinVar is, what this repo does)
- A high-level Mermaid diagram showing the 5 pipeline stages
- Quick links to each documentation section
- Badge linking to CI status

- [ ] **Step 2: Write `docs/getting-started.md`**

Content migrated and expanded from README.md:
- Prerequisites (Node.js, GCP access, BigQuery basics)
- Clone + install
- Build (`npm run build` / `npx tsc`)
- Test (`npm test`)
- Local MkDocs development (`mkdocs serve`)

- [ ] **Step 3: Verify local build**

```bash
mkdocs serve
```
Expected: Site renders at localhost:8000 with working navigation

- [ ] **Step 4: Commit**

```bash
git add docs/index.md docs/getting-started.md
git commit -m "docs: add landing page and getting started guide"
```

---

### Task 4: Architecture documentation

**Files:**
- Create: `docs/architecture/index.md`
- Create: `docs/architecture/data-pipeline.md`
- Create: `docs/architecture/bigquery-schema.md`

- [ ] **Step 1: Write `docs/architecture/index.md`**

Content:
- Repository directory structure overview (tree diagram)
- Tech stack summary (TypeScript, SQL, Python, GCP)
- How the pieces fit together: TS compiles to JS → uploaded to GCS → used by BQ UDFs → SQL procs call UDFs → CI/CD deploys changes

- [ ] **Step 2: Write `docs/architecture/data-pipeline.md`**

Content — the 5-stage pipeline with detail:

1. **External Data Ingestion** — GCS file ingest service updates reference tables (submitter orgs, NCBI genes, HPO, MONDO)
2. **Dataset Preparation** — SQL procedures normalize ClinVar XML→JSON data, build `scv_summary`, validate
3. **Temporal Collection** — Extract time-series snapshots of VCV/RCV/SCV classifications per release
4. **Temporal Summation** — Aggregate temporal data into trend summaries
5. **Tracker Reports & Curation** — Generate GC tracker reports, curation annotations

Include a Mermaid flowchart showing data flow between stages.

- [ ] **Step 3: Write `docs/architecture/bigquery-schema.md`**

Content:
- Key BQ datasets: `clinvar_ingest`, `variation_tracker`
- Key tables/views referenced across scripts (e.g., `scv_summary`, `gc_scv_obs`, `clinvar_sum_scvs`, `all_schemas()`)
- How `schema_name` / `release_date` parameterization works across procedures

- [ ] **Step 4: Commit**

```bash
git add docs/architecture/
git commit -m "docs: add architecture overview, pipeline, and schema docs"
```

---

### Task 5: TypeScript utilities documentation

**Files:**
- Create: `docs/typescript/index.md`
- Create: `docs/typescript/bq-utils.md`
- Create: `docs/typescript/parse-utils.md`

- [ ] **Step 1: Write `docs/typescript/index.md`**

Content:
- Purpose: TS utilities compiled to JS, uploaded to GCS, consumed by BigQuery UDFs
- Build process: `npx tsc` → `dist/` → GCS bucket `gs://clinvar-ingest/bq-tools`
- How SQL functions in `scripts/parsing-funcs/` and `scripts/general/` reference these JS libraries
- Testing with Jest

- [ ] **Step 2: Write `docs/typescript/bq-utils.md`**

Read `src/bq-utils.ts` and document each exported function:
- `formatNearestMonth(dateStr)` — purpose, params, return, example
- `determineMonthBasedOnRange(startDate, endDate)` — purpose, params, return
- `normalizeAndKeyById(jsonStr)` — purpose, params, return
- `createSigType(items)` — purpose, params, return
- `normalizeHpId(hpId)` — purpose, params, return
- `isEmpty(val)`, `parseSingle(val)`, etc.

- [ ] **Step 3: Write `docs/typescript/parse-utils.md`**

Read `src/parse-utils.ts` and document the major parsing functions:
- Group by ClinVar entity type: AttributeSet, Citation, Comment, XRef, HGVS, SequenceLocation, etc.
- For each group: purpose, input format (ClinVar JSON structure), output format
- Note: this is a large file (~3,585 lines) — focus on the public/exported functions, organized by entity

- [ ] **Step 4: Commit**

```bash
git add docs/typescript/
git commit -m "docs: add TypeScript utilities reference documentation"
```

---

### Task 6: SQL scripts documentation

**Files:**
- Create: `docs/sql-scripts/index.md`
- Create: `docs/sql-scripts/dataset-preparation.md`
- Create: `docs/sql-scripts/temporal-data-collection.md`
- Create: `docs/sql-scripts/temporal-data-summation.md`
- Create: `docs/sql-scripts/tracker-report-update.md`
- Create: `docs/sql-scripts/parsing-funcs.md`
- Create: `docs/sql-scripts/clinvar-curation.md`
- Create: `docs/sql-scripts/external-table-setup.md`
- Create: `docs/sql-scripts/general.md`

- [ ] **Step 1: Write `docs/sql-scripts/index.md`**

Content:
- Overview of the 104 SQL scripts across 13 categories
- Naming conventions: `*-proc.sql` (procedures), `*-func.sql` (functions), numbered prefixes for execution order
- How CI/CD auto-deploys modified `-proc.sql` and `-func.sql` files
- Table showing each subdirectory, file count, and purpose

- [ ] **Step 2: Write each category page**

For each category page, read the actual SQL files in that directory and document:
- Purpose of the category
- List of scripts with one-line descriptions
- Execution order (based on numeric prefixes)
- Key procedures/functions defined
- Dependencies (which tables/views they read/write)

The most critical categories to document thoroughly:

1. **dataset-preparation** — the core normalization pipeline
2. **temporal-data-collection** — time-series extraction
3. **tracker-report-update** — final report generation
4. **parsing-funcs** — bridge between TS utilities and SQL

- [ ] **Step 3: Commit**

```bash
git add docs/sql-scripts/
git commit -m "docs: add SQL scripts reference documentation"
```

---

### Task 7: GCP services documentation

**Files:**
- Create: `docs/gcp-services/index.md`
- Create: `docs/gcp-services/gcs-file-ingest.md`

- [ ] **Step 1: Write `docs/gcp-services/index.md`**

Content:
- Overview of GCP services in this repo
- Links to each service page

- [ ] **Step 2: Write `docs/gcp-services/gcs-file-ingest.md`**

Content (expand from existing `gcp-services/gcs-file-ingest-service/readme.md`):
- Purpose: Cloud Function that ingests reference data files from GCS to BigQuery
- Reference files handled: submitter organizations, NCBI genes, HGNC genes, HPO terms, MONDO terms
- GCS bucket: `external-dataset-ingest`
- BQ target: `clingen-dev.clinvar_ingest`
- Deployment: `deploy.sh` script details
- Triggering: `trigger.sh` and GCS event triggers
- Helper scripts: `get-organization-summary.sh`, `get-ncbi-gene-txt.sh`, `get-hgnc-gene.sh`
- Code structure: `main.py`, `utils.py`, tests

- [ ] **Step 3: Commit**

```bash
git add docs/gcp-services/
git commit -m "docs: add GCP services documentation"
```

---

### Task 8: CI/CD and contributing docs

**Files:**
- Create: `docs/ci-cd.md`
- Create: `docs/contributing.md`

- [ ] **Step 1: Write `docs/ci-cd.md`**

Content — document the GitHub Actions workflow (`.github/workflows/node.js.yml`):
- Two-job architecture: Build → Deploy
- Build job: conditional on TS file changes, compiles, tests, uploads artifacts
- Deploy job: detects modified SQL files, authenticates to GCP, uploads JS to GCS, executes SQL in BigQuery
- Docs workflow: auto-deploys MkDocs site on `docs/` or `mkdocs.yml` changes
- Diagram showing the CI/CD flow

- [ ] **Step 2: Write `docs/contributing.md`**

Content migrated from README.md Contributing section, expanded with:
- Branch and PR workflow
- Pre-commit hooks (trailing whitespace, YAML check, ruff for Python, mypy)
- SQL script naming conventions
- How to add a new SQL procedure and have it auto-deploy
- How to add/modify TypeScript utilities
- How to run docs locally (`mkdocs serve`)

- [ ] **Step 3: Commit**

```bash
git add docs/ci-cd.md docs/contributing.md
git commit -m "docs: add CI/CD pipeline and contributing guide"
```

---

## Chunk 3: Polish and Deploy

### Task 9: Add link to docs site in README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add documentation site link to README**

Add after the CI badge line:
```markdown
**[Full Documentation](https://clingen-data-model.github.io/clinvar-ingest-bq-tools/)**
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add link to GitHub Pages documentation site"
```

---

### Task 10: Final verification and deployment

- [ ] **Step 1: Run full local build with strict mode**

```bash
mkdocs build --strict
```
Expected: No warnings, clean build

- [ ] **Step 2: Preview locally**

```bash
mkdocs serve
```
Expected: All pages render, navigation works, mermaid diagrams display, code blocks have copy buttons

- [ ] **Step 3: Verify all internal links work**

Navigate through every page in the local preview, check for broken links.

- [ ] **Step 4: Push to main**

```bash
git push origin main
```
Expected: GitHub Actions `Deploy Docs` workflow triggers and publishes to GitHub Pages

- [ ] **Step 5: Enable GitHub Pages (if not already)**

In repo Settings → Pages → Source: set to `gh-pages` branch, `/ (root)`.

- [ ] **Step 6: Verify live site**

Visit `https://clingen-data-model.github.io/clinvar-ingest-bq-tools/` and confirm all pages load correctly.

---

## Implementation Notes

### Content Authoring Guidance

1. **Read the source first** — every doc page should be written after reading the actual source files it describes
2. **Use Mermaid diagrams** — the Material theme supports them natively; use flowcharts for pipelines, entity diagrams for schema relationships
3. **Admonitions for important notes** — use `!!! note`, `!!! warning`, `!!! tip` for callouts
4. **Code examples from actual files** — use real snippets from the repo, not fabricated examples
5. **Keep it maintainable** — don't duplicate information that's already in code comments; link to source files where appropriate

### Estimated Scope

- **10 tasks**, approximately **20 documentation files** to create
- The bulk of the work is in Tasks 5-6 (TypeScript and SQL docs) which require reading source files carefully
- Tasks 1-2 (scaffolding) are mechanical and fast
- Task 10 (deployment) depends on repo admin enabling GitHub Pages

### Future Enhancements (Not In Scope)

- Auto-generated API docs from TypeScript JSDoc comments
- SQL script dependency graph visualization
- Versioned documentation (per ClinVar release)
- Search analytics to see what users look for most
