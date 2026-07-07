# Web POS — Checkout & Draft-Edit Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two placeholder routes with real dedicated screens — `/pos/checkout` (standalone payment step) and `/drafts/:id` (in-place held-order editor).

**Architecture:** Slice 1 (Checkout) moves the payment block off `PosPage` onto a new `CheckoutPage` that reads the existing global cart store; no refactor needed. Slice 2 (Draft edit) turns `cartStore` into a factory so a second store instance backs a draft editor, extracts the cart-editing UI into a shared `CartBuilder`, and adds `DraftEditPage`.

**Tech Stack:** React 18, TypeScript, Zustand, TanStack Query, react-router-dom v6, Tailwind, Vitest + Testing Library.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-07-web-pos-checkout-and-draft-edit-screens-design.md`.
- Work on branch `feat/web-checkout-draft-edit`.
- No changes to the sale-write path, `usePaymentDraft`/payment helpers, `useCheckout`, draft schema, Firestore rules, or reporting.
- Both routes already pass the guards (`/pos/checkout` is a common route; `/drafts/*` is treated as common in `routeGuards.ts`) — do NOT touch `routeGuards.ts`.
- Run commands from inside `web_admin/`. Verify with `npm run typecheck` and `npm run test`.
- Money via `formatMoney`; existing token classes (`tk-*`, `light-*`, `bodySmall`, etc.); primary button `bg-light-text text-light-background hover:bg-primary-dark`.
- Keep the existing resume-into-POS flow and the Save-as-draft dialog on `/pos` unchanged.

---

# Slice 1 — Checkout screen (`/pos/checkout`)

Independent of the store refactor. Ships first.

### Task 1: `OrderSummary` — read-only cart summary component

**Files:**
- Create: `src/presentation/features/pos/OrderSummary.tsx`
- Test: `src/presentation/features/pos/OrderSummary.test.tsx`

**Interfaces:**
- Consumes: `cartSubtotal`, `cartDiscount`, `cartGrandTotal` from `@/domain/sales/cart`; `cartLaborSubtotal`, `describedLaborLines` from `@/domain/sales/labor`; `saleItemNet` from `@/domain/entities/SaleItem`; `DiscountType` from `@/domain/enums/DiscountType`; `formatMoney`.
- Produces: `export function OrderSummary({ lines, discountType, laborLines }: { lines: CartLine[]; discountType: DiscountType; laborLines: LaborLine[] }): JSX.Element`

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OrderSummary } from './OrderSummary';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { CartLine } from '@/domain/sales/cart';
import type { LaborLine } from '@/domain/entities/LaborLine';

const line: CartLine = {
  id: 'p1', productId: 'p1', sku: 'OIL-AX7', name: 'Shell AX7 Oil',
  unitPrice: 320, unitCost: 210, quantity: 2, discountValue: 0, unit: 'pcs',
};
const labor: LaborLine = { id: 'l1', description: 'Change oil', fee: 150 };

describe('OrderSummary', () => {
  it('lists items with net line totals and a grand total including labor', () => {
    render(<OrderSummary lines={[line]} discountType={DiscountType.amount} laborLines={[labor]} />);
    expect(screen.getByText('Shell AX7 Oil')).toBeInTheDocument();
    expect(screen.getByText(/Change oil/)).toBeInTheDocument();
    // 2×320 = 640 items + 150 labor = 790 total
    expect(screen.getByText('₱790.00')).toBeInTheDocument();
  });

  it('renders a labor row only when labor exists', () => {
    render(<OrderSummary lines={[line]} discountType={DiscountType.amount} laborLines={[]} />);
    expect(screen.queryByText('Labor')).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test -- OrderSummary`
Expected: FAIL — cannot find module `./OrderSummary`.

- [ ] **Step 3: Write minimal implementation**

```tsx
import { cartSubtotal, cartDiscount, cartGrandTotal, type CartLine } from '@/domain/sales/cart';
import { cartLaborSubtotal, describedLaborLines } from '@/domain/sales/labor';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { LaborLine } from '@/domain/entities/LaborLine';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export function OrderSummary({
  lines,
  discountType,
  laborLines,
}: {
  lines: CartLine[];
  discountType: DiscountType;
  laborLines: LaborLine[];
}) {
  const isPct = discountType === DiscountType.percentage;
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const labor = cartLaborSubtotal(laborLines);
  const total = cartGrandTotal(lines, laborLines, discountType);
  const described = describedLaborLines(laborLines);

  return (
    <div className="rounded-lg border border-light-hairline bg-light-card">
      <div className="border-b border-light-hairline px-tk-md py-tk-sm text-bodyMedium font-semibold text-light-text">
        Order summary
      </div>
      <ul className="divide-y divide-light-hairline">
        {lines.map((l) => (
          <li key={l.productId} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm text-bodySmall">
            <span className="min-w-0">
              <span className="block text-light-text">{l.name}</span>
              <span className="block text-[12px] text-light-text-hint">
                {l.quantity} × {formatMoney(l.unitPrice)}
              </span>
            </span>
            <span className="font-medium text-light-text tabular-nums">{formatMoney(saleItemNet(l, isPct))}</span>
          </li>
        ))}
        {described.map((l) => (
          <li key={l.id} className="flex items-center justify-between gap-tk-md bg-light-subtle px-tk-md py-tk-sm text-bodySmall">
            <span className="text-light-text">🔧 {l.description || 'Service'}</span>
            <span className="font-medium text-light-text tabular-nums">{formatMoney(l.fee)}</span>
          </li>
        ))}
      </ul>
      <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
        <Row label="Subtotal" value={formatMoney(subtotal)} />
        <Row label="Discount" value={`− ${formatMoney(discount)}`} />
        {labor > 0 ? <Row label="Labor" value={formatMoney(labor)} /> : null}
        <Row label="Total" value={formatMoney(total)} strong />
      </dl>
    </div>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div className="flex justify-between">
      <dt className="text-light-text-hint">{label}</dt>
      <dd className={cn('text-light-text tabular-nums', strong && 'font-semibold')}>{value}</dd>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test -- OrderSummary`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add src/presentation/features/pos/OrderSummary.tsx src/presentation/features/pos/OrderSummary.test.tsx
git commit -m "feat(web): OrderSummary read-only cart summary for checkout"
```

---

### Task 2: `CheckoutPage` — guard, payment, complete, success handoff

**Files:**
- Create: `src/presentation/features/pos/CheckoutPage.tsx`
- Test: `src/presentation/features/pos/CheckoutPage.test.tsx`

**Interfaces:**
- Consumes: `useCartStore` (global), `usePaymentDraft`, `useCheckout`, `describedLaborLines`, `cartGrandTotal`, `PaymentSection`, `OrderSummary` (Task 1), `RoutePaths`, react-router `Navigate`/`useNavigate`.
- Produces: `export function CheckoutPage(): JSX.Element`. On success it navigates to `RoutePaths.pos` with router state `{ completedSaleNumber: string }`.

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { CheckoutPage } from './CheckoutPage';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Product } from '@/domain/entities';

const product = (o: Partial<Product> = {}): Product =>
  ({ id: 'p1', sku: 'A', name: 'Plug', price: 100, cost: 60, unit: 'pcs', quantity: 9, isActive: true, ...o } as Product);

function harness(saleRepo: Partial<Container['saleRepo']>) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  return render(
    <DiProvider override={{ saleRepo: saleRepo as Container['saleRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/pos/checkout']}>
          <Routes>
            <Route path="/pos/checkout" element={<CheckoutPage />} />
            <Route path="/pos" element={<div>POS PAGE {`${history.state}`}</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('CheckoutPage', () => {
  it('redirects to /pos when the cart is empty', () => {
    useCartStore.getState().clear();
    harness({ create: vi.fn() });
    expect(screen.getByText(/POS PAGE/)).toBeInTheDocument();
  });

  it('completes the sale and returns to /pos', async () => {
    useCartStore.getState().clear();
    useCartStore.getState().addLine(product());
    useAuthStore.setState({ user: { id: 'u1', email: 'a@b.co', displayName: 'Cashier', role: 'admin', isActive: true } as never });
    const create = vi.fn().mockResolvedValue({ id: 's1', saleNumber: 'S-00100' });
    harness({ create });
    await userEvent.click(screen.getByRole('button', { name: /complete sale/i }));
    await waitFor(() => expect(create).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(screen.getByText(/POS PAGE/)).toBeInTheDocument());
    expect(useCartStore.getState().lines).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test -- CheckoutPage`
Expected: FAIL — cannot find module `./CheckoutPage`.

- [ ] **Step 3: Write minimal implementation**

```tsx
import { useEffect } from 'react';
import { Navigate, Link, useNavigate } from 'react-router-dom';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';
import { cartGrandTotal } from '@/domain/sales/cart';
import { describedLaborLines } from '@/domain/sales/labor';
import { RoutePaths } from '@/presentation/router/routePaths';
import { PaymentSection } from './PaymentSection';
import { OrderSummary } from './OrderSummary';
import { cn } from '@/core/utils/cn';

export function CheckoutPage() {
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
  const draftId = useCartStore((s) => s.draftId);
  const clear = useCartStore((s) => s.clear);
  const checkout = useCheckout();
  const navigate = useNavigate();

  const grandTotal = cartGrandTotal(lines, laborLines, discountType);
  const pay = usePaymentDraft(grandTotal);

  useEffect(() => {
    document.title = 'Checkout';
  }, []);

  if (lines.length === 0) return <Navigate to={RoutePaths.pos} replace />;

  const canComplete = pay.isValid && !checkout.isPending;
  const onComplete = async () => {
    try {
      const sale = await checkout.mutateAsync({
        lines,
        discountType,
        paymentMethod: pay.paymentMethod,
        tenders: pay.tenders,
        amountReceived: pay.amountReceived,
        changeGiven: pay.changeGiven,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
        draftId,
      });
      pay.reset();
      clear();
      navigate(RoutePaths.pos, { state: { completedSaleNumber: sale.saleNumber } });
    } catch {
      // surfaced via checkout.error
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-tk-md px-tk-xl py-tk-lg">
      <Link to={RoutePaths.pos} className="text-bodySmall text-light-text-secondary hover:text-light-text">
        ← Back to cart
      </Link>
      <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Checkout</h1>

      {checkout.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {checkout.error.message}
        </p>
      ) : null}

      <OrderSummary lines={lines} discountType={discountType} laborLines={laborLines} />

      <div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
        <PaymentSection pay={pay} grandTotal={grandTotal} />
        <button
          type="button"
          disabled={!canComplete}
          onClick={onComplete}
          className={cn(
            'w-full rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
            !canComplete && 'cursor-not-allowed opacity-60',
          )}
        >
          {checkout.isPending ? 'Completing…' : 'Complete sale'}
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test -- CheckoutPage`
Expected: PASS (2 tests). If the auth-store shape differs, match the existing `authStore` `User` type.

- [ ] **Step 5: Commit**

```bash
git add src/presentation/features/pos/CheckoutPage.tsx src/presentation/features/pos/CheckoutPage.test.tsx
git commit -m "feat(web): CheckoutPage — payment step with empty-cart guard"
```

---

### Task 3: Point `/pos` at the checkout screen; move payment off `PosPage`

**Files:**
- Modify: `src/presentation/features/pos/PosPage.tsx`
- Modify: `src/presentation/router/routes.tsx:64`

**Interfaces:**
- Consumes: `CheckoutPage` (Task 2), `useLocation`/`useNavigate`, `RoutePaths`.
- Produces: `PosPage` no longer renders `PaymentSection`/`usePaymentDraft`/`useCheckout`; it renders a **Checkout** button linking to `/pos/checkout` and shows the success banner from router state.

- [ ] **Step 1: Wire the route** — in `routes.tsx`, replace line 64:

```tsx
{ path: RoutePaths.checkout, element: <CheckoutPage /> },
```

and add the import near the other pos imports:

```tsx
import { CheckoutPage } from '@/presentation/features/pos/CheckoutPage';
```

- [ ] **Step 2: Edit `PosPage.tsx`** — remove payment wiring, add Checkout button + router-state banner.

Remove these imports/hooks from `PosPage`: `useCheckout`, `usePaymentDraft`, `PaymentSection`, and the `pay`, `checkout`, `onComplete`, `grandTotal`-for-payment usage tied to completing the sale (keep `grandTotal` for the totals `<dl>`). Add:

```tsx
import { Link, useLocation } from 'react-router-dom';
import { RoutePaths } from '@/presentation/router/routePaths';
```

Change the `done` state initializer to read the completed sale from navigation state, and clear it from history so a refresh won't re-show it:

```tsx
const location = useLocation();
const [done, setDone] = useState<string | null>(
  (location.state as { completedSaleNumber?: string } | null)?.completedSaleNumber ?? null,
);
useEffect(() => {
  if ((location.state as { completedSaleNumber?: string } | null)?.completedSaleNumber) {
    window.history.replaceState({}, '');
  }
}, []); // run once
```

Replace the payment + Complete-sale card (the `<div className="space-y-tk-sm rounded-lg ...">` block containing `<PaymentSection>` and the Complete-sale button) with a Checkout button, keeping the Save-as-draft button beneath it:

```tsx
<div className="space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
  <Link
    to={RoutePaths.checkout}
    aria-disabled={lines.length === 0}
    className={cn(
      'block w-full rounded-md bg-light-text px-tk-md py-tk-sm text-center text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
      lines.length === 0 && 'pointer-events-none cursor-not-allowed opacity-60',
    )}
  >
    Checkout
  </Link>
  <button
    type="button"
    disabled={lines.length === 0 || saveDraft.isPending}
    onClick={openSave}
    className={cn(
      'w-full rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle',
      (lines.length === 0 || saveDraft.isPending) && 'cursor-not-allowed opacity-60',
    )}
  >
    {saveDraft.isPending ? 'Saving…' : draftId ? 'Update draft' : 'Save as draft'}
  </button>
</div>
```

Delete the now-unused `canComplete`/`onComplete`/`pay` code.

- [ ] **Step 3: Typecheck + full test run**

Run: `npm run typecheck && npm run test`
Expected: typecheck clean; all tests pass (no test imported the removed `PosPage` internals).

- [ ] **Step 4: `/verify`** — drive the real app: `/pos` → search + add an item → Checkout → pay Cash → Complete sale → land on `/pos` with the green "Sale … completed." banner; confirm Save-as-draft still works.

- [ ] **Step 5: Commit**

```bash
git add src/presentation/features/pos/PosPage.tsx src/presentation/router/routes.tsx
git commit -m "feat(web): split POS into cart + dedicated /pos/checkout"
```

---

# Slice 2 — Draft-edit screen (`/drafts/:id`)

Needs the store factory + shared `CartBuilder`.

### Task 4: Turn `cartStore` into a factory; add the draft-edit instance

**Files:**
- Modify: `src/presentation/stores/cartStore.ts`
- Create: `src/presentation/stores/draftEditStore.ts`
- Modify: `src/presentation/stores/cartStore.test.ts`

**Interfaces:**
- Produces: `export function createCartStore(): UseBoundStore<StoreApi<CartState>>`; `export const useCartStore = createCartStore()` (unchanged identity/type); `export type CartStore = typeof useCartStore`. New file exports `export const useDraftEditStore = createCartStore()`.

- [ ] **Step 1: Add the failing test** to `cartStore.test.ts`:

```tsx
import { createCartStore } from './cartStore';
// ...inside describe('cartStore', ...)
it('createCartStore() instances are independent', () => {
  const a = createCartStore();
  const b = createCartStore();
  a.getState().addLine(product());
  expect(a.getState().lines).toHaveLength(1);
  expect(b.getState().lines).toHaveLength(0);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run test -- cartStore`
Expected: FAIL — `createCartStore` is not exported.

- [ ] **Step 3: Refactor `cartStore.ts`** — wrap the existing `create<CartState>(...)` body in a factory, keep the singleton export:

```tsx
import { create, type StoreApi, type UseBoundStore } from 'zustand';
// ...existing type imports unchanged...

export function createCartStore(): UseBoundStore<StoreApi<CartState>> {
  return create<CartState>((set) => ({
    // ...the ENTIRE existing store body, unchanged...
  }));
}

export const useCartStore = createCartStore();
export type CartStore = typeof useCartStore;
```

Then create `draftEditStore.ts`:

```tsx
import { createCartStore } from './cartStore';

/** A cart-store instance dedicated to editing one draft in place, so the live
 *  POS cart is never disturbed. Hydrated via loadDraft on the draft-edit page. */
