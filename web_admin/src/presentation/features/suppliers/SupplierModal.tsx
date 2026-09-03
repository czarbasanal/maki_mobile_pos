// Add/edit supplier — per design/maki-pos-edit-supplier-modal, built on the
// NEW shared Modal shell. One component, two modes: an empty draft titled
// "Add supplier" (no Deactivate, "Create supplier" primary), or a draft
// seeded from the record with a live subtitle ("12 parts sourced · last
// received Aug 12, 2026") so the form finally says who you're editing.
// Nothing mutates the directory until Save; a dirty draft confirms before a
// stray scrim click or Escape discards typed notes.
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useSupplierById } from '@/presentation/hooks/useSuppliers';
import {
  useCreateSupplier,
  useDeactivateSupplier,
  useUpdateSupplier,
} from '@/presentation/hooks/useSupplierMutations';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useReceivings } from '@/presentation/hooks/useReceivings';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { TransactionType, transactionTypeDisplayName } from '@/domain/enums';
import { formatInShopZone } from '@/domain/time/shopTime';
import { resolvePreset } from '@/domain/reports/dateRange';
import { cn } from '@/core/utils/cn';
import { Modal } from '@/presentation/components/ui/Modal';
import { toast } from '@/presentation/components/ui/toast';

interface Draft {
  name: string;
  address: string;
  contactPerson: string;
  email: string;
  contactNumber: string;
  alternativeNumber: string;
  transactionType: TransactionType;
  notes: string;
}

const EMPTY: Draft = {
  name: '',
  address: '',
  contactPerson: '',
  email: '',
  contactNumber: '',
  alternativeNumber: '',
  transactionType: TransactionType.cash,
  notes: '',
};

// Three fixed options don't warrant a dropdown (guide §3); a legacy value
// outside them (45/90 days, N/A) joins as a fourth chip so it stays visible.
const TERMS_CHIPS: TransactionType[] = [
  TransactionType.cash,
  TransactionType.terms30d,
  TransactionType.terms60d,
];

const blank = (v: string) => (v.trim() ? v.trim() : null);

