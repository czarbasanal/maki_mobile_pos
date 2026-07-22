// String-backed payslip form state — mirrors the checkout usePaymentDraft
// idiom (web_admin/src/presentation/hooks/usePaymentDraft.ts): every numeric
// field is held as a raw string so a user can type "48" or "3.5" without the
// input fighting them, and the numeric PayslipInputs computePayslip consumes
// is derived on every render via `Number(text) || 0` (blank/non-numeric ->
// 0; negative values pass through and flip `isValid` to false instead of
// being silently clamped).
//
// `days` is seeded from the pay period's dates (all present, last day off —
// a 6-day work week) and reseeded whenever the caller passes a different
// period (prev/next week navigation), so the grid always matches the actual
// dates on screen.

import { useEffect, useRef, useState } from 'react';
import { computePayslip } from '@/domain/hr/computePayslip';
import type { PayPeriod } from '@/domain/hr/payPeriod';
import type {
  DayStatus,
  PayslipComputed,
  PayslipDay,
  PayslipDefaults,
  PayslipInputs,
} from '@/domain/hr/types';

export interface OtherRow {
  id: string;
  label: string;
  amountText: string;
}

export interface PayslipPctSeed {
  regularHolidayPct: number;
  specialHolidayPct: number;
}

const NEXT_STATUS: Record<DayStatus, DayStatus> = {
  present: 'absent',
  absent: 'dayOff',
  dayOff: 'present',
};

function seedDays(period: PayPeriod): PayslipDay[] {
  const lastIndex = period.dates.length - 1;
  return period.dates.map((date, i) => ({ date, status: i === lastIndex ? 'dayOff' : 'present' }));
}

// Number(...) || 0: blank/non-numeric text collapses to 0 silently; only a
// genuinely negative number should trip validation (see isValid below).
function parseNum(text: string): number {
  return Number(text) || 0;
}

export interface UsePayslipDraftResult {
  hoursWorkedText: string;
  setHoursWorkedText: (v: string) => void;
  dailyRateText: string;
  setDailyRateText: (v: string) => void;
  overtimeHoursText: string;
  setOvertimeHoursText: (v: string) => void;
  overtimeRatePerHourText: string;
  setOvertimeRatePerHourText: (v: string) => void;
  regularHolidayDaysText: string;
  setRegularHolidayDaysText: (v: string) => void;
  regularHolidayPctText: string;
  setRegularHolidayPctText: (v: string) => void;
  specialHolidayDaysText: string;
  setSpecialHolidayDaysText: (v: string) => void;
  specialHolidayPctText: string;
  setSpecialHolidayPctText: (v: string) => void;
  incentivesText: string;
  setIncentivesText: (v: string) => void;
  sssText: string;
  setSssText: (v: string) => void;
  philhealthText: string;
  setPhilhealthText: (v: string) => void;
  pagibigText: string;
  setPagibigText: (v: string) => void;
  lateText: string;
  setLateText: (v: string) => void;
  absencesText: string;
  setAbsencesText: (v: string) => void;
  cashAdvanceText: string;
  setCashAdvanceText: (v: string) => void;
  others: OtherRow[];
  addOther: () => void;
  removeOther: (id: string) => void;
  setOtherLabel: (id: string, label: string) => void;
  setOtherAmountText: (id: string, amountText: string) => void;
  days: PayslipDay[];
  setDay: (date: string, status: DayStatus) => void;
  inputs: PayslipInputs;
  computed: PayslipComputed;
  isValid: boolean;
  /**
   * Fills (or, for `null`, blanks) every field from a saved
   * PayslipDefaults profile — numeric fields, other-deduction rows, and the
   * day grid, positionally onto `applyPeriod.dates` (index i of
   * dayPattern -> applyPeriod.dates[i]; a short/missing pattern leaves the
   * remaining days at the default seed). Takes `applyPeriod` as an
   * argument rather than reading this hook's own `period` prop: the caller
   * (PayrollPage.onEmployeeChange) may re-anchor the period in the SAME
   * event handler that picks the employee, and the hook's `period` prop
   * won't reflect that until the next render — passing the freshly
   * computed value here avoids applying defaults onto a stale window.
   * Also updates the internal reseed-tracking ref to the applied period's
   * start so the effect that reseeds on period-prop change doesn't
   * immediately stomp what was just applied once the parent's `period`
   * state catches up on the next render.
   */
  applyDefaults: (defaults: PayslipDefaults | null, applyPeriod: PayPeriod) => void;
  /** Snapshot of the current form (minus pcts) shaped as a PayslipDefaults, for "Save as defaults". */
  snapshotDefaults: () => PayslipDefaults;
}

