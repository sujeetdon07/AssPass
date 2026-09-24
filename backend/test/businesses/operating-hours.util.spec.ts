import { describe, it, expect } from 'vitest';
import {
  evaluateOperatingStatus,
  OperatingHours,
} from '../../src/modules/businesses/utils/operating-hours.util.js';

describe('OperatingHoursUtil', () => {
  it('returns closed when operating hours are null or undefined', () => {
    const resultNull = evaluateOperatingStatus(null);
    expect(resultNull.isOpen).toBe(false);
    expect(resultNull.status).toBe('closed');
    expect(resultNull.statusText).toBe('Hours not available');

    const resultUndefined = evaluateOperatingStatus(undefined);
    expect(resultUndefined.isOpen).toBe(false);
    expect(resultUndefined.status).toBe('closed');
  });

  it('correctly evaluates when a business is open during normal hours', () => {
    const hours: OperatingHours = {
      monday: {
        isClosed: false,
        intervals: [{ open: '09:00', close: '21:00' }],
      },
    };

    // A Monday at 14:30 in Asia/Kolkata (UTC 09:00)
    const refDate = new Date('2026-09-21T09:00:00.000Z'); // 2026-09-21 is a Monday
    const result = evaluateOperatingStatus(hours, 'Asia/Kolkata', refDate);

    expect(result.isOpen).toBe(true);
    expect(result.status).toBe('open');
    expect(result.statusText).toBe('Open · Closes at 9:00 PM');
  });

  it('correctly reports closes_later when within 60 minutes of closing', () => {
    const hours: OperatingHours = {
      monday: {
        isClosed: false,
        intervals: [{ open: '09:00', close: '21:00' }],
      },
    };

    // Monday at 20:30 in Asia/Kolkata (UTC 15:00) -> 30 mins before 21:00
    const refDate = new Date('2026-09-21T15:00:00.000Z');
    const result = evaluateOperatingStatus(hours, 'Asia/Kolkata', refDate);

    expect(result.isOpen).toBe(true);
    expect(result.status).toBe('closes_later');
    expect(result.statusText).toBe('Open · Closes at 9:00 PM');
  });

  it('correctly reports opens_later when before opening on the same day', () => {
    const hours: OperatingHours = {
      monday: {
        isClosed: false,
        intervals: [{ open: '10:00', close: '22:00' }],
      },
    };

    // Monday at 08:30 in Asia/Kolkata (UTC 03:00)
    const refDate = new Date('2026-09-21T03:00:00.000Z');
    const result = evaluateOperatingStatus(hours, 'Asia/Kolkata', refDate);

    expect(result.isOpen).toBe(false);
    expect(result.status).toBe('opens_later');
    expect(result.statusText).toBe('Closed · Opens at 10:00 AM');
  });

  it('correctly reports closed and opening tomorrow when closed today', () => {
    const hours: OperatingHours = {
      monday: {
        isClosed: true,
      },
      tuesday: {
        isClosed: false,
        intervals: [{ open: '08:00', close: '20:00' }],
      },
    };

    // Monday at 14:00 in Asia/Kolkata
    const refDate = new Date('2026-09-21T08:30:00.000Z');
    const result = evaluateOperatingStatus(hours, 'Asia/Kolkata', refDate);

    expect(result.isOpen).toBe(false);
    expect(result.status).toBe('closed');
    expect(result.statusText).toContain('Opens 8:00 AM tomorrow');
  });

  it('handles overnight shifts accurately', () => {
    const hours: OperatingHours = {
      monday: {
        isClosed: false,
        intervals: [{ open: '20:00', close: '03:00' }],
      },
      tuesday: {
        isClosed: false,
        intervals: [{ open: '20:00', close: '03:00' }],
      },
    };

    // Monday night at 23:00 in Asia/Kolkata (UTC 17:30)
    const refDateMonNight = new Date('2026-09-21T17:30:00.000Z');
    const resMonNight = evaluateOperatingStatus(hours, 'Asia/Kolkata', refDateMonNight);
    expect(resMonNight.isOpen).toBe(true);

    // Tuesday early morning at 01:30 in Asia/Kolkata (UTC 20:00 Monday) -> still open from Monday night!
    const refDateTueEarly = new Date('2026-09-21T20:00:00.000Z');
    const resTueEarly = evaluateOperatingStatus(hours, 'Asia/Kolkata', refDateTueEarly);
    expect(resTueEarly.isOpen).toBe(true);
    expect(resTueEarly.statusText).toBe('Open · Closes at 3:00 AM');
  });

  it('respects different timezones accurately', () => {
    const hours: OperatingHours = {
      monday: {
        isClosed: false,
        intervals: [{ open: '09:00', close: '17:00' }],
      },
    };

    // 14:00 UTC on Monday:
    // In New York (EDT, UTC-4), this is 10:00 AM (Open)
    const resNY = evaluateOperatingStatus(hours, 'America/New_York', new Date('2026-09-21T14:00:00.000Z'));
    expect(resNY.isOpen).toBe(true);

    // In Tokyo (JST, UTC+9), this is 23:00 (11:00 PM) (Closed)
    const resTokyo = evaluateOperatingStatus(hours, 'Asia/Tokyo', new Date('2026-09-21T14:00:00.000Z'));
    expect(resTokyo.isOpen).toBe(false);
  });
});
