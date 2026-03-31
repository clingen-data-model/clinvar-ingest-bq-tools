# bq-utils.ts -- BigQuery Utility Functions

**Source:** `src/bq-utils.ts` (373 lines)
**Compiled to:** `dist/bq-utils.js`
**GCS path:** `gs://clinvar-ingest/bq-tools/bq-utils.js`

This module provides general-purpose utility functions for date formatting, JSON transformation, significance type calculations, and identifier normalization. These functions are called from BigQuery UDFs defined in `scripts/general/`.

---

## Date Functions

### `formatNearestMonth`

Rounds a date to the nearest month and formats it as a short month-year string.

```typescript
function formatNearestMonth(date: Date | string): string
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `date` | `Date \| string` | A Date object or date string (e.g., `"2024-03-18"`) |

**Returns:** A string in the format `"Mon 'YY"` (e.g., `"Mar '24"`).

**Behavior:**

- Calculates the midpoint of the current month
- If the day is past the midpoint, rounds up to the next month
- Handles December-to-January year transitions
- Parses string dates manually to avoid timezone issues

!!! example
    - `"2024-03-10"` (day 10 of 31) returns `"Mar '24"` (before midpoint)
    - `"2024-03-20"` (day 20 of 31) returns `"Apr '24"` (after midpoint)

**SQL wrapper:** `scripts/general/bq-formatNearestMonth-func.sql`

---

### `determineMonthBasedOnRange`

Determines which month a date range primarily falls within, returning both a sortable key and a display label.

```typescript
function determineMonthBasedOnRange(
  startDate: Date,
  endDate: Date
): { yymm: string; monyy: string }
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `startDate` | `Date` | Start of the date range |
| `endDate` | `Date` | End of the date range |

**Returns:** An object with two properties:

| Property | Format | Example |
|---|---|---|
| `yymm` | `"YY-MM"` | `"24-03"` |
| `monyy` | `"Mon 'YY"` | `"Mar '24"` |

**Behavior:**

- If `startDate > endDate`, the dates are swapped
- Compares the number of days the range spans in the prior month vs. the current month (relative to `endDate`)
- If days are equal, the current month is selected (uses `>=`)

**SQL wrapper:** `scripts/general/bq-determineMonthBasedOnRange-func.sql`

---

### `formatMonthYear`

Internal helper that formats a Date to `"Mon 'YY"` format.

```typescript
function formatMonthYear(date: Date): string
```

!!! note
    This is a helper used by `formatNearestMonth` and `determineMonthBasedOnRange`. It is not wrapped by a separate SQL function.

---

## JSON Transformation Functions

### `normalizeAndKeyById`

Recursively normalizes JSON objects by collapsing prefixed keys (e.g., `value_string` to `value`, `start_position` to `start`) and converting `copies`, `start`, and `end` values to numeric types. Optionally re-keys the object by its `id` field.

```typescript
function normalizeAndKeyById(
  inputObject: JsonObjectWithId,
  skipKeyById?: boolean
): Record<string, JsonObjectWithId> | JsonObjectWithId
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `inputObject` | `JsonObjectWithId` | -- | A JSON object that must have a string `id` property |
| `skipKeyById` | `boolean` | `false` | If `true`, returns the normalized object without re-keying |

**Returns:**

- When `skipKeyById` is `false`: An object keyed by the portion of `id` after the colon (e.g., `"clinvar:200"` becomes key `"200"`)
- When `skipKeyById` is `true`: The normalized object as-is

**Normalization transforms applied recursively:**

1. **Prefix collapsing:** Keys like `value_string`, `objectCondition_code`, `start_position` are collapsed to their prefix (`value`, `objectCondition`, `start`)
2. **Numeric conversion:** `copies`, `start`, and `end` values are parsed to integers where possible; `"null"` and `""` become `null`
3. **Safe replacement:** A new key only overwrites an existing key if the existing value is `null` or an empty array

**SQL wrapper:** `scripts/general/bq-normalizeAndKeyById-func.sql`

---

### `keyObjectById`

Re-keys an object by the portion of its `id` after the colon (or the full `id` if no colon is present).

```typescript
function keyObjectById(
  inputObject: JsonObjectWithId
): Record<string, JsonObjectWithId>
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `inputObject` | `JsonObjectWithId` | Must have a non-empty string `id` property |

**Returns:** A new object where the key is derived from the `id` value.

!!! example
    Input: `{ "id": "clinvar:200", "name": "test" }`
    Output: `{ "200": { "id": "clinvar:200", "name": "test" } }`

!!! note
    This is a helper used by `normalizeAndKeyById`. It is not wrapped by a separate SQL function.

---

## Significance Type Functions

### `createSigType`

Creates an array of objects representing the count and percentage of each clinical significance category (not significant, uncertain, significant).

```typescript
function createSigType(
  nosigCount: number,
  uncCount: number,
  sigCount: number
): SigType[]
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `nosigCount` | `number` | Count of not-significant items |
| `uncCount` | `number` | Count of uncertain items |
| `sigCount` | `number` | Count of significant items |

**Returns:** An array of three `SigType` objects, each containing:

```typescript
type SigType = {
  count: number;
  percent: number;  // rounded to 3 decimal places
};
```

The array order is: `[nosig, uncertain, significant]`.

**Behavior:**

- If the total count is zero, returns `[{count:0, percent:0}, ...]`
- Percentages are calculated as `Math.round((count / total) * 1000) / 1000`

**SQL wrapper:** `scripts/general/bq-createSigType-func.sql`

---

## Identifier Normalization

### `normalizeHpId`

Normalizes Human Phenotype Ontology (HPO) identifiers to the standard format `HP:0000000` (seven-digit zero-padded).

```typescript
function normalizeHpId(
  hpId: string | null | undefined
): string | null | undefined
```

**Parameters:**

| Parameter | Type | Description |
|---|---|---|
| `hpId` | `string \| null \| undefined` | The HP ID to normalize |

**Returns:** The normalized HP ID, or `null`/`undefined` if the input was `null`/`undefined`.

**Behavior:**

- Collapses redundant prefixes like `HP:HP:1234` or `hp:hp:1234`
- Strips leading zeros, then re-pads to exactly 7 digits
- If the digit count exceeds 7 after trimming, returns the original value uppercased
- If the input does not resolve to all digits after prefix removal, returns the original uppercased

!!! example
    - `"hp:hp:1234"` returns `"HP:0001234"`
    - `"HP:0000001"` returns `"HP:0000001"`
    - `"HP123"` returns `"HP:0000123"`

**SQL wrapper:** `scripts/general/bq-normalizeHpId-func.sql`
