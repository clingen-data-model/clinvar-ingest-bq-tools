
/**
 * Formats a given date or string into the nearest month in the format "Month Year".
 * If the day of the month is 15 or greater, it rounds up to the next month.
 * If the month is December, it transitions to the next year.
 *
 * @param date - The date or string to be formatted.
 * @returns The formatted date in the format "Month Year".
 */
function formatNearestMonth(date: Date | string): string {
  let inputDate: Date;

  if (typeof date === 'string') {
    // Parse string dates manually to avoid timezone issues
    const dateMatch = date.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (dateMatch) {
      const year = parseInt(dateMatch[1], 10);
      const month = parseInt(dateMatch[2], 10) - 1; // Month is 0-indexed
      const day = parseInt(dateMatch[3], 10);
      inputDate = new Date(year, month, day);
    } else {
      inputDate = new Date(date);
    }
  } else {
    // For Date objects, extract UTC components and recreate as local date
    // This ensures consistent behavior regardless of how the Date was originally created
    const year = date.getUTCFullYear();
    const month = date.getUTCMonth();
    const day = date.getUTCDate();
    inputDate = new Date(year, month, day);
  }

  if (isNaN(inputDate.getTime())) {
    throw new Error('Invalid date provided');
  }

  // Get the year, month, and day from the date
  let year = inputDate.getFullYear();
  let month = inputDate.getMonth(); // getMonth() returns month from 0-11
  const day = inputDate.getDate();

  // Calculate the number of days in the current month
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const midpoint = Math.ceil(daysInMonth / 2);

  // Decide whether to round up or down based on which half of the month the day falls in
  if (day > midpoint) {
    month += 1; // Move to the next month
    if (month === 12) { // Check for year transition
      month = 0;
      year += 1;
    }
  }

  // Create a new Date object for the first of the determined month/year
  const newDate = new Date(year, month, 1);

  return formatMonthYear(newDate);
}


function formatMonthYear(date: Date): string {
  // Format the date to "MMM 'YY"
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const formattedMonth = monthNames[date.getMonth()];
  const formattedYear = date.getFullYear().toString().substring(2);

  return `${formattedMonth} '${formattedYear}`;
}

/**
 * Determines the month based on a date range.
 *
 * @param startDate - The start date of the range.
 * @param endDate - The end date of the range.
 * @returns The month in the format "MM/YYYY" that has more days in the range, or the prior month if the days are equal.
 */
function calculateDaysInRange(startDate: Date, endDate: Date): number {
  return (endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24) + 1;
}

function getMonthBoundaries(date: Date) {
  const firstDay = new Date(date.getFullYear(), date.getMonth(), 1);
  const lastDay = new Date(date.getFullYear(), date.getMonth() + 1, 0);
  return { firstDay, lastDay };
}

function determineMonthBasedOnRange(startDate: Date, endDate: Date): { yymm: string; monyy: string } {
  if (startDate > endDate) {
    [startDate, endDate] = [endDate, startDate];
  }

  const priorMonth = new Date(endDate.getFullYear(), endDate.getMonth() - 1, 1);
  const currentMonth = new Date(endDate.getFullYear(), endDate.getMonth(), 1);

  const priorBoundaries = getMonthBoundaries(priorMonth);
  const adjustedPriorStart = priorBoundaries.firstDay > startDate ? priorBoundaries.firstDay : startDate;

  const daysInPriorMonth = calculateDaysInRange(adjustedPriorStart, priorBoundaries.lastDay);
  const daysInCurrentMonth = calculateDaysInRange(currentMonth, endDate);

  const selectedDate = daysInCurrentMonth >= daysInPriorMonth ? endDate : adjustedPriorStart;
  const monthStr = (selectedDate.getMonth() + 1).toString().padStart(2, '0');
  const yearStr = selectedDate.getFullYear().toString().substring(2);
  const monthYear = formatMonthYear(selectedDate);

  return { yymm: `${yearStr}-${monthStr}`, monyy: monthYear };
}


