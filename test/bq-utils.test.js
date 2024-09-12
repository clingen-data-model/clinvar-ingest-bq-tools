const rewire = require('rewire');
const bqUtils = rewire('../dist/bq-utils.js');

const formatNearestMonth = bqUtils.__get__('formatNearestMonth');
const determineMonthBasedOnRange = bqUtils.__get__('determineMonthBasedOnRange');
const keyObjectById = bqUtils.__get__('keyObjectById');
const normalizeAndKeyById = bqUtils.__get__('normalizeAndKeyById');


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
    start: 'null',
    end: '[null, null]',
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
      start: null,
      end: [null, null],
      value: 'value1',
      objectCondition: 'condition1',
      definingContext: {  locationId: 'prefix:123', locationName: 'test' }
    }
  });
});
