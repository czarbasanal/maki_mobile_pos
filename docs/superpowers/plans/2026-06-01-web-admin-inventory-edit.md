# Web Inventory Slice 2a — Edit form + SKU relink + price-history — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let an admin edit an existing product at `/inventory/edit/:id`, including a full SKU change (self-excluding uniqueness + atomic variation relink) and price-history recording on cost/price change.

**Architecture:** A new `InventoryFormPage` (edit mode) mirrors `SupplierFormPage`, loads via the existing `useProduct(id)`, and saves through a new `useUpdateProduct` mutation. The repo gains `skuExists(excludeId)`, `countSkuVariations`, and an atomic `updateProductWithSku` (writeBatch re-pointing `baseSku` children). Cost/price changes trigger a best-effort `recordPriceChange`; cost changes re-encode `costCode`. **Admin-only** (web shell already enforces).

**Tech Stack:** React, TypeScript, React Router v6, TanStack Query v5, react-hook-form + zod, Firebase Firestore, Vitest. Spec: `docs/superpowers/specs/2026-06-01-web-admin-inventory-edit-design.md` (this is Slice **2a**; Slice 2b = stock/deactivate). Run from `web_admin/`.

**Toolchain:** typecheck `npx tsc --noEmit -p tsconfig.json`; logic tests `--environment=node`; unit-tested modules use **relative imports**.

---

## Context verified (slice2-understand workflow)

- `SupplierFormPage.tsx` is the form template (zod + react-hook-form; `Field`/`Section`/`inputCls`/`blank` helpers at the bottom). Edit-load via `useProduct(id)` (react-query `{data,isLoading,error}`) — already exists, do NOT make a `useProductById`.
- `FirestoreSupplierRepository.nameExists(name, excludeId)` = `query(col, where('name','==',name), limit(2))` then `docs.some(d => d.id !== excludeId)` — mirror for SKU.
- `FirestoreProductRepository.update(id,input,actorId)` → `updateData()` whitelists sku/name/costCode/cost/price/quantity/reorderLevel/unit/supplierId/supplierName/isActive/baseSku/variationNumber/barcode/category/imageUrl/notes/updatedByName, and rebuilds `searchKeywords` ONLY when `name` is present (from `[sku ?? name, name, category]`). `recordPriceChange(id, {price,cost,changedBy,reason})` writes `products/{id}/price_history`.
- `encodeCostCode(cc: CostCode, cost: number): string` (`@/domain/entities`); `useCostCode()` → `{data: CostCode|null, isLoading, error}` (subscription).
- `useActiveCategories(kind)` → subscription `{data: Category[]|null,...}`; product category is a free-text **name** string. `useSuppliers()` → subscription `{data: Supplier[]|null,...}` (NOT isActive-filtered).
- Mobile reason strings: `'Price update'` / `'Cost update'` / `'Price + cost update'` (EPS 0.01); the web `derivePriceHistorySource` already maps all three to "Manual edit".
- `RoutePaths.productEdit = '/inventory/edit/:id'` is wired to a placeholder in `routes.tsx`; the route guard already requires `editProduct||editProductLimited`. Admin passes.

## File Structure

**Create:** `domain/products/priceHistoryReason.ts` (+test), `presentation/hooks/useProductMutations.ts`, `presentation/features/inventory/InventoryFormPage.tsx`.
**Modify:** `domain/repositories/ProductRepository.ts`, `data/repositories/FirestoreProductRepository.ts`, `presentation/router/routes.tsx`, `presentation/features/inventory/InventoryDetailPage.tsx`.

---

## Task 1: `priceHistoryReason` pure helper

**Files:**
- Create: `web_admin/src/domain/products/priceHistoryReason.ts`
- Test: `web_admin/src/domain/products/priceHistoryReason.test.ts`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/products/priceHistoryReason.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { priceHistoryReason } from './priceHistoryReason';