export const useDraftEditStore = createCartStore();
```

- [ ] **Step 4: Run to verify it passes**

Run: `npm run test -- cartStore`
Expected: PASS (all prior tests + the new independence test).

- [ ] **Step 5: Commit**

```bash
git add src/presentation/stores/cartStore.ts src/presentation/stores/draftEditStore.ts src/presentation/stores/cartStore.test.ts
git commit -m "refactor(web): cartStore factory + draft-edit store instance"
```

---

### Task 5: Parameterize `LaborSection` by store; extract `CartBuilder`

**Files:**
- Modify: `src/presentation/features/pos/LaborSection.tsx`
- Create: `src/presentation/features/pos/CartBuilder.tsx`
- Modify: `src/presentation/features/pos/PosPage.tsx`

**Interfaces:**
- Produces: `LaborSection` accepts `{ store: CartStore }`. `CartBuilder` = `export function CartBuilder({ store }: { store: CartStore }): JSX.Element` — renders the product search + cart lines (qty/discount/remove/low-stock) + `<LaborSection store={store} />` + totals, all bound to the passed store.
- Consumes: `useProducts`, `cartSubtotal`/`cartDiscount`/`cartGrandTotal`/`lowStockLines`, `cartLaborSubtotal`, `saleItemNet`, `DiscountType`, `formatMoney`, `CartStore` type from `cartStore`.

- [ ] **Step 1: Edit `LaborSection.tsx`** — replace its `import { useCartStore }` selectors with a `store` prop:

```tsx
import type { CartStore } from '@/presentation/stores/cartStore';
// ...
export function LaborSection({ store }: { store: CartStore }) {
  const laborLines = store((s) => s.laborLines);
  const addLaborLine = store((s) => s.addLaborLine);
  const setLaborLine = store((s) => s.setLaborLine);
  const removeLaborLine = store((s) => s.removeLaborLine);
  const mechanicId = store((s) => s.mechanicId);
  const mechanicName = store((s) => s.mechanicName);
  const setMechanic = store((s) => s.setMechanic);
  // ...rest of the existing body unchanged...
}
```

- [ ] **Step 2: Create `CartBuilder.tsx`** — move the product-search `<section>` and the cart `<div className="rounded-lg border ...">` (lines + `<LaborSection>` + totals `<dl>`) out of `PosPage`, bound to `store`:

```tsx
import { useMemo, useState } from 'react';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import type { CartStore } from '@/presentation/stores/cartStore';
import { cartSubtotal, cartDiscount, cartGrandTotal, lowStockLines } from '@/domain/sales/cart';
import { cartLaborSubtotal } from '@/domain/sales/labor';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { LaborSection } from './LaborSection';

