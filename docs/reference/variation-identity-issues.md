# ClinVar Variation Identity Processing Issues - Non-Technical Summary

This document explains the various issues that can occur during ClinVar variation identity processing, written for non-technical readers.

## Overview

The ClinVar variation identity processing system assesses every unique ClinVar variant (identified by ClinVar's variation ID) to determine if there is sufficient data to transform it into a standardized VRS v2.0 representation. The goal is to convert variants into one of three VRS classes:

- **Allele** - for precise sequence changes
- **CopyNumberCount** - for variants with known copy numbers
- **CopyNumberChange** - for variants that gain or lose genetic material

This assessment determines what is in scope for VRS transformation, identifies insufficient variant data, and flags variants that may not be supported by the VRS-python normalizer tool. The resulting VRS representations will become the foundation for Cat-VRS v1.0 (categorical variant) representations.

**Important Note**: This process intentionally excludes ClinVar haplotypes and genotypes, as these complex genetic combinations are outside the scope of VRS transformation.

**Reference Specifications**:

- VRS v2.0: <https://vrs.ga4gh.org/en/stable/>
- Cat-VRS v1.0: <https://cat-vrs.ga4gh.org/en/latest/>

## Types of Issues

### 1. Variant Scope Issues

#### Issue: "haplotype and genotype variations are not supported"

- **What it means**: Some ClinVar entries describe combinations of variants (haplotypes) or complete genetic profiles (genotypes). These are intentionally excluded from this VRS transformation process.
- **Why it happens**: This assessment focuses only on individual variants that can be represented as VRS Alleles, CopyNumberCounts, or CopyNumberChanges. Haplotypes and genotypes require different handling approaches.
- **Impact**: These entries are flagged as out-of-scope and will not receive VRS representations in this process.

#### Issue: "protein expressions not supported"

- **What it means**: The variant is described at the protein level (starting with NP_) rather than at the DNA level. Protein-level descriptions are out of scope for this pipeline.
- **Why it happens**: This assessment pipeline is designed to work with DNA-level variant descriptions. Protein-level variants require different processing approaches.
- **Impact**: Protein-level variants are flagged as out-of-scope and will not receive VRS representations in this process.

### 2. VRS-Python Normalizer Limitations

The following issues occur due to limitations of the VRS-python normalizer tool and its API, not fundamental VRS specification problems:

#### Issue: "range copies are not supported"

- **What it means**: Some genetic variants specify a range of possible copy numbers (e.g., "2-4 copies") rather than exact counts. The VRS-python normalizer cannot process these range-based copy number descriptions.
- **Why it happens**: This is a shortcoming of the current VRS-python normalizer tool and its API. The normalizer requires exact copy number values.
- **Impact**: These variants cannot be processed by the VRS-python tool and must be excluded from the transformation process.

#### Issue: "sequence for accession not supported by vrs-python release"

- **What it means**: Genetic variants are described relative to reference sequences (like NC_, NM_, etc.). Some reference sequences are not supported by the VRS-python normalizer tool.
- **Why it happens**: This is a limitation of the VRS-python API - it only works with specific reference sequences that are included in its release. Newer, deprecated, or specialized reference sequences may not be available.
- **Impact**: Variants referencing unsupported sequences cannot be transformed to VRS and remain unprocessed.

#### Issue: "repeat expressions are not supported"

- **What it means**: Some genetic variants involve repetitive DNA sequences described with special notation like brackets and numbers. The VRS-python normalizer cannot process these expressions.
- **Example**: Variants described as `[CAG]15` (15 repeats of CAG sequence)
- **Why it happens**: This is a shortcoming of the VRS-python normalizer's parsing capabilities.
- **Impact**: Repeat-based variants cannot be transformed to VRS Alleles and remain unprocessed.

#### Issue: "expression contains unbalanced parentheses"

- **What it means**: The genetic variant description has mismatched opening and closing parentheses, making it impossible for the VRS-python tool to parse correctly.
- **Why it happens**: While this can be due to data entry errors, it's also a limitation of the VRS-python normalizer's parsing robustness.
- **Impact**: These variants cannot be processed by VRS-python and need correction before transformation is possible.

### 3. HGVS Expression Issues

HGVS (Human Genome Variation Society) is the standard way to describe genetic variants. The following issues prevent VRS transformation due to unsupported HGVS patterns:

#### Issue: "intronic positions are not resolvable in sequence"

- **What it means**: The variant is located in non-coding regions between genes (introns) using special notation that the VRS-python normalizer cannot resolve to precise genomic coordinates.
- **Example**: Positions described as `123+5` or `456-10`
- **Why it happens**: Intronic offset notation describes positions relative to exon boundaries, but VRS Alleles require absolute genomic coordinates. Resolving these offsets requires transcript-to-genome alignment data that the VRS-python normalizer does not perform.
- **Impact**: These variants cannot be mapped to the precise genomic locations required for VRS Allele creation.

#### Issue: "unsupported hgvs expression"

- **What it means**: The genetic variant description doesn't match any of the HGVS patterns that the VRS-python normalizer can recognize and process.
- **Why it happens**: Non-standard notation, complex variants, or formatting that falls outside VRS-python's supported HGVS subset.
- **Impact**: These variants cannot be transformed to VRS and require either correction or exclusion from the process.

### 4. Processing Pipeline Issues

#### Issue: "Pipeline could not identify a validly formatted source"

- **What it means**: The assessment couldn't find any usable representation (SPDI, HGVS, or gnomAD format) for the genetic variant that would be suitable for VRS transformation.
- **Why it happens**: The variant data may be incomplete, corrupted, or lack the specific formatting required by VRS-python normalization.
- **Impact**: These variants cannot undergo VRS transformation and remain without standardized representations.

#### Issue: "No viable variation members identified"

- **What it means**: The assessment couldn't find any processable components for this genetic variant that meet the requirements for VRS transformation.
- **Why it happens**: All available descriptions of the variant have issues that prevent VRS processing, or the variant lacks sufficient contextual information.
- **Impact**: The variant remains excluded from VRS transformation and will not receive a Cat-VRS representation.

## Issue Summary

The table below categorizes all issue types by their root cause and whether they may be resolved in future releases.

| Issue | Category | Potentially Resolvable? |
| ----- | -------- | ----------------------- |
| Haplotype/genotype not supported | Scope | No — intentionally out of scope |
| Protein expressions not supported | Scope | No — outside pipeline design |
| Range copies not supported | VRS-python limitation | Yes — if normalizer adds range support |
| Sequence for accession not supported | VRS-python limitation | Yes — as reference sequences are updated |
| Repeat expressions not supported | VRS-python limitation | Yes — if normalizer adds repeat parsing |
| Unbalanced parentheses | VRS-python limitation | Partial — data corrections or parser improvements |
| Intronic positions not resolvable | HGVS | Yes — if normalizer adds transcript alignment |
| Unsupported HGVS expression | HGVS | Partial — depends on specific notation |
| Pipeline could not identify a valid source | Pipeline | Partial — depends on upstream data quality |
| No viable variation members identified | Pipeline | Partial — depends on upstream data quality |

## Recommendations for Data Users

1. **Check the issue field**: Review the issue field on any variant that was not transformed to understand why it was excluded.
2. **Distinguish scope from limitations**: Scope exclusions (haplotypes, genotypes, protein expressions) are permanent by design. VRS-python limitations may be resolved in future releases.
3. **Expert review**: Variants flagged with pipeline or HGVS issues may benefit from domain expert evaluation to determine if manual VRS creation is feasible.
4. **Monitor VRS-python releases**: As the normalizer adds support for new reference sequences, repeat expressions, and intronic resolution, re-running the assessment may recover previously excluded variants.

## Technical Context

This assessment is part of converting ClinVar genetic variant data into standardized VRS v2.0 (Variation Representation Specification) format, which will enable creation of Cat-VRS v1.0 categorical variant representations. This standardization facilitates better data sharing, analysis, and interoperability across different genetic databases and research systems while maintaining precise computational definitions of genetic variants.
