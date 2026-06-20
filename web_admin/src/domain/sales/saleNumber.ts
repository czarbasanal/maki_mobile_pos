/** Local-time YYYYMMDD key for the daily sale counter (settings/sale_counters). */
export function counterKey(date: Date): string {
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, '0');
  const d = `${date.getDate()}`.padStart(2, '0');
  return `${y}${m}${d}`;
}

/** Human sale number: SALE-YYYYMMDD-NNN (sequence zero-padded to >= 3). */
export function formatSaleNumber(date: Date, seq: number): string {
  return `SALE-${counterKey(date)}-${`${seq}`.padStart(3, '0')}`;
}