export function CartBuilder({ store }: { store: CartStore }) {
  const { data: products } = useProducts();
  const lines = store((s) => s.lines);
  const discountType = store((s) => s.discountType);
  const addLine = store((s) => s.addLine);
  const setQty = store((s) => s.setQty);
  const setLineDiscount = store((s) => s.setLineDiscount);
  const removeLine = store((s) => s.removeLine);
  const setDiscountType = store((s) => s.setDiscountType);
  const laborLines = store((s) => s.laborLines);

  const [search, setSearch] = useState('');
  const isPct = discountType === DiscountType.percentage;
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const grandTotal = cartGrandTotal(lines, laborLines, discountType);
  const labor = cartLaborSubtotal(laborLines);

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return active.filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q)).slice(0, 50);
  }, [active, search]);
  const lowStock = useMemo(() => lowStockLines(lines, active), [lines, active]);

  return (
    <div className="grid grid-cols-1 gap-tk-lg lg:grid-cols-2">
      <section className="space-y-tk-md">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search products by name or SKU"
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none focus:border-light-text"
        />
        <div className="divide-y divide-light-hairline rounded-lg border border-light-hairline bg-light-card">
          {results.length === 0 ? (
            <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">
              {search.trim() ? 'No matches.' : 'Type to search products.'}
            </p>
          ) : (
            results.map((p) => (
              <button key={p.id} type="button" onClick={() => addLine(p)}
                className="flex w-full items-center justify-between gap-tk-md px-tk-md py-tk-sm text-left hover:bg-light-subtle">
                <span>
                  <span className="block text-bodySmall text-light-text">{p.name}</span>
                  <span className="block text-[12px] text-light-text-hint">{p.sku} · {p.quantity} on hand</span>
                </span>
                <span className="text-bodySmall font-medium text-light-text">{formatMoney(p.price)}</span>
              </button>
            ))
          )}
        </div>
      </section>

      <section className="space-y-tk-md">
        <div className="rounded-lg border border-light-hairline bg-light-card">
          <div className="flex items-center justify-between border-b border-light-hairline px-tk-md py-tk-sm">
            <span className="text-bodyMedium font-semibold text-light-text">Cart</span>
            <label className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
              Discount
              <select value={discountType} onChange={(e) => setDiscountType(e.target.value as DiscountType)}
                className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]">
                <option value={DiscountType.amount}>₱ amount</option>
                <option value={DiscountType.percentage}>%</option>
              </select>
            </label>
          </div>
          {lines.length === 0 ? (
            <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">Cart is empty.</p>
          ) : (
            <ul className="divide-y divide-light-hairline">
              {lines.map((l) => (
                <li key={l.productId} className="space-y-tk-xs px-tk-md py-tk-sm">
                  <div className="flex items-center justify-between gap-tk-sm">
                    <span className="text-bodySmall text-light-text">{l.name}</span>
                    <button type="button" onClick={() => removeLine(l.productId)} className="text-light-text-hint hover:text-error">
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
                    <label className="flex items-center gap-tk-xs">
                      Qty
                      <input type="number" min={1} value={l.quantity}
                        onChange={(e) => setQty(l.productId, Number(e.target.value))}
                        className="w-16 rounded-md border border-light-border px-tk-sm py-[4px]" />
                    </label>
                    <label className="flex items-center gap-tk-xs">
                      {isPct ? '%' : '₱'} off
                      <input type="number" min={0} step="0.01" value={l.discountValue}
                        onChange={(e) => setLineDiscount(l.productId, Number(e.target.value))}
                        className="w-20 rounded-md border border-light-border px-tk-sm py-[4px]" />
                    </label>
                    <span className="ml-auto font-medium text-light-text">{formatMoney(saleItemNet(l, isPct))}</span>
                  </div>
                  {lowStock.has(l.productId) ? <p className="text-[11px] text-warning-dark">⚠ exceeds on-hand stock</p> : null}
                </li>
              ))}
            </ul>
          )}
          <LaborSection store={store} />
          <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
            <Row label="Subtotal" value={formatMoney(subtotal)} />
            <Row label="Discount" value={`− ${formatMoney(discount)}`} />
            {labor > 0 ? <Row label="Labor" value={formatMoney(labor)} /> : null}
            <Row label="Total" value={formatMoney(grandTotal)} strong />
          </dl>
        </div>
      </section>
    </div>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div className="flex justify-between">
      <dt className="text-light-text-hint">{label}</dt>
      <dd className={cn('text-light-text', strong && 'font-semibold')}>{value}</dd>
    </div>
  );
}
```

- [ ] **Step 3: Rewrite `PosPage.tsx`** to use `CartBuilder` for the editing surface, keeping the banners, the Checkout + Save-draft buttons, and the Save-as-draft dialog. `PosPage` keeps its `useCartStore` reads only for `lines`/`draftId`/`draftName`/labor/mechanic/`clear` needed by the save dialog and the banners. Render:

```tsx
return (
  <div className="space-y-tk-md px-tk-xl py-tk-lg">
    <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">POS</h1>
    {/* banners: done / saveDraft.isSuccess (unchanged) */}
    <CartBuilder store={useCartStore} />
    <div className="ml-auto max-w-sm space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
      {/* Checkout Link + Save-as-draft button from Task 3 Step 2 */}
    </div>
    {/* Save-as-draft <Dialog> unchanged */}
  </div>
);
```

- [ ] **Step 4: Typecheck + tests + verify**

Run: `npm run typecheck && npm run test`
Expected: clean + green.
Then `/verify`: `/pos` still searches, edits the cart, adds labor/mechanic, checks out, and saves drafts exactly as before.

- [ ] **Step 5: Commit**

```bash
git add src/presentation/features/pos/LaborSection.tsx src/presentation/features/pos/CartBuilder.tsx src/presentation/features/pos/PosPage.tsx
git commit -m "refactor(web): extract store-parameterized CartBuilder from PosPage"
```

---

### Task 6: `useDraft(id)` — single-draft query hook

**Files:**
- Create: `src/presentation/hooks/useDraft.ts`
- Test: `src/presentation/hooks/useDraft.test.ts`

**Interfaces:**
- Consumes: `useDraftRepo` from `@/infrastructure/di/container`, `queryKeys.drafts.byId`, `useQuery`.
- Produces: `export function useDraft(id: string): UseQueryResult<Draft | null, Error>`.

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it, vi } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useDraft } from './useDraft';
import type { ReactNode } from 'react';

function wrap(draftRepo: Partial<Container['draftRepo']>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <DiProvider override={{ draftRepo: draftRepo as Container['draftRepo'] }}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </DiProvider>
  );
}

describe('useDraft', () => {
  it('fetches one draft by id', async () => {
    const getById = vi.fn().mockResolvedValue({ id: 'd1', name: 'Mr Cruz' });
    const { result } = renderHook(() => useDraft('d1'), { wrapper: wrap({ getById }) });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual({ id: 'd1', name: 'Mr Cruz' });
    expect(getById).toHaveBeenCalledWith('d1');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run test -- useDraft`