// json transforms
interface JsonObjectWithId {
  id: string;
  [key: string]: unknown;
}

/**
 * Transforms an input object into a new object keyed by the portion of the 'id' after the colon or the 'id' property itself if no colon is present.
 * @param inputObject - The input object to transform.
 * @returns A new object with the portion of the 'id' after the colon as the key or the 'id' property as the key if no colon is present.
 * @throws {Error} If the input object does not have an 'id' property.
 */
function keyObjectById(inputObject: JsonObjectWithId): Record<string, JsonObjectWithId> {
  if (!inputObject || !inputObject.hasOwnProperty('id') || typeof inputObject.id !== 'string') {
    throw new Error('Input object must have a valid string "id" property.');
  }

  if (inputObject.id.trim() === '') {
    throw new Error('Input object "id" property cannot be empty.');
  }

  // Extract the final key value if a colon is present in the 'id' property
  let key = inputObject.id;
  if (key.includes(':')) {
    key = key.split(':')[1];
  }

  // Create a new object using the extracted key value as the key itself
  const transformedObject: Record<string, JsonObjectWithId> = {};
  transformedObject[key] = inputObject;

  return transformedObject;
}

interface JsonObject {
  [key: string]: unknown;
}

type TransformFunction = (key: string | number, value: unknown) => { key: string; value: unknown } | undefined;

// Helpers
const isObject = (x: unknown): x is JsonObject =>
  typeof x === "object" && x !== null && !Array.isArray(x);

const isEmptyArray = (x: unknown): x is unknown[] =>
  Array.isArray(x) && x.length === 0;

/**
 * Only allow writing the replacement if:
 *  - the new key didn’t exist before, OR
 *  - its current value is null, OR
 *  - its current value is an empty array
 */
function canWriteReplacement(
  obj: JsonObject,
  newKey: string,
  oldKey: string
): boolean {
  if (newKey === oldKey || !(newKey in obj)) return true;
  const existing = obj[newKey];
  return existing === null || isEmptyArray(existing);
}

function recurseJson(
  node: JsonObject | unknown[],
  fns: TransformFunction[]
): void {
  if (Array.isArray(node)) {
    for (let i = 0; i < node.length; i++) {
      let val = node[i];

      for (const fn of fns) {
        const rep = fn(i, val);
        if (rep) {
          val = rep.value;
          node[i] = val;
        }
      }

      if (isObject(val) || Array.isArray(val)) {
        recurseJson(val, fns);
      }
    }

  } else if (isObject(node)) {
    // snapshot original keys so new ones don't get re-visited
    const keys = Object.keys(node);

    for (const origKey of keys) {
      let val = node[origKey];
      let curKey = origKey;

      for (const fn of fns) {
        const rep = fn(curKey, val);
        if (rep) {
          // always delete the old property
          delete node[curKey];

          // only write the new one if it passes our rule
          if (canWriteReplacement(node, rep.key, curKey)) {
            node[rep.key] = rep.value;
          }

          // for further transforms & recursion, work on the new value
          val = rep.value;
          curKey = rep.key;
        }
      }

      if (isObject(val) || Array.isArray(val)) {
        recurseJson(val, fns);
      }
    }
  }
}

type LocalKeyType = "copies" | "start" | "end";
type ParsedValue = number | string | null;
type Result = { key: LocalKeyType; value: ParsedValue | ParsedValue[] };

function isEmpty(v: unknown): boolean {
  return v === null || v === "null" || v === "";
}

function parseSingle(v: unknown): ParsedValue {
  if (isEmpty(v)) return null;
  const s = String(v);
  const n = parseInt(s, 10);
  return !isNaN(n) ? n : s;
}

const VALID_KEYS = new Set(["copies", "start", "end"]);

