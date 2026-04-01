# ACMG v4 Variant Pathogenicity Model (Under Construction)

!!! warning "Work in Progress"
    This document and the accompanying JSON example are actively being developed. The model is not yet finalized and may change significantly.

## Overview

This work-in-progress explores how ACMG v4 variant pathogenicity assessments can be represented using the GA4GH VA-Spec (Variant Annotation Specification) data model. The goal is to capture the full structure of an ACMG v4 classification — including the proposition, evidence lines, scoring, and contributing agents — in a machine-readable format that aligns with GA4GH standards.

## Context

This effort is being developed in conjunction with the **SVC v4 (Sequence Variant Curation v4) working group** at ClinGen. The working group's approach and requirements are described in the [`CCG25 - Harrison S.pptx`](CCG25%20-%20Harrison%20S.pptx) presentation.

The JSON example models a `VariantPathogenicityProposition` Statement that demonstrates:

- **Proposition structure** using the subject-predicate-object-qualifier (SPOQ) pattern, where a categorical variant is assessed as causal for a disease condition
- **Qualifiers** for penetrance, gene context, mode of inheritance, and allele origin
- **Nested evidence lines** reflecting the hierarchical ACMG v4 scoring framework:
    - **Human Observation (HO)** — observation counting, population frequency, and affected observations (monoallelic, de novo)
    - **Locus Specificity** — gene-disease association strength
    - **Functional & Predictive (FP)** — functional data supporting pathogenicity
- **Score-based classification** where evidence line scores roll up through cap-and-sum rules to produce a final pathogenicity classification
- **Contributions** tracking evaluator and submitter roles with dates

## Example File

The annotated JSON example is located alongside this document:

- [`acmgv4-working-in-progress.json`](acmgv4-working-in-progress.json) — A commented JSONC file illustrating a pathogenic classification for `NM_004700.4:c.803CCT[1]` (ClinGen allele `CA347424`) as causal for autosomal dominant nonsyndromic hearing loss 2A.

## Open Questions

The JSON example includes inline comments highlighting several open design questions being discussed with the SVC v4 working group:

- Whether `evidenceLineCode` fields (e.g., `HO`, `HO.ObsCnt`, `FP`) should be formalized as part of the model
- How to represent the specific scoring rules (cap, sum, round) used at each evidence line level
- Whether `strengthOfEvidenceProvided` is meaningful at all evidence line levels
- How to formalize the code systems for ACMG-specific terms (classification, strength, penetrance, allele origin)
- Whether edited scores and user notes should be captured in the model