describe('priceHistoryReason', () => {
  it('returns null when neither moved (within EPS)', () => {
    expect(priceHistoryReason(60, 100, 60, 100)).toBeNull();
    expect(priceHistoryReason(60, 100, 60.005, 100.005)).toBeNull();
  });
  it('detects price-only change', () => {
    expect(priceHistoryReason(60, 100, 60, 120)).toBe('Price update');
  });
  it('detects cost-only change', () => {
    expect(priceHistoryReason(60, 100, 70, 100)).toBe('Cost update');
  });
  it('detects both', () => {
    expect(priceHistoryReason(60, 100, 70, 120)).toBe('Price + cost update');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/priceHistoryReason.test.ts`
Expected: FAIL — cannot resolve `./priceHistoryReason`.

- [ ] **Step 3: Write the implementation**

Create `web_admin/src/domain/products/priceHistoryReason.ts`:

```ts
// Picks the price_history reason string for an edit, matching the mobile
// literals so derivePriceHistorySource renders "Manual edit". Returns null when
// neither cost nor price moved by more than one centavo. Pure -> relative imports.
const EPS = 0.01;

export function priceHistoryReason(
  oldCost: number,
  oldPrice: number,
  newCost: number,
  newPrice: number,
): string | null {
  const costChanged = Math.abs(newCost - oldCost) > EPS;
  const priceChanged = Math.abs(newPrice - oldPrice) > EPS;
  if (costChanged && priceChanged) return 'Price + cost update';
  if (costChanged) return 'Cost update';
  if (priceChanged) return 'Price update';
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/priceHistoryReason.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/priceHistoryReason.ts web_admin/src/domain/products/priceHistoryReason.test.ts
git commit -m "feat(web-admin): priceHistoryReason helper for inventory edits"
```

---

## Task 2: Repository — skuExists(excludeId), countSkuVariations, updateProductWithSku

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Update the interface**

In `web_admin/src/domain/repositories/ProductRepository.ts`, change the `skuExists`
line and add two methods in the `ProductRepository` interface:

Replace:

```ts
  skuExists(sku: string): Promise<boolean>;
```

with:

```ts
  skuExists(sku: string, excludeId?: string): Promise<boolean>;
  countSkuVariations(baseSku: string): Promise<number>;
  updateProductWithSku(
    id: string,
    input: ProductUpdateInput,
    oldSku: string,
    newSku: string,
    actorId: string,
    actorName: string | null,
  ): Promise<void>;
```

- [ ] **Step 2: Add `limit`, `getDocs`, `writeBatch`, `where` to the firestore imports**

In `web_admin/src/data/repositories/FirestoreProductRepository.ts`, ensure the
`firebase/firestore` import list includes `limit`, `getDocs`, `where`, and add
`writeBatch`. (`limit`, `getDocs`, `where` are already imported from the Slice 1 work;
add `writeBatch` alphabetically next to `where`.)

```ts
  updateDoc,
  where,
  writeBatch,
  type Firestore,
```

- [ ] **Step 3: Implement skuExists(excludeId) (self-excluding)**

Replace the existing `skuExists` body:

```ts
  async skuExists(sku: string): Promise<boolean> {
    return (await this.getBySku(sku)) != null;
  }
```

with:

```ts
  async skuExists(sku: string, excludeId?: string): Promise<boolean> {
    const snap = await getDocs(query(this.col(), where('sku', '==', sku), limit(2)));
    return snap.docs.some((d) => d.id !== excludeId);
  }
```

- [ ] **Step 4: Implement countSkuVariations + updateProductWithSku**

In the same file, immediately after `skuExists`, add:

```ts
  async countSkuVariations(baseSku: string): Promise<number> {
    const snap = await getDocs(query(this.col(), where('baseSku', '==', baseSku)));
    return snap.size;
  }

  async updateProductWithSku(
    id: string,
    input: ProductUpdateInput,
    oldSku: string,
    newSku: string,
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    const batch = writeBatch(this.db);
    // Product doc: reuse updateData so searchKeywords rebuild + whitelist apply.
    batch.update(
      doc(this.db, FirestoreCollections.products, id),
      this.updateData({ ...input, sku: newSku }, actorId),
    );
    // Re-point every variation child (baseSku == oldSku) to the new SKU.
    const children = await getDocs(
      query(collection(this.db, FirestoreCollections.products), where('baseSku', '==', oldSku)),
    );
    for (const child of children.docs) {
      batch.update(child.ref, {
        baseSku: newSku,
        updatedBy: actorId,
        updatedByName: actorName,
        updatedAt: serverTimestamp(),
      });
    }
    await batch.commit();
  }
```

- [ ] **Step 5: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean. (The `bulkReceive`/import callers of `skuExists` pass one arg — still valid since `excludeId` is optional.)

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web-admin): skuExists(excludeId) + countSkuVariations + updateProductWithSku batch"
```

---

## Task 3: `useUpdateProduct` mutation hook

**Files:**
- Create: `web_admin/src/presentation/hooks/useProductMutations.ts`

- [ ] **Step 1: Write the hook**

Create `web_admin/src/presentation/hooks/useProductMutations.ts`:

```ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';

export interface UpdateProductInput {
  id: string;
  oldSku: string;
  patch: ProductUpdateInput;
  /** Set when cost and/or price changed; triggers a best-effort price_history write. */
  priceChange: { price: number; cost: number; reason: string } | null;
}

export function useUpdateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, UpdateProductInput>({
    mutationFn: async ({ id, oldSku, patch, priceChange }) => {
      if (!actor) throw new Error('Not signed in');
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: actor.displayName };
      const skuChanged = fullPatch.sku !== undefined && fullPatch.sku !== oldSku;

      if (skuChanged) {
        const newSku = fullPatch.sku as string;
        if (await repo.skuExists(newSku, id)) {
          throw new Error('A product with this SKU already exists');
        }
        await repo.updateProductWithSku(id, fullPatch, oldSku, newSku, actor.id, actor.displayName);
      } else {
        await repo.update(id, fullPatch, actor.id);
      }

      if (priceChange) {
        try {
          await repo.recordPriceChange(id, {
            price: priceChange.price,
            cost: priceChange.cost,
            changedBy: actor.id,
            reason: priceChange.reason,
          });
        } catch {
          // best-effort, mirroring mobile — never fail the save on a history write
        }
      }

      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/hooks/useProductMutations.ts
git commit -m "feat(web-admin): useUpdateProduct (SKU relink branch + price-history)"
```

---

## Task 4: InventoryFormPage (edit mode)

**Files:**
- Create: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`

- [ ] **Step 1: Write the page**

Create `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`:

```tsx
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { useProduct } from '@/presentation/hooks/useProduct';
import { useUpdateProduct } from '@/presentation/hooks/useProductMutations';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useProductRepo } from '@/infrastructure/di/container';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { priceHistoryReason } from '@/domain/products/priceHistoryReason';
import { encodeCostCode } from '@/domain/entities';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

const schema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  sku: z
    .string()
    .trim()
    .min(1, 'SKU is required')
    .max(50, 'Max 50 characters')
    .regex(/^[A-Za-z0-9-]+$/, 'Use only letters, numbers, and hyphens'),
  barcode: z.string().trim().optional().or(z.literal('')),
  cost: z.coerce.number().min(0, 'Must be ≥ 0'),
  price: z.coerce.number().min(0, 'Must be ≥ 0'),
  reorderLevel: z.coerce.number().int('Whole number').min(0, 'Must be ≥ 0'),
  unit: z.string().trim().min(1, 'Unit is required'),
  category: z.string().optional().or(z.literal('')),
  supplierId: z.string().optional().or(z.literal('')),
  notes: z.string().trim().optional().or(z.literal('')),
});
type FormValues = z.infer<typeof schema>;

const blank = (s: string | undefined) => (s && s.trim() ? s.trim() : null);

/** Build a <select> option list of names that always includes `current`, even
 *  if it is no longer in the active list (so an orphaned value isn't dropped). */
function withCurrent(names: string[], current: string | null): string[] {
  if (current && !names.includes(current)) return [current, ...names];
  return names;
}

export function InventoryFormPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const repo = useProductRepo();

  const { data: target, isLoading, error } = useProduct(id);
  const update = useUpdateProduct();
  const { data: productCats } = useActiveCategories(CategoryKind.product);
  const { data: units } = useActiveCategories(CategoryKind.unit);
  const { data: suppliers } = useSuppliers();
  const { data: costCodeMapping } = useCostCode();

  const [skuDialog, setSkuDialog] = useState<{ open: boolean; count: number; values: FormValues | null }>(
    { open: false, count: 0, values: null },
  );

  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: '', sku: '', barcode: '', cost: 0, price: 0, reorderLevel: 0,
      unit: 'pcs', category: '', supplierId: '', notes: '',
    },
  });

  useEffect(() => {
    document.title = target ? `Edit ${target.name} · Inventory` : 'Edit product';
  }, [target]);

  useEffect(() => {
    if (!target) return;
    reset({
      name: target.name,
      sku: target.sku,
      barcode: target.barcode ?? '',
      cost: target.cost,
      price: target.price,
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
  // Active suppliers + the currently-saved one even if now inactive.
  const supplierOptions = useMemo(() => {
    const active = (suppliers ?? []).filter((s) => s.isActive);
    if (target?.supplierId && !active.some((s) => s.id === target.supplierId)) {
      const saved = (suppliers ?? []).find((s) => s.id === target.supplierId);
      if (saved) return [saved, ...active];
    }
    return active;
  }, [suppliers, target?.supplierId]);

  if (error) return <ErrorView title="Could not load product" message={error.message} />;
  if (isLoading || !target) return <LoadingView label="Loading product…" />;

  const submitting = isSubmitting || update.isPending;
  const mutationError = update.error?.message ?? null;

  const doSave = async (values: FormValues) => {
    const costNum = Number(values.cost);
    const priceNum = Number(values.price);
    const reason = priceHistoryReason(target.cost, target.price, costNum, priceNum);
    const costChanged = Math.abs(costNum - target.cost) > 0.01;
    // Re-encode costCode from the new cost so mobile's cost-code display stays correct.
    const costCode =
      costChanged && costCodeMapping ? encodeCostCode(costCodeMapping, costNum) : target.costCode;
    const supplier = (suppliers ?? []).find((s) => s.id === values.supplierId);

    const patch: ProductUpdateInput = {
      name: values.name.trim(),
      sku: values.sku.trim(),
      category: blank(values.category),
      cost: costNum,
      costCode,
      price: priceNum,
      reorderLevel: Number(values.reorderLevel),
      unit: values.unit.trim() || 'pcs',
      supplierId: values.supplierId || null,
      supplierName: supplier?.name ?? null,
      barcode: blank(values.barcode),
      notes: blank(values.notes),
    };

    try {
      await update.mutateAsync({
        id: target.id,
        oldSku: target.sku,
        patch,
        priceChange: reason ? { price: priceNum, cost: costNum, reason } : null,
      });
      navigate(RoutePaths.inventory);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Save failed';
      if (msg.toLowerCase().includes('sku already exists')) {
        setError('sku', { type: 'duplicate', message: msg });
      }
    }
  };

  const onSubmit = async (values: FormValues) => {
    if (values.sku.trim() !== target.sku) {
      const count = await repo.countSkuVariations(target.sku);
      setSkuDialog({ open: true, count, values });
      return;
    }
    await doSave(values);
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
          Edit product
        </h1>
      </header>

      {mutationError && !errors.sku ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {mutationError}
        </p>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-tk-lg" noValidate>
        <Section title="Identity">
          <Field label="Name" error={errors.name?.message}
            input={<input type="text" className={inputCls(!!errors.name)} {...register('name')} />} />
          <Field label="SKU" error={errors.sku?.message}
            input={<input type="text" className={inputCls(!!errors.sku)} {...register('sku')} />} />
          <p className="text-[12px] text-light-text-hint">
            Changing the SKU keeps past sales &amp; receiving records on the old code and re-points linked variations.
          </p>
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
            {submitting ? 'Saving…' : 'Save changes'}
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
            <span className="font-mono">{target.sku}</span>
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
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean. (If `encodeCostCode` isn't re-exported from `@/domain/entities`, import it from `@/domain/entities/CostCode` instead — verify the export.)

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryFormPage.tsx
git commit -m "feat(web-admin): inventory edit form (dropdowns, SKU-change confirm, price-history)"
```

---

## Task 5: Wire the edit route + detail-page Edit button

**Files:**
- Modify: `web_admin/src/presentation/router/routes.tsx`
- Modify: `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`

- [ ] **Step 1: Wire the route**

In `routes.tsx`, add the import after the other inventory imports:

```tsx
import { InventoryFormPage } from '@/presentation/features/inventory/InventoryFormPage';
```

Replace:

```tsx
        { path: RoutePaths.productEdit, element: placeholder('Edit product', 'phase 7') },
```

with:

```tsx
        { path: RoutePaths.productEdit, element: <InventoryFormPage /> },
```

- [ ] **Step 2: Add the Edit button to the detail page**

In `InventoryDetailPage.tsx`, add to the imports:

```tsx
import { generatePath } from 'react-router-dom';
import { PencilSquareIcon } from '@heroicons/react/24/outline';
```

(Adjust the existing `react-router-dom` import to include `generatePath` alongside `Link`/`useParams`, and add `PencilSquareIcon` to the heroicons import.)

Then, in the `<header>` block (which already has the right-aligned `Inactive` badge area), add an Edit link. Replace the header's closing — find the `{!product.isActive ? (... Inactive badge ...) : null}` and wrap the right side so the Edit link always shows:

```tsx
        <div className="flex items-center gap-tk-sm">
          {!product.isActive ? (
            <span className="rounded-full bg-light-subtle px-tk-sm py-[2px] text-[11px] font-medium text-light-text-secondary">
              Inactive
            </span>
          ) : null}
          <Link
            to={generatePath(RoutePaths.productEdit, { id: product.id })}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <PencilSquareIcon className="h-4 w-4" /> Edit
          </Link>
        </div>
```

(Replace the existing standalone `{!product.isActive ? (...) : null}` node in the header with this `<div>`.)

- [ ] **Step 3: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: tsc clean; build succeeds.

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/router/routes.tsx web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx
git commit -m "feat(web-admin): wire /inventory/edit/:id + detail-page Edit button"
```

---

## Task 6: Final gates

- [ ] **Step 1: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 2: Unit tests**

Run: `cd web_admin && npx vitest run --environment=node`
Expected: all suites pass (existing 72 + `priceHistoryReason`).

- [ ] **Step 3: Build**

Run: `cd web_admin && npm run build`
Expected: succeeds.

- [ ] **Step 4: Manual smoke (optional)**

As an admin: open a product → Edit → change price (confirm a `price_history` entry
appears in the Price History view labeled "Manual edit"); change category/unit/supplier;
change the SKU (confirm dialog shows old→new + variation count; after save the product
and any variation children carry the new SKU); re-edit with the SAME SKU (must save with
no false duplicate error).

---

## Self-Review notes (author)

- **Spec coverage (2a portion):** §3.1 skuExists(excludeId) → T2; §3.4 relink → T2; §3.5 keyword rebuild (always send name+sku+category) → T4 patch; §4 useUpdateProduct → T3; §5 edit form (fields, dropdowns+orphan, SKU confirm, costCode re-encode, price-history) → T4; §7 priceHistoryReason → T1; §8 detail Edit button → T5; §10 route → T5.
- **Deferred to Slice 2b:** Adjust-Stock dialog, deactivate/reactivate, show-inactive toggle, the `setStock`/`adjustStock`/`deactivate`/`reactivate` repo impls + their hooks, `resolveStockChange` helper.
- **Type consistency:** `priceHistoryReason(oldCost,oldPrice,newCost,newPrice)`, `UpdateProductInput{id,oldSku,patch,priceChange}`, `skuExists(sku,excludeId?)`, `countSkuVariations`, `updateProductWithSku(id,input,oldSku,newSku,actorId,actorName)` are used identically across tasks.
- **Admin-only:** no per-role gating (web shell enforces). The patch always includes name+sku+category so searchKeywords rebuild from consistent values.
