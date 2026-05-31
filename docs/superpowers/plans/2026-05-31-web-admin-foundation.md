# Web Admin Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the web admin onto the React `web_admin/` app served at root `/`, remove the Flutter web layer, and bring the React sales data model up to date with the labor-era Firestore schema behind a shared `summarizeSales()` util.

**Architecture:** Two codebases change. In `web_admin/` (Vite + React 18 + Tailwind + React Query + Firebase) we extend the `Sale` types + Firestore converter with labor/mechanic/tenders + the full payment-method set, add a `summarizeSales()` util mirroring the Dart `getSalesSummary` (parts-only top-line + parallel labor track), wire it into the existing DashboardPage, and move the app from `/admin` to `/`. In the Flutter app we delete the now-redundant web layer (mobile-only) and repoint Firebase hosting to the React build.

**Tech Stack:** React 18, TypeScript (strict), Vite, Vitest + @testing-library, Firebase Web SDK; Flutter (removal only); Firebase Hosting.

**Spec:** docs/superpowers/specs/2026-05-31-web-admin-foundation-design.md

---

### Task 1: Add `maya` / `salmon` / `mixed` to the React `PaymentMethod`

**Files:**
- Modify: `web_admin/src/domain/enums/PaymentMethod.ts`
- Test: `web_admin/src/domain/enums/PaymentMethod.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/enums/PaymentMethod.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import {
  PaymentMethod,
  paymentMethodFromString,
  realTenderMethods,
} from './PaymentMethod';

describe('PaymentMethod', () => {
  it('maps every known Firestore value, defaulting unknown to cash', () => {
    expect(paymentMethodFromString('cash')).toBe(PaymentMethod.cash);
    expect(paymentMethodFromString('gcash')).toBe(PaymentMethod.gcash);
    expect(paymentMethodFromString('maya')).toBe(PaymentMethod.maya);
    expect(paymentMethodFromString('salmon')).toBe(PaymentMethod.salmon);
    expect(paymentMethodFromString('mixed')).toBe(PaymentMethod.mixed);
    expect(paymentMethodFromString('bogus')).toBe(PaymentMethod.cash);
    expect(paymentMethodFromString(null)).toBe(PaymentMethod.cash);
  });

  it('realTenderMethods are the money-holding buckets and exclude mixed', () => {
    expect(realTenderMethods).toEqual([
      PaymentMethod.cash,
      PaymentMethod.gcash,
      PaymentMethod.maya,
      PaymentMethod.salmon,
    ]);
    expect(realTenderMethods).not.toContain(PaymentMethod.mixed);
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `cd web_admin && npx vitest run src/domain/enums/PaymentMethod.test.ts`. Expected: FAIL — `realTenderMethods` is not exported, and `paymentMethodFromString('maya')` returns `cash`.

- [ ] **Step 3: Implement** — replace the entire contents of `web_admin/src/domain/enums/PaymentMethod.ts`:
```ts
// Mirror of lib/core/enums/payment_method.dart.
export const PaymentMethod = {
  cash: 'cash',
  gcash: 'gcash',
  maya: 'maya',
  salmon: 'salmon',
  mixed: 'mixed',
} as const;

export type PaymentMethod = (typeof PaymentMethod)[keyof typeof PaymentMethod];

export const paymentMethodDisplayName: Record<PaymentMethod, string> = {
  cash: 'Cash',
  gcash: 'GCash',
  maya: 'Maya',
  salmon: 'Salmon',
  mixed: 'Mixed',
};

const _knownMethods = new Set<string>(Object.values(PaymentMethod));

export function paymentMethodFromString(
  value: string | null | undefined,
): PaymentMethod {
  return value != null && _knownMethods.has(value)
    ? (value as PaymentMethod)
    : PaymentMethod.cash;
}

export function paymentMethodHasFees(method: PaymentMethod): boolean {
  return method === PaymentMethod.gcash || method === PaymentMethod.maya;
}

