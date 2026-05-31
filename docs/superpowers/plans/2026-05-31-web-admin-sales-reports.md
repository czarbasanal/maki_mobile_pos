# Web Admin — Sales Monitoring + Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the web admin's Reports section — a date-range Sales report + Profit report + Sale detail + a hub — with a browsable sales list, top-selling products, and CSV export.

**Architecture:** Client-side aggregation (like the dashboard): fetch sales in a date range via `SaleRepository.list({start,end,limit})`, aggregate with the existing `summarizeSales()` + a new `topSellingProducts()` domain fn. Pure logic in small tested units; thin page components compose them. No new dependencies, no charts.

**Tech Stack:** React 18 + Vite + Tailwind + React Query + `date-fns`; Vitest (node env for logic). Run all commands from `web_admin/`.

**Spec:** docs/superpowers/specs/2026-05-31-web-admin-sales-reports-design.md

**Testing strategy:** Unit-test the pure logic in **node env** (`--environment=node`, sub-second — jsdom cold-start is ~300s here). The codebase has no component tests; verify pages with `npx tsc --noEmit -p tsconfig.json` + `npm run build` + a manual deploy check. Do NOT use `npm run typecheck` (broken `tsc -b --noEmit`); use `tsc --noEmit -p tsconfig.json`.

---

### Task 1: `resolvePreset` date-range presets

**Files:**
- Create: `web_admin/src/domain/reports/dateRange.ts`
- Test: `web_admin/src/domain/reports/dateRange.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/reports/dateRange.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { resolvePreset } from './dateRange';

// Fixed "now": Wed 2026-05-13 14:30 local.
const now = new Date(2026, 4, 13, 14, 30, 0);

function iso(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(
    d.getMinutes(),
  ).padStart(2, '0')}`;
}

