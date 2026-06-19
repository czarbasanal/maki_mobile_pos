import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { ArrowLeftIcon, ArrowPathIcon } from '@heroicons/react/24/outline';
import { useProduct } from '@/presentation/hooks/useProduct';
import { useCreateProduct, useUpdateProduct } from '@/presentation/hooks/useProductMutations';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useProductRepo } from '@/infrastructure/di/container';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { priceHistoryReason } from '@/domain/products/priceHistoryReason';
import { generateSku } from '@/domain/products/sku';
import { encodeCostCode } from '@/domain/entities';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

// Required numeric: a blank input must error, not silently coerce to 0
// (Number('') === 0). Map blank -> NaN so z.number rejects it.
const reqNumber = (msg: string, int = false) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? (v.trim() === '' ? NaN : Number(v)) : v),
    (int
      ? z.number({ invalid_type_error: msg }).int('Whole number')
      : z.number({ invalid_type_error: msg })
    ).min(0, 'Must be ≥ 0'),
  );

const schema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  sku: z
    .string()
    .trim()
    .min(1, 'SKU is required')
    .max(50, 'Max 50 characters')
    .regex(/^[A-Za-z0-9-]+$/, 'Use only letters, numbers, and hyphens'),
  barcode: z.string().trim().optional().or(z.literal('')),
  cost: reqNumber('Cost is required'),
  price: reqNumber('Price is required'),
  quantity: reqNumber('Quantity is required', true),
  reorderLevel: reqNumber('Reorder level is required', true),
  unit: z.string().trim().min(1, 'Unit is required'),
  category: z.string().optional().or(z.literal('')),
  supplierId: z.string().optional().or(z.literal('')),
  notes: z.string().trim().optional().or(z.literal('')),
});
type FormValues = z.infer<typeof schema>;

const blank = (s: string | undefined) => (s && s.trim() ? s.trim() : null);

function withCurrent(names: string[], current: string | null): string[] {
  if (current && !names.includes(current)) return [current, ...names];
  return names;
}