function initialsOf(name: string): string {
  const parts = name.split(/\s+/).filter((w) => /[A-Za-z]/.test(w));
  if (parts.length === 0) return '+';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

export function SupplierModal() {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const isEditing = !!id;
  const { data: target, isLoading } = useSupplierById(id);

  const close = () => navigate(RoutePaths.suppliers);

  if (isEditing && (isLoading || !target)) {
    return (
      <Modal open onClose={close} title="Edit supplier">
        <LoadingView label="Loading supplier…" />
      </Modal>
    );
  }

  return <SupplierModalForm key={target?.id ?? 'new'} targetId={id ?? null} initial={
    target
      ? {
          name: target.name,
          address: target.address ?? '',
          contactPerson: target.contactPerson ?? '',
          email: target.email ?? '',
          contactNumber: target.contactNumber ?? '',
          alternativeNumber: target.alternativeNumber ?? '',
          transactionType: target.transactionType,
          notes: target.notes ?? '',
        }
      : EMPTY
  } targetActive={target?.isActive ?? false} />;
}

function SupplierModalForm({
  targetId,
  initial,
  targetActive,
}: {
  targetId: string | null;
  initial: Draft;
  targetActive: boolean;
}) {
  const navigate = useNavigate();
  const isEditing = targetId !== null;

  // Draft state is separate from the row — nothing mutates until Save.
  const [draft, setDraft] = useState<Draft>(initial);
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [confirmDiscard, setConfirmDiscard] = useState(false);
  const [confirmDeactivate, setConfirmDeactivate] = useState(false);

  const create = useCreateSupplier();
  const update = useUpdateSupplier();
  const deactivate = useDeactivateSupplier();
  const busy = create.isPending || update.isPending;

  // The live subtitle: what you actually buy from them.
  const { data: products } = useProducts();
  const receiptsRange = useMemo(
    () => ({ start: new Date(2020, 0, 1), end: resolvePreset('today').end }),
    [],
  );
  const { data: receivings } = useReceivings(receiptsRange);
  const subtitle = useMemo(() => {
    if (!isEditing) return 'A vendor you can tag on purchase orders and receipts.';
    const parts = (products ?? []).filter((p) => p.supplierId === targetId && p.isActive).length;
    let last: Date | null = null;
    for (const r of receivings ?? []) {
      if (r.status !== 'completed' || r.supplierId !== targetId) continue;
      const when = r.completedAt ?? r.createdAt;
      if (!last || when > last) last = when;
    }
    if (parts === 0 && !last) return 'No parts sourced yet';
    const partsText = `${parts} ${parts === 1 ? 'part' : 'parts'} sourced`;
    return last
      ? `${partsText} · last received ${formatInShopZone(last, { month: 'short', day: 'numeric', year: 'numeric' })}`
      : partsText;
  }, [isEditing, targetId, products, receivings]);

  const dirty = useMemo(
    () => (Object.keys(draft) as Array<keyof Draft>).some((k) => draft[k] !== initial[k]),
    [draft, initial],
  );
  const canSave = draft.name.trim() !== '' && !busy;

  const set = <K extends keyof Draft>(key: K, value: Draft[K]) => {
    setDraft((d) => ({ ...d, [key]: value }));
    if (key === 'name') setFieldError(null);
  };

  const close = () => navigate(RoutePaths.suppliers);
  const requestClose = () => {
    // Losing typed notes to a stray click is this modal's characteristic
    // failure — a dirty draft confirms first (guide §4).
    if (dirty && !busy) setConfirmDiscard(true);
    else if (!busy) close();
  };

  const save = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!canSave) return;
    const payload = {
      name: draft.name.trim(),
      address: blank(draft.address),
      contactPerson: blank(draft.contactPerson),
      contactNumber: blank(draft.contactNumber),
      alternativeNumber: blank(draft.alternativeNumber),
      email: blank(draft.email),
      transactionType: draft.transactionType,
      notes: blank(draft.notes),
    };
    try {
      if (isEditing) await update.mutateAsync({ id: targetId, ...payload });
      else await create.mutateAsync(payload);
      toast.success('Supplier saved', payload.name);
      close();
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Save failed';
      // A duplicate name surfaces on the field, not as a toast (guide §5).
      if (msg.toLowerCase().includes('already exists')) setFieldError(msg);
      else setFieldError(msg);
    }
  };

  const termsOptions = TERMS_CHIPS.includes(draft.transactionType)
    ? TERMS_CHIPS
    : [...TERMS_CHIPS, draft.transactionType];

  return (
    <>
      <Modal
        open
        onClose={requestClose}
        title={isEditing ? 'Edit supplier' : 'Add supplier'}
        subtitle={subtitle}
        icon={
          <div
            aria-hidden
            className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[10px] bg-accent-soft font-mono text-[12px] font-semibold text-accent-text"
          >
            {initialsOf(draft.name)}
          </div>
        }
        footer={
          <>
            {isEditing && targetActive ? (
              <button
                type="button"
                onClick={() => {
                  deactivate.reset();
                  setConfirmDeactivate(true);
                }}
                className="rounded-ctl px-tk-md py-tk-sm text-ctl-sm font-medium text-neg hover:bg-neg-soft"
              >
                Deactivate supplier
              </button>
            ) : null}
            <span className="ml-auto" />
            <button
              type="button"
              onClick={requestClose}
              disabled={busy}
              className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink-2 hover:bg-surface-2"
            >
              Cancel
            </button>
            <button
              type="submit"
              form="supplier-form"
              aria-disabled={!canSave || undefined}
              className={cn(
                'rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-sm font-semibold text-accent-ink hover:brightness-95',
                !canSave && 'cursor-default opacity-[.45]',
              )}
            >
              {busy ? 'Saving…' : isEditing ? 'Save changes' : 'Create supplier'}
            </button>
          </>
        }
      >
        <form id="supplier-form" onSubmit={save} noValidate className="flex flex-col gap-[18px]">
          <div className="grid grid-cols-[repeat(auto-fit,minmax(240px,1fr))] gap-3">
            <Field label="Name" error={fieldError ?? undefined}>
              <input
                data-autofocus
                type="text"
                value={draft.name}
                onChange={(e) => set('name', e.target.value)}
                className={inputCls(!!fieldError)}
              />
            </Field>
            <Field label="Address">
              <input
                type="text"
                value={draft.address}
                onChange={(e) => set('address', e.target.value)}
                className={inputCls(false)}
              />
            </Field>
          </div>

          <section className="flex flex-col gap-2.5">
            <SectionLabel>Contact</SectionLabel>
            <div className="grid grid-cols-[repeat(auto-fit,minmax(240px,1fr))] gap-3">
              <Field label="Contact person">
                <input
                  type="text"
                  value={draft.contactPerson}
                  onChange={(e) => set('contactPerson', e.target.value)}
                  className={inputCls(false)}
                />
              </Field>
              <Field label="Email">
                <input
                  type="email"
                  value={draft.email}
                  onChange={(e) => set('email', e.target.value)}
                  className={inputCls(false)}
                />
              </Field>
              <Field label="Contact number">
                <input
                  type="text"
                  inputMode="tel"
                  value={draft.contactNumber}
                  onChange={(e) => set('contactNumber', e.target.value)}
                  className={cn(inputCls(false), 'font-mono')}
                />
              </Field>
              <Field label="Alternative number">
                <input
                  type="text"
                  inputMode="tel"
                  value={draft.alternativeNumber}
                  onChange={(e) => set('alternativeNumber', e.target.value)}
                  className={cn(inputCls(false), 'font-mono')}
                />
              </Field>
            </div>
          </section>

          <section className="flex flex-col gap-2.5">
            <SectionLabel>Payment terms</SectionLabel>
            <div className="flex flex-wrap gap-2">
              {termsOptions.map((t) => (
                <button
                  key={t}
                  type="button"
                  aria-pressed={draft.transactionType === t}
                  onClick={() => set('transactionType', t)}
                  className={cn(
                    'rounded-ctl border px-[15px] py-2 text-ctl-sm font-medium',
                    draft.transactionType === t
                      ? 'border-accent-text bg-accent-soft text-accent-text'
                      : 'border-line bg-surface text-ink-2 hover:text-ink',
                  )}
                >
                  {transactionTypeDisplayName[t]}
                </button>
              ))}
            </div>
          </section>

          <section className="flex flex-col gap-2.5">
            <SectionLabel>Notes</SectionLabel>
            <textarea
              value={draft.notes}
              onChange={(e) => set('notes', e.target.value)}
              placeholder="Anything the next buyer should know — who to ask for, delivery habits, price quirks."
              className={cn(inputCls(false), 'min-h-[74px] resize-y leading-normal')}
            />
          </section>
        </form>
      </Modal>

      <Dialog
        open={confirmDiscard}
        onClose={() => setConfirmDiscard(false)}
        title="Discard changes?"
      >
        <p className="text-cell text-ink-2">Your edits haven’t been saved.</p>
        <div className="mt-tk-md flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setConfirmDiscard(false)}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            Keep editing
          </button>
          <button
            type="button"
            onClick={close}
            className="rounded-ctl bg-neg-soft px-tk-md py-tk-sm text-ctl-md font-medium text-neg hover:brightness-95"
          >
            Discard
          </button>
        </div>
      </Dialog>

      <Dialog
        open={confirmDeactivate}
        onClose={() => {
          if (!deactivate.isPending) setConfirmDeactivate(false);
        }}
        title="Deactivate supplier?"
        dismissable={!deactivate.isPending}
      >
        <p className="text-cell text-ink-2">
          <span className="font-medium text-ink">{draft.name}</span> disappears from pickers,
          but every past receipt and purchase order keeps referencing it.
        </p>
        {deactivate.error ? (
          <p className="mt-tk-sm text-ctl-sm text-neg">{deactivate.error.message}</p>
        ) : null}
        <div className="mt-tk-md flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setConfirmDeactivate(false)}
            disabled={deactivate.isPending}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={deactivate.isPending}
            onClick={async () => {
              if (!targetId) return;
              try {
                await deactivate.mutateAsync(targetId);
                close();
              } catch {
                // surfaced above
              }
            }}
            className="rounded-ctl bg-neg-soft px-tk-md py-tk-sm text-ctl-md font-medium text-neg hover:brightness-95 disabled:opacity-60"
          >
            {deactivate.isPending ? 'Deactivating…' : 'Deactivate'}
          </button>
        </div>
      </Dialog>
    </>
  );
}

function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-ctl border bg-surface-2 px-3 py-2.5 text-[13px] text-ink outline-none transition-colors placeholder:text-ink-3',
    hasError ? 'border-neg' : 'border-line focus:border-accent-line',
  );
}

function Field({
  label,
  error,
  children,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="flex flex-col gap-[6px]">
      <span className="text-[11.5px] font-semibold text-ink-2">{label}</span>
      {children}
      {error ? <span className="text-[11.5px] text-neg">{error}</span> : null}
    </label>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">
      {children}
    </span>
  );
}
