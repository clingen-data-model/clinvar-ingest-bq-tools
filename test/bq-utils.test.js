const rewire = require('rewire');
const bqUtils = rewire('../dist/bq-utils.js');

const formatNearestMonth = bqUtils.__get__('formatNearestMonth');
const determineMonthBasedOnRange = bqUtils.__get__('determineMonthBasedOnRange');
const keyObjectById = bqUtils.__get__('keyObjectById');
const normalizeAndKeyById = bqUtils.__get__('normalizeAndKeyById');
const normalizeHpId = bqUtils.__get__('normalizeHpId');
const createSigType = bqUtils.__get__('createSigType');

test('formatNearestMonth should format dates correctly', () => {
  expect(formatNearestMonth(new Date('2024-04-16'))).toBe("May '24");
  expect(formatNearestMonth(new Date('2024-04-14'))).toBe("Apr '24");
});

test('determineMonthBasedOnRange should determine correct month based on range', () => {
  const result = determineMonthBasedOnRange(new Date('2024-03-01'), new Date('2024-03-31'));
  expect(result).toEqual({ yymm: '24-03', monyy: "Mar '24" });
});

test('keyObjectById should transform input object correctly', () => {
  const inputObject = { id: 'prefix:123', value: 'test' };
  const result = keyObjectById(inputObject);
  expect(result).toEqual({ '123': inputObject });
});

test('normalizeAndKeyById should normalize and key input object correctly', () => {
  const inputObject = {
    id: 'prefix:123',
    copies: '10',
    start_array: [null, '200'],
    end_array: ['400', null],
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
    copies: '10',
    start: '10',
    end: '25',
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
      start: 10,
      end: 25,
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
