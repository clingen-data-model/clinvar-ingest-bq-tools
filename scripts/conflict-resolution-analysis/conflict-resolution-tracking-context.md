# Conflict Resolution Tracking - Context Understanding

## Overview

This document captures my understanding of the ClinVar Curation project context as explained, to serve as a foundation for developing datasets that analyze the impact of clinvar-curation data on conflict resolution over time.

---

## System Architecture

### Upstream Pipeline: clinvar-ingest

The clinvar-ingest pipeline is the data foundation:

- **Source**: Weekly ClinVar data releases from NCBI
- **Processing**: Transforms and normalizes raw ClinVar data
- **Output**: BigQuery datasets in the `clingen-dev` GCP project
- **Dataset Naming Convention**: `clinvar_YYYY_MM_DD_v#_#_##`
  - `YYYY_MM_DD` = Release date from ClinVar
  - `v#_#_##` = Semantic version of the ingest pipeline

### Downstream: ClinVar Curation Project

The curation project sits on top of the ingested data:

- **Purpose**: Help curators inspect ClinVar VCVs and their associated SCVs (submissions)
- **Primary Action**: Curators can "flag" SCVs that meet certain criteria
- **Users**: Curators and project leads who manage curation efficacy

---

## Key Data Entities

### VCV (Variant Clinical Variation)
- Represents a variant in ClinVar
- Aggregates multiple submissions (SCVs) for the same variant
- Has a star rating (0-4 stars) based on review status and conflict state

### SCV (Submitted Clinical Variation)
- Individual submission from a submitter (lab, VCEP, etc.)
- Tied to a specific variant (VCV)
- Contains clinical significance interpretation (pathogenic, benign, VUS, etc.)

### Annotations (clinvar_annotation table)
- Curator-created records capturing flagging decisions
- Backed by external Google Sheet (curators append directly to the sheet)
- Links to specific SCV identifiers from ClinVar releases
- Located in `clinvar_curator` dataset on `clingen-dev` project

---

## Current Infrastructure (scripts/clinvar-curation/)

### Tables & Views Created by `00-initialize-cvc-tables.sql`

| Object | Type | Purpose |
|--------|------|---------|
| `cvc_clinvar_reviews` | Table | Tracks review status of annotations |
| `cvc_clinvar_submissions` | Table | Maps annotations to SCV submissions |
| `cvc_clinvar_batches` | Table | Batch metadata with finalization dates |
| `cvc_annotations_base_mv` | Materialized View | Consolidated annotation records with enrichment |
| `cvc_annotations_view` | View | Adds `is_latest` flag for filtering |
| `cvc_batch_scv_max_annotation_view` | View | Latest annotation per SCV per batch |
| `cvc_submitted_annotations_view` | View | Submitted annotations with validity status |
| `cvc_submitted_outcomes_view` | View | Outcomes of submitted annotations |

### External Data Source

- **Table**: `clinvar_curator.clinvar_annotations_native`
- **Backing**: Google Sheet (`1dUnmBZSnz3aeB948b7pIq0iT7_FuCDvtv6FXaVsNcOo`)
- **Sheet Tab**: 'SCV Records' (columns A:S)
- **Key Fields**: vcv_id, scv_id, submitter_id, variation_id, action, reason, annotation_date, curator_email

---

## Curation Workflow (My Understanding)

1. **Curator inspects** a VCV and its associated SCVs
2. **Curator identifies** an SCV as a "flagging candidate" (or other action)
3. **Curator adds record** to the Google Sheet with:
   - SCV identifier (scv_id with version)
   - VCV identifier
   - Action taken (e.g., "flagging candidate", "no change", "remove flagged submission")
   - Reason and notes
   - Annotation timestamp
4. **Annotations are reviewed** (tracked in `cvc_clinvar_reviews`)
5. **Annotations are batched** for submission to NCBI
6. **Outcomes are tracked** (flagged, deleted, resubmitted, pending/rejected)

---

## The Conflict Resolution Challenge

