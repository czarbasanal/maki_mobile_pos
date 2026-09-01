// The ONE domain-status → tone mapping (spec §7 Badge). "Completed" is the
// same green in the sales table, job order list and drawer because every
// screen routes through this function.
import type { Tone } from './Badge';

const TONE_BY_STATUS: Record<string, Tone> = {
  completed: 'positive',
  approved: 'positive',
  received: 'positive',
  pending: 'warning',
  open: 'warning',
  partial: 'warning',
  refunded: 'negative',
  rejected: 'negative',
  cancelled: 'negative',
  voided: 'neutral',
  draft: 'neutral',
};

export function statusTone(status: string): Tone {
  return TONE_BY_STATUS[status.toLowerCase()] ?? 'neutral';
}
