import { describe, expect, it } from 'vitest';
import { statusTone } from './statusTone';

describe('statusTone', () => {
  it('maps sale statuses per spec §5.6 + JO guide §A', () => {
    expect(statusTone('completed')).toBe('positive');
    expect(statusTone('Completed')).toBe('positive');
    expect(statusTone('pending')).toBe('warning');
    expect(statusTone('refunded')).toBe('negative');
    // JO guide §A: voided matches the struck-through number in --neg.
    expect(statusTone('voided')).toBe('negative');
  });

  it('maps job-order statuses per the JO guide', () => {
    expect(statusTone('billed')).toBe('positive');
    expect(statusTone('In progress')).toBe('warning');
    expect(statusTone('open')).toBe('info');
  });
  it('falls back to neutral for unknown statuses', () => {
    expect(statusTone('sideways')).toBe('neutral');
  });
});
