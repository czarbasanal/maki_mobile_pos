// Tiny formatters shared by the report screens: a share as "49%" or "—",
// and the shop-zone "Sep 4 · 4:12 PM" cell.
import { formatInShopZone, shopIsoDate } from '@/domain/time/shopTime';
import type { DateRange } from '@/domain/reports/dateRange';

export function pctLabel(share: number | null, digits = 0): string {
  return share === null ? '—' : `${(share * 100).toFixed(digits)}%`;
}

export function whenLabel(d: Date): string {
  const day = formatInShopZone(d, { month: 'short', day: 'numeric' });
  const time = formatInShopZone(d, { hour: 'numeric', minute: '2-digit', hour12: true });
  return `${day} · ${time}`;
}

export function dayLabel(d: Date): string {
  return formatInShopZone(d, { month: 'short', day: 'numeric' });
}

export function csvFileName(report: string, range: DateRange): string {
  return `${report}-${shopIsoDate(range.start)}-${shopIsoDate(range.end)}.csv`;
}
