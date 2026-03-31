# parse-utils.ts -- ClinVar Content Parsers

**Source:** `src/parse-utils.ts` (3,585 lines)
**Compiled to:** `dist/parse-utils.js`
**GCS path:** `gs://clinvar-ingest/bq-tools/parse-utils.js`

This module provides functions for parsing the `content` JSON fields in the ClinVar BigQuery schema. ClinVar XML data is converted to JSON during ingest, and these fields contain nested structures that use XML-style attribute conventions (`@Type`, `$` for text content, etc.). Each parser takes a JSON string, extracts a specific entity type, and returns a normalized output structure with snake_case keys and null-safe values.

!!! info "Naming Convention"
    All parsers follow the same pattern: accept a JSON string, parse it, and return normalized output. Internal `build*` helper functions handle the actual field mapping but are not intended for direct use from SQL.

---

## GeneList

Parses gene list entries from clinical assertion variant objects.

### `parseGeneLists`

```typescript
function parseGeneLists(json: string): GeneListOutput[]
```

**Input key:** `GeneList`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `symbol` | `string \| null` | `Gene.@Symbol` |
| `relationship_type` | `string \| null` | `Gene.@RelationshipType` |
| `name` | `string \| null` | `Gene.Name.$` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseGeneLists-func.sql`

---

## Comment

Parses comment objects from ClinVar content fields.

### `parseComments`

```typescript
function parseComments(json: string): CommentOutput[]
```

**Input key:** `Comment`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `text` | `string \| null` | `$` |
| `type` | `string \| null` | `@Type` |
| `source` | `string \| null` | `@DataSource` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseComments-func.sql`

---

## Citation

Parses citation references including PubMed IDs, BookShelf IDs, URLs, and citation text.

### `parseCitations`

```typescript
function parseCitations(json: string): CitationOutput[]
```

**Input key:** `Citation`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `type` | `string \| null` | `@Type` |
| `abbrev` | `string \| null` | `@Abbrev` |
| `id` | `Array<{source, id, curie}> \| null` | `ID` (single or array) |
| `url` | `string \| null` | `URL.$` |
| `text` | `string \| null` | `CitationText.$` |

Each citation ID entry includes a `curie` field constructed as `"Source:ID"` (e.g., `"PubMed:20301418"`).

**SQL wrapper:** `scripts/parsing-funcs/parse-parseCitations-func.sql`

---

## XRef (Cross-Reference)

Parses cross-reference entries from ClinVar content fields.

### `parseXRefs`

```typescript
function parseXRefs(json: string): XRefOutput[]
```

