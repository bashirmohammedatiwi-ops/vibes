import { BookingOrigin } from '@prisma/client';
import { summarizeCoverage } from './coverage.util';

describe('summarizeCoverage', () => {
  const now = new Date(2026, 8, 14);

  it('counts unlogged days as open so guests would see them as available', () => {
    const coverage = summarizeCoverage({
      now,
      propertyIds: ['farm-1'],
      bookings: [
        {
          propertyId: 'farm-1',
          startDate: new Date('2026-09-14T00:00:00.000Z'),
          endDate: new Date('2026-09-15T00:00:00.000Z'),
          origin: BookingOrigin.PLATFORM,
        },
        {
          propertyId: 'farm-1',
          startDate: new Date('2026-09-16T00:00:00.000Z'),
          endDate: new Date('2026-09-17T00:00:00.000Z'),
          origin: BookingOrigin.EXTERNAL,
        },
      ],
      closed: [{ propertyId: 'farm-1', date: new Date('2026-09-18T00:00:00.000Z') }],
    });

    expect(coverage.propertyCount).toBe(1);
    expect(coverage.totalSlots).toBe(30);
    expect(coverage.platformDays).toBe(1);
    expect(coverage.externalDays).toBe(1);
    expect(coverage.closedDays).toBe(1);
    expect(coverage.openDays).toBe(27);
  });
});
