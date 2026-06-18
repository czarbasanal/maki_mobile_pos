import { describe, expect, it } from 'vitest';
import { supplierConverter } from './supplierConverter';

function snap(id: string, data: Record<string, unknown>) {
  return { id, data: () => data } as never;
}
const opts = {} as never;

describe('supplierConverter.fromFirestore', () => {
  it('reads leadTimeDays as a number', () => {
    const s = supplierConverter.fromFirestore(
      snap('sup-1', {
        name: 'Acme',
        transactionType: 'cash',
        createdAt: new Date('2026-06-01T00:00:00Z'),
        leadTimeDays: 5,
      }),
      opts,
    );
    expect(s.leadTimeDays).toBe(5);
  });

  it('defaults a missing leadTimeDays to null', () => {
    const s = supplierConverter.fromFirestore(
      snap('sup-2', {
        name: 'Beta',
        transactionType: 'cash',
        createdAt: new Date('2026-06-01T00:00:00Z'),
      }),
      opts,
    );
    expect(s.leadTimeDays).toBeNull();
  });
});
