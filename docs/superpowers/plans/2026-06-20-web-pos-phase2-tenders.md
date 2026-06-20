# Web POS Phase 2 — Tenders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the web POS checkout record GCash, Maya, Mixed (cash + one digital), and Salmon (downpayment + receivable) sales — producing a correct `tenders` map and `paymentMethod` label — instead of always cash.

**Architecture:** Pure helpers in `src/domain/sales/payment.ts` turn a `PaymentDraft` (cashier entry) into `{ paymentMethod, tenders, amountReceived, changeGiven }`, mirroring the mobile salmon/mixed contract. A local `usePaymentDraft` hook holds the transient entry; a `PaymentSection` component renders the chip selector + conditional inputs. The sale-write path is unchanged except `useCheckout` now passes the chosen payment fields through (via an extracted, pure `buildSaleInput`). No schema, repository, reporting, store-shape, or display changes — the read side already buckets tenders.

**Tech Stack:** React + Vite + TypeScript, Zustand, TanStack Query, Vitest. Run all commands from `web_admin/`.

## Global Constraints

- All commands run from `web_admin/`. Verify with `npm run typecheck` and `npm run test`.
- Vitest resolves the `@/` alias (e.g. `@/domain/enums/PaymentMethod`).
- Money is pesos with 2 decimals; round every split remainder to cents.
- `paymentMethod` is the cashier-chosen **label**; `tenders` is the actual money by method and always sums to `grandTotal`. `mixed` is a label only — never a tender key. `salmon` IS a tender key (the receivable bucket).
- Contract (mirror exactly):
  | mode | `paymentMethod` | `tenders` | `amountReceived` | `changeGiven` |
  |---|---|---|---|---|
  | cash | cash | `{cash: total}` | cashReceived | `max(0, cashReceived − total)` |
  | gcash | gcash | `{gcash: total}` | total | 0 |
  | maya | maya | `{maya: total}` | total | 0 |
  | mixed | mixed | `{cash: total−split, [digital]: split}` | total | 0 |
  | salmon | salmon | `{[dpMethod]: split, salmon: total−split}` | split | 0 |
- Validation: cash → `cashReceived ≥ total`; gcash/maya → always valid; mixed/salmon → `0 < split < total`.
- Color discipline: neutral chips/controls; color only for the error message (`text-error-dark`). No decorative color.
- Do NOT touch: `Sale` entity, `PaymentMethod` enum, `summarizeSales`, `FirestoreSaleRepository`, report/detail pages, `cartStore` shape.

---

### Task 1: Pure payment helpers

**Files:**
- Create: `web_admin/src/domain/sales/payment.ts`
- Test: `web_admin/src/domain/sales/payment.test.ts`

**Interfaces:**
- Consumes: `PaymentMethod` from `@/domain/enums/PaymentMethod`.
- Produces:
  - `type PaymentMode = 'cash' | 'gcash' | 'maya' | 'mixed' | 'salmon'`
  - `type DigitalMethod = 'gcash' | 'maya'`
  - `type DpMethod = 'cash' | 'gcash' | 'maya'`
  - `interface PaymentDraft { mode: PaymentMode; cashReceived: number; digitalMethod: DigitalMethod; dpMethod: DpMethod; splitAmount: number }`
  - `const emptyPaymentDraft: PaymentDraft`
  - `paymentLabel(mode: PaymentMode): PaymentMethod`
  - `buildTenders(draft: PaymentDraft, total: number): Partial<Record<PaymentMethod, number>>`
  - `amountReceivedFor(draft: PaymentDraft, total: number): number`
  - `changeGivenFor(draft: PaymentDraft, total: number): number`
  - `paymentError(draft: PaymentDraft, total: number): string | null`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/sales/payment.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import {
  amountReceivedFor,
  buildTenders,
  changeGivenFor,
  emptyPaymentDraft,
  paymentError,
  paymentLabel,
  type PaymentDraft,
} from './payment';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';

const draft = (over: Partial<PaymentDraft> = {}): PaymentDraft => ({
  ...emptyPaymentDraft,
  ...over,
});

describe('paymentLabel', () => {
  it('maps each mode to its PaymentMethod label', () => {
    expect(paymentLabel('cash')).toBe(PaymentMethod.cash);
    expect(paymentLabel('gcash')).toBe(PaymentMethod.gcash);
    expect(paymentLabel('maya')).toBe(PaymentMethod.maya);
    expect(paymentLabel('mixed')).toBe(PaymentMethod.mixed);
    expect(paymentLabel('salmon')).toBe(PaymentMethod.salmon);
  });
});

