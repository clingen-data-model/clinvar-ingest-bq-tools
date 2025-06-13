
/**
 * Formats a given date or string into the nearest month in the format "Month Year".
 * If the day of the month is 15 or greater, it rounds up to the next month.
 * If the month is December, it transitions to the next year.
 * 
 * @param date - The date or string to be formatted.
 * @returns The formatted date in the format "Month Year".
 */
function formatNearestMonth(date: Date | string): string {
  const inputDate = typeof date === 'string' ? new Date(date) : date;
  
  // Get the year, month, and day from the date
  let year = inputDate.getFullYear();
  let month = inputDate.getMonth(); // getMonth() returns month from 0-11
  const day = inputDate.getDate();

  // Decide whether to round up or down based on the day of the month
  if (day >= 15) {
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

// // Example usage:
// console.log(formatNearestMonth(new Date())); // Use current date
// console.log(formatNearestMonth("2024-04-16")); // Use a string date input



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
function determineMonthBasedOnRange(startDate: Date, endDate: Date): { yymm: string; monyy: string } {
  // Ensure the start date is before the end date
  if (startDate > endDate) {
    [startDate, endDate] = [endDate, startDate];
  }

  // Set the prior month date from the end by subtracting one month from the end date
  let firstDayOfPriorMonth = new Date(endDate.getFullYear(), endDate.getMonth() - 1, 1);
  const firstDayOfLastMonth = new Date(endDate.getFullYear(), endDate.getMonth(), 1);
  const lastDayOfLastMonth = endDate;

  // Check if the last day of the prior month is greater than the start date
  const lastDayOfPriorMonth = new Date(firstDayOfPriorMonth.getFullYear(), firstDayOfPriorMonth.getMonth() + 1, 0);
  firstDayOfPriorMonth = firstDayOfPriorMonth > startDate ? firstDayOfPriorMonth : startDate;
  
  // Calculate days in prior and current month within the range
  const daysInPriorMonth = (lastDayOfPriorMonth.getTime() - firstDayOfPriorMonth.getTime()) / (1000 * 60 * 60 * 24) + 1;
  const daysInLastMonth = (lastDayOfLastMonth.getTime() - firstDayOfLastMonth.getTime()) / (1000 * 60 * 60 * 24) + 1;

  // Check which month has more days in the range or use the prior month if the days are equal
  let mon_yy = ""
  let yy = ""
  let mm = ""
  if (daysInLastMonth >= daysInPriorMonth) {
    mm = (lastDayOfLastMonth.getMonth() + 1).toString().padStart(2, '0');
    yy = lastDayOfLastMonth.getFullYear().toString().substring(2);
    mon_yy = formatMonthYear(lastDayOfLastMonth);
  } else {
    mm = (firstDayOfPriorMonth.getMonth() + 1).toString().padStart(2, '0');
    yy = firstDayOfPriorMonth.getFullYear().toString().substring(2);
    mon_yy = formatMonthYear(firstDayOfPriorMonth);
  }
  return { yymm: `${yy}-${mm}`, monyy: mon_yy };
}

// // Example usage
// const startDate = new Date("2023-03-15");
// const endDate = new Date("2023-04-10");
// console.log(determineMonthBasedOnRange(startDate, endDate)); // Output will depend on the calculated days

// json transforms
interface JsonObjectWithId {
  id: string;
  [key: string]: any;  // Allow any other key-value pairs
}

/**
 * Transforms an input object into a new object keyed by the portion of the 'id' after the colon or the 'id' property itself if no colon is present.
 * @param inputObject - The input object to transform.
 * @returns A new object with the portion of the 'id' after the colon as the key or the 'id' property as the key if no colon is present.
 * @throws {Error} If the input object does not have an 'id' property.
 */
function keyObjectById(inputObject: JsonObjectWithId): Record<string, JsonObjectWithId> {
  // Check if the input object has the property 'id'
  if (!inputObject || !inputObject.hasOwnProperty('id')) {
      throw new Error('Input object must have an "id" property.');
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

interface AnyObject {
  [key: string]: any;
}

type TransformFunction = (key: string | number, value: any) => AnyObject | undefined;

function recurseJson(obj: AnyObject, fns: TransformFunction[]): void {
  // Check if the input is an object or array
  if (typeof obj === 'object' && obj !== null) {
      // If it's an array, iterate over its elements
      if (Array.isArray(obj)) {
          for (let i = 0; i < obj.length; i++) {
              let value = obj[i];
              // Execute each function on the value
              for (const fn of fns) {
                  const replacement = fn(i, value); // Call the function with index and value
                  if (replacement !== undefined) {
                      value = replacement; // Replace the value with the returned value if it's not undefined
                  }
              }
              obj[i] = value; // Update the array element
              // Recursively call the function for each element
              recurseJson(obj[i], fns);
          }
      } else {
          // If it's an object, iterate over its keys
          for (const key in obj) {
              if (obj.hasOwnProperty(key)) {
                  let value = obj[key];
                  // Execute each function on the value
                  for (const fn of fns) {
                      const replacement = fn(key, value); // Call the function with key and value
                      if (replacement !== undefined) {
                          delete obj[key]; // Remove the original key-value pair
                          obj[replacement.key] = replacement.value; // Add the new key-value pair
                          value = replacement.value; // Update the value
                      }
                  }
                  // Recursively call the function for nested objects and arrays
                  recurseJson(value, fns);
              }
          }
      }
  }
}

function convertCopiesStartAndEndValue(key: string | number, value: any): { key: string; value: any } | undefined {
  if (key === 'copies' || key === 'start' || key === 'end') {
      if (value === 'null' || value === '') {
          // If the value is "null" or an empty string, transform it to JSON null
          return { key, value: null };
      } else if (typeof value === 'string') {
          if (value.startsWith('[') && value.endsWith(']')) {
              // If it's a string that represents an array, transform it to a JSON array
              return { key, value: JSON.parse(value.replace(/null/g, 'null')) };
          } else {
              // If it's a plain string without brackets, attempt to convert it to an integer
              const parsedInt = parseInt(value, 10);
              return { key, value: isNaN(parsedInt) ? value : parsedInt }; // Preserve original if parsing fails
          }
      }
  }
  return undefined;
}

function normalizeValueKey(key: string | number, value: any): { key: string; value: any } | undefined {
  if (typeof key === "string" && (/^value_/.test(key))) {
    return { key: 'value', value };
  }
  if (typeof key === "string" && (/^objectCondition_/.test(key))) {
    return { key: 'objectCondition', value };
  }
  if (typeof key === "string" && (/^objectTumorType_/.test(key))) {
    return { key: 'objectTumorType', value };
  }
  if (typeof key === "string" && (/^definingContext_/.test(key))) {
    return { key: 'definingContext', value };
  }
  return undefined;
}

function normalizeAndKeyById(inputObject: JsonObjectWithId): Record<string, JsonObjectWithId> {
  recurseJson(inputObject, [convertCopiesStartAndEndValue, normalizeValueKey]);
  return keyObjectById(inputObject);
}

// Attach to global object explicitly if necessary (e.g., for Node.js)
if (typeof global !== 'undefined') {
  (global as any).formatNearestMonth = formatNearestMonth;
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
function createSigType(nosig_count: number, unc_count: number, sig_count: number): SigType[] {
  
  // Convert inputs to numbers (integers) to avoid concatenation when used in SQL function
  nosig_count = Number(nosig_count);
  unc_count = Number(unc_count);
  sig_count = Number(sig_count);

  // Check if the total count is zero to avoid division by zero
  if ((nosig_count + unc_count + sig_count) === 0) {
    return [
      { count: 0, percent: 0 },
      { count: 0, percent: 0 },
      { count: 0, percent: 0 }
    ];
  }

  // Calculate the total count
  const total = nosig_count + unc_count + sig_count;

  // Calculate percentages and return an array of SigType objects
  // The returned array ORDINAL positions must be: 0 = nosig, 1 = unc, 2 = sig
  return [
    { count: nosig_count, percent: Math.round((nosig_count / total) * 1000) / 1000 },
    { count: unc_count, percent: Math.round((unc_count / total) * 1000) / 1000 },
    { count: sig_count, percent: Math.round((sig_count / total) * 1000) / 1000 }
  ];
}

/**
 * Normalize HP ID to the form HP:[\d]{7}, or remove or add leading zeros if gt or lt 7 digits, respectively.
 * Handles case-insensitive HP: prefixes like hp:hp:1234 and malformed entries.
 */
function normalizeHpId(hp_id: string | null | undefined): string | null | undefined {
  if (hp_id === null || hp_id === undefined) return hp_id;

  const original = hp_id;

  // Collapse multiple HP: or HP prefixes like HP:HP0123 → HP0123
  const collapsed = hp_id.replace(/^(hp:)+/i, '')  // collapse HP:HP:
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
