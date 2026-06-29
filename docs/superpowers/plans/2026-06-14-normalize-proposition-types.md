# Normalize Proposition Types Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate duplication between `clinvar_proposition_types` and `clinvar_clinsig_types` by normalizing proposition-level data (`gks_type`, `statement_type`) into `clinvar_proposition_types`, removing redundant gks/final columns from `clinvar_clinsig_types`, and renaming `original_*` columns to drop the prefix.

**Architecture:** `clinvar_proposition_types` becomes the single source of truth for proposition metadata — gks_type name, owning statement_type, display order, and conflict detectability. `clinvar_clinsig_types` keeps classification-level concerns (direction, strength, code_system, predicate, etc.) and references propositions via the `proposition_type` code column. The `gks_proposition_type`, `gks_code_order`, `gks_description_order`, and `final_proposition_type` columns are dropped. The `original_*` prefix is dropped from the three retained columns. `final_predicate` stays on `clinvar_clinsig_types` because target propositions (PROG, DIAG, TR) have multiple predicates per proposition type depending on classification outcome.

**Tech Stack:** BigQuery SQL (stored procedures, translation tables)

---

## Current State Summary

### `clinvar_clinsig_types` columns to DROP (4):
- `gks_proposition_type` — redundant with `original_proposition_type`
- `gks_code_order` — redundant with `original_code_order`
- `gks_description_order` — redundant with `original_description_order`
- `final_proposition_type` — redundant with `clinvar_proposition_types.gks_type`

### `clinvar_clinsig_types` columns to RENAME (3):
- `original_proposition_type` → `proposition_type`
- `original_code_order` → `code_order`
- `original_description_order` → `description_order`

### `clinvar_clinsig_types` columns that STAY as-is:
- `final_predicate` — stays because target propositions have multiple predicates per type (e.g. PROG has `associatedWithBetterOutcomeFor`, `associatedWithWorseOutcomeFor`, `associatedWithUndefinedOutcomeFor`)

### `clinvar_proposition_types` gains:
- `statement_type_code` — FK to `clinvar_statement_types.code` (per the TODO comment at line 31)

### Downstream column renames:
- `gks_proposition_type` → `proposition_type` (everywhere)
- `original_proposition_type` → `proposition_type` (everywhere)
- `gks_code_order` → `code_order` (where referenced)
- `original_code_order` → `code_order` (where referenced)

---

## Chunk 1: Translation Table Changes

### Task 1: Update `clinvar_proposition_types` table definition

**Files:**
- Modify: `scripts/dataset-preparation/00-setup-translation-tables.sql:149-182`

- [ ] **Step 1: Add `statement_type_code` column and populate all rows**

The table should become:

```sql
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_proposition_types` (
    code STRING,
    label STRING,
    gks_type STRING,
    statement_type_code STRING,
    display_order INT64,
    conflict_detectable BOOL
);
```

Populate with these values:

| code | label | gks_type | statement_type_code | display_order | conflict_detectable |
|------|-------|----------|---------------------|---------------|---------------------|
| path | Pathogenicity | VariantPathogenicityProposition | GermlineClassification | 10 | TRUE |
| sci | Somatic Clinical Impact | VariantClinicalSignificanceProposition | SomaticClinicalImpact | 11 | FALSE |
| onco | Oncogenicity | VariantOncogenicityProposition | OncogenicityClassification | 12 | TRUE |
| aff | Affects | ClinvarAffectsProposition | GermlineClassification | 20 | FALSE |
| assoc | Association | ClinvarAssociationProposition | GermlineClassification | 30 | FALSE |
| cdfs | Conflicting Data From Submitters | ClinvarConflictingDataFromSubmitterProposition | GermlineClassification | 35 | FALSE |
| cs | Confers Sensitivity | ClinvarConfersSensitivityProposition | GermlineClassification | 40 | FALSE |
| dr | Drug Response | ClinvarDrugResponseProposition | GermlineClassification | 50 | FALSE |
| np | Not Provided | ClinvarNotProvidedProposition | GermlineClassification | 60 | FALSE |
| oth | Other | ClinvarOtherProposition | GermlineClassification | 70 | FALSE |
| protect | Protective | ClinvarProtectiveProposition | GermlineClassification | 80 | FALSE |
| rf | Risk Factor | ClinvarRiskFactorProposition | GermlineClassification | 90 | FALSE |
| undef | Undefined | ClinvarUndefinedProposition | GermlineClassification | 95 | FALSE |
| prog | Prognostic | VariantPrognosticProposition | SomaticClinicalImpact | 100 | FALSE |
| diag | Diagnostic | VariantDiagnosticProposition | SomaticClinicalImpact | 110 | FALSE |
| tr | Therapeutic Response | VariantTherapeuticResponseProposition | SomaticClinicalImpact | 120 | FALSE |

- [ ] **Step 2: Remove the TODO comment at line 31** (now resolved by adding `statement_type_code`)

---

### Task 2: Update `clinvar_clinsig_types` — drop 4 columns, rename 3

**Files:**
- Modify: `scripts/dataset-preparation/00-setup-translation-tables.sql:33-113`

- [ ] **Step 1: Update CREATE TABLE — drop 4 columns, rename 3**

```sql
CREATE OR REPLACE TABLE `clinvar_ingest.clinvar_clinsig_types` (
    statement_type STRING,
    code STRING,
    label STRING,
    significance INT64,
    proposition_type STRING,
    code_order INT64,
    description_order INT64,
    direction STRING,
    strength_code STRING,
    strength_label STRING,
    classification_code STRING,
    penetrance_level STRING,
    code_system STRING,
    final_predicate STRING
);
```

- [ ] **Step 2: Update the INSERT column list and VALUES (lines 54-113)**

Remove the 4 dropped columns from the column list and each VALUES row. Rename the 3 `original_*` columns. Each row goes from 18 values to 14.

- [ ] **Step 3: Update the clingen-stage conditional block (lines 115-147)**

Update the SELECT list to use renamed columns and remove dropped ones:
- `original_proposition_type` → `proposition_type`
- `original_code_order` → `code_order`
- `original_description_order` → `description_order`
- Remove: `gks_proposition_type`, `gks_code_order`, `gks_description_order`

- [ ] **Step 4: Commit translation table changes**

```bash
git add scripts/dataset-preparation/00-setup-translation-tables.sql
git commit -m "refactor: normalize proposition metadata into clinvar_proposition_types