Based on the notes in `conflict-resolution-tracking-plan.md`, the key questions to address:

### Metrics Needed

1. **Denominator**: Total unique variants (for percentages)
2. **Monthly conflict counts**: ClinSig conflicts at VCV level (1 vs 0 stars)
3. **Resolution tracking**: How many conflicts have been resolved

### Attribution Questions

- Did a conflict resolve because of curation (flagging)?
- Or did it resolve organically (submitter actions independent of curation)?

### Temporal Challenges

- **Repeat resolves**: Curated, resolved, then conflicting again
- **New resolves vs re-conflicts**: Distinguishing first-time resolutions from recurring patterns

### State Categories (from notes)

| State | Description |
|-------|-------------|
| New conflict | Newly conflicting in this release |
| Unresolved conflict | Continuing conflict, no change |
| VCEP resolved | Resolved by VCEP activity (MedSig conflicts?) |
| Lab resolved | Resolved by lab activity |
| CVC MSR | CVC medically significant resolution |
| CVC fully resolved | Completely resolved via curation |

---

## Clinical Significance Definitions

### Three-Tier Classification System

| Tier | Abbreviation | Also Known As | Classifications |
|------|--------------|---------------|-----------------|
| **ClinSig** | clinsig, medsig | Clinically Significant, Medically Significant | Pathogenic, Likely pathogenic, Established risk allele, Likely risk allele, Pathogenic low penetrance, Likely pathogenic low penetrance |
| **Uncertain** | unsig, VUS | Uncertain Clinical/Medical Significance | Uncertain significance, Uncertain risk allele, VUS (Variant of Uncertain Significance) |
| **Non-ClinSig** | non-clinsig, not medsig | Not Medically Significant | Benign, Likely benign |

### VCV Aggregate Classification Logic

VCVs are **aggregate classifications** based on the **top-ranking SCVs** for a given variant. All top-ranking SCV classifications are compared for concordance or discordance (conflict).

### Conflict Types

**ClinSig Conflict (Medically Significant Conflict):**
- VCV has at least one **ClinSig** classification (P/LP/risk allele)
- AND at least one **non-ClinSig** OR **Uncertain** classification (B/LB or VUS)
- This is the **primary conflict type** the curation project aims to resolve
- Represents disagreement about clinical/medical actionability

**Non-ClinSig Conflict:**
- VCV has all **non-ClinSig** classifications (B/LB)
- AND at least one **Uncertain** classification (VUS)
- Lower priority than ClinSig conflicts but still represents disagreement

### Concordant States (No Conflict)

**ClinSig Concordant:**
- All top-ranking SCVs have ClinSig classifications (all P/LP/risk alleles)
- No conflict - agreement on clinical significance

**Non-ClinSig Concordant:**
- All top-ranking SCVs have non-ClinSig classifications (all B/LB)
- No conflict - agreement on benign status

---

## Star Rating System

### SCV Review Status → Star Rank

Every SCV has a review status that determines its star rank:

| Review Status | Stars | Notes |
|---------------|-------|-------|
| No assertion provided | N/A | No classification to compare; often confused with 0-star but distinct |
| No assertion criteria provided | 0 | Has classification but no criteria backing it |
| Criteria provided | 1 | Standard submission with assertion criteria |
| Reviewed by expert panel | 3 | VCEP (Variant Curation Expert Panel) submission |
| Practice guideline | 4 | Professional guideline-level evidence |

### VCV Star Rating Logic

The VCV's star rating is determined by the **maximum rank of its SCVs**, but with important nuances:

**Max SCV Rank = 0 stars:**
- VCV can never be more than 0 stars
- Review status does NOT indicate conflict even if discordant classifications exist
- Must look at VCV classification to detect conflicts

**Max SCV Rank = 1 star:**
- VCV can have one of three review statuses:
  - ⭐⭐ (2-star): "Criteria provided, multiple submitters, no conflicts"
  - ⭐ (1-star): "Criteria provided, conflicting classifications"
  - ⭐ (1-star): "Criteria provided, single submitter"

