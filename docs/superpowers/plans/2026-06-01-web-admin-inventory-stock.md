# Web Inventory Slice 2b — Stock adjust + deactivate/reactivate + show-inactive — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Let an admin adjust a product's stock (Add/Remove/Set), soft-delete (deactivate) and reactivate products from the web, and reveal inactive products via a list toggle.

**Architecture:** Implement the three thrown repo stubs (`adjustStock`/`setStock`/`deactivate`) + add `reactivate`, all stamping audit fields; Add/Remove use Firestore `increment` (concurrency-safe), Set writes an absolute value. A pure `resolveStockChange` helper drives an `AdjustStockDialog`; the detail page gains an action bar (Adjust / Delete / Reactivate); the list gains a Show-inactive toggle. **Admin-only** (web shell enforces). Continues Slice 2a.

**Tech Stack:** React, TypeScript, React Router v6, TanStack Query v5, Firebase Firestore, Tailwind, Vitest. Spec: `docs/superpowers/specs/2026-06-01-web-admin-inventory-edit-design.md` (Slice **2b** portion). Run from `web_admin/`.

**Toolchain:** typecheck `npx tsc --noEmit -p tsconfig.json`; logic tests `--environment=node`; tested modules use **relative imports**.

---

## Context verified (slice2-understand workflow + current code)

- Stubs at `FirestoreProductRepository.ts:213-221` are zero-arg and throw. Interface (`ProductRepository.ts:37-39`): `adjustStock(id,delta,actorId)`, `setStock(id,quantity,actorId)`, `deactivate(id,actorId)` — **no `actorName`, no `reactivate`**.
- Mobile stock dialog = 3 modes `add`/`remove`/`set`; add→`+qty` increment, remove→`-qty` increment, set→absolute. Validation: qty>0 for add/remove; set≥0; remove ≤ current. Reason/Note is a non-functional stub on mobile → **omit**. No activity-log, no price_history on stock change.
- Deactivate = soft-delete (`isActive:false` + audit), shown to users as **"Delete"** (red) with copy "hidden from POS and inventory lists; past sales and receivings remain intact." Reactivate is **net-new on web**.
- `InventoryDetailPage.tsx` (post-2a): header has an Edit `<Link>` (lines 59-71); cards grid; a "View price history" `<Link>` (lines 100-106). It's a function component with early returns after `useProduct(id)` — new hooks/state must go **before** the returns.
- `InventoryListPage.tsx:35` `const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products])` feeds counts/category/table; the filter row is ~lines 80-95. `cn` is imported.
- `Dialog` props `{open,onClose,title,dismissable?,children}`; `Spinner` takes `className`. Tailwind status tokens: `text-success-dark`/`text-warning-dark`/`text-error-dark`.
- `useProductMutations.ts` already exports `useUpdateProduct`; extend it. Mutations invalidate `['product', id]` (detail refetch); the list `watchAll` auto-updates.

## File Structure

**Create:** `domain/products/resolveStockChange.ts` (+test), `presentation/features/inventory/AdjustStockDialog.tsx`.
**Modify:** `domain/repositories/ProductRepository.ts`, `data/repositories/FirestoreProductRepository.ts`, `presentation/hooks/useProductMutations.ts`, `presentation/features/inventory/InventoryDetailPage.tsx`, `presentation/features/inventory/InventoryListPage.tsx`.

---

## Task 1: `resolveStockChange` pure helper

**Files:**
- Create: `web_admin/src/domain/products/resolveStockChange.ts`
- Test: `web_admin/src/domain/products/resolveStockChange.test.ts`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/products/resolveStockChange.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { resolveStockChange } from './resolveStockChange';

