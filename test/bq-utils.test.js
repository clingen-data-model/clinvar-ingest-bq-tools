const rewire = require('rewire');
const bqUtils = rewire('../dist/bq-utils.js');

const formatNearestMonth = bqUtils.__get__('formatNearestMonth');
const formatMonthYear = bqUtils.__get__('formatMonthYear');
const determineMonthBasedOnRange = bqUtils.__get__('determineMonthBasedOnRange');
const calculateDaysInRange = bqUtils.__get__('calculateDaysInRange');
const getMonthBoundaries = bqUtils.__get__('getMonthBoundaries');
const keyObjectById = bqUtils.__get__('keyObjectById');
const normalizeAndKeyById = bqUtils.__get__('normalizeAndKeyById');
const normalizeHpId = bqUtils.__get__('normalizeHpId');
const createSigType = bqUtils.__get__('createSigType');
const isEmpty = bqUtils.__get__('isEmpty');
const parseSingle = bqUtils.__get__('parseSingle');
const convertCopiesStartAndEndValue = bqUtils.__get__('convertCopiesStartAndEndValue');
const normalizeValueKey = bqUtils.__get__('normalizeValueKey');

test('formatNearestMonth should format dates correctly', () => {
  expect(formatNearestMonth(new Date('2024-04-16'))).toBe("May '24");
  expect(formatNearestMonth(new Date('2024-04-14'))).toBe("Apr '24");
  expect(formatNearestMonth('2024-01-15')).toBe("Jan '24");
  expect(formatNearestMonth('2024-12-20')).toBe("Jan '25");

  // Test error handling
  expect(() => formatNearestMonth('invalid-date')).toThrow('Invalid date provided');
  expect(() => formatNearestMonth('')).toThrow('Invalid date provided');
});

test('determineMonthBasedOnRange should determine correct month based on range', () => {
  const result = determineMonthBasedOnRange(new Date('2024-03-01'), new Date('2024-03-31'));
  expect(result).toEqual({ yymm: '24-03', monyy: "Mar '24" });
});

test('keyObjectById should transform input object correctly', () => {
  const inputObject = { id: 'prefix:123', value: 'test' };
  const result = keyObjectById(inputObject);
  expect(result).toEqual({ '123': inputObject });

  // Test without colon
  const simpleObject = { id: '456', name: 'simple' };
  expect(keyObjectById(simpleObject)).toEqual({ '456': simpleObject });

  // Test error cases
  expect(() => keyObjectById(null)).toThrow('Input object must have a valid string "id" property.');
  expect(() => keyObjectById({})).toThrow('Input object must have a valid string "id" property.');
  expect(() => keyObjectById({ id: 123 })).toThrow('Input object must have a valid string "id" property.');
  expect(() => keyObjectById({ id: '' })).toThrow('Input object "id" property cannot be empty.');
  expect(() => keyObjectById({ id: '   ' })).toThrow('Input object "id" property cannot be empty.');
});

test('normalizeAndKeyById should normalize and key input object correctly', () => {
  const inputObject = {
    id: 'prefix:123',
    copies: '10',
    copies_range: [],
    start: null,
    end: null,
    start_range: [null, '200'],
    end_range: ['400', null],
    value_test: 'value1',
    objectCondition_complex: 'condition1',
    definingContext_location:
      {
        locationId: 'prefix:123',
        locationName: 'test'
      }
  };
  const result = normalizeAndKeyById(inputObject);
  expect(result).toEqual({
    '123': {
      id: 'prefix:123',
      copies: 10,
      start: [null, 200],
      end: [400, null],
      value: 'value1',
      objectCondition: 'condition1',
      definingContext: {  locationId: 'prefix:123', locationName: 'test' }
    }
  });
});

test('normalizeAndKeyById should normalize and key input object correctly', () => {
  const inputObject = {
    id: 'prefix:123',
    copies_range: ['1','5'],
    start: '10',
    end: null,
    start_range: [],
    end_range: ['100','200'],
    value_test: 'value1',
    objectCondition_complex: 'condition1',
    definingContext_location:
      {
        locationId: 'prefix:123',
        locationName: 'test'
      }
  };
  const result = normalizeAndKeyById(inputObject);
  expect(result).toEqual({
    '123': {
      id: 'prefix:123',
      copies: [1, 5],
      start: 10,
      end: [100, 200],
      value: 'value1',
      objectCondition: 'condition1',
      definingContext: {  locationId: 'prefix:123', locationName: 'test' }
    }
  });
});

test('createSigType should return correct counts and percentages', () => {
    expect(createSigType(0, 0, 0)).toEqual([
        { count: 0, percent: 0 },
        { count: 0, percent: 0 },
        { count: 0, percent: 0 }
    ]);

    expect(createSigType(10, 0, 0)).toEqual([
        { count: 10, percent: 1 },
        { count: 0, percent: 0 },
        { count: 0, percent: 0 }
    ]);

    expect(createSigType(0, 10, 0)).toEqual([
        { count: 0, percent: 0 },
        { count: 10, percent: 1 },
        { count: 0, percent: 0 }
    ]);

    expect(createSigType(0, 0, 10)).toEqual([
        { count: 0, percent: 0 },
        { count: 0, percent: 0 },
        { count: 10, percent: 1 }
    ]);

    expect(createSigType(10, 10, 10)).toEqual([
        { count: 10, percent: 0.333 },
        { count: 10, percent: 0.333 },
        { count: 10, percent: 0.333 }
    ]);

    expect(createSigType(5, 10, 15)).toEqual([
        { count: 5, percent: 0.167 },
        { count: 10, percent: 0.333 },
        { count: 15, percent: 0.5 }
    ]);
});

