# TypeScript Utilities

## Overview

This project includes two TypeScript source files that compile to JavaScript libraries consumed by BigQuery user-defined functions (UDFs). The compiled JS files are uploaded to a GCS bucket and referenced directly from SQL function definitions, allowing BigQuery to execute complex JSON parsing and data transformation logic that would be difficult or impossible to express in pure SQL.

| Source File | Compiled Output | Purpose |
|---|---|---|
| `src/bq-utils.ts` | `dist/bq-utils.js` | Date formatting, JSON normalization, significance calculations, HP ID normalization |
| `src/parse-utils.ts` | `dist/parse-utils.js` | Parsing ClinVar XML-to-JSON `content` fields into structured output |

## Build Process

TypeScript is compiled to ES6 JavaScript using the TypeScript compiler:

```bash
npx tsc
```

This outputs compiled `.js` files to the `dist/` directory. The compiled files are then uploaded to the GCS bucket `gs://clinvar-ingest/bq-tools/` where BigQuery can access them as external JavaScript libraries.

The `tsconfig.json` specifies:

- **Target:** ES6
- **Module:** CommonJS
- **Output directory:** `./dist`
- **Root directory:** `./src`
- **Strict mode:** enabled

## How BigQuery SQL Functions Reference These Libraries

SQL wrapper functions in `scripts/parsing-funcs/` and `scripts/general/` create BigQuery UDFs that call the JavaScript functions. Each SQL file uses `CREATE OR REPLACE FUNCTION` with `LANGUAGE js` and an `OPTIONS` block that specifies the GCS library path.

**Example -- a parsing function wrapper** (`scripts/parsing-funcs/parse-parseCitations-func.sql`):

```sql
CREATE OR REPLACE FUNCTION `clinvar_ingest.parseCitations`(json STRING)
RETURNS ARRAY<STRUCT<id ARRAY<STRUCT<id STRING, source STRING, curie STRING>>,
                     url STRING, type STRING, abbrev STRING, text STRING>>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseCitations(json);
""";
```

**Example -- a bq-utils function wrapper** (`scripts/general/bq-formatNearestMonth-func.sql`):

```sql
CREATE OR REPLACE FUNCTION `clinvar_ingest.formatNearestMonth`(arg DATE)
RETURNS STRING
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/bq-utils.js'])
AS r"""
  return formatNearestMonth(arg);
""";
```

!!! note "Function Scope"
    The TypeScript functions are **not** exported using `export` or `module.exports`. When BigQuery loads a JavaScript library, all top-level functions become available in the UDF scope. This means every function defined at the top level of each `.ts` file is callable from the corresponding SQL wrapper.

### SQL Wrapper Locations

| Directory | Library Referenced | Functions Wrapped |
|---|---|---|
| `scripts/parsing-funcs/` | `parse-utils.js` | `parseCitations`, `parseComments`, `parseGeneLists`, `parseHGVS`, `parseMethods`, `parseObservedData`, `parseSample`, `parseSequenceLocations`, `parseTraitSet`, `parseXRefs`, `parseAttributeSet`, `parseAggDescription` |
| `scripts/general/` | `bq-utils.js` | `formatNearestMonth`, `determineMonthBasedOnRange`, `createSigType`, `normalizeHpId`, `normalizeAndKeyById` |
| `scripts/general/` | `parse-utils.js` | `deriveHGVS` |

## Testing

Tests are run with Jest:

```bash
npm test
```

Test files live in the `/test` directory and include sample ClinVar XML data. The test suite covers both parsing utilities and BigQuery transformation functions. Tests use the `rewire` package to access non-exported functions for unit testing.

## Detailed Function Reference

- **[bq-utils.ts](bq-utils.md)** -- Date formatting, JSON normalization, significance type calculations, and HP ID normalization
- **[parse-utils.ts](parse-utils.md)** -- ClinVar content JSON parsers organized by entity type (GeneList, Citation, HGVS, Method, Sample, Trait, etc.)
