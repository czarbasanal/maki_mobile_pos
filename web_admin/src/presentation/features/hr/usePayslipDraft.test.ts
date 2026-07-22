import { describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { usePayslipDraft } from './usePayslipDraft';
import { payPeriodFor, shiftPeriod } from '@/domain/hr/payPeriod';
import type { PayslipDefaults } from '@/domain/hr/types';

// Mon 2026-07-20 .. Sun 2026-07-26 — same period the payPeriod.test.ts fixture
// uses, computed the same way (anchor + weekStartDay), no need to fake `Date`.
const PERIOD = payPeriodFor(new Date(2026, 6, 22), 1);
const PCTS = { regularHolidayPct: 100, specialHolidayPct: 30 };

const DEFAULTS: PayslipDefaults = {
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
  dayPattern: ['absent', 'present', 'present', 'present', 'present', 'present', 'present'],
};

describe('usePayslipDraft', () => {
  it('seeds a 7-day period with every day present except the last, which defaults to day off', () => {
    const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
    expect(result.current.days).toHaveLength(7);
    expect(result.current.days.slice(0, 6).every((d) => d.status === 'present')).toBe(true);
    expect(result.current.days[6]).toEqual({ date: '2026-07-26', status: 'dayOff' });
  });

  it('seeds the holiday percentages from settings into the inputs', () => {
    const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
    expect(result.current.inputs.regularHolidayPct).toBe(100);
    expect(result.current.inputs.specialHolidayPct).toBe(30);
  });

  it('computes the worked example live as hours/rate are set', () => {
    const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
    act(() => {
      result.current.setDailyRateText('640');
      result.current.setHoursWorkedText('48');
    });
    expect(result.current.computed.basePay).toBe(3840);
    expect(result.current.computed.net).toBe(3840);
  });

  it("setDay overrides a single date's status", () => {
    const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
    act(() => result.current.setDay('2026-07-20', 'absent'));
    expect(result.current.days[0]).toEqual({ date: '2026-07-20', status: 'absent' });
  });

  it('reseeds days when the period changes', () => {
    const { result, rerender } = renderHook(({ period }) => usePayslipDraft(period, PCTS), {
      initialProps: { period: PERIOD },
    });
    act(() => result.current.setDay('2026-07-20', 'absent'));
    const nextPeriod = shiftPeriod(PERIOD, 1);
    rerender({ period: nextPeriod });
    expect(result.current.days[6]).toEqual({ date: nextPeriod.dates[6], status: 'dayOff' });
    expect(result.current.days[0]).toEqual({ date: nextPeriod.dates[0], status: 'present' });
  });

  it('adds, edits, and removes an other-deduction row', () => {
    const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
    act(() => result.current.addOther());
    const id = result.current.others[0].id;
    act(() => {
      result.current.setOtherLabel(id, 'Load');
      result.current.setOtherAmountText(id, '100');
    });
    expect(result.current.inputs.deductions.others).toEqual([{ label: 'Load', amount: 100 }]);
    act(() => result.current.removeOther(id));
    expect(result.current.others).toHaveLength(0);
    expect(result.current.inputs.deductions.others).toHaveLength(0);
  });

  it('flags a negative field as invalid while non-numeric text silently becomes 0', () => {
    const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
    expect(result.current.isValid).toBe(true);
    act(() => result.current.setIncentivesText('abc'));
    expect(result.current.isValid).toBe(true); // non-numeric -> 0, still valid
    act(() => result.current.setIncentivesText('-5'));
    expect(result.current.isValid).toBe(false);
  });

  describe('applyDefaults', () => {
    it('fills every numeric field, the others rows, and the day grid positionally from a non-null profile', () => {
      const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
      act(() => result.current.applyDefaults(DEFAULTS, PERIOD));

      expect(result.current.hoursWorkedText).toBe('40');
      expect(result.current.overtimeHoursText).toBe('4');
      expect(result.current.overtimeRatePerHourText).toBe('90');
      expect(result.current.regularHolidayDaysText).toBe('1');
      expect(result.current.specialHolidayDaysText).toBe('0');
      expect(result.current.incentivesText).toBe('200');
      expect(result.current.sssText).toBe('100');
      expect(result.current.philhealthText).toBe('50');
      expect(result.current.pagibigText).toBe('25');
      expect(result.current.lateText).toBe('0');
      expect(result.current.absencesText).toBe('0');
      expect(result.current.cashAdvanceText).toBe('300');
      expect(result.current.others).toHaveLength(1);
      expect(result.current.others[0]).toMatchObject({ label: 'Load', amountText: '100' });

      // dayPattern[0] = 'absent' -> onto PERIOD.dates[0] (2026-07-20); the
      // rest are 'present', overriding the default seed's last-day-off.
      expect(result.current.days).toEqual([
        { date: '2026-07-20', status: 'absent' },
        { date: '2026-07-21', status: 'present' },
        { date: '2026-07-22', status: 'present' },
        { date: '2026-07-23', status: 'present' },
        { date: '2026-07-24', status: 'present' },
        { date: '2026-07-25', status: 'present' },
        { date: '2026-07-26', status: 'present' },
      ]);

      // Percentages are untouched — they stay settings-seeded.
      expect(result.current.regularHolidayPctText).toBe('100');
      expect(result.current.specialHolidayPctText).toBe('30');
    });

    it('does not touch dailyRateText (prefilled separately from the employee record)', () => {
      const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
      act(() => result.current.setDailyRateText('999'));
      act(() => result.current.applyDefaults(DEFAULTS, PERIOD));
      expect(result.current.dailyRateText).toBe('999');
    });

    it('keeps the default seed for days beyond a short dayPattern', () => {
      const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
      const short: PayslipDefaults = { ...DEFAULTS, dayPattern: ['absent'] };
      act(() => result.current.applyDefaults(short, PERIOD));
      expect(result.current.days[0]).toEqual({ date: '2026-07-20', status: 'absent' });
      // Untouched indices fall back to the base seed: present, ..., last day off.
      expect(result.current.days[1]).toEqual({ date: '2026-07-21', status: 'present' });
      expect(result.current.days[6]).toEqual({ date: '2026-07-26', status: 'dayOff' });
    });

    it('a null profile resets every numeric field, others, and the day grid to the default seed', () => {
      const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
      act(() => result.current.applyDefaults(DEFAULTS, PERIOD));
      expect(result.current.hoursWorkedText).toBe('40'); // sanity: defaults applied first

      act(() => result.current.applyDefaults(null, PERIOD));

      expect(result.current.hoursWorkedText).toBe('');
      expect(result.current.overtimeHoursText).toBe('');
      expect(result.current.overtimeRatePerHourText).toBe('');
      expect(result.current.regularHolidayDaysText).toBe('');
      expect(result.current.specialHolidayDaysText).toBe('');
      expect(result.current.incentivesText).toBe('');
      expect(result.current.sssText).toBe('');
      expect(result.current.philhealthText).toBe('');
      expect(result.current.pagibigText).toBe('');
      expect(result.current.lateText).toBe('');
      expect(result.current.absencesText).toBe('');
      expect(result.current.cashAdvanceText).toBe('');
      expect(result.current.others).toHaveLength(0);
      expect(result.current.days.slice(0, 6).every((d) => d.status === 'present')).toBe(true);
      expect(result.current.days[6]).toEqual({ date: '2026-07-26', status: 'dayOff' });
      // Percentages stay untouched by a reset too.
      expect(result.current.regularHolidayPctText).toBe('100');
      expect(result.current.specialHolidayPctText).toBe('30');
    });

    it('applies onto a period passed as an argument even if it differs from the currently rendered period, and a later rerender with that period does not re-seed over it', () => {
      const { result, rerender } = renderHook(({ period }) => usePayslipDraft(period, PCTS), {
        initialProps: { period: PERIOD },
      });
      const nextPeriod = shiftPeriod(PERIOD, 1);

      // Simulates PayrollPage computing the post-anchor period locally and
      // passing it straight to applyDefaults in the same handler, before the
      // parent's setPeriod has re-rendered this hook with the new period.
      act(() => result.current.applyDefaults(DEFAULTS, nextPeriod));
      expect(result.current.days[0]).toEqual({ date: nextPeriod.dates[0], status: 'absent' });

      // Now the parent commits the period change; the hook's own reseed
      // effect must not clobber what applyDefaults just set.
      rerender({ period: nextPeriod });
      expect(result.current.days[0]).toEqual({ date: nextPeriod.dates[0], status: 'absent' });
      expect(result.current.hoursWorkedText).toBe('40');
    });
  });

  describe('snapshotDefaults', () => {
    it('captures the current numeric inputs, deductions (incl. others), and positional day statuses', () => {
      const { result } = renderHook(() => usePayslipDraft(PERIOD, PCTS));
      act(() => {
        result.current.setHoursWorkedText('40');
        result.current.setOvertimeHoursText('4');
        result.current.setOvertimeRatePerHourText('90');
        result.current.setRegularHolidayDaysText('1');
        result.current.setSpecialHolidayDaysText('0');
        result.current.setIncentivesText('200');
        result.current.setSssText('100');
        result.current.setPhilhealthText('50');
        result.current.setPagibigText('25');
        result.current.setCashAdvanceText('300');
        result.current.addOther();
      });
      const otherId = result.current.others[0].id;
      act(() => {
        result.current.setOtherLabel(otherId, 'Load');
        result.current.setOtherAmountText(otherId, '100');
        result.current.setDay('2026-07-20', 'absent');
      });

      const snapshot = result.current.snapshotDefaults();
      expect(snapshot).toEqual({
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
        dayPattern: ['absent', 'present', 'present', 'present', 'present', 'present', 'dayOff'],
      });
      // No pct fields in the snapshot shape.
      expect(snapshot).not.toHaveProperty('regularHolidayPct');
      expect(snapshot).not.toHaveProperty('specialHolidayPct');
    });
  });
});
