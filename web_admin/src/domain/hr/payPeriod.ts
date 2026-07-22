export interface PayPeriod { start: string; end: string; dates: string[] }

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** 7-day period containing `anchor`, starting on ISO weekday `weekStartDay` (1=Mon..7=Sun). */
export function payPeriodFor(anchor: Date, weekStartDay: number): PayPeriod {
  const a = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate());
  const isoDow = ((a.getDay() + 6) % 7) + 1; // JS Sun=0 → ISO 1..7
  const diff = (isoDow - weekStartDay + 7) % 7;
  const start = new Date(a);
  start.setDate(a.getDate() - diff);
  const dates = Array.from({ length: 7 }, (_, k) => {
    const d = new Date(start);
    d.setDate(start.getDate() + k);
    return iso(d);
  });
  return { start: dates[0], end: dates[6], dates };
}

export function shiftPeriod(p: PayPeriod, weeks: number): PayPeriod {
  const [y, m, d] = p.start.split('-').map(Number);
  const s = new Date(y, m - 1, d + weeks * 7);
  const dates = Array.from({ length: 7 }, (_, k) => {
    const n = new Date(s);
    n.setDate(s.getDate() + k);
    return iso(n);
  });
  return { start: dates[0], end: dates[6], dates };
}
