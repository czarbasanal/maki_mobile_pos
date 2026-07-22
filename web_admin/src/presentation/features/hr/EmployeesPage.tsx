import { useEffect, useState } from 'react';
import { EyeIcon, EyeSlashIcon, PencilIcon, PlusIcon } from '@heroicons/react/24/outline';
import { useMutation } from '@tanstack/react-query';
import { useEmployeeRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from '@/presentation/hooks/useFirestoreSubscription';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type { Employee } from '@/domain/hr/types';
import type { EmployeeUpdateInput } from '@/domain/repositories/EmployeeRepository';
import { WEEKDAYS, weekdayLabel } from '@/domain/hr/weekdays';

// Blank -> NaN so a cleared/never-filled field fails the > 0 check instead of
// silently passing as 0 (Number('') === 0).
function parseDailyRate(raw: string): number {
  const trimmed = raw.trim();
  return trimmed === '' ? NaN : Number(trimmed);
}

export function EmployeesPage() {
  useEffect(() => {
    document.title = 'Employees · MAKI POS Admin';
  }, []);

  const repo = useEmployeeRepo();
  const {
    data: employees,
    isLoading,
    error,
  } = useFirestoreSubscription<Employee[]>(
    (onData, onError) => repo.watchAll(onData, { includeInactive: true }, onError),
    [repo],
  );

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Employee | null>(null);
  const [name, setName] = useState('');
  const [dailyRate, setDailyRate] = useState('');
  const [active, setActive] = useState(true);
  // '' = Default (use settings/hr.weekStartDay); '1'..'7' = an override.
  const [weekStartDay, setWeekStartDay] = useState('');

  const create = useMutation<
    Employee,
    Error,
    { name: string; dailyRate: number; weekStartDay: number | null }
  >({
    mutationFn: (input) => repo.create(input),
  });
  const update = useMutation<void, Error, { id: string } & EmployeeUpdateInput>({
    mutationFn: ({ id, ...patch }) => repo.update(id, patch),
  });
  const busy = create.isPending || update.isPending;

  const parsedRate = parseDailyRate(dailyRate);
  const rateIsValid = Number.isFinite(parsedRate) && parsedRate > 0;

  const openAdd = () => {
    create.reset();
    update.reset();
    setEditing(null);
    setName('');
    setDailyRate('');
    setActive(true);
    setWeekStartDay('');
    setDialogOpen(true);
  };
  const openEdit = (e: Employee) => {
    create.reset();
    update.reset();
    setEditing(e);
    setName(e.name);
    setDailyRate(String(e.dailyRate));
    setActive(e.isActive);
    setWeekStartDay(e.weekStartDay != null ? String(e.weekStartDay) : '');
    setDialogOpen(true);
  };
  const closeDialog = () => {
    setDialogOpen(false);
    create.reset();
    update.reset();
  };

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed || !rateIsValid) return;
    const weekStartDayValue = weekStartDay === '' ? null : Number(weekStartDay);
    try {
      if (editing) {
        await update.mutateAsync({
          id: editing.id,
          name: trimmed,
          dailyRate: parsedRate,
          isActive: active,
          weekStartDay: weekStartDayValue,
        });
      } else {
        await create.mutateAsync({ name: trimmed, dailyRate: parsedRate, weekStartDay: weekStartDayValue });
      }
      setDialogOpen(false);
    } catch {
      // Surfaced via create.error / update.error below; dialog stays open
      // with the entered data intact so the user can retry.
    }
  };

  const toggleActive = async (e: Employee) => {
    try {
      await update.mutateAsync({ id: e.id, isActive: !e.isActive });
    } catch {
      // Surfaced via update.error below.
    }
  };

  // While the dialog is open, an error came from Save (create or edit).
  // While it's closed, an update error can only be from the list's
  // toggle-active action.
  const dialogError = dialogOpen ? (editing ? update.error : create.error) : null;
  const listError = !dialogOpen ? update.error : null;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Employees</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Employees registered for payroll.
          </p>
        </div>
        <button
          type="button"
          onClick={openAdd}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add
        </button>
      </header>

      {listError ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {listError.message}
        </p>
      ) : null}

      {error ? (
        <ErrorView title="Could not load employees" message={error.message} />
      ) : isLoading || !employees ? (
        <LoadingView label="Loading…" />
      ) : employees.length === 0 ? (
        <EmptyState title="No employees yet" description="Add the first employee." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {employees.map((e) => (
              <li key={e.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                <div className="min-w-0">
                  <span
                    className={cn(
                      'block truncate text-bodySmall',
                      e.isActive ? 'text-light-text' : 'text-light-text-hint line-through',
                    )}
                  >
                    {e.name}
                    {e.isActive ? '' : ' (inactive)'}
                  </span>
                  <span className="mt-0.5 block truncate text-xs text-light-text-secondary">
                    <span>{formatMoney(e.dailyRate)}</span> / day
                    {e.weekStartDay != null ? ` · Week starts ${weekdayLabel(e.weekStartDay)}` : ''}
                  </span>
                </div>
                <span className="flex shrink-0 items-center gap-tk-xs">
                  <button
                    type="button"
                    onClick={() => openEdit(e)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    <PencilIcon className="h-3.5 w-3.5" /> Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => toggleActive(e)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    {e.isActive ? <EyeSlashIcon className="h-3.5 w-3.5" /> : <EyeIcon className="h-3.5 w-3.5" />}
                    {e.isActive ? 'Deactivate' : 'Reactivate'}
                  </button>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Dialog
        open={dialogOpen}
        onClose={() => {
          if (!busy) closeDialog();
        }}
        title={editing ? 'Edit employee' : 'Add employee'}
        dismissable={!busy}
      >
        <div className="space-y-tk-md">
          {dialogError ? (
            <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
              {dialogError.message}
            </p>
          ) : null}
          <div>
            <label htmlFor="employee-name" className="mb-tk-xs block text-bodySmall text-light-text-secondary">
              Name
            </label>
            <input
              id="employee-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
          <div>
            <label
              htmlFor="employee-daily-rate"
              className="mb-tk-xs block text-bodySmall text-light-text-secondary"
            >
              Daily rate
            </label>
            <input
              id="employee-daily-rate"
              type="number"
              step="0.01"
              min="0"
              value={dailyRate}
              onChange={(e) => setDailyRate(e.target.value)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
          <div>
            <label
              htmlFor="employee-week-start-day"
              className="mb-tk-xs block text-bodySmall text-light-text-secondary"
            >
              Week starts on
            </label>
            <select
              id="employee-week-start-day"
              value={weekStartDay}
              onChange={(e) => setWeekStartDay(e.target.value)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            >
              <option value="">Default</option>
              {WEEKDAYS.map((day) => (
                <option key={day.value} value={day.value}>
                  {day.label}
                </option>
              ))}
            </select>
          </div>
          {editing ? (
            <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
              <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
              Active
            </label>
          ) : null}
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button
              type="button"
              onClick={closeDialog}
              disabled={busy}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSave}
              disabled={busy || !name.trim() || !rateIsValid}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              {busy ? <Spinner className="h-3.5 w-3.5" /> : null} Save
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
