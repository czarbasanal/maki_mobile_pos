import { useEffect, useMemo, useState, type ChangeEvent, type ReactNode } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { format } from 'date-fns';
import { ArrowLeftIcon, TrashIcon } from '@heroicons/react/24/outline';
import {
  useCreateExpense,
  useDeleteExpense,
  useExpense,
  useUpdateExpense,
  type UpdateExpenseInput,
} from '@/presentation/hooks/useExpenses';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { useExpenseRepo } from '@/infrastructure/di/container';
import { deleteExpenseReceipt, uploadExpenseReceipt } from '@/data/expenseReceiptStorage';
import { PaymentMethod, paymentMethodDisplayName } from '@/domain/enums';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

// Blank -> NaN so an untouched/cleared amount fails the > 0 check instead of
// silently passing as 0 (Number('') === 0).
const reqAmount = z.preprocess(
  (v) => (typeof v === 'string' ? (v.trim() === '' ? NaN : Number(v)) : v),
  z.number({ invalid_type_error: 'Amount is required' }).positive('Must be greater than 0'),
);

const schema = z.object({
  description: z.string().trim().min(1, 'Description is required'),
  amount: reqAmount,
  category: z.string().trim().min(1, 'Category is required'),
  paidVia: z.string().trim().min(1, 'Paid via is required'),
  date: z.string().trim().min(1, 'Date is required'),
  notes: z.string().trim().optional().or(z.literal('')),
});
type FormValues = z.infer<typeof schema>;

const blank = (s: string | undefined) => (s && s.trim() ? s.trim() : null);
const todayStr = () => format(new Date(), 'yyyy-MM-dd');

function withCurrent(names: string[], current: string | null): string[] {
  if (current && !names.includes(current)) return [current, ...names];
  return names;
}

