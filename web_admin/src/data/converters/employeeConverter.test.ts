import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import type { Employee, PayslipDefaults } from '@/domain/hr/types';
import { employeeConverter } from './employeeConverter';

// Minimal fake snapshot — the converter only reads `.id` and `.data()`.
const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

const FULL_DEFAULTS: PayslipDefaults = {
  hoursWorked: 40,
  overtimeHours: 4,
  overtimeRatePerHour: 90,
  regularHolidayDays: 1,
  specialHolidayDays: 0,
  incentives: 200,
  deductions: {
    sss: 100,
    philhealth: 50,
    pagibig: 25,
    late: 0,
    absences: 0,
    cashAdvance: 300,
    others: [{ label: 'Load', amount: 100 }],
  },
  dayPattern: ['present', 'present', 'present', 'present', 'present', 'present', 'dayOff'],
};

describe('employeeConverter.toFirestore', () => {
  it('writes name / dailyRate / isActive (audit fields are server-managed by the repo)', () => {
    const e: Employee = {
      id: 'ignored-on-write',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      payslipDefaults: null,
      createdAt: null,
      updatedAt: null,
    };
    expect(employeeConverter.toFirestore(e as never)).toEqual({
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      payslipDefaults: null,
    });
  });

  it('round-trips a weekStartDay override', () => {
    const e: Employee = {
      id: 'ignored-on-write',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: 3,
      payslipDefaults: null,
      createdAt: null,
      updatedAt: null,
    };
    expect(employeeConverter.toFirestore(e as never)).toEqual({
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: 3,
      payslipDefaults: null,
    });
  });

  it('writes a full payslipDefaults object as-is', () => {
    const e: Employee = {
      id: 'ignored-on-write',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      payslipDefaults: FULL_DEFAULTS,
      createdAt: null,
      updatedAt: null,
    };
    expect(employeeConverter.toFirestore(e as never)).toEqual({
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      payslipDefaults: FULL_DEFAULTS,
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
      payslipDefaults: null,
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
    expect(e.payslipDefaults).toBeNull();
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

  it('round-trips a full payslipDefaults object', () => {
    const raw = employeeConverter.toFirestore({
      id: 'ignored',
      name: 'Juan',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      payslipDefaults: FULL_DEFAULTS,
      createdAt: null,
      updatedAt: null,
    } as never);
    const e = employeeConverter.fromFirestore(snap('e5', raw));
    expect(e.payslipDefaults).toEqual(FULL_DEFAULTS);
  });

  it('treats an explicit null payslipDefaults the same as missing', () => {
    const e = employeeConverter.fromFirestore(snap('e6', { name: 'Juan', payslipDefaults: null }));
    expect(e.payslipDefaults).toBeNull();
  });

  it('tolerates a partial payslipDefaults map: missing others -> [], missing/short dayPattern kept as-is', () => {
    const e = employeeConverter.fromFirestore(
      snap('e7', {
        name: 'Juan',
        payslipDefaults: {
          hoursWorked: 40,
          deductions: { sss: 100 },
          dayPattern: ['absent'],
        },
      }),
    );
    expect(e.payslipDefaults).toEqual({
      hoursWorked: 40,
      overtimeHours: 0,
      overtimeRatePerHour: 0,
      regularHolidayDays: 0,
      specialHolidayDays: 0,
      incentives: 0,
      deductions: {
        sss: 100,
        philhealth: 0,
        pagibig: 0,
        late: 0,
        absences: 0,
        cashAdvance: 0,
        others: [],
      },
      dayPattern: ['absent'],
    });
  });

  it('tolerates a payslipDefaults map with no deductions/dayPattern at all', () => {
    const e = employeeConverter.fromFirestore(
      snap('e8', { name: 'Juan', payslipDefaults: { hoursWorked: 40 } }),
    );
    expect(e.payslipDefaults?.deductions).toEqual({
      sss: 0,
      philhealth: 0,
      pagibig: 0,
      late: 0,
      absences: 0,
      cashAdvance: 0,
      others: [],
    });
    expect(e.payslipDefaults?.dayPattern).toEqual([]);
  });
});
