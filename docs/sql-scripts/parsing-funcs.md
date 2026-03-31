# Parsing Functions

The parsing functions are BigQuery SQL wrappers around JavaScript UDF implementations that live in the TypeScript source (`src/parse-utils.ts`). They extract structured data from the raw JSON content fields stored in ClinVar's `clinical_assertion` and related tables.

All parsing functions use the `LANGUAGE js` option and load the compiled JavaScript library from `gs://clinvar-ingest/bq-tools/parse-utils.js`.

## Scripts

| File | Function Created | Return Type | Description |
|------|------------------|-------------|-------------|
| `parse-parseAggDescription-func.sql` | `clinvar_ingest.parseAggDescription()` | `STRUCT<description ARRAY<...>>` | Parses aggregate classification descriptions including clinical impact assertion type, significance, date last evaluated, and submission count |
| `parse-parseAttributeSet-func.sql` | `clinvar_ingest.parseAttributeSet()` | `ARRAY<STRUCT<attribute, citation, xref, comment>>` | Parses `AttributeSet` elements from content JSON, extracting typed attributes with associated citations, cross-references, and comments |
| `parse-parseCitations-func.sql` | `clinvar_ingest.parseCitations()` | `ARRAY<STRUCT<id, url, type, abbrev, text>>` | Parses citation arrays from interpretation and attribute set contexts, returning structured citation records with source IDs |
| `parse-parseComments-func.sql` | `clinvar_ingest.parseComments()` | `ARRAY<STRUCT<text, type, source>>` | Parses comment elements from content JSON |
| `parse-parseComments-func.sql` | `clinvar_ingest.parseCommentItems()` | `ARRAY<STRUCT<db, id, type, status, url>>` | Parses pre-extracted comment item arrays (defined in the same file) |
| `parse-parseGeneLists-func.sql` | `clinvar_ingest.parseGeneLists()` | `ARRAY<STRUCT<symbol, relationship_type, name>>` | Parses `GeneList` elements to extract gene symbols, relationship types, and names |
| `parse-parseHGVS-func.sql` | `clinvar_ingest.parseHGVS()` | `ARRAY<STRUCT<nucleotide_expression, protein_expression, molecular_consequence, assembly, type>>` | Parses HGVS expression sets including nucleotide and protein expressions, MANE Select/Plus Clinical flags, and molecular consequences |
| `parse-parseMethods-func.sql` | `clinvar_ingest.parseMethods()` | `ARRAY<STRUCT<name_platform, type_platform, purpose, ...>>` | Parses observation method data including platform info, result types, citations, cross-references, software, and method/observation attributes |
| `parse-parseObservedData-func.sql` | `clinvar_ingest.parseObservedData()` | `ARRAY<STRUCT<attribute, severity, citation, xref, comment>>` | Parses `ObservedData` elements from observation content, including mode of inheritance, assertion methods, and variant allele counts |
| `parse-parseSample-func.sql` | `clinvar_ingest.parseSample()` | `STRUCT<sample_description, origin, ethnicity, ...>` | Parses sample/observation data including demographics (age, gender, ethnicity), affected status, family data, and co-occurrence sets |
| `parse-parseSequenceLocations-func.sql` | `clinvar_ingest.parseSequenceLocations()` | `ARRAY<STRUCT<for_display, assembly, chr, start, stop, ...>>` | Parses sequence location data including genomic coordinates, VCF positions, reference/alternate alleles, and assembly information |
| `parse-parseTraitSet-func.sql` | `clinvar_ingest.parseTraitSet()` | `STRUCT<trait ARRAY<...>>` | Parses trait set structures including trait names, symbols, attribute sets, relationships, citations, and cross-references |
| `parse-parseXRefs-func.sql` | `clinvar_ingest.parseXRefs()` | `ARRAY<STRUCT<db, id, type, status, url, ref_field>>` | Parses cross-reference elements from content JSON |
| `parse-parseXRefs-func.sql` | `clinvar_ingest.parseXRefItems()` | `ARRAY<STRUCT<db, id, type, status, url, ref_field>>` | Parses pre-extracted cross-reference item arrays (defined in the same file) |

## How They Are Used

These functions are primarily called during the **dataset preparation** stage:

- `parseAttributeSet` and `parseComments` are called in `scv_summary` (step 03) to parse the `clinical_assertion.content` field
- `parseCitations`, `parseHGVS`, `parseGeneLists` are used to extract structured data from classification and interpretation JSON
- `parseSample`, `parseMethods`, `parseObservedData`, `parseTraitSet` are called in `gc_scv_obs` (step 05) to parse observation content
- `parseAggDescription` is used when processing aggregate VCV/RCV classification descriptions
- `parseSequenceLocations` and `parseXRefs` support various downstream queries

!!! info "JavaScript library deployment"
    The compiled JavaScript file (`parse-utils.js`) must be uploaded to `gs://clinvar-ingest/bq-tools/` before these functions will work. The `npm run build` command compiles the TypeScript source to JavaScript, but the GCS upload is a separate step.

## Test Queries

Each function file includes inline test queries (following the function definition) that demonstrate usage with sample ClinVar JSON data. These serve as both documentation and manual verification tests.