/** WeekGrid's own cycle order (present -> absent -> dayOff -> present). */
export function nextDayStatus(status: DayStatus): DayStatus {
  return NEXT_STATUS[status];
}

export function usePayslipDraft(period: PayPeriod, seedPcts: PayslipPctSeed): UsePayslipDraftResult {
  const [hoursWorkedText, setHoursWorkedText] = useState('');
  const [dailyRateText, setDailyRateText] = useState('');
  const [overtimeHoursText, setOvertimeHoursText] = useState('');
  const [overtimeRatePerHourText, setOvertimeRatePerHourText] = useState('');
  const [regularHolidayDaysText, setRegularHolidayDaysText] = useState('');
  const [regularHolidayPctText, setRegularHolidayPctText] = useState(() =>
    String(seedPcts.regularHolidayPct),
  );
  const [specialHolidayDaysText, setSpecialHolidayDaysText] = useState('');
  const [specialHolidayPctText, setSpecialHolidayPctText] = useState(() =>
    String(seedPcts.specialHolidayPct),
  );
  const [incentivesText, setIncentivesText] = useState('');
  const [sssText, setSssText] = useState('');
  const [philhealthText, setPhilhealthText] = useState('');
  const [pagibigText, setPagibigText] = useState('');
  const [lateText, setLateText] = useState('');
  const [absencesText, setAbsencesText] = useState('');
  const [cashAdvanceText, setCashAdvanceText] = useState('');
  const [others, setOthers] = useState<OtherRow[]>([]);

  const [days, setDays] = useState<PayslipDay[]>(() => seedDays(period));
  const seededPeriodStart = useRef(period.start);
  useEffect(() => {
    if (seededPeriodStart.current !== period.start) {
      seededPeriodStart.current = period.start;
      setDays(seedDays(period));
    }
  }, [period]);

  const setDay = (date: string, status: DayStatus) => {
    setDays((prev) => prev.map((d) => (d.date === date ? { ...d, status } : d)));
  };

  const applyDefaults = (defaults: PayslipDefaults | null, applyPeriod: PayPeriod) => {
    // Mark this period as already seeded BEFORE setDays below, so that if
    // the caller is also mid-flight re-anchoring the period (parent's
    // `period` prop hasn't updated yet), the reseed effect that fires once
    // it does won't see a mismatch and overwrite what we're about to set.
    seededPeriodStart.current = applyPeriod.start;
    const base = seedDays(applyPeriod);

    if (!defaults) {
      setDays(base);
      setHoursWorkedText('');
      setOvertimeHoursText('');
      setOvertimeRatePerHourText('');
      setRegularHolidayDaysText('');
      setSpecialHolidayDaysText('');
      setIncentivesText('');
      setSssText('');
      setPhilhealthText('');
      setPagibigText('');
      setLateText('');
      setAbsencesText('');
      setCashAdvanceText('');
      setOthers([]);
      return;
    }

    setDays(base.map((d, i) => (i < defaults.dayPattern.length ? { ...d, status: defaults.dayPattern[i] } : d)));
    setHoursWorkedText(String(defaults.hoursWorked));
    setOvertimeHoursText(String(defaults.overtimeHours));
    setOvertimeRatePerHourText(String(defaults.overtimeRatePerHour));
    setRegularHolidayDaysText(String(defaults.regularHolidayDays));
    setSpecialHolidayDaysText(String(defaults.specialHolidayDays));
    setIncentivesText(String(defaults.incentives));
    setSssText(String(defaults.deductions.sss));
    setPhilhealthText(String(defaults.deductions.philhealth));
    setPagibigText(String(defaults.deductions.pagibig));
    setLateText(String(defaults.deductions.late));
    setAbsencesText(String(defaults.deductions.absences));
    setCashAdvanceText(String(defaults.deductions.cashAdvance));
    setOthers(
      defaults.deductions.others.map((o) => ({
        id: crypto.randomUUID(),
        label: o.label,
        amountText: String(o.amount),
      })),
    );
  };

  const snapshotDefaults = (): PayslipDefaults => ({
    hoursWorked: parseNum(hoursWorkedText),
    overtimeHours: parseNum(overtimeHoursText),
    overtimeRatePerHour: parseNum(overtimeRatePerHourText),
    regularHolidayDays: parseNum(regularHolidayDaysText),
    specialHolidayDays: parseNum(specialHolidayDaysText),
    incentives: parseNum(incentivesText),
    deductions: {
      sss: parseNum(sssText),
      philhealth: parseNum(philhealthText),
      pagibig: parseNum(pagibigText),
      late: parseNum(lateText),
      absences: parseNum(absencesText),
      cashAdvance: parseNum(cashAdvanceText),
      others: others.map((o) => ({ label: o.label, amount: parseNum(o.amountText) })),
    },
    dayPattern: days.map((d) => d.status),
  });

  const addOther = () => {
    setOthers((prev) => [...prev, { id: crypto.randomUUID(), label: '', amountText: '' }]);
  };
  const removeOther = (id: string) => setOthers((prev) => prev.filter((o) => o.id !== id));
  const setOtherLabel = (id: string, label: string) =>
    setOthers((prev) => prev.map((o) => (o.id === id ? { ...o, label } : o)));
  const setOtherAmountText = (id: string, amountText: string) =>
    setOthers((prev) => prev.map((o) => (o.id === id ? { ...o, amountText } : o)));

  const inputs: PayslipInputs = {
    hoursWorked: parseNum(hoursWorkedText),
    dailyRate: parseNum(dailyRateText),
    overtimeHours: parseNum(overtimeHoursText),
    overtimeRatePerHour: parseNum(overtimeRatePerHourText),
    regularHolidayDays: parseNum(regularHolidayDaysText),
    specialHolidayDays: parseNum(specialHolidayDaysText),
    regularHolidayPct: parseNum(regularHolidayPctText),
    specialHolidayPct: parseNum(specialHolidayPctText),
    incentives: parseNum(incentivesText),
    deductions: {
      sss: parseNum(sssText),
      philhealth: parseNum(philhealthText),
      pagibig: parseNum(pagibigText),
      late: parseNum(lateText),
      absences: parseNum(absencesText),
      cashAdvance: parseNum(cashAdvanceText),
      others: others.map((o) => ({ label: o.label, amount: parseNum(o.amountText) })),
    },
  };

  const computed = computePayslip(inputs);

  const isValid =
    inputs.hoursWorked >= 0 &&
    inputs.dailyRate >= 0 &&
    inputs.overtimeHours >= 0 &&
    inputs.overtimeRatePerHour >= 0 &&
    inputs.regularHolidayDays >= 0 &&
    inputs.specialHolidayDays >= 0 &&
    inputs.regularHolidayPct >= 0 &&
    inputs.specialHolidayPct >= 0 &&
    inputs.incentives >= 0 &&
    inputs.deductions.sss >= 0 &&
    inputs.deductions.philhealth >= 0 &&
    inputs.deductions.pagibig >= 0 &&
    inputs.deductions.late >= 0 &&
    inputs.deductions.absences >= 0 &&
    inputs.deductions.cashAdvance >= 0 &&
    inputs.deductions.others.every((o) => o.amount >= 0);

  return {
    hoursWorkedText,
    setHoursWorkedText,
    dailyRateText,
    setDailyRateText,
    overtimeHoursText,
    setOvertimeHoursText,
    overtimeRatePerHourText,
    setOvertimeRatePerHourText,
    regularHolidayDaysText,
    setRegularHolidayDaysText,
    regularHolidayPctText,
    setRegularHolidayPctText,
    specialHolidayDaysText,
    setSpecialHolidayDaysText,
    specialHolidayPctText,
    setSpecialHolidayPctText,
    incentivesText,
    setIncentivesText,
    sssText,
    setSssText,
    philhealthText,
    setPhilhealthText,
    pagibigText,
    setPagibigText,
    lateText,
    setLateText,
    absencesText,
    setAbsencesText,
    cashAdvanceText,
    setCashAdvanceText,
    others,
    addOther,
    removeOther,
    setOtherLabel,
    setOtherAmountText,
    days,
    setDay,
    inputs,
    computed,
    isValid,
    applyDefaults,
    snapshotDefaults,
  };
}