export function InventoryFormPage() {
  const { id } = useParams<{ id: string }>();
  const isEditing = !!id;
  const navigate = useNavigate();
  const repo = useProductRepo();

  const { data: target, isLoading, error } = useProduct(id);
  const update = useUpdateProduct();
  const create = useCreateProduct();
  const { data: productCats } = useActiveCategories(CategoryKind.product);
  const { data: units } = useActiveCategories(CategoryKind.unit);
  const { data: suppliers } = useSuppliers();
  const { data: costCodeMapping } = useCostCode();

  const [autoSku, setAutoSku] = useState(true);
  const [loadNotice, setLoadNotice] = useState<string | null>(null);
  const [skuDialog, setSkuDialog] = useState<{ open: boolean; count: number; values: FormValues | null }>(
    { open: false, count: 0, values: null },
  );

  const {
    register,
    handleSubmit,
    reset,
    setError,
    setValue,
    getValues,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: '', sku: '', barcode: '', cost: 0, price: 0, quantity: 0, reorderLevel: 0,
      unit: 'pcs', category: '', supplierId: '', notes: '',
    },
  });

  useEffect(() => {
    document.title = isEditing
      ? target
        ? `Edit ${target.name} · Inventory`
        : 'Edit product'
      : 'New product · Inventory';
  }, [isEditing, target]);

  useEffect(() => {
    if (!target) return;
    reset({
      name: target.name,
      sku: target.sku,
      barcode: target.barcode ?? '',
      cost: target.cost,
      price: target.price,
      quantity: target.quantity,
      reorderLevel: target.reorderLevel,
      unit: target.unit,
      category: target.category ?? '',
      supplierId: target.supplierId ?? '',
      notes: target.notes ?? '',
    });
  }, [target, reset]);

  const categoryOptions = useMemo(
    () => withCurrent((productCats ?? []).map((c) => c.name), target?.category ?? null),
    [productCats, target?.category],
  );
  const unitOptions = useMemo(
    () => withCurrent((units ?? []).map((u) => u.name), target?.unit ?? null),
    [units, target?.unit],
  );
  const supplierOptions = useMemo(() => {
    const active = (suppliers ?? []).filter((s) => s.isActive);
    if (target?.supplierId && !active.some((s) => s.id === target.supplierId)) {
      const saved = (suppliers ?? []).find((s) => s.id === target.supplierId);
      if (saved) return [saved, ...active];
    }
    return active;
  }, [suppliers, target?.supplierId]);

  if (isEditing && error) {
    return <ErrorView title="Could not load product" message={error.message} />;
  }
  if (isEditing && (isLoading || !target)) {
    return <LoadingView label="Loading product…" />;
  }

  const submitting = isSubmitting || update.isPending || create.isPending;
  const mutationError = update.error?.message ?? create.error?.message ?? null;
  const skuLocked = !isEditing && autoSku;

  const regenerateSku = () =>
    setValue('sku', generateSku(getValues('name')), { shouldValidate: true });

  const resolveSupplier = (supplierId: string) => {
    const idOut = supplierId || null;
    const found = (suppliers ?? []).find((s) => s.id === idOut);
    if (idOut === null) return { id: null, name: null };
    if (found) return { id: idOut, name: found.name };
    if (isEditing && idOut === target?.supplierId) return { id: idOut, name: target?.supplierName ?? null };
    return { id: idOut, name: null };
  };

  const doSave = async (values: FormValues) => {
    setLoadNotice(null);
    const costNum = Number(values.cost);
    const priceNum = Number(values.price);
    const supplier = resolveSupplier(values.supplierId ?? '');

    if (isEditing && target) {
      const costChanged = Math.abs(costNum - target.cost) > 0.01;
      if (costChanged && !costCodeMapping) {
        setLoadNotice('Cost-code mapping is still loading — try again in a moment.');
        return;
      }
      const costCode = costChanged ? encodeCostCode(costCodeMapping!, costNum) : target.costCode;
      const reason = priceHistoryReason(target.cost, target.price, costNum, priceNum);
      const patch: ProductUpdateInput = {
        name: values.name.trim(),
        sku: values.sku.trim(),
        category: blank(values.category),
        cost: costNum,
        costCode,
        price: priceNum,
        reorderLevel: Number(values.reorderLevel),
        unit: values.unit.trim() || 'pcs',
        supplierId: supplier.id,
        supplierName: supplier.name,
        barcode: blank(values.barcode),
        notes: blank(values.notes),
      };
      try {
        await update.mutateAsync({
          id: target.id,
          oldSku: target.sku,
          oldBarcode: target.barcode,
          patch,
          priceChange: reason ? { price: priceNum, cost: costNum, reason } : null,
        });
        navigate(RoutePaths.inventory);
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'Save failed';
        if (msg.toLowerCase().includes('sku already exists')) setError('sku', { type: 'duplicate', message: msg });
        else if (msg.toLowerCase().includes('barcode already exists')) setError('barcode', { type: 'duplicate', message: msg });
      }
      return;
    }

    // Add mode — costCode must be derived, which needs the mapping.
    if (!costCodeMapping) {
      setLoadNotice('Cost-code mapping is still loading — try again in a moment.');
      return;
    }
    try {
      await create.mutateAsync({
        sku: values.sku.trim(),
        name: values.name.trim(),
        costCode: encodeCostCode(costCodeMapping, costNum),
        cost: costNum,
        price: priceNum,
        quantity: Number(values.quantity),
        reorderLevel: Number(values.reorderLevel),
        unit: values.unit.trim() || 'pcs',
        supplierId: supplier.id,
        supplierName: supplier.name,
        barcode: blank(values.barcode),
        category: blank(values.category),
        notes: blank(values.notes),
      });
      navigate(RoutePaths.inventory);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Save failed';
      if (msg.toLowerCase().includes('sku already exists')) setError('sku', { type: 'duplicate', message: msg });
      else if (msg.toLowerCase().includes('barcode already exists')) setError('barcode', { type: 'duplicate', message: msg });
    }
  };

  const onSubmit = async (values: FormValues) => {
    if (isEditing && target && values.sku.trim() !== target.sku) {
      const count = await repo.countSkuVariations(target.sku);
      setSkuDialog({ open: true, count, values });
      return;
    }
    await doSave(values);
  };

  // In add mode with auto-SKU on, the SKU is filled by the Name field's blur.
  // A keyboard-Enter submit fires before that blur, so populate it here too —
  // before handleSubmit runs the resolver — so a valid name never yields a
  // spurious "SKU is required".
  const onFormSubmit = (e: FormEvent<HTMLFormElement>) => {
    if (skuLocked && !getValues('sku').trim()) {
      setValue('sku', generateSku(getValues('name')));
    }
    void handleSubmit(onSubmit)(e);
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="space-y-tk-sm">
        <Link
          to={RoutePaths.inventory}
          className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
        >
          <ArrowLeftIcon className="h-3.5 w-3.5" /> Inventory
        </Link>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          {isEditing ? 'Edit product' : 'New product'}
        </h1>
      </header>

      {mutationError && !errors.sku ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {mutationError}
        </p>
      ) : null}
      {loadNotice ? (
        <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
          {loadNotice}
        </p>
      ) : null}

      <form onSubmit={onFormSubmit} className="space-y-tk-lg" noValidate>
        <Section title="Identity">
          <Field label="Name" error={errors.name?.message}
            input={
              <input
                type="text"
                className={inputCls(!!errors.name)}
                {...register('name', {
                  onBlur: () => { if (skuLocked) regenerateSku(); },
                })}
              />
            } />

          {!isEditing ? (
            <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
              <input
                type="checkbox"
                checked={autoSku}
                onChange={(e) => {
                  const on = e.target.checked;
                  setAutoSku(on);
                  if (on) regenerateSku();
                }}
              />
              Auto-generate SKU from name
            </label>
          ) : null}

          <Field label="SKU" error={errors.sku?.message}
            input={
              <div className="flex items-center gap-tk-sm">
                <input
                  type="text"
                  readOnly={skuLocked}
                  className={cn(inputCls(!!errors.sku), skuLocked && 'bg-light-subtle text-light-text-secondary')}
                  {...register('sku', {
                    onChange: () => {
                      if (update.error) update.reset();
                      if (create.error) create.reset();
                    },
                  })}
                />
                {skuLocked ? (
                  <button
                    type="button"
                    onClick={regenerateSku}
                    className="inline-flex shrink-0 items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[10px] text-bodySmall text-light-text hover:bg-light-subtle"
                  >
                    <ArrowPathIcon className="h-3.5 w-3.5" /> Regenerate
                  </button>
                ) : null}
              </div>
            } />
          {isEditing ? (
            <p className="text-[12px] text-light-text-hint">
              Changing the SKU keeps past sales &amp; receiving records on the old code and re-points linked variations.
            </p>
          ) : null}

          <Field label="Barcode" error={errors.barcode?.message}
            input={<input type="text" className={inputCls(!!errors.barcode)} {...register('barcode')} />} />
        </Section>

        <Section title="Pricing">
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <Field label="Cost" error={errors.cost?.message}
              input={<input type="number" step="0.01" className={inputCls(!!errors.cost)} {...register('cost')} />} />
            <Field label="Price" error={errors.price?.message}
              input={<input type="number" step="0.01" className={inputCls(!!errors.price)} {...register('price')} />} />
          </div>
        </Section>

        <Section title="Stock & classification">
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            {!isEditing ? (
              <Field label="Initial quantity" error={errors.quantity?.message}
                input={<input type="number" className={inputCls(!!errors.quantity)} {...register('quantity')} />} />
            ) : null}
            <Field label="Reorder level" error={errors.reorderLevel?.message}
              input={<input type="number" className={inputCls(!!errors.reorderLevel)} {...register('reorderLevel')} />} />
            <Field label="Unit" error={errors.unit?.message}
              input={
                <select className={cn(inputCls(!!errors.unit), 'pr-8')} {...register('unit')}>
                  {unitOptions.map((u) => (<option key={u} value={u}>{u}</option>))}
                </select>
              } />
            <Field label="Category" error={errors.category?.message}
              input={
                <select className={cn(inputCls(false), 'pr-8')} {...register('category')}>
                  <option value="">(none)</option>
                  {categoryOptions.map((c) => (<option key={c} value={c}>{c}</option>))}
                </select>
              } />
            <Field label="Supplier" error={errors.supplierId?.message}
              input={
                <select className={cn(inputCls(false), 'pr-8')} {...register('supplierId')}>
                  <option value="">No supplier</option>
                  {supplierOptions.map((s) => (
                    <option key={s.id} value={s.id}>{s.isActive ? s.name : `${s.name} (inactive)`}</option>
                  ))}
                </select>
              } />
          </div>
        </Section>

        <Section title="Notes">
          <Field label="Notes" error={errors.notes?.message}
            input={<textarea rows={3} className={cn(inputCls(!!errors.notes), 'resize-y leading-relaxed')} {...register('notes')} />} />
        </Section>

        <div className="flex justify-end gap-tk-sm">
          <Link to={RoutePaths.inventory}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
            Cancel
          </Link>
          <button type="submit" disabled={submitting}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60">
            {submitting ? <Spinner className="h-3.5 w-3.5" /> : null}
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Create product'}
          </button>
        </div>
      </form>

      <Dialog
        open={skuDialog.open}
        onClose={() => { if (!submitting) setSkuDialog((d) => ({ ...d, open: false })); }}
        title="Change SKU?"
        dismissable={!submitting}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text">
            <span className="font-mono">{target?.sku}</span>
            <span className="px-tk-sm text-light-text-hint">→</span>
            <span className="font-mono">{skuDialog.values?.sku}</span>
          </p>
          <ul className="list-disc space-y-tk-xs pl-5 text-bodySmall text-light-text-secondary">
            <li>Past sales and receiving records keep their original SKU.</li>
            {skuDialog.count > 0 ? (
              <li>{skuDialog.count} linked variation(s) will be re-pointed to the new SKU.</li>
            ) : null}
          </ul>
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button type="button" disabled={submitting}
              onClick={() => setSkuDialog((d) => ({ ...d, open: false }))}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
              Cancel
            </button>
            <button type="button" disabled={submitting}
              onClick={async () => {
                const values = skuDialog.values;
                setSkuDialog((d) => ({ ...d, open: false }));
                if (values) await doSave(values);
              }}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60">
              {submitting ? <Spinner className="h-3.5 w-3.5" /> : null} Change SKU
            </button>
          </div>
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