function convertCopiesStartAndEndValue(
  key: string | number,
  value: unknown
): Result | undefined {
  if (typeof key !== "string") return;

  const match = key.match(/^(copies|start|end)(?:_|$)/);
  if (!match) return;

  const baseKey = match[1] as LocalKeyType;
  if (!VALID_KEYS.has(baseKey)) return;

  if (isEmpty(value) || (Array.isArray(value) && value.every(isEmpty))) {
    return { key: baseKey, value: null };
  }

  if (Array.isArray(value)) {
    return { key: baseKey, value: value.map(parseSingle) };
  }

  return { key: baseKey, value: parseSingle(value) };
}

type NormalizedKey =
  | "start"
  | "end"
  | "copies"
  | "value"
  | "objectCondition"
  | "objectTherapy"
  | "conditionQualifier";

const PREFIX_MAP: Record<string, NormalizedKey> = {
  start: "start",
  end: "end",
  copies: "copies",
  value: "value",
  objectCondition: "objectCondition",
  objectTherapy: "objectTherapy",
  conditionQualifier: "conditionQualifier",
};

function normalizeValueKey(
  key: string | number,
  value: unknown
): { key: NormalizedKey; value: unknown } | undefined {
  if (typeof key !== "string") return undefined;

  const underscore = key.indexOf("_");
  if (underscore === -1) return undefined; // no prefix_

  const prefix = key.slice(0, underscore);
  const normalized = PREFIX_MAP[prefix];
  if (!normalized) return undefined;

  return { key: normalized, value };
}

function normalizeAndKeyById(
  inputObject: JsonObjectWithId,
  skipKeyById: boolean = false
): Record<string, JsonObjectWithId> | JsonObjectWithId {
  recurseJson(inputObject, [convertCopiesStartAndEndValue, normalizeValueKey]);
  if (skipKeyById) {
    return inputObject;
  }
  return keyObjectById(inputObject);
}


type SigType = {
  count: number;
  percent: number;
};

/**
 * Creates an array of SigType objects representing the count and percentage of each significance type.
 *
 * @param nosig_count - The count of non-significant items.
 * @param unc_count - The count of uncertain items.
 * @param sig_count - The count of significant items.
 * @returns An array of SigType objects, each containing the count and percentage of the respective significance type.
 *
 * @remarks
 * - If the total count of all types is zero, the function returns an array with zero counts and percentages.
 * - Percentages are rounded to three decimal places.
 */
function calculatePercentage(count: number, total: number): number {
  return Math.round((count / total) * 1000) / 1000;
}

function createSigType(nosigCount: number, uncCount: number, sigCount: number): SigType[] {
  const counts = [Number(nosigCount), Number(uncCount), Number(sigCount)];
  const total = counts.reduce((sum, count) => sum + count, 0);

  if (total === 0) {
    return counts.map(() => ({ count: 0, percent: 0 }));
  }

  return counts.map(count => ({
    count,
    percent: calculatePercentage(count, total)
  }));
}

/**
 * Normalize HP ID to the form HP:[\d]{7}, or remove or add leading zeros if gt or lt 7 digits, respectively.
 * Handles case-insensitive HP: prefixes like hp:hp:1234 and malformed entries.
 */
function normalizeHpId(hpId: string | null | undefined): string | null | undefined {
  if (hpId === null || hpId === undefined) return hpId;

  const original = hpId;

  // Collapse multiple HP: or HP prefixes like HP:HP0123 → HP0123
  const collapsed = hpId.replace(/^(hp:)+/i, '')  // collapse HP:HP:
                        .replace(/.*?(hp)(\d+)$/i, '$2'); // if HP123 pattern exists, keep the digits only

  // Only proceed if it’s all digits now
  if (!/^\d+$/.test(collapsed)) return original.toUpperCase();

  // Remove leading zeros
  const digits = collapsed.replace(/^0+/, '') || '0';

  if (digits.length <= 7) {
    return `HP:${digits.padStart(7, '0')}`.toUpperCase();
  }

  return original.toUpperCase(); // too long after trimming
}