**Input key:** `XRef`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `db` | `string \| null` | `@DB` |
| `id` | `string \| null` | `@ID` |
| `url` | `string \| null` | `@URL` |
| `type` | `string \| null` | `@Type` |
| `status` | `string \| null` | `@Status` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseXRefs-func.sql`

### `parseXRefItems`

Parses an array of JSON strings representing XRef items that exist outside of `content` fields (using lowercase keys instead of `@`-prefixed XML attribute keys).

```typescript
function parseXRefItems(json_array: Array<string>): XRefItemOutput[]
```

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `db` | `string \| null` | `db` |
| `id` | `string \| null` | `id` |
| `type` | `string \| null` | `type` |
| `url` | `string \| null` | `url` |
| `status` | `string \| null` | `status` |
| `ref_field` | `string \| null` | `ref_field` |

!!! note
    Unlike `parseXRefs`, this function takes an array of JSON strings (not a single JSON string) and maps from already-lowercase keys.

---

## Attribute

Parses a single Attribute object with optional type, value, integer value, and date value.

### `parseAttribute`

```typescript
function parseAttribute(json: string): AttributeOutput
```

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `type` | `string \| null` | `@Type` |
| `value` | `string \| null` | `$` |
| `integer_value` | `number \| null` | `@integerValue` (parsed to int) |
| `date_value` | `Date \| null` | `@dateValue` (parsed to Date) |

---

## AttributeSet

Parses attribute sets, which are composite objects containing an Attribute with associated Citations, XRefs, and Comments.

### `parseAttributeSet`

```typescript
function parseAttributeSet(json: string): AttributeSetOutput[]
```

**Input key:** `AttributeSet`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `attribute` | `AttributeOutput \| null` | `Attribute` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput[] \| null` | `Comment` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseAttributeSet-func.sql`

---

## HGVS Expressions

Parsers for HGVS (Human Genome Variation Society) nomenclature structures, including nucleotide expressions, protein expressions, and derived HGVS strings.

### `parseNucleotideExpression`

```typescript
function parseNucleotideExpression(json: string): NucleotideExpressionOutput
```

**Input key:** `NucleotideExpression`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `expression` | `string \| null` | `Expression.$` |
| `sequence_type` | `string \| null` | `@sequenceType` |
| `sequence_accession_version` | `string \| null` | `@sequenceAccessionVersion` |
| `sequence_accession` | `string \| null` | `@sequenceAccession` |
| `sequence_version` | `string \| null` | `@sequenceVersion` |
| `change` | `string \| null` | `@change` |
| `assembly` | `string \| null` | `@Assembly` |
| `submitted` | `string \| null` | `@Submitted` |
| `mane_select` | `boolean \| null` | `@MANESelect` (string `"true"` to boolean) |
| `mane_plus_clinical` | `boolean \| null` | `@MANEPlusClinical` (string `"true"` to boolean) |

### `parseProteinExpression`

```typescript
function parseProteinExpression(json: string): ProteinExpressionOutput
```

**Input key:** `ProteinExpression`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `expression` | `string \| null` | `Expression.$` |
| `sequence_accession_version` | `string \| null` | `@sequenceAccessionVersion` |
| `sequence_accession` | `string \| null` | `@sequenceAccession` |
| `sequence_version` | `string \| null` | `@sequenceVersion` |
| `change` | `string \| null` | `@change` |

### `parseHGVS`

Parses composite HGVS objects that combine nucleotide and protein expressions with molecular consequences.

```typescript
function parseHGVS(json: string): HGVSOutput[]
```

**Input key:** `HGVS`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `nucleotide_expression` | `NucleotideExpressionOutput \| null` | `NucleotideExpression` |
| `protein_expression` | `ProteinExpressionOutput \| null` | `ProteinExpression` |
| `molecular_consequence` | `XRefOutput[] \| null` | `MolecularConsequence` |
| `type` | `string \| null` | `@Type` |
| `assembly` | `string \| null` | `@Assembly` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseHGVS-func.sql`

### `deriveHGVS`

Derives an HGVS genomic notation string from a variation type and sequence location data. This function does not parse JSON -- it computes HGVS strings from pre-parsed data.

