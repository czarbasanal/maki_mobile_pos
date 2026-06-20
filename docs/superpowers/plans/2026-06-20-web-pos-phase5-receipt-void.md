# Web POS Phase 5 — Receipt + Void Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an admin void a completed sale (marking it voided + restoring stock atomically) and print a browser receipt for any sale — both from the existing Sale Detail page.

**Architecture:** Implement the stubbed `FirestoreSaleRepository.voidSale` as one transaction (guard already-voided, set the void fields, restore per-item stock — the reverse of the sale-create decrement). Add a `useVoidSale` mutation + a reason-dialog Void button and a print-styled `Receipt` component (Tailwind `print:` variants + `window.print()`) to `SaleDetailPage`. No `firestore.rules`, `routeGuards`, or reporting change.

**Tech Stack:** React + Vite + TypeScript, TanStack Query, Firestore, Vitest. Run all commands from `web_admin/`.

## Global Constraints

- All commands run from `web_admin/`. Verify with `npm run typecheck` (`tsc -b`) and `npm run test`; `npm run build` for UI tasks.
- Vitest resolves the `@/` alias.
- **Direct admin void** — web is admin-only, so NO request/approve workflow. Gate = reason (from active `void_reasons`) + confirm dialog, no password.
- **Void restores stock** — `quantity: increment(+qty)` per item, plus the audit keys (`updatedAt/updatedBy/updatedByName`), inside the void transaction. These are the exact 4 product keys the existing products update rule allows (the same keys the sale-create decrement writes).
- **No `firestore.rules` change** — `sales` update is `allow update: if isAdmin()`; the stock-restore write stays within the 4 permitted product keys.
- **No reporting change** — `summarizeSales` already excludes voided sales (`!saleIsVoided`).
- **Void is irreversible** (no un-void; `sales` delete is `false`).
- Receipt = browser print via Tailwind `print:` variants + `window.print()`; store name is a constant; no new dependency, no route.
- Do NOT touch: `firestore.rules`, `routeGuards.ts`, `summarizeSales`, `FirestoreSaleRepository.create`.

---

## Slice 5a — Void

### Task 1: `canVoidSale` pure helper

**Files:**
- Create: `web_admin/src/domain/sales/voiding.ts`
- Test: `web_admin/src/domain/sales/voiding.test.ts`

**Interfaces:**
- Consumes: `Sale` (`@/domain/entities`), `SaleStatus` (`@/domain/enums`), `saleIsVoided` (`@/domain/entities`).
- Produces: `canVoidSale(sale: Sale): boolean`.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/sales/voiding.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { canVoidSale } from './voiding';
import { SaleStatus } from '@/domain/enums/SaleStatus';
import type { Sale } from '@/domain/entities';

const sale = (over: Partial<Sale> = {}): Sale =>
  ({
    id: 's1',
    status: SaleStatus.completed,
    voidedAt: null,
    items: [],
    laborLines: [],
    ...over,
  }) as Sale;

