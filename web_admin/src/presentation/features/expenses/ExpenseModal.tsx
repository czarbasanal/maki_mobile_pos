// Add/edit expense — per design/maki-pos-expenses-redesign §4. One component,
// two modes, rendered OVER the list via the /expenses route's Outlet (exactly
// like ProductModal/SupplierModal). Category and Paid via are chips, not
// selects — six-ish fixed-ish options don't warrant a dropdown.
//
// Controller-ruled deviations from the guide (see the brief):
//  - Hard delete (no deletedAt) — the shop confirmed this; Activity Logs
//    keeps the trail.
//  - Amounts stay pesos-as-number (no centavos).
//  - No EXP-#### id in the subtitle — edit mode reads CATEGORY · spentOn date.
//  - No updatedVia — Record history shows createdByName/createdAt and
//    updatedByName/updatedAt only.
//  - The date field is a native <input type="date"> (yyyy-MM-dd), matching
//    the schema's existing pattern — the guide's own reference does the same.
//  - Receipt upload IS kept (the guide's "not built" note doesn't apply to
//    this repo) — ported from the old ExpenseFormPage, restyled to tokens.
import { useEffect, useMemo, useState, type ChangeEvent, type FormEvent, type ReactNode } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { format } from 'date-fns';
import { useExpense, useCreateExpense, useDeleteExpense, useUpdateExpense } from '@/presentation/hooks/useExpenses';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { useExpenseRepo } from '@/infrastructure/di/container';
import { deleteExpenseReceipt, uploadExpenseReceipt } from '@/data/expenseReceiptStorage';
import { PaymentMethod, paymentMethodDisplayName } from '@/domain/enums';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { formatInShopZone, formatShopDateTime } from '@/domain/time/shopTime';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Modal } from '@/presentation/components/ui/Modal';
import { toast } from '@/presentation/components/ui/toast';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';
import type { Expense } from '@/domain/entities';

interface Draft {
  description: string;
  amount: string;
  category: string;
  paidVia: PaymentMethod;
  date: string;
  notes: string;
}

const blank = (s: string) => (s.trim() ? s.trim() : null);
const todayStr = () => format(new Date(), 'yyyy-MM-dd');

const EMPTY: Draft = {
  description: '',
  amount: '',
  category: '',
  paidVia: PaymentMethod.cash,
  date: todayStr(),
  notes: '',
};

function withCurrent(names: string[], current: string | null): string[] {
  if (current && !names.includes(current)) return [current, ...names];
  return names;
}

export function ExpenseModal() {
  const { id } = useParams<{ id: string }>();
  const isEditing = !!id;
  const navigate = useNavigate();
  const close = () => navigate(RoutePaths.expenses);

  const { data: target, isLoading, error } = useExpense(id);

  if (isEditing && error) {
    return (
      <Modal open onClose={close} title="Edit expense" widthClassName="max-w-[520px]">
        <ErrorView title="Could not load expense" message={error.message} />
      </Modal>
    );
  }
  if (isEditing && (isLoading || !target)) {
    return (
      <Modal open onClose={close} title="Edit expense" widthClassName="max-w-[520px]">
        <div className="flex items-center justify-center py-10">
          <Spinner className="h-5 w-5" />
        </div>
      </Modal>
    );
  }

  return <ExpenseModalForm key={target?.id ?? 'new'} target={target ?? null} />;
}

