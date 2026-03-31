# Contributing

## Branch and PR Workflow

1. Fork the repository (external contributors) or create a branch from `main`.
2. Create a feature branch with a descriptive name:
    ```bash
    git checkout -b feature/your-feature-name
    ```
3. Make your changes and commit them with clear messages.
4. Push to your branch:
    ```bash
    git push origin feature/your-feature-name
    ```
5. Open a Pull Request against `main`.
6. Ensure all CI checks pass before requesting review.

## Pre-commit Hooks

This project uses [pre-commit](https://pre-commit.com/) to enforce code quality on every commit. Install hooks after cloning:

```bash
pip install pre-commit
pre-commit install
```

### Configured Hooks

**General hooks** (from `pre-commit/pre-commit-hooks` v4.5.0):

| Hook | Description |
|------|-------------|
| `trailing-whitespace` | Removes trailing whitespace from all files |
| `end-of-file-fixer` | Ensures files end with a single newline |
| `check-yaml` | Validates YAML syntax (excludes `mkdocs.yml`) |
| `check-added-large-files` | Prevents committing large binary files |
| `check-merge-conflict` | Detects unresolved merge conflict markers |

**Python hooks** (scoped to `gcp-services/gcs-file-ingest-service/**/*.py`):

| Hook | Description |
|------|-------------|
| `ruff` | Lints Python files with auto-fix (`--fix --exit-non-zero-on-fix`) |
| `ruff-format` | Formats Python files using Ruff's formatter |
| `mypy` | Type-checks Python files (`--ignore-missing-imports --no-strict-optional`) |

!!! info "YAML exclusion"
    The `check-yaml` hook excludes `mkdocs.yml` because MkDocs uses YAML features that the basic checker does not recognize.

## SQL Scripts

### Naming Conventions

SQL scripts follow a strict naming convention that determines whether they are auto-deployed by CI:

| Suffix | Purpose | Auto-deployed |
|--------|---------|---------------|
| `-proc.sql` | Stored procedure definitions (`CREATE OR REPLACE PROCEDURE`) | Yes |
| `-func.sql` | Function definitions (`CREATE OR REPLACE FUNCTION`) | Yes |
| Other `.sql` | Setup scripts, ad-hoc queries, one-time migrations | No |

Scripts within each subdirectory use numeric prefixes to indicate execution order (e.g., `00-setup.sql`, `01-first-step-proc.sql`, `02-second-step-proc.sql`).

### Adding a New SQL Procedure

1. Create the SQL file in the appropriate `scripts/` subdirectory.
2. Name it with a numeric prefix and the `-proc.sql` suffix:
    ```
    scripts/dataset-preparation/04-my-new-step-proc.sql
    ```
3. Write the procedure using `CREATE OR REPLACE PROCEDURE`.
4. Commit and push to `main`. The CI deploy job will automatically detect the new file and execute it against BigQuery in the `clingen-dev` project.

!!! warning "Execution order"
    CI executes modified SQL files in alphabetical order across all `scripts/` subdirectories. If your procedure depends on another, ensure the numeric prefixes reflect the correct order.

### Adding a New SQL Function

Follow the same pattern as procedures, but use the `-func.sql` suffix:

```
scripts/parsing-funcs/my-new-parsing-func.sql
```

### Script Directory Organization

| Directory | Purpose |
|-----------|---------|
| `scripts/clinvar-curation/` | ClinVar curation workflow scripts |
| `scripts/dataset-preparation/` | Data normalization and validation procedures |
| `scripts/external-table-setup/` | BigQuery external table definitions |
| `scripts/gks-procs/` | GA4GH Knowledge Store procedures |
| `scripts/parsing-funcs/` | SQL parsing function definitions |
| `scripts/temporal-data-collection/` | Time-series data collection procedures |
| `scripts/temporal-data-summation/` | Temporal aggregation procedures |
| `scripts/tracker-report-update/` | Report generation procedures |

## TypeScript Utilities

### Modifying Existing Utilities

1. Edit files in `src/` (primarily `bq-utils.ts` or `parse-utils.ts`).
2. Run the build to check for compilation errors:
    ```bash
    npx tsc
    ```
3. Run the test suite:
    ```bash
    npm test
    ```
4. Commit and push. CI will compile, test, and upload the updated JS to `gs://clinvar-ingest/bq-tools`.

### Adding a New Utility

1. Create or edit a `.ts` file in `src/`.
2. Export the functions you need BigQuery to access.
3. Add corresponding tests in `test/`.
4. Build and test locally before pushing:
    ```bash
    npx tsc && npm test
    ```

!!! note "BigQuery integration"
    The compiled JavaScript files in `dist/` are uploaded to GCS and referenced by BigQuery routines as external libraries. Changes to the JS output affect live BigQuery functions.

## Running Documentation Locally

The project uses [MkDocs Material](https://squidfork.github.io/mkdocs-material/) for documentation. To preview locally:

```bash
pip install mkdocs-material
mkdocs serve
```

This starts a local server at `http://127.0.0.1:8000` with live reload.

Documentation source lives in `docs/` and is configured by `mkdocs.yml` at the project root. Changes to `docs/**` or `mkdocs.yml` pushed to `main` automatically trigger a rebuild and deploy to GitHub Pages.

## License

This project is licensed under the **CC0 1.0 Universal** license. See the [LICENSE](https://github.com/clingen-data-model/clinvar-ingest-bq-tools/blob/main/LICENSE) file for details.

By contributing, you agree that your contributions will be released under the same license.
