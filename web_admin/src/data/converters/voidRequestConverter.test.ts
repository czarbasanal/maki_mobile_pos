import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { voidRequestConverter } from './voidRequestConverter';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, exists: () => true, data: () => data }) as never;

const createdTs = Timestamp.fromDate(new Date('2026-08-28T13:00:00Z'));

describe('voidRequestConverter.fromFirestore', () => {
  it('parses a pending request as mobile writes it', () => {
    const r = voidRequestConverter.fromFirestore(
      snap('r1', {
        saleId: 's1',
        saleNumber: 'SALE-20260828-020',
        saleGrandTotal: 285,
        requestedBy: 'u-belle',
        requestedByName: 'Belle',
        requestedByRole: 'cashier',
        reason: 'Payment issue',
        status: 'pending',
        read: false,
        createdAt: createdTs,
        itemsSummary: '1× Ilis carbon brass',
      }),
    );

    expect(r).toMatchObject({
      id: 'r1',
      saleId: 's1',
      saleNumber: 'SALE-20260828-020',
      saleGrandTotal: 285,
      requestedByName: 'Belle',
      reason: 'Payment issue',
      status: 'pending',
      read: false,
      itemsSummary: '1× Ilis carbon brass',
    });
    expect(r.createdAt).toEqual(new Date('2026-08-28T13:00:00Z'));
    expect(r.resolvedAt).toBeNull();
  });

  it('parses a resolved request', () => {
    const r = voidRequestConverter.fromFirestore(
      snap('r2', {
        saleId: 's2',
        status: 'rejected',
        read: true,
        createdAt: createdTs,
        resolvedBy: 'u-admin',
        resolvedByName: 'Czar',
        resolvedAt: Timestamp.fromDate(new Date('2026-08-28T14:00:00Z')),
        rejectionReason: 'Sale is correct',
      }),
    );

    expect(r.status).toBe('rejected');
    expect(r.resolvedByName).toBe('Czar');
    expect(r.rejectionReason).toBe('Sale is correct');
    expect(r.resolvedAt).toEqual(new Date('2026-08-28T14:00:00Z'));
  });

  it('falls back to pending for an unknown status, matching mobile', () => {
    const r = voidRequestConverter.fromFirestore(
      snap('r3', { saleId: 's3', status: 'bogus', createdAt: createdTs }),
    );
    expect(r.status).toBe('pending');
    // Absent optional fields read as null, never undefined — the badge counts
    // on `read` being a real boolean.
    expect(r.read).toBe(false);
    expect(r.itemsSummary).toBeNull();
  });

  it('is read-only — writes must go through the repository', () => {
    expect(() =>
      (voidRequestConverter.toFirestore as () => unknown)(),
    ).toThrow();
  });
});