function ExpenseModalForm({ target }: { target: Expense | null }) {
  const navigate = useNavigate();
  const isEditing = target !== null;
  const close = () => navigate(RoutePaths.expenses);

  const authUser = useAuthStore((s) => s.user);
  const actorName = authUser ? authUser.displayName.trim() || authUser.email : '';
  const canDelete = isEditing && !!authUser && hasPermission(authUser.role, Permission.deleteExpense);

  const repo = useExpenseRepo();
  const { data: expenseCats } = useActiveCategories(CategoryKind.expense);
  const create = useCreateExpense();
  const update = useUpdateExpense();
  const del = useDeleteExpense();

  const [draft, setDraft] = useState<Draft>(
    target
      ? {
          description: target.description,
          amount: String(target.amount),
          category: target.category,
          paidVia: target.paidVia,
          date: format(target.date, 'yyyy-MM-dd'),
          notes: target.notes ?? '',
        }
      : EMPTY,
  );
  const [receiptBlob, setReceiptBlob] = useState<Blob | null>(null);
  const [receiptPreview, setReceiptPreview] = useState<string | null>(null);
  const [receiptRemoved, setReceiptRemoved] = useState(false);
  const [loadNotice, setLoadNotice] = useState<string | null>(null);
  const [deleteOpen, setDeleteOpen] = useState(false);

  useEffect(() => {
    document.title = isEditing ? 'Edit expense · Expenses' : 'New expense · Expenses';
  }, [isEditing]);

  useEffect(() => {
    return () => {
      if (receiptPreview) URL.revokeObjectURL(receiptPreview);
    };
  }, [receiptPreview]);

  const categoryOptions = useMemo(
    () => withCurrent((expenseCats ?? []).map((c) => c.name), target?.category ?? null),
    [expenseCats, target?.category],
  );

  // Add mode only: default to the first available category once the list
  // loads, so a fresh draft doesn't sit with no chip selected — the guide's
  // reference opens on the first category too. Never overrides a value the
  // user (or the edit-mode prefill) already set.
  useEffect(() => {
    if (!isEditing && !draft.category && categoryOptions.length > 0) {
      setDraft((d) => (d.category ? d : { ...d, category: categoryOptions[0] }));
    }
  }, [isEditing, categoryOptions, draft.category]);

  const onPickFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setReceiptBlob(file);
    setReceiptPreview(URL.createObjectURL(file));
    setReceiptRemoved(false);
  };
  const removeReceipt = () => {
    setReceiptBlob(null);
    setReceiptPreview(null);
    setReceiptRemoved(true);
  };
  const shownReceipt = receiptPreview ?? (!receiptRemoved ? target?.receiptImageUrl ?? null : null);

  const submitting = create.isPending || update.isPending;
  const busy = submitting || del.isPending;
  const mutationError = create.error?.message ?? update.error?.message ?? null;

  const parsedAmount = Number(draft.amount);
  const canSave = !busy && draft.description.trim() !== '' && Number.isFinite(parsedAmount) && parsedAmount > 0;

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!canSave) return;
    setLoadNotice(null);
    const parsedDate = new Date(`${draft.date}T00:00:00`);
    const description = draft.description.trim();

    try {
      if (isEditing && target) {
        let uploadedUrl: string | undefined;
        if (receiptBlob) {
          try {
            uploadedUrl = await uploadExpenseReceipt(target.id, receiptBlob);
          } catch {
            setLoadNotice('Receipt upload failed — expense saved without the new receipt.');
          }
        }
        const patch = {
          description,
          amount: parsedAmount,
          category: draft.category.trim(),
          paidVia: draft.paidVia,
          date: parsedDate,
          notes: blank(draft.notes),
          ...(receiptBlob ? (uploadedUrl ? { receiptImageUrl: uploadedUrl } : {}) : receiptRemoved ? { receiptImageUrl: null } : {}),
        };
        await update.mutateAsync({ id: target.id, patch });
        if (!receiptBlob && receiptRemoved) {
          try {
            await deleteExpenseReceipt(target.id);
          } catch {
            // best-effort — an orphaned Storage object is harmless.
          }
        }
        toast.success('Expense updated', description);
        close();
        return;
      }

      // Create — the receipt uploads BEFORE the document is created: a
      // preset id lets it land in one write with no URL-fixup update racing
      // behind it (see ExpenseRepository.newExpenseId).
      let presetId: string | undefined;
      let receiptImageUrl: string | null = null;
      if (receiptBlob) {
        presetId = repo.newExpenseId();
        try {
          receiptImageUrl = await uploadExpenseReceipt(presetId, receiptBlob);
        } catch {
          setLoadNotice('Receipt upload failed — expense saved without a receipt.');
          presetId = undefined;
        }
      }
      await create.mutateAsync({
        id: presetId,
        description,
        amount: parsedAmount,
        category: draft.category.trim(),
        paidVia: draft.paidVia,
        date: parsedDate,
        notes: blank(draft.notes),
        receiptNumber: null,
        receiptImageUrl,
      });
      toast.success('Expense recorded', description);
      close();
    } catch {
      // Surfaced via mutationError above.
    }
  };

  const confirmDelete = async () => {
    if (!target) return;
    try {
      await del.mutateAsync({
        id: target.id,
        description: target.description,
        category: target.category,
        amount: target.amount,
      });
      if (target.receiptImageUrl) {
        try {
          await deleteExpenseReceipt(target.id);
        } catch {
          // best-effort — an orphaned Storage object is harmless.
        }
      }
      toast.success('Expense deleted', target.description);
      setDeleteOpen(false);
      close();
    } catch {
      // Surfaced via del.error below; confirm dialog stays open.
    }
  };

  const subtitle =
    isEditing && target
      ? `${target.category.toUpperCase()} · ${formatInShopZone(target.date, { month: 'short', day: 'numeric', year: 'numeric' })}`
      : 'Money leaving the shop';
  const footNote = isEditing
    ? 'Saving records you as the last editor'
    : `Recorded against ${actorName || 'you'} · today`;

  return (
    <>
      <Modal
        open
        onClose={close}
        title={isEditing ? 'Edit expense' : 'New expense'}
        subtitle={subtitle}
        widthClassName="max-w-[520px]"
        initialFocus={isEditing ? 'none' : 'first-input'}
        footer={
          <>
            <span className="text-[11px] text-ink-3">{footNote}</span>
            <span className="ml-auto" />
            <button
              type="button"
              onClick={close}
              disabled={busy}
              className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink-2 hover:bg-surface-2"
            >
              Cancel
            </button>
            <button
              type="submit"
              form="expense-form"
              aria-disabled={!canSave || undefined}
              className={cn(
                'inline-flex items-center gap-tk-xs rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-sm font-semibold text-accent-ink hover:brightness-95',
                !canSave && 'cursor-default opacity-[.45]',
              )}
            >
              {submitting ? <Spinner className="h-3.5 w-3.5" /> : null}
              {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Add expense'}
            </button>
          </>
        }
      >
        {mutationError ? (
          <p className="rounded-ctl border border-neg bg-neg-soft px-tk-md py-tk-sm text-ctl-sm text-neg">{mutationError}</p>
        ) : null}
        {loadNotice ? (
          <p className="rounded-ctl border border-accent-line bg-accent-soft px-tk-md py-tk-sm text-ctl-sm text-accent-text">
            {loadNotice}
          </p>
        ) : null}

        <form id="expense-form" onSubmit={onSubmit} noValidate className="flex flex-col gap-[16px]">
          <Field label="Description">
            <input
              data-autofocus
              type="text"
              value={draft.description}
              onChange={(e) => setDraft((d) => ({ ...d, description: e.target.value }))}
              placeholder="What was bought or paid for"
              className={inputCls(false)}
            />
          </Field>

          <div className="grid grid-cols-[repeat(auto-fit,minmax(150px,1fr))] gap-3">
            <Field label="Amount" group>
              <div className={cn(controlH, 'flex items-center gap-1.5 rounded-ctl border border-line bg-surface-2 px-3')}>
                <span className="text-[12.5px] text-ink-3">₱</span>
                <input
                  type="number"
                  step="0.01"
                  aria-label="Amount"
                  value={draft.amount}
                  onChange={(e) => setDraft((d) => ({ ...d, amount: e.target.value }))}
                  placeholder="0.00"
                  className="w-full bg-transparent text-right font-mono text-[13px] font-semibold text-ink outline-none"
                />
              </div>
            </Field>
            <Field label="Date">
              <input
                type="date"
                value={draft.date}
                onChange={(e) => setDraft((d) => ({ ...d, date: e.target.value }))}
                className={cn(inputCls(false), 'font-mono')}
              />
            </Field>
          </div>

          <Field label="Category" group>
            <div className="flex flex-wrap gap-1.5">
              {categoryOptions.map((c) => {
                const active = draft.category === c;
                return (
                  <button
                    key={c}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setDraft((d) => ({ ...d, category: c }))}
                    className={cn(
                      'rounded-ctl border px-3 py-[7px] text-ctl-sm font-medium',
                      active ? 'border-accent-text bg-accent-soft text-accent-text' : 'border-line bg-surface text-ink-2 hover:text-ink',
                    )}
                  >
                    {c}
                  </button>
                );
              })}
            </div>
          </Field>

          <Field label="Paid via" group>
            <div className="grid grid-cols-[repeat(auto-fit,minmax(88px,1fr))] gap-1.5">
              {Object.values(PaymentMethod).map((m) => {
                const active = draft.paidVia === m;
                return (
                  <button
                    key={m}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setDraft((d) => ({ ...d, paidVia: m }))}
                    className={cn(
                      'rounded-ctl border px-2 py-[9px] text-center text-ctl-sm font-medium',
                      active ? 'border-accent-text bg-accent-soft text-accent-text' : 'border-line bg-surface text-ink-2 hover:text-ink',
                    )}
                  >
                    {paymentMethodDisplayName[m]}
                  </button>
                );
              })}
            </div>
          </Field>

          <Field label="Note (optional)">
            <textarea
              rows={3}
              value={draft.notes}
              onChange={(e) => setDraft((d) => ({ ...d, notes: e.target.value }))}
              placeholder="Reference number, who was paid, anything the next person should know"
              className={cn(inputCls(false), 'resize-y leading-relaxed')}
            />
          </Field>

          <div className="flex flex-col gap-[7px]">
            {/* A second, sibling <label htmlFor> (not a wrapping label) so the
               Upload/Replace trigger's own text doesn't merge into this
               label's accessible name (nested labels concatenate their
               textContent, which breaks getByLabelText('Receipt')). */}
            <label htmlFor="expense-receipt" className="text-[11.5px] font-semibold text-ink-2">Receipt</label>
            <div className="flex items-center gap-3">
              {shownReceipt ? (
                <img src={shownReceipt} alt="" className="h-14 w-14 rounded-ctl object-cover" />
              ) : (
                <div className="flex h-14 w-14 items-center justify-center rounded-ctl border border-dashed border-line text-[10.5px] text-ink-3">
                  No receipt
                </div>
              )}
              <div className="flex items-center gap-2">
                <label
                  htmlFor="expense-receipt"
                  className="cursor-pointer rounded-ctl border border-line px-3 py-[7px] text-ctl-sm text-ink hover:bg-surface-2"
                >
                  {shownReceipt ? 'Replace' : 'Upload'}
                </label>
                <input id="expense-receipt" type="file" accept="image/*" className="hidden" onChange={onPickFile} />
                {shownReceipt ? (
                  <button
                    type="button"
                    onClick={removeReceipt}
                    className="rounded-ctl border border-line px-3 py-[7px] text-ctl-sm text-ink-2 hover:bg-surface-2"
                  >
                    Remove
                  </button>
                ) : null}
              </div>
            </div>
          </div>

          {isEditing && target ? (
            <section className="flex flex-col gap-2">
              <SectionLabel>Record history</SectionLabel>
              <div className="grid grid-cols-[repeat(auto-fit,minmax(180px,1fr))] gap-2.5">
                <HistoryEntry label="Created by" who={target.createdByName} when={target.createdAt} />
                <HistoryEntry label="Last updated by" who={target.updatedByName} when={target.updatedAt} />
              </div>
            </section>
          ) : null}

          {isEditing && target && canDelete ? (
            <section className="flex flex-col gap-2.5 rounded-[12px] border border-neg px-3.5 py-3">
              <div className="flex items-center gap-2">
                <WarningGlyph />
                <span className="text-[11.5px] font-semibold tracking-[0.2px] text-neg">Danger zone</span>
              </div>
              <div className="flex flex-wrap items-center gap-3">
                <span className="min-w-[150px] flex-1 text-[11.5px] text-ink-3 [text-wrap:pretty]">
                  Deleting keeps the entry in Activity Logs but removes it from every expense total.
                </span>
                <button
                  type="button"
                  onClick={() => {
                    del.reset();
                    setDeleteOpen(true);
                  }}
                  className="shrink-0 rounded-ctl border border-neg px-3.5 py-2 text-ctl-sm font-semibold text-neg hover:bg-neg-soft"
                >
                  Delete expense
                </button>
              </div>
            </section>
          ) : null}
        </form>
      </Modal>

      <Dialog
        open={deleteOpen}
        onClose={() => {
          if (!del.isPending) setDeleteOpen(false);
        }}
        title="Delete this expense?"
        description={target ? `"${target.description}" will be permanently deleted.` : undefined}
        dismissable={!del.isPending}
      >
        {del.error ? <p className="mb-tk-md text-bodySmall text-neg">{del.error.message}</p> : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setDeleteOpen(false)}
            disabled={del.isPending}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink hover:bg-surface-2 disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={confirmDelete}
            disabled={del.isPending}
            className="inline-flex items-center gap-tk-xs rounded-ctl bg-neg px-tk-md py-tk-sm text-ctl-sm font-semibold text-white hover:opacity-90 disabled:opacity-60"
          >
            {del.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
          </button>
        </div>
      </Dialog>
    </>
  );
}