export function ExpenseFormPage() {
  const { id } = useParams<{ id: string }>();
  const isEditing = !!id;
  const navigate = useNavigate();
  const repo = useExpenseRepo();
  const user = useAuthStore((s) => s.user);
  const canDelete = isEditing && !!user && hasPermission(user.role, Permission.deleteExpense);

  const { data: target, isLoading, error } = useExpense(id);
  const { data: expenseCats } = useActiveCategories(CategoryKind.expense);
  const create = useCreateExpense();
  const update = useUpdateExpense();
  const del = useDeleteExpense();

  const [receiptBlob, setReceiptBlob] = useState<Blob | null>(null);
  const [receiptPreview, setReceiptPreview] = useState<string | null>(null);
  const [receiptRemoved, setReceiptRemoved] = useState(false);
  const [saveNotice, setSaveNotice] = useState<string | null>(null);
  const [deleteOpen, setDeleteOpen] = useState(false);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      description: '',
      amount: 0,
      category: '',
      paidVia: PaymentMethod.cash,
      date: todayStr(),
      notes: '',
    },
  });

  useEffect(() => {
    document.title = isEditing ? 'Edit expense · Expenses' : 'New expense · Expenses';
  }, [isEditing]);

  useEffect(() => {
    if (!target) return;
    reset({
      description: target.description,
      amount: target.amount,
      category: target.category,
      paidVia: target.paidVia,
      date: format(target.date, 'yyyy-MM-dd'),
      notes: target.notes ?? '',
    });
  }, [target, reset]);

  useEffect(() => {
    return () => {
      if (receiptPreview) URL.revokeObjectURL(receiptPreview);
    };
  }, [receiptPreview]);

  const categoryOptions = useMemo(
    () => withCurrent((expenseCats ?? []).map((c) => c.name), target?.category ?? null),
    [expenseCats, target?.category],
  );

  if (isEditing && error) {
    return <ErrorView title="Could not load expense" message={error.message} />;
  }
  if (isEditing && (isLoading || !target)) {
    return <LoadingView label="Loading expense…" />;
  }

  const submitting = isSubmitting || create.isPending || update.isPending;
  const mutationError = create.error?.message ?? update.error?.message ?? null;

  const onPickFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // allow re-picking the same file
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

  const onSubmit = async (values: FormValues) => {
    setSaveNotice(null);
    const parsedDate = new Date(`${values.date}T00:00:00`);

    try {
      if (isEditing && target) {
        let uploadedUrl: string | undefined;
        if (receiptBlob) {
          try {
            uploadedUrl = await uploadExpenseReceipt(target.id, receiptBlob);
          } catch {
            setSaveNotice('Receipt upload failed — expense saved without the new receipt.');
          }
        }
        const patch: UpdateExpenseInput['patch'] = {
          description: values.description.trim(),
          amount: values.amount,
          category: values.category.trim(),
          paidVia: values.paidVia as PaymentMethod,
          date: parsedDate,
          notes: blank(values.notes),
        };
        if (receiptBlob) {
          if (uploadedUrl) patch.receiptImageUrl = uploadedUrl;
        } else if (receiptRemoved) {
          patch.receiptImageUrl = null;
        }
        await update.mutateAsync({ id: target.id, patch });
        if (!receiptBlob && receiptRemoved) {
          try {
            await deleteExpenseReceipt(target.id);
          } catch {
            // best-effort — an orphaned Storage object is harmless.
          }
        }
        navigate(RoutePaths.expenses);
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
          setSaveNotice('Receipt upload failed — expense saved without a receipt.');
          presetId = undefined;
        }
      }
      await create.mutateAsync({
        id: presetId,
        description: values.description.trim(),
        amount: values.amount,
        category: values.category.trim(),
        paidVia: values.paidVia as PaymentMethod,
        date: parsedDate,
        notes: blank(values.notes),
        receiptNumber: null,
        receiptImageUrl,
      });
      navigate(RoutePaths.expenses);
    } catch {
      // Surfaced via create.error / update.error above.
    }
  };

  const confirmDelete = async () => {
    if (!id) return;
    try {
      await del.mutateAsync(id);
      try {
        await deleteExpenseReceipt(id);
      } catch {
        // best-effort — an orphaned Storage object is harmless.
      }
      navigate(RoutePaths.expenses);
    } catch {
      // Surfaced via del.error below; confirm dialog stays open.
    }
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex items-start justify-between gap-tk-md">
        <div className="space-y-tk-sm">
          <Link
            to={RoutePaths.expenses}
            className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
          >
            <ArrowLeftIcon className="h-3.5 w-3.5" /> Expenses
          </Link>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {isEditing ? 'Edit expense' : 'New expense'}
          </h1>
        </div>
        {canDelete ? (
          <button
            type="button"
            onClick={() => setDeleteOpen(true)}
            disabled={submitting || del.isPending}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-error-dark hover:bg-error-light/40 disabled:opacity-60"
          >
            <TrashIcon className="h-3.5 w-3.5" /> Delete
          </button>
        ) : null}
      </header>

      {mutationError ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {mutationError}
        </p>
      ) : null}
      {saveNotice ? (
        <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
          {saveNotice}
        </p>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-lg" noValidate>
        <Section title="Expense">
          <Field label="Description" error={errors.description?.message}
            input={<input type="text" className={inputCls(!!errors.description)} {...register('description')} />} />

          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <Field label="Amount" error={errors.amount?.message}
              input={<input type="number" step="0.01" className={inputCls(!!errors.amount)} {...register('amount')} />} />
            <Field label="Date" error={errors.date?.message}
              input={<input type="date" className={inputCls(!!errors.date)} {...register('date')} />} />
          </div>

          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <Field label="Category" error={errors.category?.message}
              input={
                <select className={cn(inputCls(!!errors.category), 'pr-8')} {...register('category')}>
                  <option value="">Select a category</option>
                  {categoryOptions.map((c) => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
              } />
            <Field label="Paid via" error={errors.paidVia?.message}
              input={
                <select className={cn(inputCls(!!errors.paidVia), 'pr-8')} {...register('paidVia')}>
                  {Object.values(PaymentMethod).map((m) => (
                    <option key={m} value={m}>{paymentMethodDisplayName[m]}</option>
                  ))}
                </select>
              } />
          </div>

          <Field label="Notes" error={errors.notes?.message}
            input={<textarea rows={3} className={cn(inputCls(!!errors.notes), 'resize-y leading-relaxed')} {...register('notes')} />} />

          <div className="space-y-tk-xs">
            {/* A second, sibling <label htmlFor> (not a wrapping label) so the
               "Upload/Replace" trigger label doesn't merge its own text into
               this one's accessible name (nested labels concatenate their
               textContent, which would break getByLabelText('Receipt')). */}
            <label htmlFor="expense-receipt" className="block text-bodySmall font-medium text-light-text">
              Receipt
            </label>
            <div className="flex items-center gap-tk-md">
              {shownReceipt ? (
                <img src={shownReceipt} alt="" className="h-16 w-16 rounded-md object-cover" />
              ) : (
                <div className="flex h-16 w-16 items-center justify-center rounded-md border border-dashed border-light-border text-[11px] text-light-text-hint">
                  No receipt
                </div>
              )}
              <div className="flex items-center gap-tk-sm">
                <label htmlFor="expense-receipt" className="cursor-pointer rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
                  {shownReceipt ? 'Replace' : 'Upload'}
                </label>
                <input id="expense-receipt" type="file" accept="image/*" className="hidden" onChange={onPickFile} />
                {shownReceipt ? (
                  <button type="button" onClick={removeReceipt}
                    className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-secondary hover:bg-light-subtle">
                    Remove
                  </button>
                ) : null}
              </div>
            </div>
          </div>
        </Section>

        <div className="flex justify-end gap-tk-sm">
          <Link to={RoutePaths.expenses}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
            Cancel
          </Link>
          <button type="submit" disabled={submitting}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60">
            {submitting ? <Spinner className="h-3.5 w-3.5" /> : null}
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Add expense'}
          </button>
        </div>
      </form>

      <Dialog
        open={deleteOpen}
        onClose={() => {
          if (!del.isPending) setDeleteOpen(false);
        }}
        title="Delete this expense?"
        description={
          target ? `"${target.description}" will be permanently deleted.` : undefined
        }
        dismissable={!del.isPending}
      >
        {del.error ? (
          <p className="mb-tk-md text-bodySmall text-error-dark">{del.error.message}</p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setDeleteOpen(false)}
            disabled={del.isPending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={confirmDelete}
            disabled={del.isPending}
            className="inline-flex items-center gap-tk-xs rounded-md bg-error px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:bg-error-dark disabled:opacity-60"
          >
            {del.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
          </button>
        </div>
      </Dialog>
    </div>
  );
}

function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
    'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
    hasError ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
  );
}

function Field({ label, error, input }: { label: string; error?: string; input: ReactNode }) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-error">{error}</span> : null}
    </label>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-tk-sm">
      <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">{title}</h2>
      <div className="space-y-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-md">{children}</div>
    </section>
  );
}