describe('resolvePreset', () => {
  it('today = start..end of the same day', () => {
    const r = resolvePreset('today', now);
    expect(iso(r.start)).toBe('2026-05-13 00:00');
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('yesterday = the previous day', () => {
    const r = resolvePreset('yesterday', now);
    expect(iso(r.start)).toBe('2026-05-12 00:00');
    expect(iso(r.end)).toBe('2026-05-12 23:59');
  });

  it('last7 = 7 days inclusive of today', () => {
    const r = resolvePreset('last7', now);
    expect(iso(r.start)).toBe('2026-05-07 00:00'); // 6 days back
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('last30 = 30 days inclusive of today', () => {
    const r = resolvePreset('last30', now);
    expect(iso(r.start)).toBe('2026-04-14 00:00'); // 29 days back
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('thisMonth = 1st of month..now-day end', () => {
    const r = resolvePreset('thisMonth', now);
    expect(iso(r.start)).toBe('2026-05-01 00:00');
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `npx vitest run src/domain/reports/dateRange.test.ts --environment=node`. Expected: module `./dateRange` not found.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/reports/dateRange.ts`:
```ts
import { endOfDay, startOfDay, startOfMonth, subDays } from 'date-fns';

export interface DateRange {
  start: Date;
  end: Date;
}

export type RangePreset =
  | 'today'
  | 'yesterday'
  | 'last7'
  | 'last30'
  | 'thisMonth'
  | 'custom';

export const PRESET_LABELS: Record<RangePreset, string> = {
  today: 'Today',
  yesterday: 'Yesterday',
  last7: 'Last 7 days',
  last30: 'Last 30 days',
  thisMonth: 'This month',
  custom: 'Custom range',
};

/**
 * Resolves a FIXED preset (not 'custom') to a concrete date range.
 * `now` is injectable so this stays deterministic in tests.
 */
export function resolvePreset(
  preset: Exclude<RangePreset, 'custom'>,
  now: Date = new Date(),
): DateRange {
  switch (preset) {
    case 'today':
      return { start: startOfDay(now), end: endOfDay(now) };
    case 'yesterday': {
      const y = subDays(now, 1);
      return { start: startOfDay(y), end: endOfDay(y) };
    }
    case 'last7':
      return { start: startOfDay(subDays(now, 6)), end: endOfDay(now) };
    case 'last30':
      return { start: startOfDay(subDays(now, 29)), end: endOfDay(now) };
    case 'thisMonth':
      return { start: startOfMonth(now), end: endOfDay(now) };
  }
}
```

- [ ] **Step 4: Run it, expect PASS** — `npx vitest run src/domain/reports/dateRange.test.ts --environment=node`.

- [ ] **Step 5: Commit** — `git add web_admin/src/domain/reports/dateRange.ts web_admin/src/domain/reports/dateRange.test.ts && git commit -m "feat(web-admin): date-range presets (resolvePreset)"`

---

### Task 2: `topSellingProducts` aggregator

**Files:**
- Create: `web_admin/src/domain/sales/topSellingProducts.ts`
- Test: `web_admin/src/domain/sales/topSellingProducts.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/domain/sales/topSellingProducts.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import { type Sale } from '../entities';
import { topSellingProducts } from './topSellingProducts';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's',
    saleNumber: 'S',
    items: [],
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 0,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-13T10:00:00Z'),
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

function item(productId: string, name: string, qty: number, price: number, cost: number) {
  return {
    id: `${productId}-${qty}`,
    productId,
    sku: productId.toUpperCase(),
    name,
    unitPrice: price,
    unitCost: cost,
    quantity: qty,
    discountValue: 0,
    unit: 'pcs',
  };
}

describe('topSellingProducts', () => {
  it('groups by product, sums qty/revenue/cost, sorts by revenue desc', () => {
    const sales = [
      sale({ items: [item('p1', 'Spark Plug', 2, 100, 60), item('p2', 'Oil', 1, 300, 200)] }),
      sale({ items: [item('p1', 'Spark Plug', 3, 100, 60)] }),
    ];
    const top = topSellingProducts(sales);
    expect(top).toHaveLength(2);
    // p1: qty 5, revenue 500, cost 300, profit 200 (revenue 500 > p2 300)
    expect(top[0]).toMatchObject({
      productId: 'p1',
      name: 'Spark Plug',
      quantitySold: 5,
      totalRevenue: 500,
      totalCost: 300,
      totalProfit: 200,
    });
    expect(top[1].productId).toBe('p2');
  });

  it('excludes voided sales', () => {
    const sales = [
      sale({ items: [item('p1', 'A', 1, 100, 60)] }),
      sale({ status: SaleStatus.voided, items: [item('p1', 'A', 9, 100, 60)] }),
    ];
    expect(topSellingProducts(sales)[0].quantitySold).toBe(1);
  });

  it('respects the limit', () => {
    const sales = [
      sale({
        items: [
          item('p1', 'A', 1, 500, 1),
          item('p2', 'B', 1, 400, 1),
          item('p3', 'C', 1, 300, 1),
        ],
      }),
    ];
    expect(topSellingProducts(sales, 2).map((p) => p.productId)).toEqual(['p1', 'p2']);
  });

  it('item revenue is net of the item discount', () => {
    const s = sale({
      discountType: DiscountType.amount,
      items: [{ ...item('p1', 'A', 2, 100, 60), discountValue: 50 }], // 200 gross - 50 = 150
    });
    expect(topSellingProducts([s])[0].totalRevenue).toBe(150);
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `npx vitest run src/domain/sales/topSellingProducts.test.ts --environment=node`. Expected: module not found.

- [ ] **Step 3: Implement** — create `web_admin/src/domain/sales/topSellingProducts.ts`:
```ts
// Client-side "top selling products" rollup. Mirrors the Dart ProductSalesData
// from lib/domain/usecases/reports/get_top_selling_usecase.dart.

import {
  type Sale,
  saleIsVoided,
  saleItemNet,
  saleItemTotalCost,
} from '../entities';
import { DiscountType } from '../enums';

export interface ProductSalesData {
  productId: string;
  sku: string;
  name: string;
  quantitySold: number;
  totalRevenue: number;
  totalCost: number;
  totalProfit: number;
}

export function topSellingProducts(
  sales: Sale[],
  limit = 10,
): ProductSalesData[] {
  const byProduct = new Map<string, ProductSalesData>();

  for (const sale of sales) {
    if (saleIsVoided(sale)) continue;
    const isPercentage = sale.discountType === DiscountType.percentage;
    for (const it of sale.items) {
      const entry =
        byProduct.get(it.productId) ??
        {
          productId: it.productId,
          sku: it.sku,
          name: it.name,
          quantitySold: 0,
          totalRevenue: 0,
          totalCost: 0,
          totalProfit: 0,
        };
      entry.quantitySold += it.quantity;
      entry.totalRevenue += saleItemNet(it, isPercentage);
      entry.totalCost += saleItemTotalCost(it);
      entry.totalProfit = entry.totalRevenue - entry.totalCost;
      byProduct.set(it.productId, entry);
    }
  }

  return [...byProduct.values()]
    .sort((a, b) => b.totalRevenue - a.totalRevenue)
    .slice(0, limit);
}
```
Add the barrel export to `web_admin/src/domain/sales/` if one exists; otherwise import directly. (Check: there is no `src/domain/sales/index.ts` today — import `topSellingProducts` directly from `@/domain/sales/topSellingProducts`.)

- [ ] **Step 4: Run it, expect PASS** — `npx vitest run src/domain/sales/topSellingProducts.test.ts --environment=node`.

- [ ] **Step 5: Commit** — `git add web_admin/src/domain/sales/topSellingProducts.ts web_admin/src/domain/sales/topSellingProducts.test.ts && git commit -m "feat(web-admin): topSellingProducts aggregator + ProductSalesData"`

---

### Task 3: CSV export (`salesToCsv` + `downloadCsv`)

**Files:**
- Create: `web_admin/src/core/utils/csv.ts`
- Test: `web_admin/src/core/utils/csv.test.ts`

- [ ] **Step 1: Write the failing test** — create `web_admin/src/core/utils/csv.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '@/domain/enums';
import { type Sale } from '@/domain/entities';
import { salesToCsv } from './csv';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'OR-0001',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Spark Plug',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 0,
        unit: 'pcs',
      },
    ],
    laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
    mechanicId: 'm1',
    mechanicName: 'Juan Dela Cruz',
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 650,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier, A.', // comma -> must be quoted
    createdAt: new Date('2026-05-13T10:00:00Z'),
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

describe('salesToCsv', () => {
  it('emits a header + one row per sale', () => {
    const csv = salesToCsv([sale()]);
    const lines = csv.trim().split('\n');
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe(
      'saleNumber,date,items,paymentMethod,grossSales,discount,labor,total,cashier,mechanic',
    );
  });

  it('computes the money columns and quotes fields with commas', () => {
    const row = salesToCsv([sale()]).trim().split('\n')[1];
    // gross 200, discount 0, labor 450, total 650
    expect(row).toContain('OR-0001');
    expect(row).toContain('200');
    expect(row).toContain('450');
    expect(row).toContain('650');
    expect(row).toContain('"Cashier, A."'); // quoted because of the comma
    expect(row).toContain('Juan Dela Cruz');
  });

  it('handles empty input (header only)', () => {
    expect(salesToCsv([]).trim().split('\n')).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Run it, expect FAIL** — `npx vitest run src/core/utils/csv.test.ts --environment=node`. Expected: module not found.

- [ ] **Step 3: Implement** — create `web_admin/src/core/utils/csv.ts`:
```ts
// Dependency-free CSV: build the string, then download via Blob + anchor.

import {
  type Sale,
  saleGrandTotal,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';

const SALE_HEADERS = [
  'saleNumber',
  'date',
  'items',
  'paymentMethod',
  'grossSales',
  'discount',
  'labor',
  'total',
  'cashier',
  'mechanic',
] as const;

/** Quotes a CSV cell when it contains a comma, quote, or newline (RFC 4180). */
function cell(value: string | number): string {
  const s = String(value ?? '');
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function salesToCsv(sales: Sale[]): string {
  const rows = sales.map((s) =>
    [
      cell(s.saleNumber),
      cell(s.createdAt.toISOString()),
      cell(s.items.reduce((n, it) => n + it.quantity, 0)),
      cell(s.paymentMethod),
      cell(salePartsSubtotal(s)),
      cell(saleTotalDiscount(s)),
      cell(saleLaborSubtotal(s)),
      cell(saleGrandTotal(s)),
      cell(s.cashierName),
      cell(s.mechanicName ?? ''),
    ].join(','),
  );
  return [SALE_HEADERS.join(','), ...rows].join('\n');
}

export function downloadCsv(filename: string, content: string): void {
  const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
```

- [ ] **Step 4: Run it, expect PASS** — `npx vitest run src/core/utils/csv.test.ts --environment=node`.

- [ ] **Step 5: Commit** — `git add web_admin/src/core/utils/csv.ts web_admin/src/core/utils/csv.test.ts && git commit -m "feat(web-admin): salesToCsv + downloadCsv (no dependency)"`

---

### Task 4: Apply `limit` in `FirestoreSaleRepository.list`

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreSaleRepository.ts`

`SaleListFilters` already has an optional `limit`; the query never applies it. Wire it so a big range can't fetch unbounded item subcollections.

- [ ] **Step 1: Implement** — edit `web_admin/src/data/repositories/FirestoreSaleRepository.ts`. Insert one line — `  limit as fbLimit,` (right after `getDocs,`) — into the existing `firebase/firestore` import so it reads:
```ts
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit as fbLimit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  where,
  type Firestore,
} from 'firebase/firestore';
```
In `list()`, after the `orderBy('createdAt', 'desc')` push, add the limit:
```ts
    constraints.push(orderBy('createdAt', 'desc'));
    if (filters.limit) constraints.push(fbLimit(filters.limit));
```

- [ ] **Step 2: Verify it typechecks** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors. (No unit test: the repo has none and Firestore query construction needs the emulator; the behavior is exercised end-to-end by `useReportData`.)

- [ ] **Step 3: Commit** — `git add web_admin/src/data/repositories/FirestoreSaleRepository.ts && git commit -m "feat(web-admin): apply SaleListFilters.limit in FirestoreSaleRepository.list"`

---

### Task 5: `useReportData` hook

**Files:**
- Create: `web_admin/src/presentation/hooks/useReportData.ts`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/hooks/useReportData.ts`:
```ts
import { useQuery } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import { summarizeSales, type SalesSummary } from '@/domain/sales/summarizeSales';
import {
  topSellingProducts,
  type ProductSalesData,
} from '@/domain/sales/topSellingProducts';
import { type Sale } from '@/domain/entities';
import type { DateRange } from '@/domain/reports/dateRange';

const SALES_FETCH_CAP = 2000;

export interface ReportData {
  sales: Sale[];
  summary: SalesSummary;
  topProducts: ProductSalesData[];
  /** True when the fetch hit the cap, so figures may be partial. */
  capped: boolean;
  isLoading: boolean;
  error: Error | null;
}

export function useReportData(range: DateRange): ReportData {
  const repo = useSaleRepo();
  const query = useQuery({
    queryKey: ['reports', 'sales', range.start.getTime(), range.end.getTime()],
    queryFn: () =>
      repo.list({ start: range.start, end: range.end, limit: SALES_FETCH_CAP }),
  });

  const sales = query.data ?? [];
  return {
    sales,
    summary: summarizeSales(sales),
    topProducts: topSellingProducts(sales),
    capped: sales.length >= SALES_FETCH_CAP,
    isLoading: query.isLoading,
    error: (query.error as Error) ?? null,
  };
}
```

- [ ] **Step 2: Verify it typechecks** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors. (`summarizeSales` exports `SalesSummary`; confirm the import path — it is `@/domain/sales/summarizeSales`.)

- [ ] **Step 3: Commit** — `git add web_admin/src/presentation/hooks/useReportData.ts && git commit -m "feat(web-admin): useReportData hook (range -> sales + summary + top products)"`

---

### Task 6: `DateRangePicker` component

**Files:**
- Create: `web_admin/src/presentation/components/common/DateRangePicker.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/components/common/DateRangePicker.tsx`:
```tsx
import { useState } from 'react';
import { endOfDay, format, startOfDay } from 'date-fns';
import {
  PRESET_LABELS,
  resolvePreset,
  type DateRange,
  type RangePreset,
} from '@/domain/reports/dateRange';

const inputCls =
  'rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text';

const PRESETS: RangePreset[] = [
  'today',
  'yesterday',
  'last7',
  'last30',
  'thisMonth',
  'custom',
];

/**
 * Preset dropdown + (for 'custom') two native date inputs. Calls `onChange`
 * with a concrete {start,end} whenever the effective range changes. The parent
 * owns the range; default preset is 'last7' and must match the parent's initial.
 */
export function DateRangePicker({
  onChange,
}: {
  onChange: (range: DateRange) => void;
}) {
  const [preset, setPreset] = useState<RangePreset>('last7');
  const [customStart, setCustomStart] = useState('');
  const [customEnd, setCustomEnd] = useState('');

  function selectPreset(next: RangePreset) {
    setPreset(next);
    if (next !== 'custom') onChange(resolvePreset(next));
  }

  function applyCustom(startStr: string, endStr: string) {
    setCustomStart(startStr);
    setCustomEnd(endStr);
    if (startStr && endStr) {
      onChange({
        start: startOfDay(new Date(startStr)),
        end: endOfDay(new Date(endStr)),
      });
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-tk-sm">
      <select
        className={inputCls}
        value={preset}
        onChange={(e) => selectPreset(e.target.value as RangePreset)}
      >
        {PRESETS.map((p) => (
          <option key={p} value={p}>
            {PRESET_LABELS[p]}
          </option>
        ))}
      </select>

      {preset === 'custom' ? (
        <>
          <input
            type="date"
            className={inputCls}
            value={customStart}
            max={customEnd || format(new Date(), 'yyyy-MM-dd')}
            onChange={(e) => applyCustom(e.target.value, customEnd)}
          />
          <span className="text-light-text-hint">–</span>
          <input
            type="date"
            className={inputCls}
            value={customEnd}
            min={customStart}
            max={format(new Date(), 'yyyy-MM-dd')}
            onChange={(e) => applyCustom(customStart, e.target.value)}
          />
        </>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 2: Verify it typechecks** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors. (If `inputCls` token classes differ, mirror the classes used by `SupplierFormPage`'s `inputCls`.)

- [ ] **Step 3: Commit** — `git add web_admin/src/presentation/components/common/DateRangePicker.tsx && git commit -m "feat(web-admin): DateRangePicker (presets + custom native inputs)"`

---

### Task 7: `SalesTable` component

**Files:**
- Create: `web_admin/src/presentation/features/reports/SalesTable.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/reports/SalesTable.tsx`:
```tsx
import { Link } from 'react-router-dom';
import {
  saleGrandTotal,
  saleIsVoided,
  saleTotalItemCount,
  type Sale,
} from '@/domain/entities';
import { paymentMethodDisplayName } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { EmptyState } from '@/presentation/components/common/EmptyState';

const dtFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

function Th({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <th className={cn('px-tk-md py-tk-sm text-left font-medium', className)}>{children}</th>
  );
}

export function SalesTable({ sales }: { sales: Sale[] }) {
  if (sales.length === 0) {
    return <EmptyState title="No sales in this range" description="Adjust the date range above." />;
  }
  return (
    <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
      <table className="w-full text-bodySmall">
        <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
          <tr>
            <Th>When</Th>
            <Th>Sale #</Th>
            <Th>Items</Th>
            <Th>Mechanic</Th>
            <Th>Payment</Th>
            <Th className="text-right">Total</Th>
          </tr>
        </thead>
        <tbody className="divide-y divide-light-hairline">
          {sales.map((sale) => {
            const voided = saleIsVoided(sale);
            return (
              <tr key={sale.id} className="hover:bg-light-subtle">
                <td className="px-tk-md py-tk-sm text-light-text-hint">
                  {dtFmt.format(sale.createdAt)}
                </td>
                <td className="px-tk-md py-tk-sm">
                  <Link
                    to={`/reports/sale/${sale.id}`}
                    className={cn(
                      'font-semibold tabular-nums text-light-text hover:underline',
                      voided && 'text-light-text-hint line-through',
                    )}
                  >
                    {sale.saleNumber}
                  </Link>
                  {voided ? (
                    <span className="ml-tk-sm rounded-full bg-error-light px-tk-xs py-[1px] text-[10px] font-semibold uppercase tracking-wider text-error-dark">
                      Void
                    </span>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm tabular-nums">{saleTotalItemCount(sale)}</td>
                <td className="px-tk-md py-tk-sm text-light-text-hint">
                  {sale.mechanicName ?? '—'}
                </td>
                <td className="px-tk-md py-tk-sm">
                  {paymentMethodDisplayName[sale.paymentMethod]}
                </td>
                <td
                  className={cn(
                    'px-tk-md py-tk-sm text-right font-semibold tabular-nums',
                    voided ? 'text-light-text-hint line-through' : 'text-light-text',
                  )}
                >
                  {formatMoney(saleGrandTotal(sale))}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Verify it typechecks** — `npx tsc --noEmit -p tsconfig.json`. Expected: no errors.

- [ ] **Step 3: Commit** — `git add web_admin/src/presentation/features/reports/SalesTable.tsx && git commit -m "feat(web-admin): SalesTable (sales list rows -> sale detail)"`

---

### Task 8: `SalesReportPage` + wire route

**Files:**
- Create: `web_admin/src/presentation/features/reports/SalesReportPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/reports/SalesReportPage.tsx`:
```tsx
import { useEffect, useState } from 'react';
import { ChartBarIcon } from '@heroicons/react/24/outline';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReportData } from '@/presentation/hooks/useReportData';
import { salesToCsv, downloadCsv } from '@/core/utils/csv';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { SummaryCard } from '@/presentation/features/dashboard/SummaryCard';
import { SalesTable } from './SalesTable';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

const fileStamp = (d: Date) =>
  `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(
    d.getDate(),
  ).padStart(2, '0')}`;

export function SalesReportPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { sales, summary, topProducts, capped, isLoading, error } = useReportData(range);

  useEffect(() => {
    document.title = 'Sales report · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Sales report
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Sales and payment breakdown for the selected range.
          </p>
        </div>
        <DateRangePicker onChange={setRange} />
      </header>

      {error ? (
        <ErrorView title="Could not load sales" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading sales…" />
        </div>
      ) : (
        <>
          {capped ? (
            <p className="rounded-md border border-warning bg-warning-light px-tk-md py-tk-sm text-bodySmall text-warning-dark">
              Showing the most recent 2,000 sales — narrow the date range for exact totals.
            </p>
          ) : null}

          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-4">
            <SummaryCard title="Gross Sales" value={formatMoney(summary.grossAmount)} emphasized />
            <SummaryCard title="Net" value={formatMoney(summary.netAmount)} />
            <SummaryCard title="Avg order" value={formatMoney(summary.averageSaleAmount)} />
            <SummaryCard title="Sales count" value={String(summary.totalSalesCount)} />
          </div>

          <div className="grid grid-cols-1 gap-tk-lg lg:grid-cols-3">
            <Panel title="By payment method">
              <dl className="space-y-tk-sm text-bodySmall">
                {(['cash', 'gcash', 'maya', 'salmon'] as const).map((m) => (
                  <div key={m} className="flex justify-between">
                    <dt className="capitalize text-light-text-secondary">{m}</dt>
                    <dd className="tabular-nums">{formatMoney(summary.byPaymentMethod[m])}</dd>
                  </div>
                ))}
                <div className="flex justify-between border-t border-light-hairline pt-tk-sm">
                  <dt className="text-light-text-secondary">Service / Labor</dt>
                  <dd className="tabular-nums">{formatMoney(summary.laborRevenue)}</dd>
                </div>
              </dl>
            </Panel>
            <Panel title="Top products" className="lg:col-span-2">
              <TopProducts rows={topProducts} />
            </Panel>
          </div>

          <section className="space-y-tk-md">
            <div className="flex items-center justify-between">
              <h2 className="text-bodyMedium font-semibold text-light-text">
                Sales ({sales.length})
              </h2>
              <button
                type="button"
                disabled={sales.length === 0}
                onClick={() =>
                  downloadCsv(
                    `sales-${fileStamp(range.start)}-${fileStamp(range.end)}.csv`,
                    salesToCsv(sales),
                  )
                }
                className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50"
              >
                <ChartBarIcon className="h-4 w-4" />
                Download CSV
              </button>
            </div>
            <SalesTable sales={sales} />
          </section>
        </>
      )}
    </div>
  );
}

function TopProducts({ rows }: { rows: { sku: string; name: string; quantitySold: number; totalRevenue: number; totalProfit: number }[] }) {
  if (rows.length === 0) {
    return <p className="text-bodySmall text-light-text-hint">No products sold in this range.</p>;
  }
  return (
    <table className="w-full text-bodySmall">
      <thead className="text-light-text-secondary">
        <tr>
          <th className="py-tk-xs text-left font-medium">Product</th>
          <th className="py-tk-xs text-right font-medium">Qty</th>
          <th className="py-tk-xs text-right font-medium">Revenue</th>
          <th className="py-tk-xs text-right font-medium">Profit</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-light-hairline">
        {rows.map((p) => (
          <tr key={p.sku}>
            <td className="py-tk-xs">{p.name}</td>
            <td className="py-tk-xs text-right tabular-nums">{p.quantitySold}</td>
            <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalRevenue)}</td>
            <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalProfit)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function Panel({
  title,
  className,
  children,
}: {
  title: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <section
      className={`rounded-lg border border-light-hairline bg-light-card p-tk-lg ${className ?? ''}`}
    >
      <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">{title}</h2>
      {children}
    </section>
  );
}
```
NOTE: `SummaryCard` accepts `title`, `value`, `icon?`, `tone?`, `emphasized?`. If the `warning`/`warning-light`/`warning-dark` Tailwind tokens don't exist, use the same classes the codebase uses for a notice banner (check `OfflineBanner`); fall back to `border-light-border bg-light-subtle text-light-text` if there's no warning token.

- [ ] **Step 2: Wire the route** — in `web_admin/src/presentation/router/routes.tsx`, add the import (after the other feature-page imports, ~line 17):
```ts
import { SalesReportPage } from '@/presentation/features/reports/SalesReportPage';
```
and replace the sales-report placeholder line `{ path: RoutePaths.salesReport, element: placeholder('Sales report', 'phase 12') }` with:
```ts
        { path: RoutePaths.salesReport, element: <SalesReportPage /> },
```

- [ ] **Step 3: Verify** — `npx tsc --noEmit -p tsconfig.json` (no errors), then `npm run build` (succeeds). 

- [ ] **Step 4: Commit** — `git add web_admin/src/presentation/features/reports/SalesReportPage.tsx web_admin/src/presentation/router/routes.tsx && git commit -m "feat(web-admin): Sales report page (summary + payment + top products + sales list + CSV)"`

---

### Task 9: `ProfitReportPage` + wire route

**Files:**
- Create: `web_admin/src/presentation/features/reports/ProfitReportPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/reports/ProfitReportPage.tsx`:
```tsx
import { useEffect, useMemo, useState } from 'react';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReportData } from '@/presentation/hooks/useReportData';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { SummaryCard } from '@/presentation/features/dashboard/SummaryCard';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function ProfitReportPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { summary, topProducts, isLoading, error } = useReportData(range);

  // Top products by PROFIT (the report's lens), not revenue.
  const byProfit = useMemo(
    () => [...topProducts].sort((a, b) => b.totalProfit - a.totalProfit),
    [topProducts],
  );

  useEffect(() => {
    document.title = 'Profit report · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Profit report
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Cost of goods, gross profit, and margin for the selected range.
          </p>
        </div>
        <DateRangePicker onChange={setRange} />
      </header>

      {error ? (
        <ErrorView title="Could not load profit" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading…" />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-4">
            <SummaryCard title="Gross Sales" value={formatMoney(summary.grossAmount)} />
            <SummaryCard title="Total COGS" value={formatMoney(summary.totalCost)} />
            <SummaryCard
              title="Gross Profit"
              value={formatMoney(summary.totalProfit)}
              emphasized
            />
            <SummaryCard title="Margin" value={`${summary.profitMargin.toFixed(1)}%`} />
          </div>
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            <SummaryCard title="Service / Labor profit" value={formatMoney(summary.laborProfit)} />
          </div>

          <section className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
            <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">
              Top products by profit
            </h2>
            {byProfit.length === 0 ? (
              <p className="text-bodySmall text-light-text-hint">No products sold in this range.</p>
            ) : (
              <table className="w-full text-bodySmall">
                <thead className="text-light-text-secondary">
                  <tr>
                    <th className="py-tk-xs text-left font-medium">Product</th>
                    <th className="py-tk-xs text-right font-medium">Qty</th>
                    <th className="py-tk-xs text-right font-medium">Revenue</th>
                    <th className="py-tk-xs text-right font-medium">Cost</th>
                    <th className="py-tk-xs text-right font-medium">Profit</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-light-hairline">
                  {byProfit.map((p) => (
                    <tr key={p.sku}>
                      <td className="py-tk-xs">{p.name}</td>
                      <td className="py-tk-xs text-right tabular-nums">{p.quantitySold}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalRevenue)}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalCost)}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(p.totalProfit)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
        </>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Wire the route** — in `routes.tsx`, add the import:
```ts
import { ProfitReportPage } from '@/presentation/features/reports/ProfitReportPage';
```
and replace `{ path: RoutePaths.profitReport, element: placeholder('Profit report', 'phase 12') }` with:
```ts
        { path: RoutePaths.profitReport, element: <ProfitReportPage /> },
```

- [ ] **Step 3: Verify** — `npx tsc --noEmit -p tsconfig.json` + `npm run build`.

- [ ] **Step 4: Commit** — `git add web_admin/src/presentation/features/reports/ProfitReportPage.tsx web_admin/src/presentation/router/routes.tsx && git commit -m "feat(web-admin): Profit report page (COGS/profit/margin + top by profit)"`

---

### Task 10: `SaleDetailPage` + wire route

**Files:**
- Create: `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/reports/SaleDetailPage.tsx`:
```tsx
import { useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useSaleRepo } from '@/infrastructure/di/container';
import {
  saleEffectiveTenders,
  saleGrandTotal,
  saleIsPercentageDiscount,
  saleItemNet,
  saleLaborSubtotal,
  salePartsSubtotal,
  saleTotalDiscount,
} from '@/domain/entities';
import { realTenderMethods } from '@/domain/enums';
import { formatMoney } from '@/core/utils/money';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function SaleDetailPage() {
  const { id = '' } = useParams();
  const repo = useSaleRepo();
  const { data: sale, isLoading, error } = useQuery({
    queryKey: ['sales', id],
    queryFn: () => repo.getById(id),
  });

  useEffect(() => {
    document.title = 'Sale detail · MAKI POS Admin';
  }, []);

  if (isLoading) return <div className="p-tk-xl"><LoadingView label="Loading sale…" /></div>;
  if (error) return <div className="p-tk-xl"><ErrorView title="Could not load sale" message={(error as Error).message} /></div>;
  if (!sale) {
    return (
      <div className="p-tk-xl">
        <EmptyState
          title="Sale not found"
          description="It may have been removed."
          action={<Link to="/reports/sales" className="text-light-text underline">Back to sales</Link>}
        />
      </div>
    );
  }

  const isPct = saleIsPercentageDiscount(sale);
  const tenders = saleEffectiveTenders(sale);

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <header className="space-y-tk-xs">
        <Link to="/reports/sales" className="text-bodySmall text-light-text-secondary hover:underline">
          ← Back to sales
        </Link>
        <div className="flex items-center gap-tk-md">
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {sale.saleNumber}
          </h1>
          {sale.voidedAt ? (
            <span className="rounded-full bg-error-light px-tk-sm py-[2px] text-[11px] font-semibold uppercase tracking-wider text-error-dark">
              Voided
            </span>
          ) : null}
        </div>
        <p className="text-bodySmall text-light-text-secondary">
          {dtFmt.format(sale.createdAt)} · {sale.cashierName}
          {sale.mechanicName ? ` · Mechanic: ${sale.mechanicName}` : ''}
        </p>
      </header>

      <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">Item</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Unit</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Net</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {sale.items.map((it) => (
              <tr key={it.id}>
                <td className="px-tk-md py-tk-sm">
                  <span className="font-medium text-light-text">{it.name}</span>
                  <span className="ml-tk-sm text-light-text-hint">{it.sku}</span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{it.quantity}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(it.unitPrice)}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(saleItemNet(it, isPct))}
                </td>
              </tr>
            ))}
            {sale.laborLines.map((l) => (
              <tr key={l.id} className="bg-light-subtle/40">
                <td className="px-tk-md py-tk-sm" colSpan={3}>
                  <span className="text-light-text">🔧 {l.description || 'Service'}</span>
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{formatMoney(l.fee)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="ml-auto w-full max-w-sm space-y-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
        <Row label="Gross Sales" value={formatMoney(salePartsSubtotal(sale))} />
        <Row label="Discount" value={`-${formatMoney(saleTotalDiscount(sale))}`} />
        <Row label="Labor" value={formatMoney(saleLaborSubtotal(sale))} />
        <div className="border-t border-light-hairline pt-tk-xs">
          <Row label="Total" value={formatMoney(saleGrandTotal(sale))} bold />
        </div>
        <div className="mt-tk-sm border-t border-light-hairline pt-tk-sm">
          {realTenderMethods
            .filter((m) => (tenders[m] ?? 0) > 0)
            .map((m) => (
              <Row key={m} label={m} value={formatMoney(tenders[m] ?? 0)} muted />
            ))}
          <Row label="Amount received" value={formatMoney(sale.amountReceived)} muted />
          <Row label="Change" value={formatMoney(sale.changeGiven)} muted />
        </div>
      </section>
    </div>
  );
}

function Row({ label, value, bold, muted }: { label: string; value: string; bold?: boolean; muted?: boolean }) {
  return (
    <div className="flex justify-between">
      <span className={muted ? 'capitalize text-light-text-hint' : 'capitalize text-light-text-secondary'}>
        {label}
      </span>
      <span className={`tabular-nums ${bold ? 'font-semibold text-light-text' : 'text-light-text'}`}>
        {value}
      </span>
    </div>
  );
}
```
NOTE: confirm `saleIsPercentageDiscount` and `realTenderMethods` are exported from `@/domain/entities` / `@/domain/enums` respectively (they are — `saleIsPercentageDiscount` in `Sale.ts`, `realTenderMethods` in `PaymentMethod.ts`). If `bg-light-subtle/40` opacity syntax isn't enabled, drop `/40`.

- [ ] **Step 2: Wire the route** — in `routes.tsx`, add the import:
```ts
import { SaleDetailPage } from '@/presentation/features/reports/SaleDetailPage';
```
and replace `{ path: RoutePaths.saleDetail, element: placeholder('Sale detail', 'phase 12') }` with:
```ts
        { path: RoutePaths.saleDetail, element: <SaleDetailPage /> },
```

- [ ] **Step 3: Verify** — `npx tsc --noEmit -p tsconfig.json` + `npm run build`.

- [ ] **Step 4: Commit** — `git add web_admin/src/presentation/features/reports/SaleDetailPage.tsx web_admin/src/presentation/router/routes.tsx && git commit -m "feat(web-admin): Sale detail page (items + labor + totals + tenders)"`

---

### Task 11: `ReportsHubPage` + wire route

**Files:**
- Create: `web_admin/src/presentation/features/reports/ReportsHubPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Implement** — create `web_admin/src/presentation/features/reports/ReportsHubPage.tsx`:
```tsx
import { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ChartBarIcon, ArrowTrendingUpIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';

const cards = [
  {
    to: RoutePaths.salesReport,
    title: 'Sales report',
    description: 'Sales, payment breakdown, top products, and a downloadable sales list.',
    icon: ChartBarIcon,
  },
  {
    to: RoutePaths.profitReport,
    title: 'Profit report',
    description: 'Cost of goods, gross profit, margin, and top products by profit.',
    icon: ArrowTrendingUpIcon,
  },
];

export function ReportsHubPage() {
  useEffect(() => {
    document.title = 'Reports · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Reports</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Sales and profit over any date range.
        </p>
      </header>
      <div className="grid grid-cols-1 gap-tk-lg sm:grid-cols-2">
        {cards.map((c) => (
          <Link
            key={c.to}
            to={c.to}
            className="group rounded-lg border border-light-hairline bg-light-card p-tk-lg transition-colors hover:border-light-text"
          >
            <c.icon className="h-6 w-6 text-light-text-secondary" />
            <h2 className="mt-tk-md text-bodyMedium font-semibold text-light-text">{c.title}</h2>
            <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{c.description}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Wire the route** — in `routes.tsx`, add the import:
```ts
import { ReportsHubPage } from '@/presentation/features/reports/ReportsHubPage';
```
and replace `{ path: RoutePaths.reports, element: placeholder('Reports', 'phase 12') }` with:
```ts
        { path: RoutePaths.reports, element: <ReportsHubPage /> },
```

- [ ] **Step 3: Verify** — `npx tsc --noEmit -p tsconfig.json` + `npm run build`.

- [ ] **Step 4: Commit** — `git add web_admin/src/presentation/features/reports/ReportsHubPage.tsx web_admin/src/presentation/router/routes.tsx && git commit -m "feat(web-admin): Reports hub page (links to sales + profit)"`

---

### Task 12: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Logic tests + typecheck + build**
```bash
cd web_admin
npx vitest run --environment=node
npx tsc --noEmit -p tsconfig.json
npm run build
```
Expected: all vitest suites pass (incl. the new dateRange/topSellingProducts/csv tests), typecheck clean, build emits `web_admin/dist`.

- [ ] **Step 2: Manual deploy check (operator step)** — note in the PR/handoff: `firebase deploy --only hosting`, then on the live admin: open Reports → Sales report; switch presets + a custom range; confirm summary cards (Gross Sales/Net/Avg/Count), payment breakdown, top products, the sales list, and Download CSV; click a sale → detail renders; open Profit report → COGS/profit/margin/top-by-profit. Spot-check a range that includes a labor + maya/salmon sale.

- [ ] **Step 3: No commit** — verification only.

---

## Notes for the executor
- Run all React commands from `web_admin/`. Use `--environment=node` for vitest (jsdom cold-start is ~300s here).
- Typecheck with `npx tsc --noEmit -p tsconfig.json` (NOT `npm run typecheck`, which is broken). `npm run build` works.
- The pages reuse `SummaryCard`, `formatMoney`, `cn`, `EmptyState`, `LoadingView`, `ErrorView`, and the manual-`<table>` pattern from `UsersListPage`/`RecentSales`. Match existing Tailwind tokens; if a referenced token (e.g. `warning*`, `bg-*/40`) doesn't exist, fall back to a neutral equivalent and note it.
- No new dependency is added. No Firestore rules or data migration.
