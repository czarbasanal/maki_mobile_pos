/** PH (UTC+8) business day as yyyymmdd — must match mobile/rules math. */
export function phDayInt(now: Date = new Date()): number {
  const t = new Date(now.getTime() + 8 * 3600 * 1000);
  return t.getUTCFullYear() * 10000 + (t.getUTCMonth() + 1) * 100 + t.getUTCDate();
}
