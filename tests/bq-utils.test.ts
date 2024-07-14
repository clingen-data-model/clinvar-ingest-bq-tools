import { formatNearestMonth } from '../src/bq-utils';

describe('formatNearestMonth', () => {
  it('returns correct format for dates', () => {
    expect(formatNearestMonth(new Date("2024-04-14"))).toBe("Apr '24");
    expect(formatNearestMonth("2024-04-16")).toBe("May '24");
  });
});