test('normalizeHpId should normalize HP IDs correctly', () => {
  expect(normalizeHpId('HP:HP0001234')).toBe('HP:0001234');
  expect(normalizeHpId('HP1234')).toBe('HP:0001234');
  expect(normalizeHpId('HP:0001234')).toBe('HP:0001234');
  expect(normalizeHpId('1234')).toBe('HP:0001234');
  expect(normalizeHpId('HP:hp:1234')).toBe('HP:0001234');
  expect(normalizeHpId('000012345')).toBe('HP:0012345');
  expect(normalizeHpId('HP:0001234567')).toBe('HP:1234567');
  expect(normalizeHpId('HP:hp0001234567')).toBe('HP:1234567');
  expect(normalizeHpId('hp:')).toBe('HP:');
  expect(normalizeHpId('')).toBe('');
  expect(normalizeHpId(null)).toBe(null);
  expect(normalizeHpId(undefined)).toBe(undefined);
  expect(normalizeHpId('hp:123-456')).toBe('HP:123-456');
});

// New tests for missing functions

test('formatMonthYear should format dates correctly', () => {
  expect(formatMonthYear(new Date(2024, 0, 15))).toBe("Jan '24"); // Month 0 = January
  expect(formatMonthYear(new Date(2024, 11, 25))).toBe("Dec '24"); // Month 11 = December
  expect(formatMonthYear(new Date(2023, 2, 1))).toBe("Mar '23"); // Month 2 = March
});

test('calculateDaysInRange should calculate days correctly', () => {
  const start = new Date('2024-01-01');
  const end = new Date('2024-01-03');
  expect(calculateDaysInRange(start, end)).toBe(3);

  const sameDay = new Date('2024-01-01');
  expect(calculateDaysInRange(sameDay, sameDay)).toBe(1);
});

test('getMonthBoundaries should return correct boundaries', () => {
  const date = new Date('2024-06-15');
  const boundaries = getMonthBoundaries(date);

  expect(boundaries.firstDay.getFullYear()).toBe(2024);
  expect(boundaries.firstDay.getMonth()).toBe(5); // June is month 5 (0-indexed)
  expect(boundaries.firstDay.getDate()).toBe(1);
  expect(boundaries.lastDay.getFullYear()).toBe(2024);
  expect(boundaries.lastDay.getMonth()).toBe(5);
  expect(boundaries.lastDay.getDate()).toBe(30);
});

test('isEmpty should identify empty values correctly', () => {
  expect(isEmpty(null)).toBe(true);
  expect(isEmpty('null')).toBe(true);
  expect(isEmpty('')).toBe(true);
  expect(isEmpty('test')).toBe(false);
  expect(isEmpty(0)).toBe(false);
  expect(isEmpty(123)).toBe(false);
});

test('parseSingle should parse values correctly', () => {
  expect(parseSingle('123')).toBe(123);
  expect(parseSingle('0')).toBe(0);
  expect(parseSingle('abc')).toBe('abc');
  expect(parseSingle(null)).toBe(null);
  expect(parseSingle('')).toBe(null);
  expect(parseSingle('null')).toBe(null);
});

test('convertCopiesStartAndEndValue should handle various inputs', () => {
  // Test valid keys
  expect(convertCopiesStartAndEndValue('copies', '10')).toEqual({ key: 'copies', value: 10 });
  expect(convertCopiesStartAndEndValue('start_range', ['5', '15'])).toEqual({ key: 'start', value: [5, 15] });
  expect(convertCopiesStartAndEndValue('end_suffix', null)).toEqual({ key: 'end', value: null });

  // Test invalid keys
  expect(convertCopiesStartAndEndValue('invalid', '10')).toBeUndefined();
  expect(convertCopiesStartAndEndValue(123, '10')).toBeUndefined();

  // Test empty arrays
  expect(convertCopiesStartAndEndValue('copies', [])).toEqual({ key: 'copies', value: null });
  expect(convertCopiesStartAndEndValue('start', [null, ''])).toEqual({ key: 'start', value: null });
});

test('normalizeValueKey should normalize keys correctly', () => {
  expect(normalizeValueKey('value_test', 'test')).toEqual({ key: 'value', value: 'test' });
  expect(normalizeValueKey('objectCondition_complex', 'condition')).toEqual({ key: 'objectCondition', value: 'condition' });
  expect(normalizeValueKey('definingContext_location', 'context')).toEqual({ key: 'definingContext', value: 'context' });

  // Test invalid keys
  expect(normalizeValueKey('invalid_key', 'test')).toBeUndefined();
  expect(normalizeValueKey('noUnderscore', 'test')).toBeUndefined();
  expect(normalizeValueKey(123, 'test')).toBeUndefined();
});

test('determineMonthBasedOnRange should handle edge cases', () => {
  // Test swapped dates
  const result1 = determineMonthBasedOnRange(new Date('2024-03-31'), new Date('2024-03-01'));
  expect(result1).toEqual({ yymm: '24-03', monyy: "Mar '24" });

  // Test cross-month range
  const result2 = determineMonthBasedOnRange(new Date('2024-02-15'), new Date('2024-03-15'));
  expect(result2.yymm).toMatch(/24-(02|03)/);
});

test('createSigType should handle string inputs', () => {
  // Test string inputs (converted to numbers)
  expect(createSigType('5', '10', '15')).toEqual([
    { count: 5, percent: 0.167 },
    { count: 10, percent: 0.333 },
    { count: 15, percent: 0.5 }
  ]);
});

test('normalizeHpId should handle more edge cases', () => {
  // Test very long numbers
  expect(normalizeHpId('12345678901')).toBe('12345678901');

  // Test malformed cases
  expect(normalizeHpId('HP:abc123')).toBe('HP:ABC123');
  expect(normalizeHpId('random text')).toBe('RANDOM TEXT');
});