```typescript
function deriveHGVS(
  variation_type: string,
  seqLoc: SequenceLocationOutput
): string | null
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `variation_type` | `string` | The ClinVar variation type (e.g., `"single nucleotide variant"`, `"Deletion"`, `"Duplication"`, `"copy number loss"`, `"copy number gain"`) |
| `seqLoc` | `SequenceLocationOutput` | A parsed sequence location object |

**Returns:** An HGVS string (e.g., `"NC_000001.10:g.12345A>G"`) or `null` if the HGVS cannot be derived.

**Behavior:**

- For **SNVs**: constructs from `accession`, `position_vcf`, `reference_allele_vcf`, and `alternate_allele_vcf`
- For **deletions and duplications**: constructs from `accession`, `start`/`stop` (or `inner_start`/`inner_stop`/`outer_start`/`outer_stop` ranges)
- Uses `m.` prefix for mitochondrial accession `NC_012920.1`, `g.` for all others
- Returns `null` for unsupported variation types or insufficient data

**SQL wrapper:** `scripts/general/bq-deriveHGVS-func.sql`

---

## SequenceLocation

Parses genomic sequence location data including assembly information, coordinates, and VCF-style allele data.

### `parseSequenceLocations`

```typescript
function parseSequenceLocations(json: string): SequenceLocationOutput[]
```

**Input key:** `SequenceLocation`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `for_display` | `boolean \| null` | `@forDisplay` |
| `assembly` | `string \| null` | `@Assembly` |
| `assembly_accession_version` | `string \| null` | `@AssemblyAccessionVersion` |
| `assembly_status` | `string \| null` | `@AssemblyStatus` |
| `accession` | `string \| null` | `@Accession` |
| `chr` | `string \| null` | `@Chr` |
| `start` | `number \| null` | `@start` |
| `stop` | `number \| null` | `@stop` |
| `inner_start` | `number \| null` | `@innerStart` |
| `inner_stop` | `number \| null` | `@innerStop` |
| `outer_start` | `number \| null` | `@outerStart` |
| `outer_stop` | `number \| null` | `@outerStop` |
| `variant_length` | `number \| null` | `@variantLength` |
| `display_start` | `number \| null` | `@display_start` |
| `display_stop` | `number \| null` | `@display_stop` |
| `position_vcf` | `number \| null` | `@positionVCF` |
| `reference_allele_vcf` | `string \| null` | `@referenceAlleleVCF` |
| `alternate_allele_vcf` | `string \| null` | `@alternateAlleleVCF` |
| `strand` | `string \| null` | `@Strand` |
| `reference_allele` | `string \| null` | `@referenceAllele` |
| `alternate_allele` | `string \| null` | `@alternateAllele` |
| `for_display_length` | `boolean \| null` | `@forDisplayLength` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseSequenceLocations-func.sql`

---

## Software

Parses software metadata associated with methods.

### `parseSoftware`

```typescript
function parseSoftware(json: string): SoftwareOutput[]
```

**Input key:** `Software`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `name` | `string \| null` | `@name` |
| `version` | `string \| null` | `@version` |
| `purpose` | `string \| null` | `@purpose` |

---

## Method and Method Attributes

Parsers for clinical testing method objects, including method attributes and observed method attributes.

### `parseMethodAttributes`

```typescript
function parseMethodAttributes(json: string): MethodAttributeOutput[]
```

**Input key:** `MethodAttribute`

**Output fields:**

| Field | Type |
|---|---|
| `attribute` | `AttributeOutput \| null` |

### `parseObsMethodAttributes`

Parses observed method attributes, which include both an attribute and an optional comment.

```typescript
function parseObsMethodAttributes(json: string): ObsMethodAttributeOutput[]
```

**Input key:** `ObsMethodAttribute`

**Output fields:**

| Field | Type |
|---|---|
| `attribute` | `AttributeOutput \| null` |
| `comment` | `CommentOutput \| null` |

### `parseMethods`

Parses complete method objects, which aggregate platform information, result types, citations, cross-references, software, and method attributes.

```typescript
function parseMethods(json: string): MethodOutput[]
```

**Input key:** `Method`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `name_platform` | `string \| null` | `NamePlatform.$` |
| `type_platform` | `string \| null` | `TypePlatform.$` |
| `purpose` | `string \| null` | `Purpose.$` |
| `result_type` | `string \| null` | `ResultType.$` |
| `min_reported` | `number \| null` | `MinReported.$` (parsed to int) |
| `max_reported` | `number \| null` | `MaxReported.$` (parsed to int) |
| `reference_standard` | `string \| null` | `ReferenceStandard.$` |
| `description` | `string \| null` | `Description.$` |
| `source_type` | `string \| null` | `SourceType.$` |
| `method_type` | `string \| null` | `MethodType.$` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `software` | `SoftwareOutput[] \| null` | `Software` |
| `method_attribute` | `MethodAttributeOutput[] \| null` | `MethodAttribute` |
| `obs_method_attribute` | `ObsMethodAttributeOutput[] \| null` | `ObsMethodAttribute` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseMethods-func.sql`

---

## ObservedData

Parses observed data entries from clinical assertions.

### `parseObservedData`

```typescript
function parseObservedData(json: string): ObservedDataOutput[]
```

**Input key:** `ObservedData`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `attribute` | `AttributeOutput \| null` | `Attribute` |
| `severity` | `string \| null` | `Severity` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput[] \| null` | `Comment` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseObservedData-func.sql`

---

## SetElement

Parses set element structures used for names and symbols throughout ClinVar entities.

### `parseSetElement`

```typescript
function parseSetElement(json: string): SetElementOutput[]
```

**Input key:** `SetElement`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `element_value` | `string \| null` | `ElementValue.$` |
| `type` | `string \| null` | `ElementValue.@Type` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput[] \| null` | `Comment` |