Expected: FAIL — cannot find module `./useDraft`.

- [ ] **Step 3: Implement**

```tsx
import { useQuery } from '@tanstack/react-query';
import { useDraftRepo } from '@/infrastructure/di/container';
import { queryKeys } from '@/infrastructure/query/queryKeys';
import type { Draft } from '@/domain/entities';

/** One draft by id (for the draft-edit page). Null when it doesn't exist. */
export function useDraft(id: string) {
  const repo = useDraftRepo();
  return useQuery<Draft | null, Error>({
    queryKey: queryKeys.drafts.byId(id),
    queryFn: () => repo.getById(id),
  });
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npm run test -- useDraft`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/presentation/hooks/useDraft.ts src/presentation/hooks/useDraft.test.ts
git commit -m "feat(web): useDraft(id) single-draft query hook"
```

---

### Task 7: `DraftEditPage` — load, edit in place, save

**Files:**
- Create: `src/presentation/features/drafts/DraftEditPage.tsx`
- Test: `src/presentation/features/drafts/DraftEditPage.test.tsx`

**Interfaces:**
- Consumes: `useParams`, `useNavigate`, `Link`; `useDraft` (Task 6); `useDraftEditStore` (Task 4); `CartBuilder` (Task 5); `useSaveDraft` (existing); `LoadingView`/`ErrorView`/`EmptyState`; `describedLaborLines`; `RoutePaths`.
- Produces: `export function DraftEditPage(): JSX.Element`.

- [ ] **Step 1: Write the failing test** (covers load→hydrate and the converted-draft guard)

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { DraftEditPage } from './DraftEditPage';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Draft } from '@/domain/entities';
import type { ReactNode } from 'react';

const draft = (o: Partial<Draft> = {}): Draft => ({
  id: 'd1', name: 'Mr Cruz — Mio', items: [], laborLines: [], mechanicId: null, mechanicName: null,
  discountType: DiscountType.amount, createdBy: 'u1', createdByName: 'C', createdAt: new Date(),
  updatedAt: null, updatedBy: null, isConverted: false, convertedToSaleId: null, convertedAt: null, notes: null, ...o,
});

function harness(draftRepo: Partial<Container['draftRepo']>, node: ReactNode = <DraftEditPage />) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <DiProvider override={{ draftRepo: draftRepo as Container['draftRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/drafts/d1']}>
          <Routes><Route path="/drafts/:id" element={node} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('DraftEditPage', () => {
  it('shows the editor with the draft name once loaded', async () => {
    harness({ getById: vi.fn().mockResolvedValue(draft()) });
    await waitFor(() => expect(screen.getByDisplayValue('Mr Cruz — Mio')).toBeInTheDocument());
  });

  it('blocks editing a converted draft', async () => {
    harness({ getById: vi.fn().mockResolvedValue(draft({ isConverted: true })) });
    await waitFor(() => expect(screen.getByText(/already billed out/i)).toBeInTheDocument());
  });

  it('shows not-found when the draft is missing', async () => {
    harness({ getById: vi.fn().mockResolvedValue(null) });
    await waitFor(() => expect(screen.getByText(/Draft not found/i)).toBeInTheDocument());
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npm run test -- DraftEditPage`
Expected: FAIL — cannot find module `./DraftEditPage`.

