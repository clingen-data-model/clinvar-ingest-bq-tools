# Dataset Preparation — Design Notes

This document describes the architectural design and critical nuances of the dataset preparation aggregation logic. For script-by-script documentation, see the [Dataset Preparation](../../docs/sql-scripts/dataset-preparation.md) page in the project docs.

## 1. System Architecture: The Three Layers

The aggregator is built on a modular design that separates raw data ingestion from normalization and final reporting logic.

### A. The Normalization Layer

Before aggregation, data is passed through a "Rosetta Stone" of configuration tables to ensure consistency across different clinical contexts (Germline vs. Somatic).

- **`clinvar_statement_categories`**: Defines high-level classification categories and their associated proposition types.
- **`clinvar_statement_types`**: Categorizes data into high-level buckets (Germline, Somatic Clinical Impact, Oncogenicity) and assigns the ID codes (G, S, O).
- **`clinvar_clinsig_types`**: Maps messy ClinVar strings to standardized codes, guidelines (ACMG/AMP), and a numeric significance scale (0–2).
- **`scv_clinsig_map`**: A "fuzzy" lookup that cleans raw submitter strings (e.g., "vous" → "vus") into the standardized codes used by the system.

### B. The Proposition Logic Layer

- **`clinvar_proposition_types`**: Defines the scope of the assertion.

**Nuance:** The `conflict_detectable` flag is the "master switch." If `TRUE`, the aggregator performs conflict math. If `FALSE` (Somatic), classifications are treated as independent findings (Tiers), preventing accidental "conflicting" labels where multiple tier findings are valid.

### C. The Relational & Temporal Status Layer

This layer determines the Review Status (Stars) using a decoupled logic model.

- **`status_rules`** (The Logic): Defines *when* a label applies.
- **`status_definitions`** (The Content): Defines *what* the label says and *when* it was valid.

**Nuance:** This handles the 2024 nomenclature change from "interpretations" to "classifications" without requiring code changes.

For detailed documentation on review status translation logic and star ratings, see [Section 4](#4-review-status-translation) below.

## 2. Data Flow & Aggregation Logic

The core query processes data through a series of Common Table Expressions (CTEs):

1. **Normalization (`initial_prep`)**: Joins SCVs with the Normalization Layer.
2. **Aggregation (`numeric_aggregates`)**: Groups data by `variation_id` and `proposition_type`.
3. **Promotion Logic**: Automatically promotes 1-star records to 2-stars if multiple submitters agree and no conflicts exist.
4. **State Calculation (`final_prep`)**: Determines the "Data State" (e.g., `CONFLICT`, `MULTIPLE_AGREE`, `AUTHORITY`).
5. **The Agnostic Join**: Performs a `LEFT JOIN` on the Status Layer using "fuzzy" logic:

```sql
AND (rsl.rule_type IS NULL OR rsl.rule_type = fp.data_state)
```

## 3. Critical Nuances for Future Users

### The "Agnostic" (NULL) Rule Strategy

For high-authority ranks (3 & 4) and no-data ranks (0 and below), the `rule_type` in `status_rules` is set to `NULL`.

**Why:** This makes the join a "Catch-All." If an Expert Panel (Rank 3) has internal conflicts, the system ignores the conflict and correctly pulls the "Reviewed by expert panel" label. Precision logic (`CONFLICT` vs `MULTIPLE_AGREE`) is reserved strictly for Ranks 1 and 2.

### Intra-Submitter Conflict Detection (347806)

The aggregator detects conflicts even within a single submitter’s multiple submissions. It calculates `conflicting = TRUE` based on distinct significance counts, ensuring that even if `multiple_submitters = FALSE`, the label correctly reflects a "conflicting classification."

### Somatic Tier Separation

For Somatic Clinical Impact, the `agg_bucket` uses the specific tier code (`t1`, `t2`, etc.) instead of the generic `"AGGREGATED"` string. This ensures that a single variant can have multiple distinct somatic propositions (one for each tier found) rather than forcing them into a single conflicting record.

### Temporal Nomenclature

The system uses the `release_date` of the data to look up the label in `status_definitions`.

**Future Proofing:** If ClinVar changes terminology in 2027, simply add a new row to `status_definitions` with a `2027-01-01` start date. No SQL code needs to be modified.

## 4. Review Status Translation

The system uses a Relational & Temporal metadata model that separates the logic of *when* a status applies from the text of the label itself.

### Table A: `status_rules` (The Logic)

This table defines the conditions under which a specific clinical status is triggered.

- **`review_status`**: Primary identifier (the label name).
- **`rule_type`**: The logical state required (`CONFLICT`, `MULTIPLE_AGREE`, `SINGLE`). Set to `NULL` for ranks where the data state is irrelevant (e.g., Expert Panels or Rank 0).
- **`conflict_detectable`**: Distinguishes between Germline (`TRUE`) and Somatic (`FALSE`).
- **`is_scv`**: Boolean to separate individual submission labels from aggregate variant labels.

### Table B: `status_definitions` (The Content)

This table stores the clinical star-rank and the historically accurate text for each status.

- **`rank`**: The official ClinVar star rating (-3 to 4).
- **`start_release_date` / `end_release_date`**: Controls temporal nomenclature (e.g., the 2024 switch from "interpretations" to "classifications").

### Core Query Logic

The query operates in three distinct phases:

**Phase 1: Aggregation & Somatic Tiering** — Groups records by `variation_id` and `proposition_type`. Germline records consolidate into a single `"AGGREGATED"` bucket. Somatic records are bucketed by their specific `classif_type` (e.g., Tier 1, Tier 2), creating unique IDs like `[VariationID].G.1.path.t1`.

**Phase 2: The `data_state` Calculation** — Calculates the "Truth of the Data" before looking for a label:

- `AUTHORITY`: Assigned to any record with an aggregate rank of 3 or 4.
- `CONFLICT`: Assigned if `conflict_detectable` is `TRUE` and multiple distinct significances exist.
- `MULTIPLE_AGREE`: Assigned if more than one submitter exists but significances match.
- `SINGLE` / `NO_DATA`: Default states for single-submitter or empty records.

**Phase 3: The Agnostic Join (The "Catch-All")** — The final label is retrieved using a `LEFT JOIN` with "fuzzy" matching logic. By setting `rule_type` to `NULL` in the metadata for high-authority or no-data ranks, the query ignores messy underlying data (like conflicts within an Expert Panel) and pulls the correct star-level label.

### Edge Cases

- **Somatic Rank 2 Promotion**: Somatic data (T1–T4) often has `conflict_detectable = FALSE`. The metadata handles this by providing a specific Rank 2 label ("criteria provided, multiple submitters") that lacks the Germline-specific "no conflicts" suffix.
- **Temporal Terminology**: Future users do not need to update code when ClinVar changes terminology. Simply adding a new row to `status_definitions` with the new `start_release_date` will automatically update all reports generated for that period.
