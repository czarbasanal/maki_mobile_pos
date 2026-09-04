import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { adjustmentReasonConverter } from './adjustmentReasonConverter';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

describe('adjustmentReasonConverter.fromFirestore', () => {
  it('reads name / requiresNote / isActive / audit', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const updated = Timestamp.fromDate(new Date('2026-09-02T03:04:05Z'));
    const r = adjustmentReasonConverter.fromFirestore(
      snap('ar1', {
        name: 'Damaged',
        requiresNote: true,
        isActive: true,
        createdAt: created,
        updatedAt: updated,
        createdBy: 'u1',
        updatedBy: 'u2',
      }),
    );
    expect(r).toEqual({
      id: 'ar1',
      name: 'Damaged',
      requiresNote: true,
      isActive: true,
      createdAt: created.toDate(),
      updatedAt: updated.toDate(),
      createdBy: 'u1',
      updatedBy: 'u2',
    });
  });

  it('defaults name/isActive/requiresNote, nulls updatedAt', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const r = adjustmentReasonConverter.fromFirestore(snap('ar2', { createdAt: created }));
    expect(r.name).toBe('');
    expect(r.requiresNote).toBe(false);
    expect(r.isActive).toBe(true);
    expect(r.updatedAt).toBeNull();
    expect(r.createdBy).toBeNull();
    expect(r.updatedBy).toBeNull();
  });

  it('defaults requiresNote to false when missing', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const r = adjustmentReasonConverter.fromFirestore(
      snap('ar3', { name: 'Delivery', createdAt: created, isActive: true }),
    );
    expect(r.requiresNote).toBe(false);
  });
});
