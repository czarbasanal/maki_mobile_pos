// /admin/settings/cost-codes — view and edit the cost-code mapping.
//
// Saves are gated on a fresh password verification (mirrors
// PasswordDialog.show in the Flutter cost_code_settings_screen). Validation
// requires unique single-character letters for each digit and non-empty
// special codes for 00 / 000.

import { useEffect, useMemo, useState } from 'react';
import {
  ArrowPathIcon,
  ArrowRightIcon,
  CheckCircleIcon,
  PencilSquareIcon,
} from '@heroicons/react/24/outline';
import {
  costCodeEqualsMapping,
  defaultCostCode,
  encodeCostCode,
  type CostCode,
} from '@/domain/entities';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useUpdateCostCode } from '@/presentation/hooks/useUpdateCostCode';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { PageHeader } from './PageHeader';

type EditedMapping = Omit<CostCode, 'updatedAt' | 'updatedBy'>;

function toEditable(cc: CostCode): EditedMapping {
  return {
    digitToLetter: { ...cc.digitToLetter },
    doubleZeroCode: cc.doubleZeroCode,
    tripleZeroCode: cc.tripleZeroCode,
  };
}

function validate(m: EditedMapping): string | null {
  const letters = new Set<string>();
  for (let i = 0; i < 10; i += 1) {
    const d = String(i);
    const letter = m.digitToLetter[d];
    if (!letter) return `Letter for digit ${d} cannot be empty`;
    if (letter.length !== 1) return `Letter for digit ${d} must be one character`;
    if (letters.has(letter)) return `Each digit must map to a unique letter (${letter} repeats)`;
    letters.add(letter);
  }
  if (!m.doubleZeroCode) return 'Double-zero code cannot be empty';
  if (!m.tripleZeroCode) return 'Triple-zero code cannot be empty';
  return null;
}

export function CostCodeSettingsPage() {
  const { data: mapping, isLoading, error } = useCostCode();
  const update = useUpdateCostCode();

  const [editing, setEditing] = useState(false);
  const [edited, setEdited] = useState<EditedMapping | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [confirmOpen, setConfirmOpen] = useState<null | 'save' | 'reset'>(null);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    document.title = 'Cost codes · MAKI POS Admin';
  }, []);

  if (error) return <ErrorView title="Could not load cost codes" message={error.message} />;
  if (isLoading || !mapping) return <LoadingView label="Loading cost codes…" />;

  const display: EditedMapping = edited ?? toEditable(mapping);

  const startEditing = () => {
    setEdited(toEditable(mapping));
    setEditing(true);
    setValidationError(null);
    setSaveSuccess(false);
  };

  const cancelEditing = () => {
    setEditing(false);
    setEdited(null);
    setValidationError(null);
    update.reset();
  };

  const startSave = () => {
    if (!edited) return;
    const err = validate(edited);
    if (err) {
      setValidationError(err);
      return;
    }
    setValidationError(null);
    setConfirmOpen('save');
  };

  const startReset = () => {
    if (costCodeEqualsMapping(mapping, defaultCostCode)) {
      setValidationError('Already using the default mapping');
      return;
    }
    setValidationError(null);
    setConfirmOpen('reset');
  };

  const onConfirmed = async (mode: 'save' | 'reset', password: string) => {
    const target: EditedMapping =
      mode === 'reset'
        ? toEditable(defaultCostCode)
        : (edited ?? toEditable(mapping));
    await update.mutateAsync({ mapping: target, password });
    setEditing(false);
    setEdited(null);
    setConfirmOpen(null);
    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 4000);
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <div className="flex flex-wrap items-end justify-between gap-tk-md">
        <PageHeader
          title="Cost codes"
          description="Encode product costs as letters so they're hidden from non-admins."
        />
        <div className="flex gap-tk-sm">
          {editing ? (
            <>
              <button
                type="button"
                onClick={cancelEditing}
                disabled={update.isPending}
                className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={startSave}
                disabled={update.isPending}
                className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
              >
                Save changes
              </button>
            </>
          ) : (
            <>
              <button
                type="button"
                onClick={startReset}
                className="flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
              >
                <ArrowPathIcon className="h-3.5 w-3.5" />
                Reset to default
              </button>
              <button
                type="button"
                onClick={startEditing}
                className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
              >
                <PencilSquareIcon className="h-3.5 w-3.5" />
                Edit mapping
              </button>
            </>
          )}
        </div>
      </div>

      {saveSuccess ? (
        <div className="flex items-center gap-tk-sm rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          <CheckCircleIcon className="h-4 w-4 text-success" />
          Cost code mapping saved.
        </div>
      ) : null}

      {validationError ? (
        <div className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {validationError}
        </div>
      ) : null}

      <section className="space-y-tk-sm">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
          Digit → letter mapping
        </h2>
        <div className="rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <div className="grid grid-cols-2 gap-x-tk-md gap-y-tk-sm sm:grid-cols-5">
            {Array.from({ length: 10 }, (_, i) => String(i)).map((digit) => (
              <MappingCell
                key={digit}
                digit={digit}
                letter={display.digitToLetter[digit] ?? ''}
                editing={editing}
                onChange={(letter) => {
                  if (!edited) return;
                  setEdited({
                    ...edited,
                    digitToLetter: { ...edited.digitToLetter, [digit]: letter },
                  });
                }}
              />
            ))}
          </div>
        </div>
      </section>

      <section className="space-y-tk-sm">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
          Special codes
        </h2>
        <div className="rounded-lg border border-light-hairline bg-light-card p-tk-md space-y-tk-sm">
          <SpecialCodeRow
            digits="00"
            label="Double zero"
            code={display.doubleZeroCode}
            editing={editing}
            onChange={(v) => edited && setEdited({ ...edited, doubleZeroCode: v })}
          />
          <SpecialCodeRow
            digits="000"
            label="Triple zero"
            code={display.tripleZeroCode}
            editing={editing}
            onChange={(v) => edited && setEdited({ ...edited, tripleZeroCode: v })}
          />
        </div>
      </section>

      <TestSection mapping={display} />

      <PasswordConfirmDialog
        open={confirmOpen !== null}
        title={confirmOpen === 'reset' ? 'Reset to default' : 'Save cost code changes'}
        description={
          confirmOpen === 'reset'
            ? 'Enter your password to reset the mapping to the original values.'
            : 'Enter your password to save these changes.'
        }
        error={update.error?.message}
        pending={update.isPending}
        onClose={() => {
          if (update.isPending) return;
          setConfirmOpen(null);
          update.reset();
        }}
        onConfirm={(password) => {
          if (!confirmOpen) return;
          void onConfirmed(confirmOpen, password);
        }}
      />
    </div>
  );
}

