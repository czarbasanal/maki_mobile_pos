// One derivation for the Void Requests screen (void-requests guide §2/§3):
// the KPI strip, the outcome chips and the "Total voided" foot all read the
// same summary. Waiting is NEVER scoped by the date range; resolved is.
import { describe, expect, it } from 'vitest';
import type { VoidRequest } from '@/domain/entities';
import {
  ageLabel,
  ageMinutes,
  ageTone,
  durationLabel,
  summarizeVoidQueue,
  voidReasonTone,
} from './voidRequestQueue';

const NOW = new Date('2026-09-05T06:00:00Z');
const min = (n: number) => new Date(NOW.getTime() - n * 60_000);

function req(o: Partial<VoidRequest> = {}): VoidRequest {
  return {
    id: 'r', saleId: 's', saleNumber: 'SALE-1', saleGrandTotal: 100,
    requestedBy: 'u', requestedByName: 'Belle', requestedByRole: 'cashier',
    reason: 'Wrong item', status: 'pending', read: false, createdAt: min(10),
    resolvedBy: null, resolvedByName: null, resolvedAt: null, rejectionReason: null,
    itemsSummary: null,
    ...o,
  };
}

describe('voidReasonTone — keyword tones over an admin-managed reason list', () => {
  it('a "test" or "training" void is the theft signal: negative', () => {
    expect(voidReasonTone('Test transaction')).toBe('negative');
    expect(voidReasonTone('Training the new cashier')).toBe('negative');
  });
  it('matches whole words only — "restraining" and "testimonial" are not the theft signal', () => {
    expect(voidReasonTone('Restraining strap missing')).toBe('neutral');
    expect(voidReasonTone('Testimonial discount')).toBe('neutral');
    expect(voidReasonTone('Testing the register')).toBe('negative');
  });
  it('duplicates take the accent; wrong item/price are info; the rest neutral', () => {
    expect(voidReasonTone('Duplicate sale')).toBe('warning');
    expect(voidReasonTone('Charged twice')).toBe('warning');
    expect(voidReasonTone('Wrong item')).toBe('info');
    expect(voidReasonTone('wrong price on tag')).toBe('info');
    expect(voidReasonTone('Customer cancelled')).toBe('neutral');
    expect(voidReasonTone('')).toBe('neutral');
  });
});

describe('age', () => {
  it('counts whole minutes since the request', () => {
    expect(ageMinutes(min(184), NOW)).toBe(184);
    expect(ageMinutes(new Date(NOW.getTime() + 60_000), NOW)).toBe(0); // clock skew never goes negative
  });
  it('labels in m / h / d', () => {
    expect(ageLabel(12)).toBe('12m');
    expect(ageLabel(184)).toBe('3h');
    expect(ageLabel(3000)).toBe('2d');
  });
  it('escalates: <1h ink-3, 1–4h accent-text, ≥4h neg', () => {
    expect(ageTone(59)).toBe('ink-3');
    expect(ageTone(60)).toBe('accent-text');
    expect(ageTone(239)).toBe('accent-text');
    expect(ageTone(240)).toBe('neg');
  });
});

describe('durationLabel — how long the customer waited', () => {
  it('formats minutes, hours+minutes, days+hours', () => {
    expect(durationLabel(min(16), NOW)).toBe('16m');
    expect(durationLabel(min(84), NOW)).toBe('1h 24m');
    expect(durationLabel(min(60), NOW)).toBe('1h');
    expect(durationLabel(min(1500), NOW)).toBe('1d 1h');
    expect(durationLabel(min(0), NOW)).toBe('<1m');
  });
});

describe('summarizeVoidQueue', () => {
  const range = { start: min(7 * 1440), end: NOW };
  const waitingOld = req({ id: 'w1', saleNumber: 'SALE-OLD', saleGrandTotal: 1250, createdAt: min(30 * 1440) });
  const waitingNew = req({ id: 'w2', saleGrandTotal: 410, createdAt: min(20) });
  const approvedIn = req({ id: 'a1', status: 'approved', saleGrandTotal: 285, createdAt: min(2000), resolvedAt: min(1990) });
  const rejectedIn = req({ id: 'j1', status: 'rejected', saleGrandTotal: 640, createdAt: min(100), resolvedAt: min(90) });
  const approvedOut = req({ id: 'a2', status: 'approved', saleGrandTotal: 9999, createdAt: min(40 * 1440), resolvedAt: min(39 * 1440) });
  const s = summarizeVoidQueue([waitingOld, waitingNew, approvedIn, rejectedIn, approvedOut], range);

  it('the waiting queue is never scoped by the range, and the oldest leads it', () => {
    expect(s.waiting.map((r) => r.id)).toEqual(['w1', 'w2']);
    expect(s.waitingHeld).toBe(1660);
    expect(s.oldest?.saleNumber).toBe('SALE-OLD');
  });

  it('resolved history is scoped by resolvedAt; approved total and rate come from the same set', () => {
    expect(s.resolvedInRange.map((r) => r.id)).toEqual(['j1', 'a1']); // newest resolved first
    expect(s.approvedCount).toBe(1);
    expect(s.rejectedCount).toBe(1);
    expect(s.voidedTotal).toBe(285);
    expect(s.approvalRate).toBe(0.5);
  });

  it('nothing resolved in range → rate is null, never 0', () => {
    const z = summarizeVoidQueue([waitingNew], range);
    expect(z.approvalRate).toBeNull();
    expect(z.voidedTotal).toBe(0);
    expect(z.oldest?.id).toBe('w2');
  });

  it('an empty queue has no oldest', () => {
    expect(summarizeVoidQueue([], range).oldest).toBeNull();
  });
});