---

## FamilyInfo

Parses family data associated with clinical assertion samples.

### `parseFamilyInfo`

```typescript
function parseFamilyInfo(json: string): FamilyInfoOutput
```

**Input key:** `FamilyInfo`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `family_history` | `string \| null` | `FamilyHistory` |
| `num_families` | `number \| null` | `@NumFamilies` (parsed to int) |
| `num_families_with_variant` | `number \| null` | `@NumFamiliesWithVariant` (parsed to int) |
| `num_families_with_segregation_observed` | `number \| null` | `@NumFamiliesWithSegregationObserved` (parsed to int) |
| `pedigree_id` | `string \| null` | `@PedigreeID` |
| `segregation_observed` | `string \| null` | `@SegregationObserved` |

---

## Age

Parses age range data from sample objects.

### `parseAges`

```typescript
function parseAges(json: string): AgeOutput[]
```

**Input key:** `Age`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `value` | `number \| null` | `$` (parsed to int) |
| `type` | `string \| null` | `@Type` (e.g., `"minimum"`, `"maximum"`) |
| `age_unit` | `string \| null` | `@age_unit` (e.g., `"year"`) |

---

## TraitRelationship

Parses trait relationship objects that link traits to related entities.

### `parseTraitRelationships`

```typescript
function parseTraitRelationships(json: string): TraitRelationshipOutput[]
```

**Input key:** `TraitRelationship`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `name` | `SetElementOutput[] \| null` | `Name` |
| `symbol` | `SetElementOutput[] \| null` | `Symbol` |
| `attribute_set` | `AttributeSetOutput[] \| null` | `AttributeSet` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `source` | `string[] \| null` | `Source` |
| `type` | `string \| null` | `@Type` |

---

## ClinicalAssertionTrait

Parses clinical assertion trait objects, which are enriched trait structures specific to clinical assertions.

### `parseClinicalAsserTraits`

```typescript
function parseClinicalAsserTraits(json: string): ClinicalAsserTraitOutput[]
```

**Input key:** `Trait`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `name` | `SetElementOutput[] \| null` | `Name` |
| `symbol` | `SetElementOutput[] \| null` | `Symbol` |
| `attribute_set` | `AttributeSetOutput[] \| null` | `AttributeSet` |
| `trait_relationship` | `TraitRelationshipOutput[] \| null` | `TraitRelationship` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput[] \| null` | `Comment` |
| `type` | `string \| null` | `@Type` |
| `clinical_features_affected_status` | `string \| null` | `@ClinicalFeaturesAffectedStatus` |
| `id` | `string \| null` | `@ID` |

---

## Indication

Parses indication objects, which combine traits with additional metadata in clinical assertion contexts.

### `parseIndications`

```typescript
function parseIndications(json: string): IndicationOutput[]
```

**Input key:** `Indication`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `trait` | `ClinicalAsserTraitOutput[] \| null` | `Trait` |
| `name` | `SetElementOutput[] \| null` | `Name` |
| `symbol` | `SetElementOutput[] \| null` | `Symbol` |
| `attribute_set` | `AttributeSetOutput \| null` | `AttributeSet` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput \| null` | `Comment` |
| `type` | `string \| null` | `@Type` |
| `id` | `string \| null` | `@ID` |

---

## Sample

Parses sample objects from clinical assertion observations, which aggregate demographic, clinical, and family data.

### `parseSample`

```typescript
function parseSample(json: string): SampleOutput
```