/// Real tender buckets that can physically hold money. `mixed` is a label for
/// a split sale, never a bucket — its split lands in the real buckets via the
/// sale's `tenders` map.
export const realTenderMethods: PaymentMethod[] = [
  PaymentMethod.cash,
  PaymentMethod.gcash,
  PaymentMethod.maya,
  PaymentMethod.salmon,
];
```

- [ ] **Step 4: Run it, expect PASS** — `cd web_admin && npx vitest run src/domain/enums/PaymentMethod.test.ts`.

- [ ] **Step 5: Commit** — `git add web_admin/src/domain/enums/PaymentMethod.ts web_admin/src/domain/enums/PaymentMethod.test.ts && git commit -m "feat(web-admin): add maya/salmon/mixed payment methods + realTenderMethods"`

---

### Task 2: Add `LaborLine` + labor/mechanic/tenders fields and labor-aware money helpers to `Sale`

**Files:**
- Create: `web_admin/src/domain/entities/LaborLine.ts`
- Modify: `web_admin/src/domain/entities/index.ts`
- Modify: `web_admin/src/domain/entities/Sale.ts`
- Test: `web_admin/src/domain/entities/Sale.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/entities/Sale.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import {
  type Sale,
  saleEffectiveTenders,
  saleGrandTotal,
  saleLaborProfit,
  saleLaborRevenue,
  saleLaborSubtotal,
  salePartsProfit,
  salePartsRevenue,
  salePartsSubtotal,
  saleTotalCost,
  saleTotalProfit,
} from './Sale';

function baseSale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'S-1',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 0,
        unit: 'pcs',
      },
    ],
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 200,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-30T10:00:00Z'),
    updatedAt: null,
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

