import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { mechanicConverter } from './mechanicConverter';

// Minimal fake snapshot — the converter only reads `.id` and `.data()`.
const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

describe('mechanicConverter.fromFirestore', () => {
  it('reads name / isActive / audit fields and timestamps', () => {
    const created = Timestamp.fromDate(new Date('2026-01-02T03:04:05Z'));
    const updated = Timestamp.fromDate(new Date('2026-01-03T03:04:05Z'));
    const m = mechanicConverter.fromFirestore(
      snap('m1', {
        name: 'Juan',
        isActive: true,
        address: '123 Rizal St, Cebu',
        contactNumber: '0917 123 4567',
        createdAt: created,
        updatedAt: updated,
        createdBy: 'u1',
        updatedBy: 'u2',
      }),
    );
    expect(m).toEqual({
      id: 'm1',
      name: 'Juan',
      isActive: true,
      address: '123 Rizal St, Cebu',
      contactNumber: '0917 123 4567',
      createdAt: created.toDate(),
      updatedAt: updated.toDate(),
      createdBy: 'u1',
      updatedBy: 'u2',
    });
  });

  it('defaults name/isActive and tolerates a missing updatedAt + audit', () => {
    const created = Timestamp.fromDate(new Date('2026-01-02T03:04:05Z'));
    const m = mechanicConverter.fromFirestore(snap('m2', { createdAt: created }));
    expect(m.name).toBe('');
    expect(m.isActive).toBe(true);
    expect(m.address).toBeNull();
    expect(m.contactNumber).toBeNull();
    expect(m.updatedAt).toBeNull();
    expect(m.createdBy).toBeNull();
    expect(m.updatedBy).toBeNull();
  });
});
