# clinvar_2026_05_10_spdi2vrs.csv.gz

ClinVar variant-to-VRS mappings for the **May 10, 2026** ClinVar release.

## Description

This file contains GA4GH VRS (Variation Representation Specification) identifiers and representations for ClinVar variants that have been mapped to SPDI expressions by ClinVar. Only variants with a non-null SPDI source are included.

**Release date:** 2026-05-10
**Format:** CSV, gzip compressed
**Variants exported:** ~3.8M (SPDI-mapped only)

## Columns

| Column | Description |
| ------ | ----------- |
| `variation_id` | ClinVar variation ID |
| `name` | ClinVar variant name/label |
| `vrs_class` | VRS object class (e.g. Allele) |
| `fmt` | Input format (always `spdi` in this export) |
| `source` | SPDI expression used as input |
| `variation_type` | ClinVar variation type (e.g. single nucleotide variant) |
| `vrs_state_type` | VRS state type (e.g. LiteralSequenceExpression) |
| `vrs_state_sequence` | VRS state sequence (the alternate allele) |
| `vrs_state_length` | VRS state length (for repeat/length expressions) |
| `vrs_state_repeatSubunitLength` | VRS state repeat subunit length |
| `vrs_location_id` | VRS location identifier |
| `vrs_location_type` | VRS location type (e.g. SequenceLocation) |
| `vrs_location_start` | VRS location start coordinate (inter-residue) |
| `vrs_location_end` | VRS location end coordinate (inter-residue) |
| `vrs_type` | VRS type of the output object (e.g. Allele) |
| `vrs_id` | GA4GH VRS computed identifier (`ga4gh:VA.…`) |

## Notes

- Only covers variants where ClinVar provides an SPDI mapping (`in.fmt = 'spdi'` and `in.source IS NOT NULL`).
- Variants without SPDI expressions (e.g. structural variants, complex variants) are not included.
- VRS identifiers are computed using the GA4GH VRS specification and can be used for cross-system variant matching.