describe('canVoidSale', () => {
  it('is true for a completed, not-voided sale', () => {
    expect(canVoidSale(sale())).toBe(true);
  });
  it('is false when already voided', () => {
    expect(canVoidSale(sale({ status: SaleStatus.voided, voidedAt: new Date('2026-02-01') }))).toBe(false);
  });
  it('is false when the status is not completed', () => {
    expect(canVoidSale(sale({ status: SaleStatus.voided }))).toBe(false);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run test -- voiding`
Expected: FAIL — cannot resolve `./voiding`.

- [ ] **Step 3: Create the helper**

Create `web_admin/src/domain/sales/voiding.ts`:

```ts
import type { Sale } from '@/domain/entities';
import { saleIsVoided } from '@/domain/entities';
import { SaleStatus } from '@/domain/enums/SaleStatus';

/** A sale can be voided only if it is a completed sale that isn't already voided. */
export function canVoidSale(sale: Sale): boolean {
  return !saleIsVoided(sale) && sale.status === SaleStatus.completed;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npm run test -- voiding`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/sales/voiding.ts web_admin/src/domain/sales/voiding.test.ts
git commit -m "feat(web): canVoidSale helper"
```

---

### Task 2: Implement `FirestoreSaleRepository.voidSale`

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreSaleRepository.ts`

**Interfaces:**
- Consumes: the repo's existing `loadItems(saleId)` (returns `SaleItem[]` with `productId`/`quantity`), `runTransaction`, `doc`, `increment`, `serverTimestamp`, `FirestoreCollections`.
- Produces: `voidSale(id, reason, actorId, actorName): Promise<void>` — atomic mark-voided + stock restore.

- [ ] **Step 1: Add the SaleStatus import**

In `web_admin/src/data/repositories/FirestoreSaleRepository.ts`, add near the other value imports (after the `saleNumber` import line):

```ts
import { SaleStatus } from '@/domain/enums/SaleStatus';
```

- [ ] **Step 2: Replace the voidSale stub**

Replace the stub:

```ts
  async voidSale(): Promise<void> {
    throw new Error('SaleRepository.voidSale not implemented yet (phase 11)');
  }
```

with the implementation:

```ts
  async voidSale(
    id: string,
    reason: string,
    actorId: string,
    actorName: string,
  ): Promise<void> {
    // Items are immutable once written, so loading them before the transaction
    // is safe (a subcollection query can't run inside a transaction anyway).
    const items = await this.loadItems(id);
    const saleRef = doc(this.db, FirestoreCollections.sales, id);

    await runTransaction(this.db, async (tx) => {
      const snap = await tx.get(saleRef); // the only read — precedes every write
      if (!snap.exists()) throw new Error('Sale not found');
      if (snap.get('status') === SaleStatus.voided) {
        throw new Error('This sale is already voided');
      }

      tx.update(saleRef, {
        status: SaleStatus.voided,
        voidedAt: serverTimestamp(),
        voidedBy: actorId,
        voidedByName: actorName,
        voidReason: reason,
        updatedAt: serverTimestamp(),
        updatedBy: actorId,
      });

      // Stock restore — the reverse of the create() decrement. The products
      // update rule permits ONLY these 4 keys.
      for (const item of items) {
        tx.update(doc(this.db, FirestoreCollections.products, item.productId), {
          quantity: increment(item.quantity),
          updatedAt: serverTimestamp(),
          updatedBy: actorId,
          updatedByName: actorName,
        });
      }
    });
  }
```

- [ ] **Step 3: Typecheck**

Run: `npm run typecheck`
Expected: clean (the void method now matches the interface signature; was previously a no-arg stub).

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreSaleRepository.ts
git commit -m "feat(web): implement voidSale — atomic mark-voided + stock restore"
```

---

### Task 3: `useVoidSale` + Void button & reason dialog on Sale Detail

**Files:**
- Create: `web_admin/src/presentation/hooks/useVoidSale.ts`
- Modify: `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`

**Interfaces:**
- Consumes: `useSaleRepo`, `useAuthStore`, `useQueryClient`/`useMutation`, `canVoidSale` (Task 1), `useActiveCategories` (`@/presentation/hooks/useCategories`), `CategoryKind` (`@/domain/categories/categoryKind`), the common `Dialog`.
- Produces: `useVoidSale(saleId: string)` — mutation taking `{ reason: string }`, invalidates `['sales', saleId]` on success.

- [ ] **Step 1: Create the mutation hook**

Create `web_admin/src/presentation/hooks/useVoidSale.ts`:

```ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';

export function useVoidSale(saleId: string) {
  const repo = useSaleRepo();
  const actor = useAuthStore((s) => s.user);
  const qc = useQueryClient();
  return useMutation<void, Error, { reason: string }>({
    mutationFn: async ({ reason }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || actor.email;
      await repo.voidSale(saleId, reason, actor.id, actorName);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['sales', saleId] });
    },
  });
}
```

- [ ] **Step 2: Add the imports + state to SaleDetailPage**

In `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`:
- Change the React import to include `useState`:

```tsx
import { useEffect, useState } from 'react';
```

- Add these imports below the existing ones:

```tsx
import { useVoidSale } from '@/presentation/hooks/useVoidSale';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { canVoidSale } from '@/domain/sales/voiding';
import { Dialog } from '@/presentation/components/common/Dialog';
```

- Inside `SaleDetailPage`, after the `useQuery` block, add the void hooks + dialog state:

```tsx
  const voidSale = useVoidSale(id);
  const { data: voidReasons } = useActiveCategories(CategoryKind.voidReason);
  const [voidOpen, setVoidOpen] = useState(false);
  const [reason, setReason] = useState('');
```

- [ ] **Step 3: Add the Void button + dialog to the render**

In `SaleDetailPage.tsx`, immediately after the `</header>` closing tag (and before the `<section>` with the items table), insert the action bar:

```tsx
      {canVoidSale(sale) ? (
        <div className="flex flex-wrap gap-tk-sm">
          <button
            type="button"
            onClick={() => {
              setReason('');
              setVoidOpen(true);
            }}
            className="rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall font-medium text-error-dark hover:bg-error-light/30"
          >
            Void sale
          </button>
        </div>
      ) : null}
```

- Add the void dialog just before the final closing `</div>` of the page root (after the totals `<section>`):

```tsx
      <Dialog
        open={voidOpen}
        onClose={() => {
          if (!voidSale.isPending) setVoidOpen(false);
        }}
        title="Void sale"
        dismissable={!voidSale.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text-secondary">
            Voiding restores the sold stock and removes this sale from reports. This can’t be undone.
          </p>
          {(voidReasons ?? []).length === 0 ? (
            <p className="text-bodySmall text-light-text-secondary">
              No void reasons configured.{' '}
              <Link to="/settings/lists" className="text-light-text underline">
                Add them in Manage lists
              </Link>
              .
            </p>
          ) : (
            <label className="block space-y-tk-xs">
              <span className="text-bodySmall text-light-text-secondary">Reason</span>
              <select
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall"
              >
                <option value="">Select a reason…</option>
                {(voidReasons ?? []).map((r) => (
                  <option key={r.id} value={r.name}>
                    {r.name}
                  </option>
                ))}
              </select>
            </label>
          )}
          {voidSale.error ? (
            <p className="text-bodySmall text-error-dark">{voidSale.error.message}</p>
          ) : null}
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setVoidOpen(false)}
              disabled={voidSale.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!reason || voidSale.isPending}
              onClick={async () => {
                try {
                  await voidSale.mutateAsync({ reason });
                  setVoidOpen(false);
                } catch {
                  // surfaced via voidSale.error
                }
              }}
              className="rounded-md bg-error px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:bg-error-dark disabled:opacity-60"
            >
              {voidSale.isPending ? 'Voiding…' : 'Void sale'}
            </button>
          </div>
        </div>
      </Dialog>
```

(`Link` is already imported at the top of the file.)

- [ ] **Step 4: Typecheck + build**

Run: `npm run typecheck && npm run build`
Expected: both clean (the void flow is verified by browser smoke in Task 5).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/hooks/useVoidSale.ts web_admin/src/presentation/features/reports/SaleDetailPage.tsx
git commit -m "feat(web): void a sale from Sale Detail (reason dialog + stock-restoring void)"
```

---

## Slice 5b — Receipt

### Task 4: `Receipt` component + browser print

**Files:**
- Create: `web_admin/src/presentation/features/reports/Receipt.tsx`
- Modify: `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`

**Interfaces:**
- Consumes: the Sale money helpers (`salePartsSubtotal`, `saleTotalDiscount`, `saleLaborSubtotal`, `saleGrandTotal`, `saleEffectiveTenders`, `saleIsPercentageDiscount`, `saleItemNet`, `saleIsVoided`), `realTenderMethods` + `paymentMethodDisplayName` (`@/domain/enums`), `formatMoney`.
- Produces: `Receipt({ sale }: { sale: Sale })` — a print-formatted block.

- [ ] **Step 1: Create the Receipt component**

Create `web_admin/src/presentation/features/reports/Receipt.tsx`:

```tsx
import {
  saleEffectiveTenders,
  saleGrandTotal,
  saleIsPercentageDiscount,
  saleIsVoided,
  saleItemNet,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';
import type { Sale } from '@/domain/entities';
import { paymentMethodDisplayName, realTenderMethods } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';

const RECEIPT_STORE_NAME = 'MAKI Mobile POS';
const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function Receipt({ sale }: { sale: Sale }) {
  const isPct = saleIsPercentageDiscount(sale);
  const tenders = saleEffectiveTenders(sale);
  const voided = saleIsVoided(sale);

  return (
    <div className="mx-auto max-w-[320px] p-tk-md font-mono text-[12px] text-light-text">
      <div className="text-center">
        <div className="text-[14px] font-bold">{RECEIPT_STORE_NAME}</div>
        <div>{sale.saleNumber}</div>
        <div>{dtFmt.format(sale.createdAt)}</div>
        <div>Cashier: {sale.cashierName}</div>
        {sale.mechanicName ? <div>Mechanic: {sale.mechanicName}</div> : null}
      </div>

      {voided ? (
        <div className="my-tk-sm text-center font-bold">
          *** VOIDED ***{sale.voidReason ? ` (${sale.voidReason})` : ''}
        </div>
      ) : null}

      <Divider />

      {sale.items.map((it) => (
        <div key={it.id} className="flex justify-between gap-tk-sm">
          <span className="min-w-0 truncate">
            {it.name}{' '}
            <span className="text-[10px] text-light-text-hint">
              {it.quantity}×{formatMoney(it.unitPrice)}
            </span>
          </span>
          <span className="tabular-nums">{formatMoney(saleItemNet(it, isPct))}</span>
        </div>
      ))}
      {sale.laborLines.map((l) => (
        <div key={l.id} className="flex justify-between gap-tk-sm">
          <span className="min-w-0 truncate">🔧 {l.description || 'Service'}</span>
          <span className="tabular-nums">{formatMoney(l.fee)}</span>
        </div>
      ))}

      <Divider />

      <Line label="Subtotal" value={formatMoney(salePartsSubtotal(sale))} />
      <Line label="Discount" value={`-${formatMoney(saleTotalDiscount(sale))}`} />
      <Line label="Labor" value={formatMoney(saleLaborSubtotal(sale))} />
      <Line label="TOTAL" value={formatMoney(saleGrandTotal(sale))} bold />

      <Divider />

      {realTenderMethods
        .filter((m) => (tenders[m] ?? 0) > 0)
        .map((m) => (
          <Line key={m} label={paymentMethodDisplayName[m]} value={formatMoney(tenders[m] ?? 0)} />
        ))}
      <Line label="Amount received" value={formatMoney(sale.amountReceived)} />
      <Line label="Change" value={formatMoney(sale.changeGiven)} />

      <div className="mt-tk-md text-center text-[11px] text-light-text-secondary">Thank you!</div>
    </div>
  );
}

function Divider() {
  return <div className="my-tk-sm border-t border-dashed border-light-border" />;
}

function Line({ label, value, bold }: { label: string; value: string; bold?: boolean }) {
  return (
    <div className={`flex justify-between ${bold ? 'font-bold' : ''}`}>
      <span>{label}</span>
      <span className="tabular-nums">{value}</span>
    </div>
  );
}
```

- [ ] **Step 2: Wire the Receipt + Print button into SaleDetailPage**

In `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`:
- Add the import: `import { Receipt } from './Receipt';`
- Add a **Print receipt** button into the action bar. The action bar currently
  renders only when `canVoidSale(sale)`; replace that whole block with one that
  always renders (Print) and conditionally adds Void:

```tsx
      <div className="flex flex-wrap gap-tk-sm">
        <button
          type="button"
          onClick={() => window.print()}
          className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle"
        >
          Print receipt
        </button>
        {canVoidSale(sale) ? (
          <button
            type="button"
            onClick={() => {
              setReason('');
              setVoidOpen(true);
            }}
            className="rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall font-medium text-error-dark hover:bg-error-light/30"
          >
            Void sale
          </button>
        ) : null}
      </div>
```

- Wrap the page so only the receipt prints. Change the **outermost** returned
  element from `<div className="space-y-tk-lg px-tk-xl py-tk-lg">…</div>` to a
  fragment: add `print:hidden` to that div's className, and render the receipt
  as a sibling. The structure becomes:

```tsx
  return (
    <>
      <div className="space-y-tk-lg px-tk-xl py-tk-lg print:hidden">
        {/* …existing header, action bar, item table, totals, void dialog… */}
      </div>
      <div className="hidden print:block">
        <Receipt sale={sale} />
      </div>
    </>
  );
```

(Keep the void `<Dialog>` inside the `print:hidden` div — it must not print.)

- [ ] **Step 3: Typecheck + build + test**

Run: `npm run typecheck && npm run build && npm run test`
Expected: typecheck clean; build succeeds; all tests green (no behavior change to existing suites).

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/features/reports/Receipt.tsx web_admin/src/presentation/features/reports/SaleDetailPage.tsx
git commit -m "feat(web): printable receipt on Sale Detail (browser print)"
```

---

### Task 5: Verify end-to-end

**Files:** none (verification only).

- [ ] **Step 1: Full typecheck + tests + build**

Run: `npm run typecheck && npm run test && npm run build`
Expected: typecheck clean; all suites green (incl. `voiding`); build succeeds.

- [ ] **Step 2: Browser smoke — void restores stock + drops from reports**

`npm run dev`, sign in. Note a product's current stock. From `/pos` complete a small cash sale that includes that product. Open it in **Reports → Sale Detail** → **Void sale** → pick a reason → confirm. ✅ The sale now shows the **Voided** badge; in **Reports → Sales** the totals **drop** the sale; the product's stock went **back up** by the sold quantity (check Inventory). ✅ Re-opening the voided sale shows **no** Void button.

(If `void_reasons` is empty, the dialog links to Manage lists — add one at `/settings/lists` → Void reasons first.)

- [ ] **Step 3: Browser smoke — print receipt**

On a Sale Detail page, click **Print receipt** → ✅ the browser print dialog opens showing only a clean receipt (store header, sale#, items, labor, totals, tenders, change) — not the full admin page. Print a voided sale → ✅ the receipt shows the **VOIDED** stamp + reason.

- [ ] **Step 4: Commit (only if smoke-fix tweaks were needed)**

```bash
git add -A
git commit -m "fix(web): receipt/void smoke-test fixes"
```

---

## Notes for the implementer

- **Spec:** `docs/superpowers/specs/2026-06-20-web-pos-phase5-receipt-void-design.md`.
- **Green between tasks:** Task 1 (helper) and Task 2 (repo) are additive; Task 3 adds the void UI; Task 4 adds the receipt + the `print:` wrapping. Each leaves typecheck + tests green.
- **No deploy.** Deployment (push + `firebase deploy --only hosting`) is a separate, explicitly-authorized step.
- **This is the final POS-epic phase.**
```
