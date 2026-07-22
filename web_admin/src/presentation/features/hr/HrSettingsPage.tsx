// /hr/settings — week start day + holiday pay percentages used when
// computing payslips (computePayslip / payPeriod helpers). Loads the current
// settings (falling back to DEFAULT_HR_SETTINGS when the doc is unset) and
// saves edits back to settings/hr. Mirrors CostCodeSettingsPage's
// load→edit→save shape, minus the password gate (HR settings aren't
// sensitive the way cost-code letters are).

import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { CheckCircleIcon } from '@heroicons/react/24/outline';
import { useHrSettingsRepo } from '@/infrastructure/di/container';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import type { HrSettings } from '@/domain/hr/types';

const WEEKDAYS: { value: number; label: string }[] = [
  { value: 1, label: 'Monday' },
  { value: 2, label: 'Tuesday' },
  { value: 3, label: 'Wednesday' },
  { value: 4, label: 'Thursday' },
  { value: 5, label: 'Friday' },
  { value: 6, label: 'Saturday' },
  { value: 7, label: 'Sunday' },
];

interface EditedSettings {
  weekStartDay: number;
  regularHolidayPct: string;
  specialHolidayPct: string;
}

function toEditable(s: HrSettings): EditedSettings {
  return {
    weekStartDay: s.weekStartDay,
    regularHolidayPct: String(s.regularHolidayPct),
    specialHolidayPct: String(s.specialHolidayPct),
  };
}

// Blank/non-numeric -> NaN so a cleared field fails the >= 0 check instead of
// silently passing as 0 (Number('') === 0).
function parsePct(raw: string): number {
  const trimmed = raw.trim();
  return trimmed === '' ? NaN : Number(trimmed);
}

function pctError(value: number, label: string): string | null {
  if (!Number.isFinite(value) || value < 0) {
    return `${label} must be a number that is 0 or greater`;
  }
  return null;
}

export function HrSettingsPage() {
  useEffect(() => {
    document.title = 'HR Settings · MAKI POS Admin';
  }, []);

  const repo = useHrSettingsRepo();
  const queryClient = useQueryClient();
  const {
    data: settings,
    isLoading,
    error,
  } = useQuery({
    queryKey: ['hrSettings'],
    queryFn: () => repo.get(),
  });

  const [edited, setEdited] = useState<EditedSettings | null>(null);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    if (settings && !edited) setEdited(toEditable(settings));
  }, [settings, edited]);

  const save = useMutation<void, Error, HrSettings>({
    mutationFn: (next) => repo.save(next),
    onSuccess: (_data, next) => {
      queryClient.setQueryData(['hrSettings'], next);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 4000);
    },
  });

  if (error) {
    return <ErrorView title="Could not load HR settings" message={(error as Error).message} />;
  }
  if (isLoading || !edited) return <LoadingView label="Loading HR settings…" />;

  const regularHolidayPctValue = parsePct(edited.regularHolidayPct);
  const specialHolidayPctValue = parsePct(edited.specialHolidayPct);
  const regularHolidayError = pctError(regularHolidayPctValue, 'Regular holiday %');
  const specialHolidayError = pctError(specialHolidayPctValue, 'Special holiday %');
  const isValid = !regularHolidayError && !specialHolidayError;

  const onSave = () => {
    if (!isValid) return;
    setSaveSuccess(false);
    save.mutate({
      weekStartDay: edited.weekStartDay,
      regularHolidayPct: regularHolidayPctValue,
      specialHolidayPct: specialHolidayPctValue,
    });
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            HR Settings
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Week start day and holiday pay percentages used when computing payslips.
          </p>
        </div>
        <button
          type="button"
          onClick={onSave}
          disabled={!isValid || save.isPending}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
        >
          {save.isPending ? <Spinner className="h-3.5 w-3.5" /> : null}
          Save changes
        </button>
      </header>

      {saveSuccess ? (
        <div className="flex items-center gap-tk-sm rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          <CheckCircleIcon className="h-4 w-4 text-success" />
          HR settings saved.
        </div>
      ) : null}

      {save.error ? (
        <div className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {save.error.message}
        </div>
      ) : null}

      <section className="space-y-tk-sm">
        <div className="max-w-xs space-y-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <div>
            <label
              htmlFor="hr-week-start-day"
              className="mb-tk-xs block text-bodySmall text-light-text-secondary"
            >
              Week starts on
            </label>
            <select
              id="hr-week-start-day"
              value={edited.weekStartDay}
              onChange={(e) => setEdited({ ...edited, weekStartDay: Number(e.target.value) })}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            >
              {WEEKDAYS.map((day) => (
                <option key={day.value} value={day.value}>
                  {day.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label
              htmlFor="hr-regular-holiday-pct"
              className="mb-tk-xs block text-bodySmall text-light-text-secondary"
            >
              Regular holiday %
            </label>
            <input
              id="hr-regular-holiday-pct"
              type="number"
              step="1"
              min="0"
              value={edited.regularHolidayPct}
              onChange={(e) => setEdited({ ...edited, regularHolidayPct: e.target.value })}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
            {regularHolidayError ? (
              <p className="mt-tk-xs text-xs text-error">{regularHolidayError}</p>
            ) : null}
          </div>

          <div>
            <label
              htmlFor="hr-special-holiday-pct"
              className="mb-tk-xs block text-bodySmall text-light-text-secondary"
            >
              Special holiday %
            </label>
            <input
              id="hr-special-holiday-pct"
              type="number"
              step="1"
              min="0"
              value={edited.specialHolidayPct}
              onChange={(e) => setEdited({ ...edited, specialHolidayPct: e.target.value })}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
            {specialHolidayError ? (
              <p className="mt-tk-xs text-xs text-error">{specialHolidayError}</p>
            ) : null}
          </div>
        </div>
      </section>
    </div>
  );
}