const controlH = 'h-[42px]';

function inputCls(hasError: boolean): string {
  return cn(
    'h-[42px] w-full rounded-ctl border bg-surface-2 px-3 py-2.5 text-[13px] text-ink outline-none transition-colors placeholder:text-ink-3',
    hasError ? 'border-neg' : 'border-line focus:border-accent-line',
  );
}

function Field({
  label,
  group = false,
  children,
}: {
  label: string;
  /** Composite content (chip rows, the receipt block) must NOT sit in a
   *  <label> — a label associates with its first labelable descendant and
   *  would steal its accessible name. */
  group?: boolean;
  children: ReactNode;
}) {
  const Tag = group ? 'div' : 'label';
  return (
    <Tag className="flex flex-col gap-[7px]">
      <span className="text-[11.5px] font-semibold text-ink-2">{label}</span>
      {children}
    </Tag>
  );
}

function SectionLabel({ children }: { children: ReactNode }) {
  return <span className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">{children}</span>;
}

function WarningGlyph() {
  return (
    <svg width="14" height="14" viewBox="0 0 20 20" fill="none" stroke="var(--neg)" strokeWidth="1.8" aria-hidden>
      <path d="M10 3.2 17.6 16.4H2.4Z" />
      <line x1="10" y1="8.4" x2="10" y2="12" />
      <circle cx="10" cy="14.2" r=".6" fill="var(--neg)" />
    </svg>
  );
}

/** One Record-history entry: label / person / timestamp. Person and
 *  timestamp read as ONE fact ("Bern recorded it on Sep 2"), not two
 *  separate fields. An unedited record (updatedAt null) shows "—" and
 *  "Never edited" rather than repeating the creator. A legacy doc whose
 *  updatedAt is set but updatedByName is missing shows "—" with the real
 *  timestamp — it WAS edited, just before this field existed. */
function HistoryEntry({ label, who, when }: { label: string; who: string | null; when: Date | null }) {
  const name = who?.trim() ? who : null;
  const whenText = when ? formatShopDateTime(when) : 'Never edited';
  return (
    <div className="flex flex-col gap-[3px] rounded-ctl border border-line bg-surface-2 px-3 py-2.5">
      <span className="text-[10px] font-semibold uppercase tracking-[0.8px] text-ink-3">{label}</span>
      <span className={cn('text-[12.5px] font-semibold', name ? 'text-ink' : 'text-ink-3')}>{name ?? '—'}</span>
      <span className="font-mono text-[10.5px] text-ink-3">{whenText}</span>
    </div>
  );
}