- [ ] **Step 3: Implement**

```tsx
import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDraft } from '@/presentation/hooks/useDraft';
import { useDraftEditStore } from '@/presentation/stores/draftEditStore';
import { useSaveDraft } from '@/presentation/hooks/useDraftMutations';
import { describedLaborLines } from '@/domain/sales/labor';
import { CartBuilder } from '@/presentation/features/pos/CartBuilder';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

export function DraftEditPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { data: draft, isLoading, error } = useDraft(id);
  const save = useSaveDraft();

  const loadDraft = useDraftEditStore((s) => s.loadDraft);
  const clear = useDraftEditStore((s) => s.clear);
  const lines = useDraftEditStore((s) => s.lines);
  const discountType = useDraftEditStore((s) => s.discountType);
  const laborLines = useDraftEditStore((s) => s.laborLines);
  const mechanicId = useDraftEditStore((s) => s.mechanicId);
  const mechanicName = useDraftEditStore((s) => s.mechanicName);

  const [name, setName] = useState('');
  const hydrated = useRef(false);

  useEffect(() => {
    document.title = 'Edit draft';
  }, []);
  useEffect(() => {
    if (draft && !draft.isConverted && !hydrated.current) {
      loadDraft(draft);
      setName(draft.name);
      hydrated.current = true;
    }
    return () => clear();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draft]);

  if (error) return <ErrorView title="Could not load draft" message={error.message} />;
  if (isLoading || !draft) {
    if (!isLoading && !draft) {
      return (
        <div className="px-tk-xl py-tk-lg">
          <EmptyState title="Draft not found" description="It may have been deleted or already billed out." />
          <Link to={RoutePaths.drafts} className="mt-tk-md inline-block text-bodySmall text-light-text-secondary hover:text-light-text">← Drafts</Link>
        </div>
      );
    }
    return <LoadingView label="Loading draft…" />;
  }
  if (draft.isConverted) {
    return (
      <div className="px-tk-xl py-tk-lg">
        <EmptyState title="Can't edit this draft" description="This draft was already billed out and can't be edited." />
        <Link to={RoutePaths.drafts} className="mt-tk-md inline-block text-bodySmall text-light-text-secondary hover:text-light-text">← Drafts</Link>
      </div>
    );
  }

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    try {
      await save.mutateAsync({
        draftId: id,
        name: trimmed,
        items: lines,
        discountType,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
      });
      navigate(RoutePaths.drafts);
    } catch {
      // surfaced via save.error
    }
  };

  return (
    <div className="space-y-tk-md px-tk-xl py-tk-lg">
      <Link to={RoutePaths.drafts} className="text-bodySmall text-light-text-secondary hover:text-light-text">← Drafts</Link>
      <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Edit draft</h1>

      {save.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {save.error.message}
        </p>
      ) : null}

      <label className="block max-w-sm space-y-tk-xs">
        <span className="text-bodySmall text-light-text-secondary">Draft name</span>
        <input type="text" value={name} onChange={(e) => setName(e.target.value)}
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text" />
      </label>

      <CartBuilder store={useDraftEditStore} />

      <div className="flex justify-end gap-tk-sm">
        <Link to={RoutePaths.drafts} className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">Cancel</Link>
        <button type="button" onClick={onSave} disabled={save.isPending || !name.trim()}
          className={cn('rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
            (save.isPending || !name.trim()) && 'cursor-not-allowed opacity-60')}>
          {save.isPending ? 'Saving…' : 'Save changes'}
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npm run test -- DraftEditPage`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/presentation/features/drafts/DraftEditPage.tsx src/presentation/features/drafts/DraftEditPage.test.tsx
git commit -m "feat(web): DraftEditPage — in-place held-order editor"
```

---

### Task 8: Wire the route + add the Edit entry point on the Drafts list

**Files:**
- Modify: `src/presentation/router/routes.tsx:66`
- Modify: `src/presentation/features/drafts/DraftsPage.tsx`

**Interfaces:**
- Consumes: `DraftEditPage` (Task 7), `Link`, `RoutePaths`.
- Produces: `/drafts/:id` renders `<DraftEditPage/>`; each draft row has an **Edit** link to `/drafts/:id` alongside Resume + delete.

- [ ] **Step 1: Wire the route** — in `routes.tsx`, replace line 66:

```tsx
{ path: RoutePaths.draftEdit, element: <DraftEditPage /> },
```

and import it:

```tsx
import { DraftEditPage } from '@/presentation/features/drafts/DraftEditPage';
```

- [ ] **Step 2: Add the Edit link** in `DraftsPage.tsx`. Add `import { Link } from 'react-router-dom';` and, in the row action cluster (before the Resume button), insert:

```tsx
<Link
  to={`/drafts/${d.id}`}
  className="rounded-md border border-light-border px-tk-md py-[6px] text-[12px] font-medium text-light-text hover:bg-light-subtle"