**Input key:** `Sample`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `sample_description.description` | `SetElementOutput \| null` | `SampleDescription.Description` |
| `sample_description.citation` | `CitationOutput \| null` | `SampleDescription.Citation` |
| `origin` | `string \| null` | `Origin.$` |
| `ethnicity` | `string \| null` | `Ethnicity.$` |
| `geographic_origin` | `string \| null` | `GeographicOrigin.$` |
| `tissue` | `string \| null` | `Tissue.$` |
| `cell_line` | `string \| null` | `CellLine.$` |
| `species` | `string \| null` | `Species.$` |
| `taxonomy_id` | `string \| null` | `Species.@TaxonomyId` |
| `age` | `AgeOutput[] \| null` | `Age` |
| `strain` | `string \| null` | `Strain.$` |
| `affected_status` | `string \| null` | `AffectedStatus.$` |
| `number_tested` | `number \| null` | `NumberTested.$` (parsed to int) |
| `number_males` | `number \| null` | `NumberMales.$` (parsed to int) |
| `number_females` | `number \| null` | `NumberFemales.$` (parsed to int) |
| `number_chr_tested` | `number \| null` | `NumberChrTested.$` (parsed to int) |
| `gender` | `string \| null` | `Gender.$` |
| `family_data` | `FamilyInfoOutput \| null` | `FamilyData` |
| `proband` | `string \| null` | `Proband.$` |
| `indication` | `IndicationOutput \| null` | `Indication` |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput[] \| null` | `Comment` |
| `source_type` | `string \| null` | `SourceType.$` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseSample-func.sql`

---

## Trait

Parses VCV-level trait objects (distinct from `ClinicalAssertionTrait` used in SCV contexts).

### `parseTraits`

```typescript
function parseTraits(json: string): TraitOutput[]
```

**Input key:** `Trait`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `id` | `string \| null` | `@ID` |
| `type` | `string \| null` | `@Type` |
| `name` | `SetElementOutput[] \| null` | `Name` |
| `symbol` | `SetElementOutput[] \| null` | `Symbol` |
| `attribute_set` | `AttributeSetOutput[] \| null` | `AttributeSet` |
| `trait_relationship` | `{type, id}` | `TraitRelationship` (simple object, not array) |
| `citation` | `CitationOutput[] \| null` | `Citation` |
| `xref` | `XRefOutput[] \| null` | `XRef` |
| `comment` | `CommentOutput[] \| null` | `Comment` |

---

## TraitSet

Parses trait set objects, which group multiple traits under a common type.

### `parseTraitSet`

```typescript
function parseTraitSet(json: string): TraitSetOutput
```

**Input key:** `TraitSet`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `type` | `string \| null` | `@Type` |
| `id` | `string \| null` | `@ID` |
| `trait` | `TraitOutput[] \| null` | `Trait` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseTraitSet-func.sql`

---

## Classification Description

Parsers for aggregate classification description objects used in RCV and VCV classifications.

### `parseDescriptionItems`

Parses individual classification description items.

```typescript
function parseDescriptionItems(json: string): DescriptionItemOutput[]
```

**Input key:** `Description`

**Output fields:**

| Field | Type | Source |
|---|---|---|
| `clinical_impact_assertion_type` | `string \| null` | `@ClinicalImpactAssertionType` |
| `clinical_impact_clinical_significance` | `string \| null` | `@ClinicalImpactClinicalSignificance` |
| `date_last_evaluated` | `Date \| null` | `@DateLastEvaluated` (parsed to Date) |
| `num_submissions` | `number \| null` | `@SubmissionCount` (parsed to int) |
| `interp_description` | `string \| null` | `$` |

### `parseAggDescription`

Parses aggregate classification description objects, returning a wrapper around an array of description items.

```typescript
function parseAggDescription(json: string): AggDescriptionOutput
```

**Output fields:**

| Field | Type |
|---|---|
| `description` | `DescriptionItemOutput[] \| null` |

**SQL wrapper:** `scripts/parsing-funcs/parse-parseAggDescription-func.sql`
