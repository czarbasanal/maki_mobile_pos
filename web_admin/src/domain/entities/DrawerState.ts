// Read-model of the drawer_state/state doc — written by sale creation and
// day closing (mobile + FirestoreSaleRepository). Web only READS it.
import { shopDayInt } from '../time/shopTime';

export interface DrawerState {
  lastSaleDay: number | null; // yyyymmdd of the newest sale
  lastClosedDay: number | null; // yyyymmdd of the newest sealed day
}

export function isRegisterOpen(state: DrawerState): boolean {
  if (state.lastSaleDay == null) return false;
  return state.lastClosedDay == null || state.lastSaleDay > state.lastClosedDay;
}

/** The business date the header reports: an open shift that ran past
 *  midnight still belongs to its opening day (spec §5.9). */
export function businessDayFor(state: DrawerState | null, now: Date): number {
  const today = shopDayInt(now);
  if (state && isRegisterOpen(state) && state.lastSaleDay != null && state.lastSaleDay < today) {
    return state.lastSaleDay;
  }
  return today;
}

export function formatDayInt(dayInt: number): string {
  const year = Math.floor(dayInt / 10000);
  const month = Math.floor((dayInt % 10000) / 100);
  const day = dayInt % 100;
  return new Intl.DateTimeFormat('en-PH', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(year, month - 1, day)));
}