>
  Edit
</Link>
```

- [ ] **Step 3: Typecheck + full test run**

Run: `npm run typecheck && npm run test`
Expected: clean + all green.

- [ ] **Step 4: `/verify`** — `/drafts` → **Edit** on a held order → `/drafts/:id` loads it → change qty / add an item / rename → **Save changes** → back on `/drafts` with the update persisted, and the live POS cart untouched. Also confirm **Resume** still loads into POS, and opening `/drafts/:id` for a converted draft shows the "already billed out" notice.

- [ ] **Step 5: Commit**

```bash
git add src/presentation/router/routes.tsx src/presentation/features/drafts/DraftsPage.tsx
git commit -m "feat(web): wire /drafts/:id editor + Edit action on drafts list"
```

---

## Self-Review

- **Spec coverage:** Checkout screen (Tasks 1-3) ✓; empty-cart guard (Task 2) ✓; success banner handoff (Tasks 2-3) ✓; store factory (Task 4) ✓; shared CartBuilder (Task 5) ✓; useDraft (Task 6) ✓; DraftEditPage with load/error/not-found/converted states + save (Task 7) ✓; DraftsPage Edit entry + route wiring (Task 8) ✓; both routes unchanged in guards (Global Constraints) ✓; resume-into-POS preserved (Task 8 verify) ✓.
- **Placeholder scan:** none — every code step shows full code.
- **Type consistency:** `CartStore = typeof useCartStore` used consistently in Tasks 4/5/7; `createCartStore` returns the same bound-store type; `useDraft(id)` returns `Draft | null`; `SaveDraftInput` fields match `useDraftMutations`.

## Execution Handoff

Plan complete. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks.
2. **Inline Execution** — execute in this session with checkpoints.