describe('resolveStockChange', () => {
  it('adds to current', () => {
    expect(resolveStockChange('add', 5, 3)).toBe(8);
  });
  it('removes from current', () => {
    expect(resolveStockChange('remove', 5, 3)).toBe(2);
  });
  it('sets the absolute value', () => {
    expect(resolveStockChange('set', 5, 3)).toBe(3);
  });
  it('can go negative on remove (validation is the caller’s job)', () => {
    expect(resolveStockChange('remove', 2, 5)).toBe(-3);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/resolveStockChange.test.ts`
Expected: FAIL — cannot resolve `./resolveStockChange`.

- [ ] **Step 3: Write the implementation**

Create `web_admin/src/domain/products/resolveStockChange.ts`:

```ts
// Resulting quantity for a stock adjustment. Pure -> relative imports. The
// caller validates (qty>0 for add/remove, set>=0, remove<=current).
export type StockMode = 'add' | 'remove' | 'set';

export function resolveStockChange(mode: StockMode, current: number, qty: number): number {
  if (mode === 'add') return current + qty;
  if (mode === 'remove') return current - qty;
  return qty;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/resolveStockChange.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/resolveStockChange.ts web_admin/src/domain/products/resolveStockChange.test.ts
git commit -m "feat(web-admin): resolveStockChange helper"
```

---

## Task 2: Implement stock + deactivate/reactivate repo methods

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Update the interface signatures**

In `ProductRepository.ts`, replace:

```ts
  adjustStock(id: string, delta: number, actorId: string): Promise<void>;
  setStock(id: string, quantity: number, actorId: string): Promise<void>;
  deactivate(id: string, actorId: string): Promise<void>;
```

with:

```ts
  adjustStock(id: string, delta: number, actorId: string, actorName: string | null): Promise<void>;
  setStock(id: string, quantity: number, actorId: string, actorName: string | null): Promise<void>;
  deactivate(id: string, actorId: string, actorName: string | null): Promise<void>;
  reactivate(id: string, actorId: string, actorName: string | null): Promise<void>;
```

- [ ] **Step 2: Add `increment` to the firestore imports**

In `FirestoreProductRepository.ts`, add `increment` to the `firebase/firestore`
import list (alphabetically, next to `getDocs`):

```ts
  getDocs,
  increment,
  limit,
```

- [ ] **Step 3: Replace the three thrown stubs + add reactivate**

In `FirestoreProductRepository.ts`, replace:

```ts
  async adjustStock(): Promise<void> {
    throw new Error('ProductRepository.adjustStock not implemented yet (phase 7)');
  }
  async setStock(): Promise<void> {
    throw new Error('ProductRepository.setStock not implemented yet (phase 7)');
  }
  async deactivate(): Promise<void> {
    throw new Error('ProductRepository.deactivate not implemented yet (phase 7)');
  }
```

with:

```ts
  async adjustStock(id: string, delta: number, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      quantity: increment(delta),
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async setStock(id: string, quantity: number, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      quantity,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async deactivate(id: string, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      isActive: false,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
  async reactivate(id: string, actorId: string, actorName: string | null): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      isActive: true,
      updatedBy: actorId,
      updatedByName: actorName,
      updatedAt: serverTimestamp(),
    });
  }
```

- [ ] **Step 4: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web-admin): implement adjustStock/setStock/deactivate + reactivate"
```

---

## Task 3: Stock + deactivate/reactivate mutation hooks

**Files:**
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts`

- [ ] **Step 1: Append the hooks**

At the end of `useProductMutations.ts`, add:

```ts
export function useAdjustStock() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; delta: number }>({
    mutationFn: async ({ id, delta }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.adjustStock(id, delta, actor.id, actor.displayName);
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useSetStock() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { id: string; quantity: number }>({
    mutationFn: async ({ id, quantity }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.setStock(id, quantity, actor.id, actor.displayName);
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useDeactivateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, string>({
    mutationFn: async (id) => {
      if (!actor) throw new Error('Not signed in');
      await repo.deactivate(id, actor.id, actor.displayName);
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
  });
}

export function useReactivateProduct() {
  const repo = useProductRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, string>({
    mutationFn: async (id) => {
      if (!actor) throw new Error('Not signed in');
      await repo.reactivate(id, actor.id, actor.displayName);
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
git commit -m "feat(web-admin): stock + deactivate/reactivate mutation hooks"
```

---

## Task 4: AdjustStockDialog component

**Files:**
- Create: `web_admin/src/presentation/features/inventory/AdjustStockDialog.tsx`

- [ ] **Step 1: Write the component**

Create `web_admin/src/presentation/features/inventory/AdjustStockDialog.tsx`:

```tsx
import { useState } from 'react';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { useAdjustStock, useSetStock } from '@/presentation/hooks/useProductMutations';
import { resolveStockChange, type StockMode } from '@/domain/products/resolveStockChange';
import type { Product } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

const MODES: { value: StockMode; label: string }[] = [
  { value: 'add', label: 'Add' },
  { value: 'remove', label: 'Remove' },
  { value: 'set', label: 'Set to' },
];

export function AdjustStockDialog({
  product,
  open,
  onClose,
}: {
  product: Product;
  open: boolean;
  onClose: () => void;
}) {
  const [mode, setMode] = useState<StockMode>('add');
  const [qtyText, setQtyText] = useState('');
  const adjust = useAdjustStock();
  const setStock = useSetStock();
  const busy = adjust.isPending || setStock.isPending;

  const qty = Number(qtyText);
  const numericOk = qtyText.trim() !== '' && Number.isInteger(qty) && qty >= 0;

  let err: string | null = null;
  if (qtyText.trim() !== '') {
    if (!Number.isInteger(qty) || qty < 0) err = 'Enter a whole number ≥ 0';
    else if ((mode === 'add' || mode === 'remove') && qty <= 0) err = 'Quantity must be greater than 0';
    else if (mode === 'remove' && qty > product.quantity) err = 'Cannot remove more than current stock';
  }

  const showPreview = numericOk && !err;
  const newQty = showPreview ? resolveStockChange(mode, product.quantity, qty) : product.quantity;
  const previewColor =
    newQty <= 0 ? 'text-error-dark' : newQty <= product.reorderLevel ? 'text-warning-dark' : 'text-success-dark';
  const canApply = showPreview && !busy;

  const apply = async () => {
    if (mode === 'set') await setStock.mutateAsync({ id: product.id, quantity: qty });
    else await adjust.mutateAsync({ id: product.id, delta: mode === 'add' ? qty : -qty });
    setQtyText('');
    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={() => { if (!busy) { setQtyText(''); onClose(); } }}
      title="Adjust stock"
      dismissable={!busy}
    >
      <div className="space-y-tk-md">
        <div className="inline-flex rounded-md border border-light-hairline p-[2px]">
          {MODES.map((m) => (
            <button
              key={m.value}
              type="button"
              onClick={() => setMode(m.value)}
              className={cn(
                'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
                mode === m.value
                  ? 'bg-light-subtle font-semibold text-light-text'
                  : 'text-light-text-secondary hover:text-light-text',
              )}
            >
              {m.label}
            </button>
          ))}
        </div>

        <div>
          <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">Quantity</label>
          <input
            type="number"
            inputMode="numeric"
            value={qtyText}
            onChange={(e) => setQtyText(e.target.value)}
            autoFocus
            className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
          />
          {err ? <p className="mt-tk-xs text-[12px] text-error">{err}</p> : null}
        </div>

        <p className="text-bodySmall text-light-text-secondary">
          New quantity:{' '}
          <span className={cn('font-semibold', showPreview ? previewColor : 'text-light-text-hint')}>
            {showPreview ? newQty : '—'}
          </span>{' '}
          {product.unit}
        </p>

        <div className="flex justify-end gap-tk-sm pt-tk-sm">
          <button
            type="button"
            disabled={busy}
            onClick={() => { setQtyText(''); onClose(); }}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={!canApply}
            onClick={apply}
            className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
          >
            {busy ? <Spinner className="h-3.5 w-3.5" /> : null} Apply
          </button>
        </div>
      </div>
    </Dialog>
  );
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/inventory/AdjustStockDialog.tsx
git commit -m "feat(web-admin): AdjustStockDialog (add/remove/set, live preview)"
```

---

## Task 5: Detail page — Adjust / Delete / Reactivate actions

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`

- [ ] **Step 1: Add imports**

In `InventoryDetailPage.tsx`, change the `react` import to include `useState`, add
icons, and import the dialog + hooks:

```tsx
import { useEffect, useState, type ReactNode } from 'react';
```

Add to the heroicons import (which already has `ArrowLeftIcon, ClockIcon, PencilSquareIcon`): `AdjustmentsHorizontalIcon, ArrowPathIcon, TrashIcon`.

After the existing imports, add:

```tsx
import { AdjustStockDialog } from './AdjustStockDialog';
import { useDeactivateProduct, useReactivateProduct } from '@/presentation/hooks/useProductMutations';
import { Dialog } from '@/presentation/components/common/Dialog';
```

- [ ] **Step 2: Add state + hooks before the early returns**

Immediately after `const { data: product, isLoading, error } = useProduct(id);`, add:

```tsx
  const [adjustOpen, setAdjustOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const deactivate = useDeactivateProduct();
  const reactivate = useReactivateProduct();
```

- [ ] **Step 3: Add the action buttons to the header**

In the header's right-side `<div className="flex items-center gap-tk-sm">` (which has the
Inactive badge + Edit link), add an Adjust button and a Delete/Reactivate button. Replace
that whole `<div>…</div>` block with:

```tsx
        <div className="flex flex-wrap items-center gap-tk-sm">
          {!product.isActive ? (
            <span className="rounded-full bg-light-subtle px-tk-sm py-[2px] text-[11px] font-medium text-light-text-secondary">
              Inactive
            </span>
          ) : null}
          <button
            type="button"
            onClick={() => setAdjustOpen(true)}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <AdjustmentsHorizontalIcon className="h-4 w-4" /> Adjust stock
          </button>
          <Link
            to={generatePath(RoutePaths.productEdit, { id: product.id })}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <PencilSquareIcon className="h-4 w-4" /> Edit
          </Link>
          {product.isActive ? (
            <button
              type="button"
              onClick={() => setConfirmDelete(true)}
              className="inline-flex items-center gap-tk-xs rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall text-error-dark hover:bg-error-light/40"
            >
              <TrashIcon className="h-4 w-4" /> Delete
            </button>
          ) : (
            <button
              type="button"
              disabled={reactivate.isPending}
              onClick={() => reactivate.mutate(product.id)}
              className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
            >
              <ArrowPathIcon className="h-4 w-4" /> Reactivate
            </button>
          )}
        </div>
```

- [ ] **Step 4: Add the dialogs before the component's closing `</div>`**

Just before the final `</div>` that closes the page (after the "View price history"
`<Link>` block), add:

```tsx
      <AdjustStockDialog product={product} open={adjustOpen} onClose={() => setAdjustOpen(false)} />

      <Dialog
        open={confirmDelete}
        onClose={() => { if (!deactivate.isPending) setConfirmDelete(false); }}
        title="Delete Product?"
        dismissable={!deactivate.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text-secondary">
            Delete “{product.name}”? This product will be hidden from POS and inventory lists.
            Past sales and receivings that reference it remain intact.
          </p>
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button
              type="button"
              disabled={deactivate.isPending}
              onClick={() => setConfirmDelete(false)}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={deactivate.isPending}
              onClick={async () => { await deactivate.mutateAsync(product.id); setConfirmDelete(false); }}
              className="inline-flex items-center gap-tk-xs rounded-md bg-error-dark px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:opacity-90 disabled:opacity-60"
            >
              {deactivate.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
            </button>
          </div>
        </div>
      </Dialog>
```

Add `Spinner` to the `LoadingView` import: change
`import { LoadingView } from '@/presentation/components/common/LoadingView';` to
`import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';`.

- [ ] **Step 5: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: tsc clean; build succeeds.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx
git commit -m "feat(web-admin): detail-page Adjust stock / Delete / Reactivate actions"
```

---

## Task 6: List page — Show-inactive toggle

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryListPage.tsx`

- [ ] **Step 1: Add the EyeIcon/EyeSlashIcon imports + state**

In `InventoryListPage.tsx`, change the heroicons import to add `EyeIcon, EyeSlashIcon`
alongside `MagnifyingGlassIcon`:

```tsx
import { EyeIcon, EyeSlashIcon, MagnifyingGlassIcon } from '@heroicons/react/24/outline';
```

Add a state hook next to the other `useState`s (e.g. after `const [category, setCategory] = ...`):

```tsx
  const [showInactive, setShowInactive] = useState(false);
```

- [ ] **Step 2: Make the `active` memo honor the toggle**

Replace:

```tsx
  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
```

with:

```tsx
  const active = useMemo(
    () => (showInactive ? (products ?? []) : (products ?? []).filter((p) => p.isActive)),
    [products, showInactive],
  );
```

(Counts, category list, and the table all derive from `active`, so the toggle updates them all.)

- [ ] **Step 3: Add the toggle button to the filter row**

In the filter row (the `<div className="flex flex-wrap items-center gap-tk-sm">` holding
the search input and category `<select>`), add after the category `<select>`:

```tsx
        <button
          type="button"
          onClick={() => setShowInactive((v) => !v)}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
        >
          {showInactive ? <EyeSlashIcon className="h-3.5 w-3.5" /> : <EyeIcon className="h-3.5 w-3.5" />}
          {showInactive ? 'Hide inactive' : 'Show inactive'}
        </button>
```

- [ ] **Step 4: Mute inactive rows in the table**

In the table `<tr>` for each product, replace:

```tsx
                  <tr
                    key={p.id}
                    onClick={() => navigate(`/inventory/${p.id}`)}
                    className="cursor-pointer hover:bg-light-subtle"
                  >
```

with:

```tsx
                  <tr
                    key={p.id}
                    onClick={() => navigate(`/inventory/${p.id}`)}
                    className={cn('cursor-pointer hover:bg-light-subtle', !p.isActive && 'opacity-50')}
                  >
```

And in that row's Name cell, append an inactive marker — replace:

```tsx
                    <Td className="font-medium text-light-text">{p.name}</Td>
```

with:

```tsx
                    <Td className="font-medium text-light-text">
                      {p.name}
                      {!p.isActive ? <span className="ml-tk-xs text-light-text-hint">(inactive)</span> : null}
                    </Td>
```

- [ ] **Step 5: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: tsc clean; build succeeds.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryListPage.tsx
git commit -m "feat(web-admin): inventory list show-inactive toggle"
```

---

## Task 7: Final gates

- [ ] **Step 1: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 2: Unit tests**

Run: `cd web_admin && npx vitest run --environment=node`
Expected: all suites pass (existing 76 + `resolveStockChange`).

- [ ] **Step 3: Build**

Run: `cd web_admin && npm run build`
Expected: succeeds.

- [ ] **Step 4: Manual smoke (optional)**

As an admin: open a product → Adjust stock → Add/Remove/Set with live preview + the three
validations; quantity updates. Delete → confirm → product leaves the default list; "Show
inactive" reveals it greyed with "(inactive)"; open it → Reactivate restores it.

---

## Self-Review notes (author)

- **Spec coverage (2b portion):** §3.2 stub impls (+actorName) → T2; §3.3 reactivate → T2; §6 Adjust-Stock dialog (3 modes, increment/absolute, validation, preview) → T1+T4; §8 detail actions (Adjust/Delete/Reactivate, "Delete" copy) → T5; §9 show-inactive toggle → T6; §7 resolveStockChange → T1.
- **Deliberate omissions (per spec):** no Reason/Note field; no activity-log; no price_history on stock change; the "View price history" link is left as-is (admin-only shell makes the `viewProductCost` gate a no-op).
- **Type consistency:** `StockMode='add'|'remove'|'set'`, `resolveStockChange(mode,current,qty)`, `useAdjustStock({id,delta})`/`useSetStock({id,quantity})`/`useDeactivateProduct(id)`/`useReactivateProduct(id)`, repo methods all gain `actorName: string|null` — used identically across tasks.
- **Concurrency:** Add/Remove use `increment` (race-safe); Set is absolute (mobile-parity lost-update risk, accepted).
