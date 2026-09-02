// The ONE domain-status → tone mapping (spec §7 Badge). "Completed" is the
// same green in the sales table, job order list and drawer because every
// screen routes through this function.
import type { Tone } from './Badge';

const TONE_BY_STATUS: Record<string, Tone> = {
  completed: 'positive',
  approved: 'positive',
  received: 'positive',
  billed: 'positive',
  pending: 'warning',
  partial: 'warning',
  'in progress': 'warning',
  in_progress: 'warning',
  // A ticket on the bench is information, not a warning (JO guide §A).
  open: 'info',
  refunded: 'negative',
  rejected: 'negative',
  cancelled: 'negative',
  // The number and money are struck through wherever a voided sale shows;
  // the pill matches in --neg (JO guide §A status tones).
  voided: 'negative',
  // A draft receipt is a working view, not a dead state (receiving guide §A).
  draft: 'info',
};

export function statusTone(status: string): Tone {
  return TONE_BY_STATUS[status.toLowerCase()] ?? 'neutral';
}