function MappingCell({
  digit,
  letter,
  editing,
  onChange,
}: {
  digit: string;
  letter: string;
  editing: boolean;
  onChange: (letter: string) => void;
}) {
  return (
    <div className="flex items-center gap-tk-sm">
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-md bg-light-subtle font-mono text-bodyMedium font-semibold text-light-text">
        {digit}
      </span>
      <ArrowRightIcon className="h-3.5 w-3.5 shrink-0 text-light-text-hint" />
      {editing ? (
        <input
          type="text"
          value={letter}
          maxLength={1}
          onChange={(e) => onChange(e.target.value.toUpperCase())}
          className="h-9 w-12 rounded-md border border-light-border bg-light-card text-center font-mono text-bodyMedium font-semibold uppercase outline-none focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0"
        />
      ) : (
        <span className="grid h-9 w-12 place-items-center rounded-md border border-light-hairline bg-light-card font-mono text-bodyMedium font-semibold text-light-text">
          {letter || '—'}
        </span>
      )}
    </div>
  );
}

function SpecialCodeRow({
  digits,
  label,
  code,
  editing,
  onChange,
}: {
  digits: string;
  label: string;
  code: string;
  editing: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <div className="flex items-center gap-tk-md">
      <span className="font-mono text-bodyMedium font-semibold text-light-text-secondary">
        {digits}
      </span>
      <ArrowRightIcon className="h-3.5 w-3.5 shrink-0 text-light-text-hint" />
      {editing ? (
        <input
          type="text"
          value={code}
          maxLength={4}
          onChange={(e) => onChange(e.target.value.toUpperCase())}
          className="h-9 w-24 rounded-md border border-light-border bg-light-card px-tk-sm font-mono text-bodyMedium font-semibold uppercase outline-none focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0"
        />
      ) : (
        <span className="grid h-9 min-w-[6rem] place-items-center rounded-md border border-light-hairline bg-light-card px-tk-sm font-mono text-bodyMedium font-semibold text-light-text">
          {code}
        </span>
      )}
      <span className="ml-auto text-bodySmall text-light-text-hint">{label}</span>
    </div>
  );
}

function TestSection({ mapping }: { mapping: EditedMapping }) {
  const samples = useMemo(() => [99, 125, 500, 1000, 1234, 10000], []);
  const cc: CostCode = { ...mapping, updatedAt: null, updatedBy: null };
  return (
    <section className="space-y-tk-sm">
      <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
        Encoding preview
      </h2>
      <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card divide-y divide-light-hairline">
        {samples.map((amount) => (
          <div key={amount} className="flex items-center gap-tk-md px-tk-md py-tk-sm">
            <span className="w-24 font-mono text-bodySmall text-light-text-secondary">
              {formatMoney(amount)}
            </span>
            <ArrowRightIcon className="h-3.5 w-3.5 text-light-text-hint" />
            <span className="font-mono text-bodyMedium font-semibold text-light-text">
              {encodeCostCode(cc, amount)}
            </span>
          </div>
        ))}
      </div>
    </section>
  );
}

function PasswordConfirmDialog({
  open,
  title,
  description,
  error,
  pending,
  onClose,
  onConfirm,
}: {
  open: boolean;
  title: string;
  description: string;
  error?: string;
  pending: boolean;
  onClose: () => void;
  onConfirm: (password: string) => void;
}) {
  const [password, setPassword] = useState('');
  useEffect(() => {
    if (!open) setPassword('');
  }, [open]);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
      description={description}
      dismissable={!pending}
    >
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!password) return;
          onConfirm(password);
        }}
        className="space-y-tk-md"
      >
        <label className="block space-y-tk-xs">
          <span className="text-bodySmall font-medium text-light-text">Password</span>
          <input
            type="password"
            autoComplete="current-password"
            autoFocus
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className={cn(
              'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
              'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
              error ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
            )}
          />
        </label>
        {error ? <p className="text-bodySmall text-error">{error}</p> : null}
        <div className="flex justify-end gap-tk-sm pt-tk-sm">
          <button
            type="button"
            onClick={onClose}
            disabled={pending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={pending || !password}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
          >
            {pending ? <Spinner className="h-3.5 w-3.5" /> : null}
            {pending ? 'Confirming…' : 'Confirm'}
          </button>
        </div>
      </form>
    </Dialog>
  );
}
