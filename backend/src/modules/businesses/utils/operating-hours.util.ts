export interface TimeInterval {
  open: string; // "HH:mm" 24-hour format e.g. "09:00"
  close: string; // "HH:mm" 24-hour format e.g. "21:00"
}

export interface DaySchedule {
  isClosed: boolean;
  intervals?: TimeInterval[];
}

export interface OperatingHours {
  monday?: DaySchedule;
  tuesday?: DaySchedule;
  wednesday?: DaySchedule;
  thursday?: DaySchedule;
  friday?: DaySchedule;
  saturday?: DaySchedule;
  sunday?: DaySchedule;
}

export type OperatingStatusType = 'open' | 'closed' | 'opens_later' | 'closes_later';

export interface OperatingStatusResult {
  isOpen: boolean;
  status: OperatingStatusType;
  statusText: string;
}

const DAYS_OF_WEEK = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const;

function timeToMinutes(timeStr: string): number | null {
  if (!timeStr || typeof timeStr !== 'string') return null;
  const match = timeStr.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const h = parseInt(match[1], 10);
  const m = parseInt(match[2], 10);
  if (h === 24 && m === 0) return 24 * 60;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

function format12Hour(timeStr: string): string {
  const mins = timeToMinutes(timeStr);
  if (mins === null) return timeStr;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  const period = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  const mStr = `:${m.toString().padStart(2, '0')}`;
  return `${h12}${mStr} ${period}`;
}

/**
 * Evaluates the real-time open/closed operating status of a business
 * given its configured operating hours, business timezone, and reference date.
 */
export function evaluateOperatingStatus(
  hours?: OperatingHours | null,
  timezone?: string | null,
  referenceDate: Date = new Date(),
): OperatingStatusResult {
  if (!hours || typeof hours !== 'object') {
    return {
      isOpen: false,
      status: 'closed',
      statusText: 'Hours not available',
    };
  }

  const tz = (timezone && timezone.trim()) || 'Asia/Kolkata';

  let dayName: string;
  let currHour: number;
  let currMin: number;

  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      weekday: 'long',
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
    });

    const parts = formatter.formatToParts(referenceDate);
    const weekdayPart = parts.find((p) => p.type === 'weekday')?.value.toLowerCase() || 'monday';
    const hourPart = parseInt(parts.find((p) => p.type === 'hour')?.value || '0', 10);
    const minutePart = parseInt(parts.find((p) => p.type === 'minute')?.value || '0', 10);

    dayName = weekdayPart;
    currHour = hourPart === 24 ? 0 : hourPart;
    currMin = currHour * 60 + minutePart;
  } catch {
    // If timezone is invalid, fallback to UTC
    const d = referenceDate;
    dayName = DAYS_OF_WEEK[d.getUTCDay()];
    currMin = d.getUTCHours() * 60 + d.getUTCMinutes();
  }

  const todayIndex = DAYS_OF_WEEK.indexOf(dayName as any);
  const safeTodayIndex = todayIndex >= 0 ? todayIndex : 1;
  const todayKey = DAYS_OF_WEEK[safeTodayIndex] as keyof OperatingHours;
  const yesterdayIndex = (safeTodayIndex + 6) % 7;
  const yesterdayKey = DAYS_OF_WEEK[yesterdayIndex] as keyof OperatingHours;

  const todaySchedule = hours[todayKey];
  const yesterdaySchedule = hours[yesterdayKey];

  // 1. Check if an overnight shift started yesterday is still active today
  if (
    yesterdaySchedule &&
    !yesterdaySchedule.isClosed &&
    Array.isArray(yesterdaySchedule.intervals)
  ) {
    for (const interval of yesterdaySchedule.intervals) {
      const openMin = timeToMinutes(interval.open);
      const closeMin = timeToMinutes(interval.close);
      if (openMin !== null && closeMin !== null && openMin > closeMin) {
        // Overnight interval spanning into today
        if (currMin < closeMin) {
          const closesSoon = closeMin - currMin <= 60;
          return {
            isOpen: true,
            status: closesSoon ? 'closes_later' : 'open',
            statusText: `Open · Closes at ${format12Hour(interval.close)}`,
          };
        }
      }
    }
  }

  // 2. Check today's intervals
  if (todaySchedule && !todaySchedule.isClosed && Array.isArray(todaySchedule.intervals)) {
    for (const interval of todaySchedule.intervals) {
      const openMin = timeToMinutes(interval.open);
      const closeMin = timeToMinutes(interval.close);

      if (openMin !== null && closeMin !== null) {
        if (openMin <= closeMin) {
          // Normal daytime interval
          if (currMin >= openMin && currMin < closeMin) {
            const closesSoon = closeMin - currMin <= 60;
            return {
              isOpen: true,
              status: closesSoon ? 'closes_later' : 'open',
              statusText: `Open · Closes at ${format12Hour(interval.close)}`,
            };
          }
        } else {
          // Overnight interval starting today and ending tomorrow
          if (currMin >= openMin) {
            return {
              isOpen: true,
              status: 'open',
              statusText: `Open · Closes at ${format12Hour(interval.close)}`,
            };
          }
        }
      }
    }

    // Today is open, but is it currently before an interval?
    const upcomingIntervals = todaySchedule.intervals
      .map((i) => ({ ...i, openMins: timeToMinutes(i.open) }))
      .filter((i) => i.openMins !== null && i.openMins > currMin)
      .sort((a, b) => (a.openMins ?? 0) - (b.openMins ?? 0));

    if (upcomingIntervals.length > 0) {
      const nextOpen = upcomingIntervals[0];
      return {
        isOpen: false,
        status: 'opens_later',
        statusText: `Closed · Opens at ${format12Hour(nextOpen.open)}`,
      };
    }
  }

  // 3. Not currently open today: check next open day
  for (let offset = 1; offset <= 7; offset++) {
    const nextDayIndex = (safeTodayIndex + offset) % 7;
    const nextDayKey = DAYS_OF_WEEK[nextDayIndex] as keyof OperatingHours;
    const nextSchedule = hours[nextDayKey];

    if (
      nextSchedule &&
      !nextSchedule.isClosed &&
      Array.isArray(nextSchedule.intervals) &&
      nextSchedule.intervals.length > 0
    ) {
      const firstInterval = nextSchedule.intervals[0];
      const dayLabel =
        offset === 1
          ? 'tomorrow'
          : nextDayKey.charAt(0).toUpperCase() + nextDayKey.slice(1);
      return {
        isOpen: false,
        status: 'closed',
        statusText: `Closed · Opens ${format12Hour(firstInterval.open)} ${dayLabel}`,
      };
    }
  }

  return {
    isOpen: false,
    status: 'closed',
    statusText: 'Closed',
  };
}
