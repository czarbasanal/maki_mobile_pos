// /admin/suppliers/add and /admin/suppliers/edit/:id — single page covering
// both modes. Mirrors the Flutter supplier_form_screen.dart fields:
// name, address, contact person, contact number + alt, email, terms, notes.

import { useEffect } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { useSupplierById } from '@/presentation/hooks/useSuppliers';
import {
  useCreateSupplier,
  useUpdateSupplier,
} from '@/presentation/hooks/useSupplierMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { RoutePaths } from '@/presentation/router/routePaths';
import { TransactionType, transactionTypeDisplayName } from '@/domain/enums';
import { cn } from '@/core/utils/cn';

// Empty strings round-trip cleanly through the form; converted to null at
// submit time so Firestore stores explicit absences instead of "".
const schema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  contactPerson: z.string().trim().optional().or(z.literal('')),
  contactNumber: z.string().trim().optional().or(z.literal('')),
  alternativeNumber: z.string().trim().optional().or(z.literal('')),
  email: z
    .union([z.string().trim().email('Invalid email'), z.literal('')])
    .optional(),
  address: z.string().trim().optional().or(z.literal('')),
  transactionType: z.enum([
    TransactionType.cash,
    TransactionType.terms30d,
    TransactionType.terms45d,
    TransactionType.terms60d,
    TransactionType.terms90d,
    TransactionType.notApplicable,
  ]),
  notes: z.string().trim().optional().or(z.literal('')),
});

type FormValues = z.infer<typeof schema>;

const blank = (s: string | undefined) => (s && s.trim() ? s.trim() : null);

const TERMS_OPTIONS: TransactionType[] = [
  TransactionType.cash,
  TransactionType.terms30d,
  TransactionType.terms45d,
  TransactionType.terms60d,
  TransactionType.terms90d,
  TransactionType.notApplicable,
];

export function SupplierFormPage() {
  const params = useParams<{ id?: string }>();
  const editingId = params.id;
  const isEditing = !!editingId;
  const navigate = useNavigate();

  const { data: target, isLoading, error } = useSupplierById(editingId);
  const create = useCreateSupplier();
  const update = useUpdateSupplier();

  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: '',
      contactPerson: '',
      contactNumber: '',
      alternativeNumber: '',
      email: '',
      address: '',
      transactionType: TransactionType.cash,
      notes: '',
    },
  });

  useEffect(() => {
    document.title = isEditing
      ? 'Edit supplier · MAKI POS Admin'
      : 'New supplier · MAKI POS Admin';
  }, [isEditing]);

  useEffect(() => {
    if (!target) return;
    reset({
      name: target.name,
      contactPerson: target.contactPerson ?? '',
      contactNumber: target.contactNumber ?? '',
      alternativeNumber: target.alternativeNumber ?? '',
      email: target.email ?? '',
      address: target.address ?? '',
      transactionType: target.transactionType,
      notes: target.notes ?? '',
    });
  }, [target, reset]);

  if (isEditing && error) {
    return <ErrorView title="Could not load supplier" message={error.message} />;
  }
  if (isEditing && isLoading) return <LoadingView label="Loading supplier…" />;
  if (isEditing && !target) return <LoadingView label="Loading supplier…" />;

  const submitting = isSubmitting || create.isPending || update.isPending;
  const mutationError = create.error?.message ?? update.error?.message ?? null;

  const onSubmit = async (values: FormValues) => {
    const payload = {
      name: values.name,
      contactPerson: blank(values.contactPerson),
      contactNumber: blank(values.contactNumber),
      alternativeNumber: blank(values.alternativeNumber),
      email: blank(values.email),
      address: blank(values.address),
      transactionType: values.transactionType,
      notes: blank(values.notes),
    };
    try {
      if (isEditing && target) {
        await update.mutateAsync({ id: target.id, ...payload });
      } else {
        await create.mutateAsync(payload);
      }
      navigate(RoutePaths.suppliers);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Save failed';
      if (msg.toLowerCase().includes('already exists')) {
        setError('name', { type: 'duplicate', message: msg });
      }
    }
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="space-y-tk-sm">
        <Link
          to={RoutePaths.suppliers}
          className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
        >
          <ArrowLeftIcon className="h-3.5 w-3.5" />
          Suppliers
        </Link>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          {isEditing ? 'Edit supplier' : 'New supplier'}
        </h1>
      </header>

      {mutationError && !errors.name ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {mutationError}
        </p>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-lg" noValidate>
        <Section title="Basic information">
          <Field
            label="Name"
            error={errors.name?.message}
            input={<input type="text" autoFocus className={inputCls(!!errors.name)} {...register('name')} />}
          />
          <Field
            label="Address"
            error={errors.address?.message}
            input={<input type="text" className={inputCls(!!errors.address)} {...register('address')} />}
          />
        </Section>

        <Section title="Contact">
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <Field
              label="Contact person"
              error={errors.contactPerson?.message}
              input={
                <input
                  type="text"
                  className={inputCls(!!errors.contactPerson)}
                  {...register('contactPerson')}
                />
              }
            />
            <Field
              label="Email"
              error={errors.email?.message}
              input={
                <input
                  type="email"
                  inputMode="email"
                  className={inputCls(!!errors.email)}
                  {...register('email')}
                />
              }
            />
            <Field
              label="Contact number"
              error={errors.contactNumber?.message}
              input={
                <input
                  type="tel"
                  inputMode="tel"
                  className={inputCls(!!errors.contactNumber)}
                  {...register('contactNumber')}
                />
              }
            />
            <Field
              label="Alternative number"
              error={errors.alternativeNumber?.message}
              input={
                <input
                  type="tel"
                  inputMode="tel"
                  className={inputCls(!!errors.alternativeNumber)}
                  {...register('alternativeNumber')}
                />
              }
            />
          </div>
        </Section>

        <Section title="Terms">
          <Field
            label="Payment terms"
            error={errors.transactionType?.message}
            input={
              <select
                className={cn(inputCls(false), 'pr-8')}
                {...register('transactionType')}
              >
                {TERMS_OPTIONS.map((t) => (
                  <option key={t} value={t}>
                    {transactionTypeDisplayName[t]}
                  </option>
                ))}
              </select>
            }
          />
        </Section>

        <Section title="Notes">
          <Field
            label="Internal notes"
            error={errors.notes?.message}
            input={
              <textarea
                rows={3}
                className={cn(inputCls(!!errors.notes), 'resize-y leading-relaxed')}
                {...register('notes')}
              />
            }
          />
        </Section>

        <div className="flex justify-end gap-tk-sm">
          <Link
            to={RoutePaths.suppliers}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            Cancel
          </Link>
          <button
            type="submit"
            disabled={submitting}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submitting ? <Spinner className="h-3.5 w-3.5" /> : null}
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Create supplier'}
          </button>
        </div>
      </form>
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

function Field({
  label,
  error,
  input,
}: {
  label: string;
  error?: string;
  input: React.ReactNode;
}) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-error">{error}</span> : null}
    </label>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-tk-sm">
      <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
        {title}
      </h2>
      <div className="rounded-lg border border-light-hairline bg-light-card p-tk-md space-y-tk-md">
        {children}
      </div>
    </section>
  );
}
