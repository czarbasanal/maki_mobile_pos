import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { tagConverter } from './tagConverter';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

describe('tagConverter.fromFirestore', () => {
  it('reads name / color / description / isActive / audit', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const updated = Timestamp.fromDate(new Date('2026-09-02T03:04:05Z'));
    const t = tagConverter.fromFirestore(
      snap('t1', {
        name: 'Intact',
        color: 'green',
        description: 'Physical count verified',
        isActive: true,
        createdAt: created,
        updatedAt: updated,
        createdBy: 'u1',
        updatedBy: 'u2',
      }),
    );
    expect(t).toEqual({
      id: 't1',
      name: 'Intact',
      color: 'green',
      description: 'Physical count verified',
      isActive: true,
      createdAt: created.toDate(),
      updatedAt: updated.toDate(),
      createdBy: 'u1',
      updatedBy: 'u2',
    });
  });

  it('defaults name/isActive, normalizes a bad color to gray, nulls description', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const t = tagConverter.fromFirestore(snap('t2', { createdAt: created, color: 'neon' }));
    expect(t.name).toBe('');
    expect(t.color).toBe('gray');
    expect(t.description).toBeNull();
    expect(t.isActive).toBe(true);
    expect(t.updatedAt).toBeNull();
  });
});