Add statement_type_code to clinvar_proposition_types.
Drop gks_proposition_type, gks_code_order, gks_description_order,
final_proposition_type from clinvar_clinsig_types.
Rename original_proposition_type→proposition_type,
original_code_order→code_order, original_description_order→description_order."
```

---

## Chunk 2: Dataset Preparation Procedure Updates

### Task 3: Update `scv_summary` proc

**Files:**
- Modify: `scripts/dataset-preparation/03-scv-summary-proc.sql:140-250`

- [ ] **Step 1: In Step 3e (clinsig temp table, ~line 145-146)**

Replace:
```sql
cst.original_proposition_type,
cst.gks_proposition_type,
```
With:
```sql
cst.proposition_type,
```

- [ ] **Step 2: In Step 4 (final assembly, ~lines 192-193)**

Replace:
```sql
cst.original_proposition_type,
cst.gks_proposition_type,
```
With:
```sql
cst.proposition_type,
```

- [ ] **Step 3: Commit**

---

### Task 4: Verify `validate_dataset` proc — no changes needed

**Files:**
- Review: `scripts/dataset-preparation/02-validate-dataset-proc.sql:44-73`

The validation joins `clinvar_clinsig_types` on `code` + `statement_type` — both columns are retained. No changes needed.

---

### Task 5: Verify `gc_scv_obs` proc — no changes needed

**Files:**
- Review: `scripts/dataset-preparation/05-gc_scv_obs-proc.sql:100-104`

Joins on `label` + `statement_type` and selects `cct.code` — all retained. No changes needed.

---

## Chunk 3: Temporal Data Collection Updates

### Task 6: Update `clinvar_scvs` table schema

**Files:**
- Modify: `scripts/temporal-data-collection/00-setup-temporal-tables.sql:117-145`

- [ ] **Step 1: Remove `gks_proposition_type` column, rename `original_proposition_type` → `proposition_type`**

- [ ] **Step 2: Commit**

---

### Task 7: Update `clinvar_scvs` proc

**Files:**
- Modify: `scripts/temporal-data-collection/09-clinvar-scvs-proc.sql`

- [ ] **Step 1: Replace all `gks_proposition_type` with `proposition_type` in WHERE/match clauses (~lines 100, 199)**

- [ ] **Step 2: Replace `original_proposition_type` with `proposition_type` in INSERT/UPDATE (~lines 70, 126)**

- [ ] **Step 3: Commit**

---

## Chunk 4: Temporal Data Summation Updates

### Task 8: Rename `gks_proposition_type` → `proposition_type` in summation procs

**Files:**
- Modify: `scripts/temporal-data-summation/02-clinvar-sum-vsp-rank-group-proc.sql` — ~5 references
- Modify: `scripts/temporal-data-summation/03-clinvar-sum-scvs-proc.sql` — ~3 references
- Modify: `scripts/temporal-data-summation/04-clinvar-sum-vsp-rank-group-change-proc.sql` — ~9 references
- Modify: `scripts/temporal-data-summation/05-clinvar-sum-vsp-top-rank-group-change-proc.sql` — ~11 references

- [ ] **Step 1: In each file, find-and-replace `gks_proposition_type` → `proposition_type`**

These appear in SELECT, GROUP BY, ORDER BY, and JOIN ON clauses. Mechanical rename.

- [ ] **Step 2: Check if any summation table schemas (e.g. `clinvar_sum_scvs`) also need the column rename**

- [ ] **Step 3: Commit**

---

## Chunk 5: Tracker Report and Curation Updates

### Task 9: Update tracker reports

**Files:**
- Modify: `scripts/tracker-report-update/02-tracker-reports-rebuild-proc.sql` — ~17 references of `gks_proposition_type`
- Modify: `scripts/tracker-report-update/03-gc-tracker-report-proc.sql` — uses `gks_code_order`

- [ ] **Step 1: Replace all `gks_proposition_type` → `proposition_type`**

- [ ] **Step 2: In gc-tracker-report-proc.sql (~line 103), replace `cct.gks_code_order` with `cct.code_order`**

- [ ] **Step 3: Commit**

---

### Task 10: Update curation scripts

**Files:**
- Modify: `scripts/clinvar-curation/02-cvc-annotations-func.sql` — ~2 references
- Modify: `scripts/clinvar-curation/04-cvc-annotations-impact-func.sql` — ~13 references
- Modify: `scripts/clinvar-curation/05-cvc-outlier-clinsig-func.sql` — ~12 references
- Modify: `scripts/clinvar-curation/cvc-submitted-outcomes-stats.sql` — ~14 references

- [ ] **Step 1: Replace all `gks_proposition_type` → `proposition_type`**

- [ ] **Step 2: Commit**

---

### Task 11: Update analysis scripts

**Files:**
- Modify: `scripts/clinvar-miner/01-pathogenicity-breakdown.sql` — ~8 references
- Modify: `scripts/clinvar-miner/02-concordance-breakdown.sql` — ~13 references
- Modify: `scripts/conflict-resolution-analysis/01-get-monthly-conflicts.sql` — ~6 references

- [ ] **Step 1: Replace all `gks_proposition_type` → `proposition_type`**

- [ ] **Step 2: Commit**

---

## Chunk 6: Documentation Updates

### Task 12: Update architecture docs

**Files:**
- Modify: `docs/architecture/bigquery-schema.md`
- Modify: `docs/architecture/data-pipeline.md`
- Modify: `docs/sql-scripts/dataset-preparation.md`
- Modify: `docs/sql-scripts/temporal-data-collection.md`
- Modify: `docs/sql-scripts/temporal-data-summation.md`

- [ ] **Step 1: Update table descriptions to reflect new schema**
- [ ] **Step 2: Replace any references to `gks_proposition_type` or `original_proposition_type` with `proposition_type`**
- [ ] **Step 3: Commit**

---

## Impact Summary

| Area | Files affected | Nature of change |
|------|---------------|-----------------|
| Translation tables | 1 | Schema restructure (the core change) |
| Dataset preparation procs | 1 | Drop `gks_proposition_type`, rename `original_proposition_type` |
| Temporal collection | 2 | Table schema + proc column renames |
| Temporal summation | 4 | Mechanical column renames |
| Tracker reports | 2 | Column renames + `gks_code_order` → `code_order` |
| Curation scripts | 4 | Mechanical column renames |
| Analysis scripts | 3 | Mechanical column renames |
| Documentation | 5 | Description updates |
| **Total** | **22 files** | |

## Column Rename Cheat Sheet

| Old name | New name | Where |
|----------|----------|-------|
| `original_proposition_type` | `proposition_type` | `clinvar_clinsig_types`, `scv_summary`, `clinvar_scvs`, downstream |
| `original_code_order` | `code_order` | `clinvar_clinsig_types` |
| `original_description_order` | `description_order` | `clinvar_clinsig_types` |
| `gks_proposition_type` | *(dropped — use `proposition_type`)* | `clinvar_clinsig_types`, `scv_summary`, `clinvar_scvs`, downstream |
| `gks_code_order` | *(dropped — use `code_order`)* | `clinvar_clinsig_types`, gc-tracker-report |
| `gks_description_order` | *(dropped)* | `clinvar_clinsig_types` |
| `final_proposition_type` | *(dropped — use `clinvar_proposition_types.gks_type`)* | `clinvar_clinsig_types` |

## Risk Notes

1. **The `clinvar_scvs` temporal table** stores historical data. Renaming its columns requires either:
   - A one-time migration `ALTER TABLE ... RENAME COLUMN` in BigQuery, OR
   - Dropping and recreating (loses data)
   - **Recommendation:** Use `ALTER TABLE ... RENAME COLUMN` for live BigQuery tables.

2. **The clingen-stage conditional block** re-creates `clinvar_clinsig_types` with a subset of columns. Must be updated to use the new names (Task 2, Step 3).

3. **Any external consumers** (dashboards, notebooks, downstream queries outside this repo) that reference `gks_proposition_type`, `original_proposition_type`, `gks_code_order`, or `final_proposition_type` will break. Coordinate with consumers before deploying.

4. **`final_predicate` stays on `clinvar_clinsig_types`** because target propositions have multiple predicates per proposition type:
   - PROG: `associatedWithBetterOutcomeFor`, `associatedWithWorseOutcomeFor`, `associatedWithUndefinedOutcomeFor`
   - DIAG: `isDiagnosticInclusionCriterionFor`, `isDiagnosticExclusionCriterionFor`, `isDiagnosticUndefinedCriterionFor`
   - TR: `predictsSensitivityTo`, `predictsResistanceTo`, `predictsReducedSensitivtyTo`, `predictsUndefinedResponseTo`
   - UNDEF: `isClinvarUndefinedAssociationFor`
