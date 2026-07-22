import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import type { Employee } from '@/domain/hr/types';
import { employeeConverter } from './employeeConverter';

// Minimal fake snapshot — the converter only reads `.id` and `.data()`.
const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

describe('employeeConverter.toFirestore', () => {
  it('writes name / dailyRate / isActive (audit fields are server-managed by the repo)', () => {
    const e: Employee = {
      id: 'ignored-on-write',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      createdAt: null,
      updatedAt: null,
    };
    expect(employeeConverter.toFirestore(e as never)).toEqual({
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
    });
  });

  it('round-trips a weekStartDay override', () => {
    const e: Employee = {
      id: 'ignored-on-write',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: 3,
      createdAt: null,
      updatedAt: null,
    };
    expect(employeeConverter.toFirestore(e as never)).toEqual({
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: 3,
    });
  });
});

describe('employeeConverter.fromFirestore', () => {
  it('reads name / dailyRate / isActive and timestamps', () => {
    const created = Timestamp.fromDate(new Date('2026-01-02T03:04:05Z'));
    const updated = Timestamp.fromDate(new Date('2026-01-03T03:04:05Z'));
    const e = employeeConverter.fromFirestore(
      snap('e1', {
        name: 'Juan',
        dailyRate: 640,
        isActive: true,
        createdAt: created,
        updatedAt: updated,
      }),
    );
    expect(e).toEqual({
      id: 'e1',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      createdAt: created.toDate(),
      updatedAt: updated.toDate(),
    });
  });

  it('defaults name/dailyRate/isActive and tolerates missing timestamps', () => {
    const e = employeeConverter.fromFirestore(snap('e2', {}));
    expect(e.name).toBe('');
    expect(e.dailyRate).toBe(0);
    expect(e.isActive).toBe(true);
    expect(e.weekStartDay).toBeNull();
    expect(e.createdAt).toBeNull();
    expect(e.updatedAt).toBeNull();
  });

  it('round-trips an explicit weekStartDay of 3', () => {
    const e = employeeConverter.fromFirestore(snap('e3', { name: 'Juan', weekStartDay: 3 }));
    expect(e.weekStartDay).toBe(3);
  });

  it('treats an explicit null weekStartDay the same as missing', () => {
    const e = employeeConverter.fromFirestore(snap('e4', { name: 'Juan', weekStartDay: null }));
    expect(e.weekStartDay).toBeNull();
  });
});