describe('Sale money math (labor-aware)', () => {
  it('parts-only sale: grandTotal equals parts revenue, no labor', () => {
    const s = baseSale();
    expect(salePartsSubtotal(s)).toBe(200);
    expect(salePartsRevenue(s)).toBe(200);
    expect(saleLaborSubtotal(s)).toBe(0);
    expect(saleGrandTotal(s)).toBe(200);
    expect(saleTotalCost(s)).toBe(120);
    expect(salePartsProfit(s)).toBe(80);
    expect(saleTotalProfit(s)).toBe(80);
  });

  it('labor raises grandTotal/profit but not the parts figures', () => {
    const s = baseSale({
      laborLines: [
        { id: 'l1', description: 'Tune-up', fee: 300 },
        { id: 'l2', description: 'Bleed', fee: 150 },
      ],
    });
    expect(salePartsRevenue(s)).toBe(200); // unchanged
    expect(saleLaborSubtotal(s)).toBe(450);
    expect(saleLaborRevenue(s)).toBe(450);
    expect(saleGrandTotal(s)).toBe(650); // 200 + 450
    expect(salePartsProfit(s)).toBe(80); // parts only
    expect(saleLaborProfit(s)).toBe(450);
    expect(saleTotalProfit(s)).toBe(530); // 80 + 450
  });

  it('effectiveTenders falls back to grandTotal on the payment method', () => {
    const s = baseSale({
      laborLines: [{ id: 'l1', description: 'x', fee: 300 }],
    });
    expect(saleEffectiveTenders(s)).toEqual({ cash: 500 }); // 200 + 300
  });

  it('effectiveTenders uses the explicit tenders map for a mixed sale', () => {
    const s = baseSale({
      paymentMethod: PaymentMethod.mixed,
      tenders: { cash: 120, gcash: 80 },
    });
    expect(saleEffectiveTenders(s)).toEqual({ cash: 120, gcash: 80 });
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `cd web_admin && npx vitest run src/domain/entities/Sale.test.ts`. Expected: FAIL — the new helpers are undefined and `Sale` has no `laborLines`/`tenders` so the fixture object errors under `strict`.

- [ ] **Step 3a: Implement** — create `web_admin/src/domain/entities/LaborLine.ts`:
```ts
// Mirror of lib/domain/entities/labor_line_entity.dart. Stored INLINE on the
// sale document's `laborLines` array (not a subcollection). Labor is full
// price, never discounted, and has zero cost (pure margin).
export interface LaborLine {
  id: string;
  description: string;
  fee: number;
}
```

- [ ] **Step 3b: Implement** — add the barrel export to `web_admin/src/domain/entities/index.ts` (after the `export * from './Sale';` line):
```ts
export * from './LaborLine';
```

- [ ] **Step 3c: Implement** — edit `web_admin/src/domain/entities/Sale.ts`. Replace the import block at the top (lines 4–11) with one that adds the `LaborLine` type import (keep `type PaymentMethod` — it's used only as a type here):
```ts
import { DiscountType, type PaymentMethod, SaleStatus } from '../enums';
import type { LaborLine } from './LaborLine';
import {
  saleItemDiscountAmount,
  saleItemGross,
  saleItemNet,
  saleItemTotalCost,
  type SaleItem,
} from './SaleItem';
```
Add four fields to the `Sale` interface (after `items: SaleItem[];`):
```ts
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  tenders: Partial<Record<PaymentMethod, number>>;
```
Replace the existing `saleGrandTotal` getter (currently `saleSubtotal(sale) - saleTotalDiscount(sale)`) and the existing `saleTotalProfit` getter with the labor-aware money block, and add the parts/labor helpers + `saleEffectiveTenders`. Concretely, REPLACE these two functions:
```ts
export function saleGrandTotal(sale: Sale): number {
  return saleSubtotal(sale) - saleTotalDiscount(sale);
}
```
and
```ts
export function saleTotalProfit(sale: Sale): number {
  return saleGrandTotal(sale) - saleTotalCost(sale);
}
```
with this block:
```ts
// ==================== LABOR-AWARE MONEY MATH ====================
// Mirrors the Dart contract: grandTotal = partsRevenue + laborRevenue, where
// labor is full price (never discounted) and zero cost.

export function salePartsSubtotal(sale: Sale): number {
  return saleSubtotal(sale);
}

export function salePartsRevenue(sale: Sale): number {
  return salePartsSubtotal(sale) - saleTotalDiscount(sale);
}

export function saleLaborSubtotal(sale: Sale): number {
  return sale.laborLines.reduce((sum, line) => sum + line.fee, 0);
}

export function saleLaborRevenue(sale: Sale): number {
  return saleLaborSubtotal(sale);
}

export function saleGrandTotal(sale: Sale): number {
  return salePartsRevenue(sale) + saleLaborRevenue(sale);
}

export function salePartsProfit(sale: Sale): number {
  return salePartsRevenue(sale) - saleTotalCost(sale);
}

export function saleLaborProfit(sale: Sale): number {
  return saleLaborRevenue(sale);
}

export function saleTotalProfit(sale: Sale): number {
  return salePartsProfit(sale) + saleLaborProfit(sale);
}

/// Normalized payment breakdown. When the sale carries an explicit `tenders`
/// map (e.g. a mixed split), use it; otherwise attribute the whole
/// labor-inclusive grandTotal to the single payment method.
export function saleEffectiveTenders(
  sale: Sale,
): Partial<Record<PaymentMethod, number>> {
  if (Object.keys(sale.tenders).length > 0) return sale.tenders;
  return { [sale.paymentMethod]: saleGrandTotal(sale) };
}
```
Leave `saleSubtotal`, `saleTotalDiscount`, `saleTotalCost`, `saleNetAmount`, `saleIsVoided`, `saleTotalItemCount`, `saleIsPercentageDiscount` unchanged.

- [ ] **Step 4: Run it, expect PASS** — `cd web_admin && npx vitest run src/domain/entities/Sale.test.ts`.

- [ ] **Step 5: Commit** — `git add web_admin/src/domain/entities/LaborLine.ts web_admin/src/domain/entities/index.ts web_admin/src/domain/entities/Sale.ts web_admin/src/domain/entities/Sale.test.ts && git commit -m "feat(web-admin): labor lines + mechanic + tenders + labor-aware money helpers on Sale"`

---

### Task 3: Parse labor/mechanic/tenders in `saleConverter`

**Files:**
- Modify: `web_admin/src/data/converters/saleConverter.ts`
- Test: `web_admin/src/data/converters/saleConverter.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/data/converters/saleConverter.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { saleConverter } from './saleConverter';

// Minimal QueryDocumentSnapshot stub — the converter only reads `.id`/`.data()`.
function snap(id: string, data: Record<string, unknown>) {
  return { id, data: () => data } as never;
}
const opts = {} as never;

describe('saleConverter.fromFirestore', () => {
  it('parses inline laborLines, mechanic, and a tenders map', () => {
    const sale = saleConverter.fromFirestore(
      snap('s1', {
        saleNumber: 'S-1',
        discountType: 'amount',
        paymentMethod: 'mixed',
        amountReceived: 650,
        changeGiven: 0,
        status: 'completed',
        cashierId: 'c1',
        cashierName: 'Cashier',
        createdAt: new Date('2026-05-30T10:00:00Z'),
        laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
        mechanicId: 'mech-1',
        mechanicName: 'Juan',
        tenders: { cash: 400, gcash: 250 },
      }),
      opts,
    );

    expect(sale.laborLines).toHaveLength(1);
    expect(sale.laborLines[0]).toEqual({
      id: 'l1',
      description: 'Tune-up',
      fee: 450,
    });
    expect(sale.mechanicId).toBe('mech-1');
    expect(sale.mechanicName).toBe('Juan');
    expect(sale.paymentMethod).toBe('mixed');
    expect(sale.tenders).toEqual({ cash: 400, gcash: 250 });
  });

  it('keeps maya/salmon tenders and drops unknown keys', () => {
    const sale = saleConverter.fromFirestore(
      snap('s2', {
        paymentMethod: 'maya',
        status: 'completed',
        createdAt: new Date('2026-05-30T10:00:00Z'),
        tenders: { maya: 300, salmon: 100, bogus: 999 },
      }),
      opts,
    );
    expect(sale.paymentMethod).toBe('maya');
    expect(sale.tenders).toEqual({ maya: 300, salmon: 100 });
  });

  it('legacy doc without labor/mechanic/tenders defaults to []/null/{}', () => {
    const sale = saleConverter.fromFirestore(
      snap('s3', {
        paymentMethod: 'cash',
        status: 'completed',
        createdAt: new Date('2026-05-30T10:00:00Z'),
      }),
      opts,
    );
    expect(sale.laborLines).toEqual([]);
    expect(sale.mechanicId).toBeNull();
    expect(sale.mechanicName).toBeNull();
    expect(sale.tenders).toEqual({});
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `cd web_admin && npx vitest run src/data/converters/saleConverter.test.ts`. Expected: FAIL — `sale.laborLines`/`sale.tenders` are `undefined` (converter does not set them yet).

- [ ] **Step 3: Implement** — edit `web_admin/src/data/converters/saleConverter.ts`. Replace the import block (lines 5–16) with one that also imports the payment-method bucket list + `LaborLine`/`PaymentMethod` types:
```ts
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { LaborLine, Sale } from '@/domain/entities';
import {
  type PaymentMethod,
  discountTypeFromString,
  paymentMethodFromString,
  realTenderMethods,
  saleStatusFromString,
} from '@/domain/enums';
import { requireDate, toDate } from './timestamps';
```
Add `laborLines`/`mechanicId`/`mechanicName`/`tenders` to the `toFirestore` return object (after `voidReason: sale.voidReason,`):
```ts
      laborLines: sale.laborLines.map((l) => ({
        id: l.id,
        description: l.description,
        fee: l.fee,
      })),
      mechanicId: sale.mechanicId,
      mechanicName: sale.mechanicName,
      tenders: sale.tenders,
```
Add the four fields to the `fromFirestore` return object (after `items: [], // loaded separately from the items subcollection`):
```ts
      laborLines: parseLaborLines(d.laborLines),
      mechanicId: d.mechanicId ?? null,
      mechanicName: d.mechanicName ?? null,
      tenders: parseTenders(d.tenders),
```
Add these two module-level helper functions at the BOTTOM of the file (after the `saleConverter` object):
```ts
function parseLaborLines(value: unknown): LaborLine[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `labor-${i}`,
      description: typeof m.description === 'string' ? m.description : '',
      fee: Number(m.fee ?? 0),
    };
  });
}

function parseTenders(
  value: unknown,
): Partial<Record<PaymentMethod, number>> {
  if (value == null || typeof value !== 'object') return {};
  const out: Partial<Record<PaymentMethod, number>> = {};
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if ((realTenderMethods as string[]).includes(key)) {
      out[key as PaymentMethod] = Number(raw ?? 0);
    }
  }
  return out;
}
```

- [ ] **Step 4: Run it, expect PASS** — `cd web_admin && npx vitest run src/data/converters/saleConverter.test.ts`.

- [ ] **Step 5: Commit** — `git add web_admin/src/data/converters/saleConverter.ts web_admin/src/data/converters/saleConverter.test.ts && git commit -m "feat(web-admin): parse inline laborLines + mechanic + tenders in saleConverter"`

---

### Task 4: Add the shared `summarizeSales()` util

**Files:**
- Create: `web_admin/src/domain/sales/summarizeSales.ts`
- Test: `web_admin/src/domain/sales/summarizeSales.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/sales/summarizeSales.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import { type Sale } from '../entities';
import { summarizeSales } from './summarizeSales';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's',
    saleNumber: 'S',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 0,
        unit: 'pcs',
      },
    ],
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 200,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-30T10:00:00Z'),
    updatedAt: null,
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

describe('summarizeSales', () => {
  it('parts-only sale: top-line is parts, labor track is zero', () => {
    const s = summarizeSales([sale()]);
    expect(s.totalSalesCount).toBe(1);
    expect(s.grossAmount).toBe(200);
    expect(s.netAmount).toBe(200);
    expect(s.totalCost).toBe(120);
    expect(s.totalProfit).toBe(80);
    expect(s.laborRevenue).toBe(0);
    expect(s.byPaymentMethod.cash).toBe(200);
  });

  it('labor sale: parts-only top-line + labor track; cash bucket is labor-inclusive', () => {
    const s = summarizeSales([
      sale({ laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }] }),
    ]);
    // Parts-only top-line (NOT 650).
    expect(s.grossAmount).toBe(200);
    expect(s.netAmount).toBe(200);
    expect(s.totalProfit).toBe(80);
    // Labor track.
    expect(s.laborRevenue).toBe(450);
    expect(s.laborProfit).toBe(450);
    // Cash bucket holds the whole labor-inclusive grandTotal.
    expect(s.byPaymentMethod.cash).toBe(650);
    // Reconciliation identity.
    const tenderTotal = Object.values(s.byPaymentMethod).reduce((a, b) => a + b, 0);
    expect(tenderTotal).toBe(s.netAmount + s.laborRevenue); // 650
  });

  it('mixed-tender sale splits into real buckets; mixed never holds money', () => {
    const s = summarizeSales([
      sale({ paymentMethod: PaymentMethod.mixed, tenders: { cash: 120, gcash: 80 } }),
    ]);
    expect(s.byPaymentMethod.cash).toBe(120);
    expect(s.byPaymentMethod.gcash).toBe(80);
    expect(s.byPaymentMethod.mixed).toBe(0);
  });

  it('excludes voided sales from money but counts them', () => {
    const s = summarizeSales([sale(), sale({ status: SaleStatus.voided })]);
    expect(s.totalSalesCount).toBe(1);
    expect(s.voidedSalesCount).toBe(1);
    expect(s.netAmount).toBe(200);
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `cd web_admin && npx vitest run src/domain/sales/summarizeSales.test.ts`. Expected: FAIL — module `./summarizeSales` does not exist.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/sales/summarizeSales.ts`:
```ts
// Mirror of lib/data/repositories/sale_repository_impl.dart getSalesSummary.
// The merchandise top-line stays PARTS-ONLY; labor rides a parallel track;
// payment buckets are labor-inclusive (the drawer physically holds labor cash).

import {
  type Sale,
  saleEffectiveTenders,
  saleIsVoided,
  saleLaborRevenue,
  salePartsRevenue,
  salePartsSubtotal,
  saleTotalCost,
  saleTotalDiscount,
} from '../entities';
import { type PaymentMethod, realTenderMethods } from '../enums';

export interface SalesSummary {
  totalSalesCount: number;
  voidedSalesCount: number;
  grossAmount: number;
  totalDiscounts: number;
  netAmount: number;
  totalCost: number;
  totalProfit: number;
  laborRevenue: number;
  laborProfit: number;
  byPaymentMethod: Record<PaymentMethod, number>;
  averageSaleAmount: number;
  profitMargin: number;
}

export function summarizeSales(sales: Sale[]): SalesSummary {
  const completed = sales.filter((s) => !saleIsVoided(s));
  const voidedCount = sales.length - completed.length;

  const byPaymentMethod: Record<PaymentMethod, number> = {
    cash: 0,
    gcash: 0,
    maya: 0,
    salmon: 0,
    mixed: 0, // a label, never a bucket — always stays 0
  };

  let grossAmount = 0;
  let totalDiscounts = 0;
  let netAmount = 0;
  let totalCost = 0;
  let laborRevenue = 0;

  for (const s of completed) {
    grossAmount += salePartsSubtotal(s);
    totalDiscounts += saleTotalDiscount(s);
    netAmount += salePartsRevenue(s);
    totalCost += saleTotalCost(s);
    laborRevenue += saleLaborRevenue(s);
    const eff = saleEffectiveTenders(s);
    for (const method of realTenderMethods) {
      byPaymentMethod[method] += eff[method] ?? 0;
    }
  }

  const totalProfit = netAmount - totalCost;
  const count = completed.length;

  return {
    totalSalesCount: count,
    voidedSalesCount: voidedCount,
    grossAmount,
    totalDiscounts,
    netAmount,
    totalCost,
    totalProfit,
    laborRevenue,
    laborProfit: laborRevenue, // labor has zero cost
    byPaymentMethod,
    averageSaleAmount: count === 0 ? 0 : netAmount / count,
    profitMargin: netAmount === 0 ? 0 : (totalProfit / netAmount) * 100,
  };
}
```

- [ ] **Step 4: Run it, expect PASS** — `cd web_admin && npx vitest run src/domain/sales/summarizeSales.test.ts`.

- [ ] **Step 5: Commit** — `git add web_admin/src/domain/sales/summarizeSales.ts web_admin/src/domain/sales/summarizeSales.test.ts && git commit -m "feat(web-admin): add summarizeSales util (parts-only top-line + labor track)"`

---

### Task 5: Point DashboardPage at `summarizeSales`

**Files:**
- Modify: `web_admin/src/presentation/features/dashboard/DashboardPage.tsx`

- [ ] **Step 1: Implement** — in `web_admin/src/presentation/features/dashboard/DashboardPage.tsx`:

Replace the imports block (lines 11–23) — drop the now-unused per-sale helpers, import `summarizeSales`:
```ts
import { useTodaysSales } from '@/presentation/hooks/useTodaysSales';
import { summarizeSales } from '@/domain/sales/summarizeSales';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { SummaryCard } from './SummaryCard';
import { RecentSales } from './RecentSales';
import { InventoryStatus } from './InventoryStatus';
import { formatMoney } from '@/core/utils/money';
```

Delete the local `interface SalesSummary { … }` and the `function summarize(sales) { … }` block (lines 25–49 in the original).

Replace the `const summary = useMemo(...)` line (line 53) with a memo over `summarizeSales` plus the displayed figures (revenue is the labor-inclusive money taken; profit already includes labor):
```ts
  const summary = useMemo(() => summarizeSales(sales ?? []), [sales]);
  const revenue = summary.netAmount + summary.laborRevenue;
  const profit = summary.totalProfit;
  const count = summary.totalSalesCount;
  const averageOrder = count === 0 ? 0 : revenue / count;
```

Update the four `SummaryCard` value props to use the new locals:
```tsx
          <SummaryCard
            title="Sales today"
            value={String(count)}
            icon={ReceiptPercentIcon}
            tone="blue"
          />
          <SummaryCard
            title="Revenue"
            value={formatMoney(revenue)}
            icon={BanknotesIcon}
            tone="yellow"
            emphasized
          />
          <SummaryCard
            title="Gross profit"
            value={formatMoney(profit)}
            icon={ArrowTrendingUpIcon}
            tone="green"
          />
          <SummaryCard
            title="Avg order"
            value={formatMoney(averageOrder)}
            icon={ChartBarIcon}
            tone="violet"
          />
```

- [ ] **Step 2: Verify it typechecks + builds** — `cd web_admin && npx tsc -b --noEmit`. Expected: no errors (the removed imports are gone; `summarizeSales` resolves). Then `npx vitest run` — all existing tests still pass.

- [ ] **Step 3: Commit** — `git add web_admin/src/presentation/features/dashboard/DashboardPage.tsx && git commit -m "feat(web-admin): dashboard uses summarizeSales (labor-inclusive revenue, correct profit)"`

---

### Task 6: Serve the React app at root `/`

**Files:**
- Modify: `web_admin/vite.config.ts`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Implement** — replace the entire contents of `web_admin/vite.config.ts`:
```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

export default defineConfig({
  base: '/',
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: true,
  },
  server: {
    port: 5173,
  },
});
```

- [ ] **Step 2: Implement** — in `web_admin/src/presentation/router/routes.tsx`, change the `createBrowserRouter` options (the `{ basename: '/admin' }` second argument, ~line 74) to root:
```ts
  { basename: '/' },
```

- [ ] **Step 3: Verify the build** — `cd web_admin && npm run build`. Expected: succeeds and emits to `web_admin/dist/` (check `ls web_admin/dist/index.html`). Confirm `dist/index.html`'s asset paths are root-relative (`/assets/...`, no `/admin/` prefix): `grep -o "/admin/" web_admin/dist/index.html || echo "no /admin/ refs (good)"`.

- [ ] **Step 4: Commit** — `git add web_admin/vite.config.ts web_admin/src/presentation/router/routes.tsx && git commit -m "feat(web-admin): serve at root (base /, drop /admin basename), build to dist"`

---

### Task 7: Remove the Flutter web layer (mobile-only)

**Files:**
- Modify: `lib/main.dart`
- Delete: `lib/presentation/web/` (whole folder), `lib/app_web.dart`, `lib/config/router/web_router.dart`, `web/` (Flutter web platform folder)
- Modify: any file that imports the deleted symbols (discovered in Step 1)

- [ ] **Step 1: Find every reference to the web layer** — from repo root:
```bash
grep -rn "app_web\|MAKIPOSWebApp\|web_router\|webRouterProvider\|presentation/web" lib | grep -v "presentation/web/"
```
Expected hits: `lib/main.dart` (imports `app_web.dart`, uses `MAKIPOSWebApp`), and possibly a router barrel (e.g. `lib/config/router/router.dart`) exporting `web_router.dart`. Note each file to fix.

- [ ] **Step 2: Edit `lib/main.dart`** — remove the `app_web.dart` import (line 6) and collapse the `kIsWeb` app branch. Replace the `runApp(...)` call so it always uses the mobile app:
```dart
  runApp(
    ProviderScope(
      child: initError != null
          ? _StartupErrorApp(error: initError)
          : const MAKIPOSMobileApp(),
    ),
  );
```
(Leave the `if (!kIsWeb) { SystemChrome... }` block and the `import 'package:flutter/foundation.dart';` as-is — `kIsWeb` is still referenced there and is harmless on mobile.)

- [ ] **Step 3: Delete the web files** —
```bash
git rm -r lib/presentation/web lib/app_web.dart lib/config/router/web_router.dart web
```
Then, for any router barrel found in Step 1 that `export`s `web_router.dart`, remove that one export line.

- [ ] **Step 4: Verify analyze + tests** —
```bash
flutter analyze lib
flutter test
```
Expected: analyze reports no errors about missing `app_web`/`web_router`/`MAKIPOSWebApp` (pre-existing info lints elsewhere are fine); `flutter test` stays green (the mobile suite never depended on the web layer). If analyze flags a dangling import the Step-1 grep missed, remove it and re-run.

- [ ] **Step 5: Commit** —
```bash
git add -A lib web
git commit -m "refactor(web): remove Flutter web layer; app is mobile-only (web served by React admin)"
```

---

### Task 8: Repoint Firebase hosting to the React build

**Files:**
- Modify: `firebase.json`

- [ ] **Step 1: Implement** — in `firebase.json`, change `hosting.public` from `build/web` to `web_admin/dist`, and remove the `/admin/**` rewrite (keep the SPA fallback). The `hosting` block becomes:
```json
"hosting":{"public":"web_admin/dist","ignore":["firebase.json","**/.*","**/node_modules/**"],"rewrites":[{"source":"**","destination":"/index.html"}]}
```
(Leave the `firestore`, `storage`, and `flutter` blocks untouched.)

- [ ] **Step 2: Verify it's valid JSON** — `python3 -c "import json; json.load(open('firebase.json')); print('valid')"`. Expected: `valid`.

- [ ] **Step 3: Commit** — `git add firebase.json && git commit -m "chore(hosting): serve React admin (web_admin/dist) at root, drop /admin rewrite"`

---

### Task 9: Final verification + handoff

**Files:** none (verification only)

- [ ] **Step 1: React app green** —
```bash
cd web_admin && npm run typecheck && npm run test && npm run build
```
Expected: typecheck clean, all vitest suites pass, build emits `web_admin/dist`.

- [ ] **Step 2: Flutter app green** —
```bash
cd .. && flutter analyze lib && flutter test
```
Expected: no new analyze errors; full mobile suite passes.

- [ ] **Step 3: Manual deploy check (operator step, not automated)** — note in the PR/handoff: deploy with `firebase deploy --only hosting`, then verify `/` loads the React admin (admin-gated), and a sale carrying labor + a maya/salmon (or mixed) tender shows correct labor-inclusive revenue, parts-only profit, and the right payment buckets on the dashboard.

- [ ] **Step 4: No commit** — this task only verifies. If a step fails, fix in the owning task and re-run.

---

## Notes for the executor
- Run React commands from `web_admin/` (it has its own `package.json`); run Flutter commands from the repo root.
- Tasks 1–5 are pure React data-model work and are independently testable; Tasks 6–8 are the migration/removal plumbing; Task 9 is the gate.
- Do not weaken any assertion to make a test pass — the reconciliation identity (`Σ byPaymentMethod == netAmount + laborRevenue`) and the parts-only top-line are the load-bearing invariants this Foundation exists to guarantee.