**Max SCV Rank = 3 or 4 stars:**
- Expert panel or practice guideline classifications
- **No conflict comparison occurs** — expert classifications stand on their own
- Listed for community use but not compared for discordance

### Detecting Conflicts (Foolproof Methods)

Since 0-star conflicts don't surface in review status, there are only two reliable ways to detect conflicts:

1. **VCV Review Status**: Check for "Criteria provided, conflicting classifications" (only works for 1-star max)
2. **VCV Classification**: Check for "Conflicting classifications of pathogenicity" (works for all cases)

**Important**: Relying solely on review status will miss 0-star conflicts!

---

## Temporal Dynamics

### ClinVar Release Cadence

- **Weekly releases**: ClinVar produces snapshots/releases typically on a weekly basis
- **Monthly retention**: First release of each month is kept indefinitely
- **Common analysis pattern**: Compare month-to-month releases to track changes over time

SCVs are constantly being added, modified, or removed between releases.

### Curation Workflow Timeline

```
[Curation Period]        [Batch Creation]       [ClinVar Processing]
     ~1 month                 ↓                    1-2 weeks
├─────────────────────┤      │                 ├──────────────┤
                             │
   Curators flag SCVs        │                 ClinVar validates
   as "flagging candidates"  │                 against their
   in clinvar_annotation     │                 current release
                             │
                       Batch Release
                       (snapshot used to
                       validate SCV versions)
```

### Key Temporal Concepts

**Curation Period:**
- Approximately one month (not a fixed period)
- Curators flag SCVs as "flagging candidates" during this time
- SCVs may become out of date before batch submission

**Batch Release:**
- The ClinVar release used to validate the batch of curations
- At batch creation time, versioned SCVs are checked for accuracy against this release
- Only "flagging candidates" with valid SCV versions are included

**Submission Processing Window:**
- ClinVar processes submitted batches within 1-2 weeks
- Risk: ClinVar may validate against a newer release
- This can cause versioned SCVs to become out of sync (updated/deleted between batch release and processing)

### ClinVar Processing & 60-Day Grace Period

Once ClinVar receives and processes a batch of flagged SCVs:

**Validation Response:**
- ClinVar returns any "out of sync" SCV versions (rejected)
- These must be removed from our flagged SCV accounting
- Can re-evaluate and resubmit in future batches if flagging reason still valid

**Starting Point for Impact Analysis:**
- Once we have the final list of validated flagged SCVs
- AND we know the release it was validated against
- This becomes the "starting point" for analyzing curation impact on variants

**60-Day Grace Period:**
- Validated flagged SCVs are NOT immediately applied to ClinVar
- Submitters have **60 days** from validation to respond
- During this window, submitters can:
  - **Remove** their SCV → flag will not be applied
  - **Update** their SCV → flag will not be applied
  - **Do nothing** → flag WILL be applied after 60 days

**Flag Application (Day 60+):**
- If submitter takes no action, the SCV is flagged in ClinVar
- Flagged SCVs **no longer impact** concordance/conflict resolution on the variant
- This is the mechanism by which curation resolves conflicts

```
[Batch Submission]  →  [ClinVar Validation]  →  [60-Day Grace Period]  →  [Flag Applied]
                              │                         │                       │
                        Rejected SCVs             Submitter can            SCV excluded from
                        returned to us            remove/update            conflict calculation
                              │
                        Starting point
                        for impact analysis
```

### Temporal Challenges for Tracking

1. **SCV Version Drift**: An SCV flagged during curation may be updated before batch submission
2. **Post-Submission Changes**: An SCV may change between batch submission and ClinVar processing
3. **Release Alignment**: Need to track which release an annotation was made against vs. batch release vs. validation release vs. current release
4. **Grace Period Outcomes**: Need to track whether submitters responded during the 60-day window
5. **Flag Application Timing**: Impact analysis must account for the 60-day delay before flags take effect

---

## Resolution Definition

