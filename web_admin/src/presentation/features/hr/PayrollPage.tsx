// /hr/payroll — the payslip generator. Pick an employee and a pay period,
// mark the week's attendance, fill in hours/OT/holiday/incentives/
// deductions, watch the live summary, then Generate Payslip freezes
// everything — including the holiday-pay settings percentages — into one
// immutable payslip snapshot and hands off to its detail page.

import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useNavigate } from 'react-router-dom';
import { useEmployeeRepo, useHrSettingsRepo, usePayslipRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from '@/presentation/hooks/useFirestoreSubscription';
import { useAuthStore } from '@/presentation/stores/authStore';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';
import { formatMoney } from '@/core/utils/money';
import { payPeriodFor, shiftPeriod, type PayPeriod } from '@/domain/hr/payPeriod';
import type { Employee, HrSettings } from '@/domain/hr/types';
import { usePayslipDraft } from './usePayslipDraft';
import { WeekGrid } from './WeekGrid';

function parseIsoLocal(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function periodLabel(period: PayPeriod): string {
  const start = parseIsoLocal(period.start).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  });
  const end = parseIsoLocal(period.end).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
  return `${start} – ${end}`;
}

export function PayrollPage() {
  useEffect(() => {
    document.title = 'Payroll · MAKI POS Admin';
  }, []);

  const employeeRepo = useEmployeeRepo();
  const hrSettingsRepo = useHrSettingsRepo();

  const {
    data: employees,
    isLoading: employeesLoading,
    error: employeesError,
  } = useFirestoreSubscription<Employee[]>((onData) => employeeRepo.watchAll(onData), [employeeRepo]);

  const {
    data: settings,
    isLoading: settingsLoading,
    error: settingsError,
  } = useQuery({ queryKey: ['hrSettings'], queryFn: () => hrSettingsRepo.get() });

  const error = employeesError ?? settingsError;
  if (error) {
    return <ErrorView title="Could not load payroll data" message={error.message} />;
  }
  if (employeesLoading || settingsLoading || !employees || !settings) {
    return <LoadingView label="Loading payroll…" />;
  }

  return <PayrollForm employees={employees} settings={settings} />;
}

