import { shopOffsetMinutes, shopTimeOf, shopWall } from '@/domain/time/shopTime';

export interface PayPeriod { start: string; end: string; dates: string[] }

const isoOfWall = (w: Date) =>
  `${w.getUTCFullYear()}-${String(w.getUTCMonth() + 1).padStart(2, '0')}-${String(w.getUTCDate()).padStart(2, '0')}`;

/**
 * 7-day period containing `anchor`, starting on ISO weekday `weekStartDay`
 * (1=Mon..7=Sun), anchored on the SHOP day — a browser in another zone would
 * otherwise pick the wrong week near midnight.
 */
export function payPeriodFor(
  anchor: Date,
  weekStartDay: number,
  offsetMinutes: number = shopOffsetMinutes(),
): PayPeriod {
  const w = shopTimeOf(anchor, offsetMinutes);
  const a = shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, w.getUTCDate());
  const isoDow = ((a.getUTCDay() + 6) % 7) + 1; // JS Sun=0 → ISO 1..7
  const diff = (isoDow - weekStartDay + 7) % 7;
  const start = new Date(a.getTime() - diff * 86_400_000);
  const dates = Array.from({ length: 7 }, (_, k) =>
    isoOfWall(new Date(start.getTime() + k * 86_400_000)),
  );
  return { start: dates[0], end: dates[6], dates };
}

export function shiftPeriod(p: PayPeriod, weeks: number): PayPeriod {
  const [y, m, d] = p.start.split('-').map(Number);
  const s = shopWall(y, m, d + weeks * 7);
  const dates = Array.from({ length: 7 }, (_, k) =>
    isoOfWall(new Date(s.getTime() + k * 86_400_000)),
  );
  return { start: dates[0], end: dates[6], dates };
}