### What Does "Resolved" Mean?

**Resolution operates at the variant (VCV) level**, not the SCV level.

A variant is considered **resolved** when:
1. It previously had a classification of "Conflicting classifications of pathogenicity"
2. SCVs were flagged (either by curation or other means)
3. The flagging removed enough conflicting SCVs that the conflict is **no longer valid**
4. The VCV classification changes from "Conflicting..." to a concordant classification

### Resolution Scenarios

**Before Resolution:**
```
VCV-123: "Conflicting classifications of pathogenicity"
├── SCV-A: Pathogenic (1-star)
├── SCV-B: Benign (1-star)        ← flagged
└── SCV-C: Pathogenic (1-star)
```

**After Resolution (SCV-B flagged and excluded):**
```
VCV-123: "Pathogenic" (concordant)
├── SCV-A: Pathogenic (1-star)
├── SCV-B: Benign (1-star)        ← flagged, excluded from calculation
└── SCV-C: Pathogenic (1-star)
```

### Resolution Can Occur Via Multiple Paths

| Resolution Path | Description |
|-----------------|-------------|
| **CVC Flagging** | Our curation project flags conflicting SCVs |
| **Submitter Action** | Submitter removes or reclassifies their SCV |
| **VCEP Classification** | Expert panel adds 3-star classification (overrides conflict) |
| **Practice Guideline** | 4-star guideline added (overrides conflict) |

### Partial vs Full Resolution

- **Full Resolution**: No conflict remains — VCV is now concordant
- **Partial Resolution (MSR)**: Medically significant conflict resolved, but other conflicts may remain
  - Example: P vs B conflict resolved, but P vs VUS conflict may still exist

---

## Impact Analysis Approach

### Phase 1: Establish Monthly Conflict Baseline (Before Curation Integration)

**Goal:** Track new and resolved conflicts month-to-month, independent of curation data initially.

**Starting Point:** August 2023 (when ClinVar Curation project began)

### Step 1: Get Monthly Releases

Use `clinvar_ingest.all_schemas()` to find the first release of each month:

```sql
-- all_schemas() returns:
-- schema_name, release_date, prev_release_date, next_release_date
SELECT
    schema_name,
    release_date,
    prev_release_date,
    next_release_date
FROM `clinvar_ingest.all_schemas`()
WHERE release_date >= '2023-08-01'
ORDER BY release_date
```

### Step 2: Extract VCV Conflicts Per Monthly Release

For each monthly release, capture:

| Field | Description |
|-------|-------------|
| `variation_id` | The variant identifier |
| `vcv_id` | VCV identifier |
| `vcv_version` | VCV version at this release |
| `review_status` | VCV review status (for star rating) |
| `classification` | "Conflicting classifications of pathogenicity" |
| `conflict_explanation` | Details how many of each classification created the conflict |

**Note:** Conflicts can be either ClinSig or Non-ClinSig per earlier definitions.

### Step 3: Month-to-Month Comparison

Compare consecutive monthly snapshots to identify:

- **New Conflicts**: VCVs that are conflicting this month but weren't last month
- **Resolved Conflicts**: VCVs that were conflicting last month but aren't this month
- **Continuing Conflicts**: VCVs that remain in conflict state

---

## Questions / Clarifications Still Needed

To build effective tracking datasets, I'll need to understand:

1. **VCEP vs Lab distinction**: How do we identify VCEP submissions vs regular lab submissions in the data?
2. **VCV table structure**: Which table(s) in the release schemas contain VCV classification and conflict explanation?
3. **Conflict explanation format**: What does the conflict explanation field look like (structured vs free text)?

---

## Next Steps

1. Explore the release schema structure to identify VCV conflict tables/fields
2. Build a query to extract conflicts from August 2023 release
3. Design the month-to-month comparison logic
4. Create a procedure to populate historical conflict data
5. Build incremental update logic for ongoing tracking
6. Develop summary/rollup views for reporting

---

*Document generated as context feedback - ready for corrections and additional details.*
