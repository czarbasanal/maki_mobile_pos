import { describe, expect, it } from 'vitest';
import { statusTone } from './statusTone';

describe('statusTone', () => {
  it('maps sale statuses per spec §5.6', () => {
    expect(statusTone('completed')).toBe('positive');
    expect(statusTone('Completed')).toBe('positive');
    expect(statusTone('pending')).toBe('warning');
    expect(statusTone('refunded')).toBe('negative');
    expect(statusTone('voided')).toBe('neutral');
  });
  it('falls back to neutral for unknown statuses', () => {
    expect(statusTone('sideways')).toBe('neutral');
  });
});