describe('buildTenders', () => {
  it('cash puts the whole total in the cash bucket', () => {
    expect(buildTenders(draft({ mode: 'cash' }), 250)).toEqual({ cash: 250 });
  });
  it('gcash / maya put the whole total in their bucket', () => {
    expect(buildTenders(draft({ mode: 'gcash' }), 250)).toEqual({ gcash: 250 });
    expect(buildTenders(draft({ mode: 'maya' }), 250)).toEqual({ maya: 250 });
  });
  it('mixed splits cash + chosen digital; cash = remainder', () => {
    expect(
      buildTenders(draft({ mode: 'mixed', digitalMethod: 'gcash', splitAmount: 700 }), 1000),
    ).toEqual({ cash: 300, gcash: 700 });
  });
  it('mixed rounds the cash remainder to cents', () => {
    expect(
      buildTenders(draft({ mode: 'mixed', digitalMethod: 'maya', splitAmount: 33.33 }), 100),
    ).toEqual({ cash: 66.67, maya: 33.33 });
  });
  it('salmon splits downpayment (any method) + salmon balance', () => {
    expect(
      buildTenders(draft({ mode: 'salmon', dpMethod: 'cash', splitAmount: 500 }), 2000),
    ).toEqual({ cash: 500, salmon: 1500 });
    expect(
      buildTenders(draft({ mode: 'salmon', dpMethod: 'gcash', splitAmount: 500 }), 2000),
    ).toEqual({ gcash: 500, salmon: 1500 });
  });
});

describe('amountReceivedFor', () => {
  it('cash returns the cash handed over', () => {
    expect(amountReceivedFor(draft({ mode: 'cash', cashReceived: 300 }), 250)).toBe(300);
  });
  it('gcash / maya / mixed return the full total', () => {
    expect(amountReceivedFor(draft({ mode: 'gcash' }), 250)).toBe(250);
    expect(amountReceivedFor(draft({ mode: 'mixed', splitAmount: 100 }), 250)).toBe(250);
  });
  it('salmon returns only the downpayment collected today', () => {
    expect(amountReceivedFor(draft({ mode: 'salmon', splitAmount: 500 }), 2000)).toBe(500);
  });
});

describe('changeGivenFor', () => {
  it('cash returns received minus total, floored at 0', () => {
    expect(changeGivenFor(draft({ mode: 'cash', cashReceived: 300 }), 250)).toBe(50);
    expect(changeGivenFor(draft({ mode: 'cash', cashReceived: 250 }), 250)).toBe(0);
  });
  it('is 0 for every non-cash mode', () => {
    expect(changeGivenFor(draft({ mode: 'gcash' }), 250)).toBe(0);
    expect(changeGivenFor(draft({ mode: 'mixed', splitAmount: 100 }), 250)).toBe(0);
    expect(changeGivenFor(draft({ mode: 'salmon', splitAmount: 100 }), 250)).toBe(0);
  });
});

