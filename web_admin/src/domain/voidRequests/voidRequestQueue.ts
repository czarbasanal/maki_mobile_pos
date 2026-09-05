// The Void Requests screen's one derivation (void-requests guide §2/§3):
// the KPI strip, the outcome chips and the "Total voided" foot all read
// this summary. The waiting queue is NEVER scoped by the date range — a
// pending request from three weeks ago is still pending; only the resolved
// history is scoped, by when it was resolved.
import type { VoidRequest } from '../entities';
import type { DateRange } from '../reports/dateRange';

/** Badge tones the reason tag uses — a subset of the ui Badge's Tone, kept here so the domain stays UI-free. */
export type VoidReasonTone = 'info' | 'warning' | 'negative' | 'neutral';

/** Reasons are admin-managed (void_reasons) plus "Other" free text, so the
 *  tone keys on words: a "test" void is the classic theft cover and reads red. */
export function voidReasonTone(reason: string): VoidReasonTone {
  const r = reason.toLowerCase();
  if (/\b(test|testing|training)\b/.test(r)) return 'negative';
  if (/duplicate|double|twice/.test(r)) return 'warning';
  if (/wrong|incorrect|mistake|price|item/.test(r)) return 'info';
  return 'neutral';
}

export function ageMinutes(createdAt: Date, now: Date): number {
  return Math.max(0, Math.floor((now.getTime() - createdAt.getTime()) / 60_000));
}

/** Bare age — `12m`, `3h`, `2d`. The row appends " waiting". */
export function ageLabel(mins: number): string {
  if (mins >= 1440) return `${Math.floor(mins / 1440)}d`;
  if (mins >= 60) return `${Math.floor(mins / 60)}h`;
  return `${mins}m`;
}

/** The only prioritisation signal on the screen: <1h quiet, 1–4h amber, ≥4h red. */
export type AgeTone = 'ink-3' | 'accent-text' | 'neg';
export function ageTone(mins: number): AgeTone {
  if (mins >= 240) return 'neg';
  if (mins >= 60) return 'accent-text';
  return 'ink-3';
}

/** How long a request took to resolve — the number worth watching. */
export function durationLabel(from: Date, to: Date): string {
  const mins = Math.max(0, Math.floor((to.getTime() - from.getTime()) / 60_000));
  if (mins < 1) return '<1m';
  if (mins < 60) return `${mins}m`;
  if (mins < 1440) {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    return m ? `${h}h ${m}m` : `${h}h`;
  }
  const d = Math.floor(mins / 1440);
  const h = Math.floor((mins % 1440) / 60);
  return h ? `${d}d ${h}h` : `${d}d`;
}

export interface VoidQueueSummary {
  /** Pending, oldest first. */
  waiting: VoidRequest[];
  waitingHeld: number;
  oldest: VoidRequest | null;
  /** Resolved within the range (by resolvedAt, falling back to createdAt), newest first. */
  resolvedInRange: VoidRequest[];
  approvedCount: number;
  rejectedCount: number;
  /** Approved amounts over the range. */
  voidedTotal: number;
  /** approved / resolved, 0–1; null with nothing resolved (render "—", never 0%). */
  approvalRate: number | null;
}

const resolvedInstant = (r: VoidRequest) => r.resolvedAt ?? r.createdAt;

export function summarizeVoidQueue(requests: VoidRequest[], range: DateRange): VoidQueueSummary {
  const waiting = requests
    .filter((r) => r.status === 'pending')
    .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  const resolvedInRange = requests
    .filter((r) => r.status !== 'pending')
    .filter((r) => {
      const t = resolvedInstant(r).getTime();
      return t >= range.start.getTime() && t <= range.end.getTime();
    })
    .sort((a, b) => resolvedInstant(b).getTime() - resolvedInstant(a).getTime());
  const approved = resolvedInRange.filter((r) => r.status === 'approved');
  return {
    waiting,
    waitingHeld: waiting.reduce((n, r) => n + r.saleGrandTotal, 0),
    oldest: waiting[0] ?? null,
    resolvedInRange,
    approvedCount: approved.length,
    rejectedCount: resolvedInRange.length - approved.length,
    voidedTotal: approved.reduce((n, r) => n + r.saleGrandTotal, 0),
    approvalRate: resolvedInRange.length > 0 ? approved.length / resolvedInRange.length : null,
  };
}