function PayrollForm({ employees, settings }: { employees: Employee[]; settings: HrSettings }) {
  const payslipRepo = usePayslipRepo();
  const actor = useAuthStore((s) => s.user);
  const navigate = useNavigate();

  // Settings seed the period's week-start-day exactly once, at mount — this
  // component only exists once settings have loaded (see PayrollPage above).
  const [period, setPeriod] = useState<PayPeriod>(() => payPeriodFor(new Date(), settings.weekStartDay));
  const [employeeId, setEmployeeId] = useState('');
  const employee = employees.find((e) => e.id === employeeId) ?? null;

  const draft = usePayslipDraft(period, {
    regularHolidayPct: settings.regularHolidayPct,
    specialHolidayPct: settings.specialHolidayPct,
  });

  const onEmployeeChange = (id: string) => {
    setEmployeeId(id);
    const picked = employees.find((e) => e.id === id);
    if (picked) draft.setDailyRateText(String(picked.dailyRate));
  };

  const generate = useMutation<string, Error, void>({
    mutationFn: async () => {
      if (!actor) throw new Error('Not signed in');
      if (!employee) throw new Error('Select an employee');
      return payslipRepo.create({
        employeeId: employee.id,
        employeeName: employee.name,
        periodStart: period.start,
        periodEnd: period.end,
        days: draft.days,
        inputs: draft.inputs,
        computed: draft.computed,
        createdBy: actor.id,
        createdByName: actor.displayName.trim() || actor.email,
      });
    },
    onSuccess: (id) => navigate(`${RoutePaths.hrPayslips}/${id}`),
  });

  const canGenerate = !!employee && draft.isValid && !generate.isPending;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Payroll</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Generate a payslip for one employee&apos;s pay period.
        </p>
      </header>

      {generate.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {generate.error.message}
        </p>
      ) : null}

      <section className="grid gap-tk-md sm:grid-cols-2">
        <div>
          <label
            htmlFor="payroll-employee"
            className="mb-tk-xs block text-bodySmall text-light-text-secondary"
          >
            Employee
          </label>
          <select
            id="payroll-employee"
            value={employeeId}
            onChange={(e) => onEmployeeChange(e.target.value)}
            className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
          >
            <option value="">Select employee…</option>
            {employees.map((e) => (
              <option key={e.id} value={e.id}>
                {e.name}
              </option>
            ))}
          </select>
        </div>

        <div>
          <span className="mb-tk-xs block text-bodySmall text-light-text-secondary">Pay period</span>
          <div className="flex items-center gap-tk-sm">
            <button
              type="button"
              onClick={() => setPeriod((p) => shiftPeriod(p, -1))}
              aria-label="Previous week"
              className="rounded-md border border-light-border px-tk-sm py-[6px] text-bodySmall text-light-text-secondary hover:bg-light-subtle"
            >
              ‹
            </button>
            <span className="min-w-[10rem] text-center text-bodySmall font-medium text-light-text">
              {periodLabel(period)}
            </span>
            <button
              type="button"
              onClick={() => setPeriod((p) => shiftPeriod(p, 1))}
              aria-label="Next week"
              className="rounded-md border border-light-border px-tk-sm py-[6px] text-bodySmall text-light-text-secondary hover:bg-light-subtle"
            >
              ›
            </button>
          </div>
        </div>
      </section>

      <section className="space-y-tk-sm">
        <h2 className="text-bodySmall font-semibold text-light-text">Days worked</h2>
        <WeekGrid days={draft.days} setDay={draft.setDay} />
      </section>

      <section className="grid gap-tk-md sm:grid-cols-2">
        <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <h2 className="text-bodySmall font-semibold text-light-text">Hours &amp; pay</h2>
          <NumberField label="Hours worked" value={draft.hoursWorkedText} onChange={draft.setHoursWorkedText} />
          <NumberField label="Daily rate" value={draft.dailyRateText} onChange={draft.setDailyRateText} />
          <NumberField
            label="Overtime hours"
            value={draft.overtimeHoursText}
            onChange={draft.setOvertimeHoursText}
          />
          <NumberField
            label="Overtime rate / hour"
            value={draft.overtimeRatePerHourText}
            onChange={draft.setOvertimeRatePerHourText}
          />
          <NumberField
            label="Regular holiday days"
            value={draft.regularHolidayDaysText}
            onChange={draft.setRegularHolidayDaysText}
          />
          <NumberField
            label="Regular holiday %"
            value={draft.regularHolidayPctText}
            onChange={draft.setRegularHolidayPctText}
          />
          <NumberField
            label="Special holiday days"
            value={draft.specialHolidayDaysText}
            onChange={draft.setSpecialHolidayDaysText}
          />
          <NumberField
            label="Special holiday %"
            value={draft.specialHolidayPctText}
            onChange={draft.setSpecialHolidayPctText}
          />
          <NumberField label="Incentives" value={draft.incentivesText} onChange={draft.setIncentivesText} />
        </div>

        <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <h2 className="text-bodySmall font-semibold text-light-text">Deductions</h2>
          <NumberField label="SSS" value={draft.sssText} onChange={draft.setSssText} />
          <NumberField label="PhilHealth" value={draft.philhealthText} onChange={draft.setPhilhealthText} />
          <NumberField label="Pag-IBIG" value={draft.pagibigText} onChange={draft.setPagibigText} />
          <NumberField label="Late" value={draft.lateText} onChange={draft.setLateText} />
          <NumberField label="Absences" value={draft.absencesText} onChange={draft.setAbsencesText} />
          <NumberField
            label="Cash advance"
            value={draft.cashAdvanceText}
            onChange={draft.setCashAdvanceText}
          />

          <div className="space-y-tk-xs pt-tk-xs">
            <div className="flex items-center justify-between">
              <span className="text-bodySmall text-light-text-secondary">Other deductions</span>
              <button
                type="button"
                onClick={draft.addOther}
                className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] text-light-text-secondary hover:bg-light-subtle"
              >
                <PlusIcon className="h-3.5 w-3.5" /> Add
              </button>
            </div>
            {draft.others.map((o) => (
              <div key={o.id} className="flex items-center gap-tk-sm">
                <input
                  type="text"
                  value={o.label}
                  onChange={(e) => draft.setOtherLabel(o.id, e.target.value)}
                  placeholder="Label"
                  aria-label="Other deduction label"
                  className="min-w-0 flex-1 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
                />
                <input
                  type="number"
                  min={0}
                  step="0.01"
                  inputMode="decimal"
                  value={o.amountText}
                  onChange={(e) => draft.setOtherAmountText(o.id, e.target.value)}
                  placeholder="Amount"
                  aria-label="Other deduction amount"
                  className="w-24 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
                />
                <button
                  type="button"
                  onClick={() => draft.removeOther(o.id)}
                  aria-label="Remove other deduction"
                  className="text-light-text-hint hover:text-error"
                >
                  <TrashIcon className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="space-y-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-md">
        <h2 className="text-bodySmall font-semibold text-light-text">Summary</h2>
        <SummaryRow label="Base pay" value={draft.computed.basePay} />
        <SummaryRow label="Overtime pay" value={draft.computed.overtimePay} />
        <SummaryRow label="Holiday pay" value={draft.computed.holidayPay} />
        <SummaryRow label="Incentives" value={draft.inputs.incentives} />
        <SummaryRow label="Gross" value={draft.computed.gross} emphasize />
        <SummaryRow label="Total deductions" value={draft.computed.totalDeductions} />
        <SummaryRow label="Net pay" value={draft.computed.net} emphasize />
      </section>

      <button
        type="button"
        disabled={!canGenerate}
        onClick={() => generate.mutate()}
        className={cn(
          'w-full rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark sm:w-auto',
          !canGenerate && 'cursor-not-allowed opacity-60',
        )}
      >
        {generate.isPending ? <Spinner className="mr-tk-xs inline h-3.5 w-3.5" /> : null}
        Generate Payslip
      </button>
    </div>
  );
}

function NumberField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall text-light-text-secondary">{label}</span>
      <input
        type="number"
        step="0.01"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[6px] text-bodySmall text-light-text outline-none focus:border-light-text"
      />
    </label>
  );
}

function SummaryRow({ label, value, emphasize }: { label: string; value: number; emphasize?: boolean }) {
  return (
    <div className="flex justify-between text-bodySmall">
      <span className={emphasize ? 'font-semibold text-light-text' : 'text-light-text-hint'}>{label}</span>
      <span className={emphasize ? 'font-semibold text-light-text' : 'text-light-text'}>
        {formatMoney(value)}
      </span>
    </div>
  );
}