describe('paymentError', () => {
  it('cash requires received >= total', () => {
    expect(paymentError(draft({ mode: 'cash', cashReceived: 240 }), 250)).toBe(
      'Cash received is less than the total',
    );
    expect(paymentError(draft({ mode: 'cash', cashReceived: 250 }), 250)).toBeNull();
    expect(paymentError(draft({ mode: 'cash', cashReceived: 300 }), 250)).toBeNull();
  });
  it('gcash / maya are always valid', () => {
    expect(paymentError(draft({ mode: 'gcash' }), 250)).toBeNull();
    expect(paymentError(draft({ mode: 'maya' }), 250)).toBeNull();
  });
  it('mixed requires 0 < digital < total', () => {
    expect(paymentError(draft({ mode: 'mixed', splitAmount: 0 }), 250)).toBe(
      'Digital amount must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'mixed', splitAmount: 250 }), 250)).toBe(
      'Digital amount must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'mixed', splitAmount: 100 }), 250)).toBeNull();
  });
  it('salmon requires 0 < downpayment < total', () => {
    expect(paymentError(draft({ mode: 'salmon', splitAmount: 0 }), 250)).toBe(
      'Downpayment must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'salmon', splitAmount: 250 }), 250)).toBe(
      'Downpayment must be between ₱0 and the total',
    );
    expect(paymentError(draft({ mode: 'salmon', splitAmount: 100 }), 250)).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test -- payment`
Expected: FAIL — cannot resolve `./payment` (module not created yet).

- [ ] **Step 3: Write minimal implementation**

Create `web_admin/src/domain/sales/payment.ts`:

```ts
// Pure helpers that turn cashier payment entry into a Sale's tender fields.
// Mirrors the mobile salmon/mixed contract: `paymentMethod` is the label,
// `tenders` is the actual money by method (always sums to grandTotal).
import { PaymentMethod } from '@/domain/enums/PaymentMethod';

export type PaymentMode = 'cash' | 'gcash' | 'maya' | 'mixed' | 'salmon';
export type DigitalMethod = 'gcash' | 'maya';
export type DpMethod = 'cash' | 'gcash' | 'maya';

export interface PaymentDraft {
  mode: PaymentMode;
  cashReceived: number; // mode 'cash' only — cash handed (drives change)
  digitalMethod: DigitalMethod; // mode 'mixed' — which digital half
  dpMethod: DpMethod; // mode 'salmon' — downpayment method
  splitAmount: number; // 'mixed' = digital amount; 'salmon' = downpayment
}

export const emptyPaymentDraft: PaymentDraft = {
  mode: 'cash',
  cashReceived: 0,
  digitalMethod: 'gcash',
  dpMethod: 'cash',
  splitAmount: 0,
};

function roundCents(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function paymentLabel(mode: PaymentMode): PaymentMethod {
  // mode values are a subset of PaymentMethod values.
  return mode as PaymentMethod;
}

export function buildTenders(
  draft: PaymentDraft,
  total: number,
): Partial<Record<PaymentMethod, number>> {
  switch (draft.mode) {
    case 'cash':
      return { [PaymentMethod.cash]: roundCents(total) };
    case 'gcash':
      return { [PaymentMethod.gcash]: roundCents(total) };
    case 'maya':
      return { [PaymentMethod.maya]: roundCents(total) };
    case 'mixed': {
      const digital = roundCents(draft.splitAmount);
      const tenders: Partial<Record<PaymentMethod, number>> = {
        [PaymentMethod.cash]: roundCents(total - digital),
      };
      tenders[draft.digitalMethod] = digital;
      return tenders;
    }
    case 'salmon': {
      const dp = roundCents(draft.splitAmount);
      const tenders: Partial<Record<PaymentMethod, number>> = {
        [PaymentMethod.salmon]: roundCents(total - dp),
      };
      tenders[draft.dpMethod] = dp;
      return tenders;
    }
  }
}

export function amountReceivedFor(draft: PaymentDraft, total: number): number {
  switch (draft.mode) {
    case 'cash':
      return draft.cashReceived;
    case 'salmon':
      return roundCents(draft.splitAmount);
    default:
      return roundCents(total); // gcash / maya / mixed — paid in full
  }
}

export function changeGivenFor(draft: PaymentDraft, total: number): number {
  if (draft.mode !== 'cash') return 0;
  return Math.max(0, roundCents(draft.cashReceived - total));
}

export function paymentError(draft: PaymentDraft, total: number): string | null {
  const t = roundCents(total);
  switch (draft.mode) {
    case 'cash':
      return roundCents(draft.cashReceived) < t
        ? 'Cash received is less than the total'
        : null;
    case 'gcash':
    case 'maya':
      return null;
    case 'mixed': {
      const s = roundCents(draft.splitAmount);
      return s > 0 && s < t ? null : 'Digital amount must be between ₱0 and the total';
    }
    case 'salmon': {
      const s = roundCents(draft.splitAmount);
      return s > 0 && s < t ? null : 'Downpayment must be between ₱0 and the total';
    }
  }
}
```

- [ ] **Step 4: Run test + typecheck to verify they pass**

Run: `npm run test -- payment && npm run typecheck`
Expected: PASS (all `payment.test.ts` cases green); typecheck clean. (Vitest strips types via esbuild, so typecheck here catches any type error in `payment.ts` — e.g. switch exhaustiveness — before later tasks depend on it.)

- [ ] **Step 5: Commit**

```bash
git add src/domain/sales/payment.ts src/domain/sales/payment.test.ts
git commit -m "feat(web): pure payment helpers — tenders/amountReceived/change/validation per mode"
```

---

### Task 2: Rewire checkout to carry payment fields (refactor, no behavior change)

Extract the sale-input construction into a pure, testable `buildSaleInput`, widen `CheckoutInput` to carry the payment fields, point `useCheckout` at it, delete the now-unused `cashTenders`, and update the PosPage call site to pass cash-equivalent values so the app behaves identically until Task 3 adds the UI.

**Files:**
- Create: `web_admin/src/presentation/hooks/buildSaleInput.ts`
- Test: `web_admin/src/presentation/hooks/buildSaleInput.test.ts`
- Modify: `web_admin/src/presentation/hooks/useCheckout.ts`
- Modify: `web_admin/src/domain/sales/cart.ts` (remove `cashTenders` + its now-unused `PaymentMethod` import)
- Modify: `web_admin/src/domain/sales/cart.test.ts` (remove `cashTenders` import + describe block + now-unused `PaymentMethod` import)
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx` (pass `paymentMethod` + `tenders` to the existing mutate call)

**Interfaces:**
- Consumes: `Sale` (`@/domain/entities/Sale`), `User` (`@/domain/entities/User`), `SaleStatus`, `DiscountType`, `PaymentMethod`, `CartLine` (`@/domain/sales/cart`).
- Produces:
  - `interface CheckoutInput { lines: CartLine[]; discountType: DiscountType; paymentMethod: PaymentMethod; tenders: Partial<Record<PaymentMethod, number>>; amountReceived: number; changeGiven: number }`
  - `buildSaleInput(input: CheckoutInput, actor: User): Omit<Sale, 'id' | 'createdAt' | 'updatedAt'>`
  - `useCheckout()` still returns the same TanStack mutation, now typed on the widened `CheckoutInput`.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/presentation/hooks/buildSaleInput.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { buildSaleInput, type CheckoutInput } from './buildSaleInput';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { DiscountType } from '@/domain/enums/DiscountType';
import { SaleStatus } from '@/domain/enums/SaleStatus';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';

const actor = (over: Partial<User> = {}): User => ({
  id: 'u1',
  email: 'cashier@shop.test',
  displayName: 'Cashier One',
  role: UserRole.cashier,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
  ...over,
});

const input = (over: Partial<CheckoutInput> = {}): CheckoutInput => ({
  lines: [],
  discountType: DiscountType.amount,
  paymentMethod: PaymentMethod.cash,
  tenders: { [PaymentMethod.cash]: 100 },
  amountReceived: 100,
  changeGiven: 0,
  ...over,
});

describe('buildSaleInput', () => {
  it('carries the payment method + tenders through verbatim', () => {
    const s = buildSaleInput(
      input({ paymentMethod: PaymentMethod.mixed, tenders: { cash: 300, gcash: 700 } }),
      actor(),
    );
    expect(s.paymentMethod).toBe(PaymentMethod.mixed);
    expect(s.tenders).toEqual({ cash: 300, gcash: 700 });
  });
  it('stamps the actor as cashier and marks the sale completed', () => {
    const s = buildSaleInput(input(), actor({ id: 'u9', displayName: 'Jo' }));
    expect(s.cashierId).toBe('u9');
    expect(s.cashierName).toBe('Jo');
    expect(s.status).toBe(SaleStatus.completed);
    expect(s.saleNumber).toBe('');
  });
  it('falls back to email when displayName is blank', () => {
    const s = buildSaleInput(input(), actor({ displayName: '   ', email: 'x@y.z' }));
    expect(s.cashierName).toBe('x@y.z');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run test -- buildSaleInput`
Expected: FAIL — cannot resolve `./buildSaleInput`.

- [ ] **Step 3a: Create `buildSaleInput.ts`**

Create `web_admin/src/presentation/hooks/buildSaleInput.ts`:

```ts
import type { Sale } from '@/domain/entities/Sale';
import type { User } from '@/domain/entities/User';
import type { CartLine } from '@/domain/sales/cart';
import type { DiscountType } from '@/domain/enums/DiscountType';
import type { PaymentMethod } from '@/domain/enums/PaymentMethod';
import { SaleStatus } from '@/domain/enums/SaleStatus';

export interface CheckoutInput {
  lines: CartLine[];
  discountType: DiscountType;
  paymentMethod: PaymentMethod;
  tenders: Partial<Record<PaymentMethod, number>>;
  amountReceived: number;
  changeGiven: number;
}

/** Compose the create-payload for a completed sale from cashier input + actor.
 *  Pure: the repo generates `saleNumber`/timestamps inside its transaction. */
export function buildSaleInput(
  input: CheckoutInput,
  actor: User,
): Omit<Sale, 'id' | 'createdAt' | 'updatedAt'> {
  const cashierName = actor.displayName.trim() || actor.email;
  return {
    saleNumber: '', // generated inside the repo transaction
    items: input.lines,
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
    tenders: input.tenders,
    discountType: input.discountType,
    paymentMethod: input.paymentMethod,
    amountReceived: input.amountReceived,
    changeGiven: input.changeGiven,
    status: SaleStatus.completed,
    cashierId: actor.id,
    cashierName,
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
  };
}
```

- [ ] **Step 3b: Point `useCheckout` at it**

Replace the entire contents of `web_admin/src/presentation/hooks/useCheckout.ts` with:

```ts
import { useMutation } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Sale } from '@/domain/entities';
import { buildSaleInput, type CheckoutInput } from './buildSaleInput';

export type { CheckoutInput };

export function useCheckout() {
  const repo = useSaleRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Sale, Error, CheckoutInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(buildSaleInput(input, actor), actor.id);
    },
  });
}
```

- [ ] **Step 3c: Remove `cashTenders` from `cart.ts`**

In `web_admin/src/domain/sales/cart.ts`:
- Delete the `cashTenders` function (the 3 lines starting `export function cashTenders(`).
- Delete the import line `import { PaymentMethod } from '@/domain/enums/PaymentMethod';` (it is now unused; confirm no other reference to `PaymentMethod` remains in the file).

- [ ] **Step 3d: Remove `cashTenders` from `cart.test.ts`**

In `web_admin/src/domain/sales/cart.test.ts`:
- Change the import on line 2 from `import { cartGrandTotal, changeFor, cashTenders, lowStockLines } from './cart';` to `import { cartGrandTotal, changeFor, lowStockLines } from './cart';`.
- Delete the `import { PaymentMethod } from '@/domain/enums/PaymentMethod';` line (now unused).
- Delete the whole `describe('cashTenders', () => { ... });` block.

- [ ] **Step 3e: Update the PosPage call site (keep cash behavior)**

In `web_admin/src/presentation/features/pos/PosPage.tsx`:
- Add the import `import { PaymentMethod } from '@/domain/enums/PaymentMethod';`.
- Replace the `checkout.mutateAsync({ ... })` call inside `onComplete` with:

```tsx
      const sale = await checkout.mutateAsync({
        lines,
        discountType,
        paymentMethod: PaymentMethod.cash,
        tenders: { [PaymentMethod.cash]: grandTotal },
        amountReceived: received,
        changeGiven: change,
      });
```

(Behavior is identical to Phase 1 — this only satisfies the widened `CheckoutInput`. Task 3 replaces it.)

- [ ] **Step 4: Run tests + typecheck**

Run: `npm run test -- buildSaleInput cart` then `npm run typecheck`
Expected: `buildSaleInput.test.ts` and `cart.test.ts` PASS; typecheck clean (no reference to `cashTenders`).

- [ ] **Step 5: Commit**

```bash
git add src/presentation/hooks/buildSaleInput.ts src/presentation/hooks/buildSaleInput.test.ts \
  src/presentation/hooks/useCheckout.ts src/domain/sales/cart.ts src/domain/sales/cart.test.ts \
  src/presentation/features/pos/PosPage.tsx
git commit -m "refactor(web): extract buildSaleInput, widen CheckoutInput for tenders (no behavior change)"
```

---

### Task 3: Payment selection UI (hook + section + PosPage wiring)

Add the transient `usePaymentDraft` hook, the `PaymentSection` chip/conditional-input component, and wire them into PosPage. After this task the cashier can choose any tender.

**Files:**
- Create: `web_admin/src/presentation/hooks/usePaymentDraft.ts`
- Create: `web_admin/src/presentation/features/pos/PaymentSection.tsx`
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx`

**Interfaces:**
- Consumes: everything `payment.ts` produces (Task 1); `CheckoutInput` (Task 2); `formatMoney` (`@/core/utils/money`), `cn` (`@/core/utils/cn`).
- Produces:
  - `usePaymentDraft(grandTotal: number)` returns `{ draft: PaymentDraft; setMode; setCashReceived; setDigitalMethod; setDpMethod; setSplitAmount; reset; paymentMethod: PaymentMethod; tenders: Partial<Record<PaymentMethod, number>>; amountReceived: number; changeGiven: number; error: string | null; isValid: boolean }`.
  - `PaymentSection({ pay, grandTotal })` — presentational; `pay` is the `usePaymentDraft` return.

- [ ] **Step 1: Create the `usePaymentDraft` hook**

Create `web_admin/src/presentation/hooks/usePaymentDraft.ts`:

```ts
import { useCallback, useState } from 'react';
import {
  amountReceivedFor,
  buildTenders,
  changeGivenFor,
  emptyPaymentDraft,
  paymentError,
  paymentLabel,
  type DigitalMethod,
  type DpMethod,
  type PaymentDraft,
  type PaymentMode,
} from '@/domain/sales/payment';

/** Holds the transient payment entry for one checkout. Reset after each sale;
 *  switching mode clears entered amounts so a stale value can't carry over. */
export function usePaymentDraft(grandTotal: number) {
  const [draft, setDraft] = useState<PaymentDraft>(emptyPaymentDraft);

  const setMode = useCallback(
    (mode: PaymentMode) => setDraft((d) => ({ ...d, mode, cashReceived: 0, splitAmount: 0 })),
    [],
  );
  const setCashReceived = useCallback(
    (cashReceived: number) => setDraft((d) => ({ ...d, cashReceived })),
    [],
  );
  const setDigitalMethod = useCallback(
    (digitalMethod: DigitalMethod) => setDraft((d) => ({ ...d, digitalMethod })),
    [],
  );
  const setDpMethod = useCallback(
    (dpMethod: DpMethod) => setDraft((d) => ({ ...d, dpMethod })),
    [],
  );
  const setSplitAmount = useCallback(
    (splitAmount: number) => setDraft((d) => ({ ...d, splitAmount })),
    [],
  );
  const reset = useCallback(() => setDraft(emptyPaymentDraft), []);

  const error = paymentError(draft, grandTotal);
  return {
    draft,
    setMode,
    setCashReceived,
    setDigitalMethod,
    setDpMethod,
    setSplitAmount,
    reset,
    paymentMethod: paymentLabel(draft.mode),
    tenders: buildTenders(draft, grandTotal),
    amountReceived: amountReceivedFor(draft, grandTotal),
    changeGiven: changeGivenFor(draft, grandTotal),
    error,
    isValid: error === null,
  };
}
```

- [ ] **Step 2: Create the `PaymentSection` component**

Create `web_admin/src/presentation/features/pos/PaymentSection.tsx`:

```tsx
import { cn } from '@/core/utils/cn';
import { formatMoney } from '@/core/utils/money';
import type { PaymentMode } from '@/domain/sales/payment';
import type { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';

type Pay = ReturnType<typeof usePaymentDraft>;

const MODES: { mode: PaymentMode; label: string }[] = [
  { mode: 'cash', label: 'Cash' },
  { mode: 'gcash', label: 'GCash' },
  { mode: 'maya', label: 'Maya' },
  { mode: 'mixed', label: 'Mixed' },
  { mode: 'salmon', label: 'Salmon' },
];

export function PaymentSection({ pay, grandTotal }: { pay: Pay; grandTotal: number }) {
  const { draft } = pay;
  const remainder = Math.max(0, grandTotal - (Number(draft.splitAmount) || 0));

  return (
    <div className="space-y-tk-sm">
      <div className="flex flex-wrap gap-tk-xs">
        {MODES.map(({ mode, label }) => (
          <button
            key={mode}
            type="button"
            onClick={() => pay.setMode(mode)}
            className={cn(
              'rounded-full border px-tk-md py-[6px] text-[12px]',
              draft.mode === mode
                ? 'border-light-text bg-light-text text-light-background'
                : 'border-light-border bg-light-card text-light-text-secondary hover:bg-light-subtle',
            )}
          >
            {label}
          </button>
        ))}
      </div>

      {draft.mode === 'cash' ? (
        <>
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall font-medium text-light-text">Cash received</span>
            <input
              type="number"
              min={0}
              step="0.01"
              value={draft.cashReceived || ''}
              onChange={(e) => pay.setCashReceived(Number(e.target.value) || 0)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall"
            />
          </label>
          <Row label="Change" value={formatMoney(pay.changeGiven)} />
        </>
      ) : null}

      {draft.mode === 'gcash' || draft.mode === 'maya' ? (
        <p className="text-bodySmall text-light-text-secondary">
          Paid in full via {draft.mode === 'gcash' ? 'GCash' : 'Maya'} — {formatMoney(grandTotal)}
        </p>
      ) : null}

      {draft.mode === 'mixed' ? (
        <div className="space-y-tk-sm">
          <SubSelector
            label="Digital"
            options={[
              { value: 'gcash', label: 'GCash' },
              { value: 'maya', label: 'Maya' },
            ]}
            value={draft.digitalMethod}
            onChange={(v) => pay.setDigitalMethod(v as 'gcash' | 'maya')}
          />
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall font-medium text-light-text">Digital amount</span>
            <input
              type="number"
              min={0}
              step="0.01"
              value={draft.splitAmount || ''}
              onChange={(e) => pay.setSplitAmount(Number(e.target.value) || 0)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall"
            />
          </label>
          <Row label="Cash portion" value={formatMoney(remainder)} />
        </div>
      ) : null}

      {draft.mode === 'salmon' ? (
        <div className="space-y-tk-sm">
          <SubSelector
            label="Downpayment via"
            options={[
              { value: 'cash', label: 'Cash' },
              { value: 'gcash', label: 'GCash' },
              { value: 'maya', label: 'Maya' },
            ]}
            value={draft.dpMethod}
            onChange={(v) => pay.setDpMethod(v as 'cash' | 'gcash' | 'maya')}
          />
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall font-medium text-light-text">Downpayment</span>
            <input
              type="number"
              min={0}
              step="0.01"
              value={draft.splitAmount || ''}
              onChange={(e) => pay.setSplitAmount(Number(e.target.value) || 0)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-[10px] text-bodySmall"
            />
          </label>
          <Row label="Salmon balance (receivable)" value={formatMoney(remainder)} />
        </div>
      ) : null}

      {pay.error ? <p className="text-[12px] text-error-dark">{pay.error}</p> : null}
    </div>
  );
}

function SubSelector({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { value: string; label: string }[];
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
      <span>{label}</span>
      <div className="flex gap-tk-xs">
        {options.map((o) => (
          <button
            key={o.value}
            type="button"
            onClick={() => onChange(o.value)}
            className={cn(
              'rounded-md border px-tk-sm py-[4px]',
              value === o.value
                ? 'border-light-text bg-light-subtle text-light-text'
                : 'border-light-border bg-light-card hover:bg-light-subtle',
            )}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-bodySmall">
      <span className="text-light-text-hint">{label}</span>
      <span className="text-light-text">{value}</span>
    </div>
  );
}
```

- [ ] **Step 3: Wire PosPage to `usePaymentDraft` + `PaymentSection`**

Replace the entire contents of `web_admin/src/presentation/features/pos/PosPage.tsx` with:

```tsx
import { useEffect, useMemo, useState } from 'react';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useCheckout } from '@/presentation/hooks/useCheckout';
import { usePaymentDraft } from '@/presentation/hooks/usePaymentDraft';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartSubtotal, cartDiscount, cartGrandTotal, lowStockLines } from '@/domain/sales/cart';
import { saleItemNet } from '@/domain/entities/SaleItem';
import { DiscountType } from '@/domain/enums/DiscountType';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { PaymentSection } from './PaymentSection';

export function PosPage() {
  const { data: products } = useProducts();
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const addLine = useCartStore((s) => s.addLine);
  const setQty = useCartStore((s) => s.setQty);
  const setLineDiscount = useCartStore((s) => s.setLineDiscount);
  const removeLine = useCartStore((s) => s.removeLine);
  const setDiscountType = useCartStore((s) => s.setDiscountType);
  const clear = useCartStore((s) => s.clear);
  const checkout = useCheckout();

  const [search, setSearch] = useState('');
  const [done, setDone] = useState<string | null>(null);

  const isPct = discountType === DiscountType.percentage;
  const subtotal = cartSubtotal(lines, discountType);
  const discount = cartDiscount(lines, discountType);
  const grandTotal = cartGrandTotal(lines, discountType);
  const pay = usePaymentDraft(grandTotal);

  useEffect(() => {
    document.title = 'POS';
  }, []);

  // Dismiss the previous sale's success banner once a new cart is started.
  useEffect(() => {
    if (lines.length > 0) setDone(null);
  }, [lines.length]);

  // Auto-dismiss the success banner a few seconds after a completed sale.
  useEffect(() => {
    if (!done) return;
    const t = setTimeout(() => setDone(null), 4000);
    return () => clearTimeout(t);
  }, [done]);

  const active = useMemo(() => (products ?? []).filter((p) => p.isActive), [products]);
  const results = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return [];
    return active
      .filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))
      .slice(0, 50);
  }, [active, search]);

  const lowStock = useMemo(() => lowStockLines(lines, active), [lines, active]);
  const canComplete = lines.length > 0 && pay.isValid && !checkout.isPending;

  const onComplete = async () => {
    try {
      const sale = await checkout.mutateAsync({
        lines,
        discountType,
        paymentMethod: pay.paymentMethod,
        tenders: pay.tenders,
        amountReceived: pay.amountReceived,
        changeGiven: pay.changeGiven,
      });
      setDone(sale.saleNumber);
      pay.reset();
      clear();
    } catch {
      // surfaced via checkout.error
    }
  };

  return (
    <div className="grid grid-cols-1 gap-tk-lg px-tk-xl py-tk-lg lg:grid-cols-2">
      {/* Left: product search */}
      <section className="space-y-tk-md">
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">POS</h1>
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
              <button
                key={p.id}
                type="button"
                onClick={() => addLine(p)}
                className="flex w-full items-center justify-between gap-tk-md px-tk-md py-tk-sm text-left hover:bg-light-subtle"
              >
                <span>
                  <span className="block text-bodySmall text-light-text">{p.name}</span>
                  <span className="block text-[12px] text-light-text-hint">
                    {p.sku} · {p.quantity} on hand
                  </span>
                </span>
                <span className="text-bodySmall font-medium text-light-text">{formatMoney(p.price)}</span>
              </button>
            ))
          )}
        </div>
      </section>

      {/* Right: cart + payment */}
      <section className="space-y-tk-md">
        {done ? (
          <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
            Sale <span className="font-mono">{done}</span> completed.
          </p>
        ) : null}
        {checkout.error ? (
          <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
            {checkout.error.message}
          </p>
        ) : null}

        <div className="rounded-lg border border-light-hairline bg-light-card">
          <div className="flex items-center justify-between border-b border-light-hairline px-tk-md py-tk-sm">
            <span className="text-bodyMedium font-semibold text-light-text">Cart</span>
            <label className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
              Discount
              <select
                value={discountType}
                onChange={(e) => setDiscountType(e.target.value as DiscountType)}
                className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
              >
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
                    <button
                      type="button"
                      onClick={() => removeLine(l.productId)}
                      className="text-light-text-hint hover:text-error"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                  <div className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
                    <label className="flex items-center gap-tk-xs">
                      Qty
                      <input
                        type="number"
                        min={1}
                        value={l.quantity}
                        onChange={(e) => setQty(l.productId, Number(e.target.value))}
                        className="w-16 rounded-md border border-light-border px-tk-sm py-[4px]"
                      />
                    </label>
                    <label className="flex items-center gap-tk-xs">
                      {isPct ? '%' : '₱'} off
                      <input
                        type="number"
                        min={0}
                        step="0.01"
                        value={l.discountValue}
                        onChange={(e) => setLineDiscount(l.productId, Number(e.target.value))}
                        className="w-20 rounded-md border border-light-border px-tk-sm py-[4px]"
                      />
                    </label>
                    <span className="ml-auto font-medium text-light-text">
                      {formatMoney(saleItemNet(l, isPct))}
                    </span>
                  </div>
                  {lowStock.has(l.productId) ? (
                    <p className="text-[11px] text-warning-dark">⚠ exceeds on-hand stock</p>
                  ) : null}
                </li>
              ))}
            </ul>
          )}

          <dl className="space-y-tk-xs border-t border-light-hairline px-tk-md py-tk-sm text-bodySmall">
            <Row label="Subtotal" value={formatMoney(subtotal)} />
            <Row label="Discount" value={`− ${formatMoney(discount)}`} />
            <Row label="Total" value={formatMoney(grandTotal)} strong />
          </dl>
        </div>

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

- [ ] **Step 4: Typecheck + full test run**

Run: `npm run typecheck && npm run test`
Expected: typecheck clean; all tests PASS (no remaining import of `PaymentMethod` or `changeFor` left unused in PosPage — both removed).

- [ ] **Step 5: Commit**

```bash
git add src/presentation/hooks/usePaymentDraft.ts \
  src/presentation/features/pos/PaymentSection.tsx \
  src/presentation/features/pos/PosPage.tsx
git commit -m "feat(web): POS tender selection — gcash/maya/mixed/salmon chips + conditional inputs"
```

---

### Task 4: Verify end-to-end (typecheck + tests + browser smoke)

**Files:** none (verification only).

- [ ] **Step 1: Full typecheck + test**

Run: `npm run typecheck && npm run test`
Expected: typecheck clean; all suites green (includes the new `payment.test.ts` and `buildSaleInput.test.ts`).

- [ ] **Step 2: Build**

Run: `npm run build`
Expected: build succeeds.

- [ ] **Step 3: Browser smoke — a Mixed sale**

Run `npm run dev`, sign in, go to `/pos`. Add a product so the total is e.g. ₱1,000. Select **Mixed**, choose **GCash**, enter digital `700` → confirm "Cash portion ₱300.00" shows and Complete enables. Complete the sale. Then open Reports → Sales: confirm the payment-methods breakdown moved ₱300 into **Cash** and ₱700 into **GCash**, and open the sale in Sale Detail to confirm the two-tender split renders.

- [ ] **Step 4: Browser smoke — a Salmon sale**

Back on `/pos`, add products for total e.g. ₱2,000. Select **Salmon**, downpayment via **Cash**, enter `500` → confirm "Salmon balance (receivable) ₱1,500.00" and Complete enables. Complete it. In Reports → Sales confirm ₱500 landed in **Cash** and ₱1,500 in the **Salmon** bucket (never counted as extra cash); Sale Detail shows the downpayment + salmon balance split.

- [ ] **Step 5: Browser smoke — validation gates**

Confirm Complete is disabled when: cart empty; Cash mode with received < total; Mixed/Salmon with split = 0 or split = total. Confirm the matching error text appears for Mixed/Salmon out-of-range entries.

- [ ] **Step 6: Commit (if any smoke-fix tweaks were needed)**

```bash
git add -A
git commit -m "fix(web): POS tenders smoke-test fixes"   # only if changes were required
```

---

## Notes for the implementer

- **Spec:** `docs/superpowers/specs/2026-06-20-web-pos-phase2-tenders-design.md`.
- **Deviation from spec §7:** the spec said "update `useCheckout.test.ts`", but that file does not exist and `useCheckout` would need react-query/DI mocking. Instead the wiring logic is extracted into the pure `buildSaleInput` and unit-tested directly (Task 2) — same coverage intent, no mocks. The hook and UI are verified by browser smoke (Task 4), matching the Phase-1 precedent (PosPage had no component test).
- **Green between tasks:** Task 2 is a behavior-preserving refactor (cash-only UI still), Task 3 turns on the selector. Each task leaves typecheck + tests green.
- Do not deploy. Deployment is a separate, explicitly-authorized step (Firestore/hosting are production).
