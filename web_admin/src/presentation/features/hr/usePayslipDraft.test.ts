import { describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { usePayslipDraft } from './usePayslipDraft';
import { payPeriodFor, shiftPeriod } from '@/domain/hr/payPeriod';

// Mon 2026-07-20 .. Sun 2026-07-26 — same period the payPeriod.test.ts fixture
// uses, computed the same way (anchor + weekStartDay), no need to fake `Date`.
const PERIOD = payPeriodFor(new Date(2026, 6, 22), 1);
const PCTS = { regularHolidayPct: 100, specialHolidayPct: 30 };

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
});
