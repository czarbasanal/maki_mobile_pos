# Price-History Views — Phase 2 (Web Admin) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Mirror the mobile price-history view in the React web admin (`web_admin/`): an admin-only page that searches a product and shows its combined cost+price history as a sparkline + filterable table, reading the same `products/{id}/price_history` Firestore subcollection.

**Architecture:** Port the mobile pure helpers to TypeScript (`domain/products/priceHistory.ts`, relative imports, unit-tested in node env). Implement the stubbed `FirestoreProductRepository.listPriceHistory`. A React Query hook feeds a thin view (inline-SVG sparkline + table) hosted on a self-contained product-search page (web has no product-detail page yet). Admin-gated via the existing `Permission.viewProductCost`.

**Tech Stack:** React, TypeScript, React Router v6, TanStack Query, Tailwind (project tokens), Firebase Firestore, Vitest. Spec: `docs/superpowers/specs/2026-06-01-price-history-views-design.md` (§7 Phase 2). Run all commands from `web_admin/`.

**Toolchain notes (from prior web work):**
- Typecheck with `npx tsc --noEmit -p tsconfig.json` (the `npm run typecheck` script is BROKEN — TS6310).
- Run pure-logic suites with `--environment=node` (jsdom cold-start is ~300s).
- Unit-tested modules + their transitive imports must use **relative imports**, NOT the `@/` alias (vitest doesn't resolve `@/`). Presentation-only files (pages/hooks/components) may use `@/`.
- If `vite build` fails on an esbuild binary error: `npm rebuild esbuild` or `npm ci`.

---

## Context already verified

- `ProductRepository` (web) already declares `listPriceHistory(productId): Promise<PriceHistoryEntry[]>` and `recordPriceChange` (the latter implemented). `PriceHistoryEntry = { price, cost, changedAt, changedBy, reason }` — **lacks `note`** (mobile has it; receiving entries store the `RCV-…` id there).
- `FirestoreProductRepository.listPriceHistory` is a **stub** that throws (`src/data/repositories/FirestoreProductRepository.ts:199`).
- `Permission.viewProductCost` exists and is **admin-only** (`src/domain/permissions/Permission.ts`).
- `Subcollections.priceHistory = 'price_history'`, `FirestoreCollections.products = 'products'` (`src/infrastructure/firebase/collections.ts`).
- `toDate(value)` in `src/data/converters/timestamps.ts` parses Firestore timestamps.
- `formatMoney(amount)` in `src/core/utils/money.ts`. `cn(...)` in `src/core/utils/cn.ts`.
- Tailwind status tokens exist: `text-success-dark`, `text-error-dark`, `text-primary-dark`, plus `text-light-text`, `text-light-text-secondary`, `text-light-text-hint`, `bg-light-subtle`, `border-light-hairline`, `bg-light-card`, spacing `px-tk-*`/`py-tk-*`, type `text-bodySmall`/`text-bodyMedium`/`text-headingMedium`.
- `useProducts()` → `SubscriptionState<Product[]>` (`{ data, error, isLoading }`, live `watchAll`). `useUsers()` → `SubscriptionState<User[]>`. `User` has `id` + `displayName`.
- `useProductRepo()` DI hook exists. Route guard: exact `protectedRoutes` map is checked before dynamic regexes, so an exact `/inventory/price-history` entry wins over the generic `/^\/inventory\/[^/]+$/` rule.

## File Structure

**Create:**
- `web_admin/src/domain/products/priceHistory.ts` — pure helpers (port of `lib/core/utils/price_history_view.dart`) + `sparklinePath`.
- `web_admin/src/domain/products/priceHistory.test.ts` — vitest unit tests.
- `web_admin/src/presentation/hooks/usePriceHistory.ts` — React Query hook.
- `web_admin/src/presentation/features/inventory/Sparkline.tsx` — inline-SVG sparkline.
- `web_admin/src/presentation/features/inventory/PriceHistoryView.tsx` — filter + sparkline(s) + table for one product.
- `web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx` — product-search host page.

**Modify:**
- `web_admin/src/domain/repositories/ProductRepository.ts` — add `note?: string | null` to `PriceHistoryEntry`.
- `web_admin/src/data/repositories/FirestoreProductRepository.ts` — implement `listPriceHistory`.
- `web_admin/src/presentation/router/routePaths.ts` — add `priceHistory`.
- `web_admin/src/presentation/router/routeGuards.ts` — add exact `protectedRoutes` entry.
- `web_admin/src/presentation/router/routes.tsx` — add route + import.
- `web_admin/src/presentation/components/common/Sidebar.tsx` — add nav item under "Stock".

---

## Task 1: Ported pure helpers + unit tests

**Files:**
- Create: `web_admin/src/domain/products/priceHistory.ts`
- Test: `web_admin/src/domain/products/priceHistory.test.ts`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/products/priceHistory.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import {
  PriceMetric,
  buildPriceHistoryRows,
  sparklineSeries,
  derivePriceHistorySource,
  sparklinePath,
} from './priceHistory';
import type { PriceHistoryEntry } from '../repositories/ProductRepository';

// Note: these fixtures don't set `note` — the helper tests never read
// `entry.note` (the receiving/RCV case is tested via raw string args below), so
// the fixtures stay valid even before Task 2 adds the optional `note` field.
function e(
  id: string,
  price: number,
  cost: number,
  reason: string | null,
): PriceHistoryEntry & { id: string } {
  return { id, price, cost, changedAt: new Date(2026, 0, 1), changedBy: 'u1', reason };
}

// newest-first, like listPriceHistory returns
const entries: PriceHistoryEntry[] = [
  e('e3', 120, 70, 'Price update'),
  e('e2', 110, 70, 'Stock receiving'),
  e('e1', 110, 60, 'Initial price'),
];

describe('buildPriceHistoryRows', () => {
  it('all metric keeps every entry with deltas vs the older entry', () => {
    const rows = buildPriceHistoryRows(entries, PriceMetric.all);
    expect(rows.length).toBe(3);
    expect(rows[0].priceDelta).toBeCloseTo(10);
    expect(rows[0].costDelta).toBeCloseTo(0);
    expect(rows[0].hasPrior).toBe(true);
    expect(rows[2].hasPrior).toBe(false);
    expect(rows[2].priceDelta).toBe(0);
  });

  it('price filter keeps origin + entries where price moved', () => {
    const rows = buildPriceHistoryRows(entries, PriceMetric.price);
    expect(rows.map((r) => (r.entry as { id: string }).id)).toEqual(['e3', 'e1']);
  });

  it('cost filter keeps origin + entries where cost moved', () => {
    const rows = buildPriceHistoryRows(entries, PriceMetric.cost);
    expect(rows.map((r) => (r.entry as { id: string }).id)).toEqual(['e2', 'e1']);
  });

  it('empty input yields no rows', () => {
    expect(buildPriceHistoryRows([], PriceMetric.all)).toEqual([]);
  });
});

describe('sparklineSeries', () => {
  it('returns price values oldest-first', () => {
    expect(sparklineSeries(entries, false)).toEqual([110, 110, 120]);
  });
  it('returns cost values oldest-first', () => {
    expect(sparklineSeries(entries, true)).toEqual([60, 70, 70]);
  });
});

describe('derivePriceHistorySource', () => {
  it('maps known reasons', () => {
    expect(derivePriceHistorySource('Initial price', null)).toBe('Created');
    expect(derivePriceHistorySource('Price update', null)).toBe('Manual edit');
    expect(derivePriceHistorySource('Cost update', null)).toBe('Manual edit');
  });
  it('receiving appends the RCV id from note when present', () => {
    expect(derivePriceHistorySource('Stock receiving', 'RCV-20260201-003')).toBe(
      'Receiving (RCV-20260201-003)',
    );
    expect(derivePriceHistorySource('Stock receiving', null)).toBe('Receiving');
  });
  it('null/empty reason -> Edit; unknown shown as-is', () => {
    expect(derivePriceHistorySource(null, null)).toBe('Edit');
    expect(derivePriceHistorySource('', null)).toBe('Edit');
    expect(derivePriceHistorySource('Promotion', null)).toBe('Promotion');
  });
});

describe('sparklinePath', () => {
  it('returns empty for fewer than 2 points', () => {
    expect(sparklinePath([5], 100, 40)).toBe('');
    expect(sparklinePath([], 100, 40)).toBe('');
  });
  it('maps min to the bottom and max to the top', () => {
    expect(sparklinePath([10, 20], 100, 40)).toBe('M0.00,40.00 L100.00,0.00');
  });
  it('centres a flat series', () => {
    expect(sparklinePath([5, 5], 100, 40)).toBe('M0.00,20.00 L100.00,20.00');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/priceHistory.test.ts`
Expected: FAIL — cannot resolve `./priceHistory` (file doesn't exist).

- [ ] **Step 3: Write the implementation**

Create `web_admin/src/domain/products/priceHistory.ts`:

```ts
// Port of lib/core/utils/price_history_view.dart. Pure, framework-free, so it
// is unit-tested in node env. Uses RELATIVE imports (vitest doesn't resolve @/).
import type { PriceHistoryEntry } from '../repositories/ProductRepository';

export const PriceMetric = { all: 'all', price: 'price', cost: 'cost' } as const;
export type PriceMetric = (typeof PriceMetric)[keyof typeof PriceMetric];

export interface PriceHistoryRow {
  entry: PriceHistoryEntry;
  priceDelta: number;
  costDelta: number;
  hasPrior: boolean;
}

const EPS = 0.005;

/**
 * Builds display rows from `entriesNewestFirst` (as `listPriceHistory` returns),
 * filtered to `metric`. Deltas are computed against the chronologically previous
 * (older = next-in-list) entry. The oldest entry has no prior, so its deltas are
 * 0 and it is always kept (origin of every series). For price/cost, an entry is
 * kept when it has no prior OR that metric moved by more than EPS.
 */
export function buildPriceHistoryRows(
  entriesNewestFirst: PriceHistoryEntry[],
  metric: PriceMetric,
): PriceHistoryRow[] {
  const rows: PriceHistoryRow[] = [];
  for (let i = 0; i < entriesNewestFirst.length; i += 1) {
    const entry = entriesNewestFirst[i];
    const prior = i + 1 < entriesNewestFirst.length ? entriesNewestFirst[i + 1] : null;
    const hasPrior = prior !== null;
    const priceDelta = hasPrior ? entry.price - prior.price : 0;
    const costDelta = hasPrior ? entry.cost - prior.cost : 0;

    let keep: boolean;
    if (metric === PriceMetric.price) keep = !hasPrior || Math.abs(priceDelta) > EPS;
    else if (metric === PriceMetric.cost) keep = !hasPrior || Math.abs(costDelta) > EPS;
    else keep = true;

    if (keep) rows.push({ entry, priceDelta, costDelta, hasPrior });
  }
  return rows;
}

/** Metric values in chronological order (oldest -> newest) for the sparkline. */
export function sparklineSeries(entriesNewestFirst: PriceHistoryEntry[], forCost: boolean): number[] {
  return entriesNewestFirst.map((entry) => (forCost ? entry.cost : entry.price)).reverse();
}

/** Maps a price-history reason (+ optional note) to a "Source" column label. */
export function derivePriceHistorySource(
  reason: string | null | undefined,
  note: string | null | undefined,
): string {
  switch (reason) {
    case 'Initial price':
      return 'Created';
    case 'Price update':
    case 'Cost update':
      return 'Manual edit';
    case 'Stock receiving': {
      const rcv = note ? /RCV-\d{8}-\d+/.exec(note)?.[0] ?? null : null;
      return rcv ? `Receiving (${rcv})` : 'Receiving';
    }
    case null:
    case undefined:
    case '':
      return 'Edit';
    default:
      return reason;
  }
}

/**
 * SVG path `d` for a sparkline. `values` are chronological; auto-scaled so the
 * min sits at the bottom and the max at the top. A flat series renders a
 * centred line. Returns '' for fewer than 2 points (caller hides the chart).
 */
export function sparklinePath(values: number[], width: number, height: number): string {
  if (values.length < 2) return '';
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min;
  const stepX = width / (values.length - 1);
  return values
    .map((v, i) => {
      const x = i * stepX;
      const y = span === 0 ? height / 2 : height - ((v - min) / span) * height;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(' ');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd web_admin && npx vitest run --environment=node src/domain/products/priceHistory.test.ts`
Expected: PASS (all describe blocks green).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/priceHistory.ts web_admin/src/domain/products/priceHistory.test.ts
git commit -m "feat(web-admin): price-history pure helpers (filter, deltas, sparkline, source)"
```

---

## Task 2: `note` field + implement `listPriceHistory`

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Add `note` to the entry type**

In `web_admin/src/domain/repositories/ProductRepository.ts`, replace:

```ts
export interface PriceHistoryEntry {
  price: number;
  cost: number;
  changedAt: Date;
  changedBy: string;
  reason: string | null;
}
```

with (optional so the existing `recordPriceChange` callers are unaffected):

```ts
export interface PriceHistoryEntry {
  price: number;
  cost: number;
  changedAt: Date;
  changedBy: string;
  reason: string | null;
  /** Free-text context; receiving entries carry the `RCV-…` id. Optional —
   *  web `recordPriceChange` doesn't write it, but mobile-written docs have it. */
  note?: string | null;
}
```

- [ ] **Step 2: Add the `limit` + `toDate` imports**

In `web_admin/src/data/repositories/FirestoreProductRepository.ts`, add `limit` to the
`firebase/firestore` import list (alphabetical, next to `getDocs`):

```ts
  getDoc,
  getDocs,
  limit,
  onSnapshot,
```

And after the `productConverter` import, add:

```ts
import { toDate } from '@/data/converters/timestamps';
```

- [ ] **Step 3: Implement `listPriceHistory`**

In the same file, replace the stub:

```ts
  async listPriceHistory(): Promise<never[]> {
    throw new Error('ProductRepository.listPriceHistory not implemented yet (phase 7)');
  }
```

with:

```ts
  async listPriceHistory(productId: string): Promise<PriceHistoryEntry[]> {
    const snap = await getDocs(
      query(
        collection(this.db, FirestoreCollections.products, productId, Subcollections.priceHistory),
        orderBy('changedAt', 'desc'),
        limit(50),
      ),
    );
    return snap.docs.map((d) => {
      const data = d.data();
      return {
        price: (data.price as number) ?? 0,
        cost: (data.cost as number) ?? 0,
        changedAt: toDate(data.changedAt) ?? new Date(0),
        changedBy: (data.changedBy as string) ?? '',
        reason: (data.reason as string | null) ?? null,
        note: (data.note as string | null) ?? null,
      };
    });
  }
```

- [ ] **Step 4: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: no output (clean). (The `listPriceHistory` signature now matches the interface; `note` is optional so `recordPriceChange` callers still compile.)

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web-admin): implement FirestoreProductRepository.listPriceHistory (+ note field)"
```

---

## Task 3: `usePriceHistory` hook

**Files:**
- Create: `web_admin/src/presentation/hooks/usePriceHistory.ts`

- [ ] **Step 1: Write the hook**

Create `web_admin/src/presentation/hooks/usePriceHistory.ts`:

```ts
import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import type { PriceHistoryEntry } from '@/domain/repositories/ProductRepository';

/** One-shot read of a product's price history (newest-first). Disabled until a
 *  productId is supplied. */
export function usePriceHistory(productId: string | null) {
  const repo = useProductRepo();
  return useQuery<PriceHistoryEntry[]>({
    queryKey: ['price-history', productId],
    queryFn: () => repo.listPriceHistory(productId as string),
    enabled: !!productId,
  });
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/hooks/usePriceHistory.ts
git commit -m "feat(web-admin): usePriceHistory query hook"
```

---

## Task 4: Sparkline + View + Page components

**Files:**
- Create: `web_admin/src/presentation/features/inventory/Sparkline.tsx`
- Create: `web_admin/src/presentation/features/inventory/PriceHistoryView.tsx`
- Create: `web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx`

- [ ] **Step 1: Sparkline component**

Create `web_admin/src/presentation/features/inventory/Sparkline.tsx`:

```tsx
import { sparklinePath } from '@/domain/products/priceHistory';

const WIDTH = 320;
const HEIGHT = 44;

/** Axis-less inline-SVG sparkline. Inherits colour from `currentColor`; renders
 *  nothing for fewer than two points (caller shows a caption instead). */
export function Sparkline({ values }: { values: number[] }) {
  const d = sparklinePath(values, WIDTH, HEIGHT);
  if (!d) return null;
  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      preserveAspectRatio="none"
      className="h-11 w-full"
      aria-hidden
    >
      <path d={d} fill="none" stroke="currentColor" strokeWidth={2} />
    </svg>
  );
}
```

- [ ] **Step 2: PriceHistoryView component**

Create `web_admin/src/presentation/features/inventory/PriceHistoryView.tsx`:

```tsx
import { useMemo, useState } from 'react';
import {
  PriceMetric,
  buildPriceHistoryRows,
  sparklineSeries,
  derivePriceHistorySource,
} from '@/domain/products/priceHistory';
import { usePriceHistory } from '@/presentation/hooks/usePriceHistory';
import { useUsers } from '@/presentation/hooks/useUsers';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { Sparkline } from './Sparkline';

const METRICS: { value: PriceMetric; label: string }[] = [
  { value: PriceMetric.all, label: 'All' },
  { value: PriceMetric.price, label: 'Price' },
  { value: PriceMetric.cost, label: 'Cost' },
];

function formatDate(d: Date): string {
  return d.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

function Delta({ value, delta }: { value: number; delta: number }) {
  const changed = Math.abs(delta) > 0.01;
  const up = delta > 0;
  return (
    <span className="inline-flex items-center gap-1">
      <span className="font-medium text-light-text">{formatMoney(value)}</span>
      {changed ? (
        <span className={up ? 'text-success-dark' : 'text-error-dark'}>
          {up ? '▲' : '▼'} {formatMoney(Math.abs(delta))}
        </span>
      ) : null}
    </span>
  );
}

export function PriceHistoryView({ productId }: { productId: string }) {
  const [metric, setMetric] = useState<PriceMetric>(PriceMetric.all);
  const { data, isLoading, error } = usePriceHistory(productId);
  const usersState = useUsers();
  const namesById = useMemo(
    () => new Map((usersState.data ?? []).map((u) => [u.id, u.displayName])),
    [usersState.data],
  );

  if (isLoading) {
    return <p className="text-bodySmall text-light-text-secondary">Loading…</p>;
  }
  if (error) {
    return <p className="text-bodySmall text-light-text-secondary">Could not load price history.</p>;
  }

  const entries = data ?? [];
  if (entries.length === 0) {
    return <p className="text-bodySmall text-light-text-secondary">No price changes yet.</p>;
  }

  const rows = buildPriceHistoryRows(entries, metric);
  const showPrice = metric !== PriceMetric.cost;
  const showCost = metric !== PriceMetric.price;
  const canChart = entries.length >= 2;

  return (
    <div className="space-y-tk-lg">
      <div className="inline-flex rounded-md border border-light-hairline p-[2px]">
        {METRICS.map((m) => (
          <button
            key={m.value}
            type="button"
            onClick={() => setMetric(m.value)}
            className={cn(
              'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
              metric === m.value
                ? 'bg-light-subtle font-semibold text-light-text'
                : 'text-light-text-secondary hover:text-light-text',
            )}
          >
            {m.label}
          </button>
        ))}
      </div>

      {canChart ? (
        <div className="space-y-tk-md text-primary-dark">
          {showPrice ? (
            <div>
              <div className="pb-tk-xs text-[11px] uppercase tracking-wider text-light-text-hint">
                Price
              </div>
              <Sparkline values={sparklineSeries(entries, false)} />
            </div>
          ) : null}
          {showCost ? (
            <div>
              <div className="pb-tk-xs text-[11px] uppercase tracking-wider text-light-text-hint">
                Cost
              </div>
              <Sparkline values={sparklineSeries(entries, true)} />
            </div>
          ) : null}
        </div>
      ) : (
        <p className="text-bodySmall text-light-text-secondary">Not enough changes to chart</p>
      )}

      <div className="overflow-hidden rounded-lg border border-light-hairline">
        <table className="w-full text-bodySmall">
          <thead className="bg-light-subtle text-left text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm font-medium">Date</th>
              {showPrice ? <th className="px-tk-md py-tk-sm font-medium">Price</th> : null}
              {showCost ? <th className="px-tk-md py-tk-sm font-medium">Cost</th> : null}
              <th className="px-tk-md py-tk-sm font-medium">Source</th>
              <th className="px-tk-md py-tk-sm font-medium">By</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={`${r.entry.changedAt.getTime()}-${i}`} className="border-t border-light-hairline">
                <td className="px-tk-md py-tk-sm text-light-text">{formatDate(r.entry.changedAt)}</td>
                {showPrice ? (
                  <td className="px-tk-md py-tk-sm">
                    <Delta value={r.entry.price} delta={r.hasPrior ? r.priceDelta : 0} />
                  </td>
                ) : null}
                {showCost ? (
                  <td className="px-tk-md py-tk-sm">
                    <Delta value={r.entry.cost} delta={r.hasPrior ? r.costDelta : 0} />
                  </td>
                ) : null}
                <td className="px-tk-md py-tk-sm text-light-text-secondary">
                  {derivePriceHistorySource(r.entry.reason, r.entry.note)}
                </td>
                <td className="px-tk-md py-tk-sm text-light-text-secondary">
                  {namesById.get(r.entry.changedBy) ?? r.entry.changedBy}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: PriceHistoryPage (search host)**

Create `web_admin/src/presentation/features/inventory/PriceHistoryPage.tsx`:

```tsx
import { useEffect, useState } from 'react';
import { useProducts } from '@/presentation/hooks/useProducts';
import type { Product } from '@/domain/entities';
import { PriceHistoryView } from './PriceHistoryView';

export function PriceHistoryPage() {
  useEffect(() => {
    document.title = 'Price History · MAKI POS Admin';
  }, []);

  const { data: products, isLoading } = useProducts();
  const [queryText, setQueryText] = useState('');
  const [selected, setSelected] = useState<Product | null>(null);

  const q = queryText.trim().toLowerCase();
  const matches =
    q.length === 0
      ? []
      : (products ?? [])
          .filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))
          .slice(0, 10);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Price History
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Search a product to see its cost &amp; selling-price changes over time.
        </p>
      </header>

      <div className="max-w-md">
        <input
          type="search"
          value={queryText}
          onChange={(ev) => {
            setQueryText(ev.target.value);
            setSelected(null);
          }}
          placeholder="Search by name or SKU…"
          className="w-full rounded-md border border-light-hairline bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
        />
        {!selected && matches.length > 0 ? (
          <ul className="mt-tk-xs overflow-hidden rounded-md border border-light-hairline bg-light-card">
            {matches.map((p) => (
              <li key={p.id}>
                <button
                  type="button"
                  onClick={() => {
                    setSelected(p);
                    setQueryText(p.name);
                  }}
                  className="flex w-full items-center justify-between px-tk-md py-tk-sm text-left text-bodySmall hover:bg-light-subtle"
                >
                  <span className="text-light-text">{p.name}</span>
                  <span className="text-light-text-hint">{p.sku}</span>
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>

      {isLoading ? (
        <p className="text-bodySmall text-light-text-secondary">Loading products…</p>
      ) : null}

      {selected ? (
        <section className="space-y-tk-md">
          <div>
            <h2 className="text-bodyMedium font-semibold text-light-text">{selected.name}</h2>
            <p className="text-bodySmall text-light-text-hint">{selected.sku}</p>
          </div>
          <PriceHistoryView productId={selected.id} />
        </section>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 4: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/inventory/
git commit -m "feat(web-admin): price-history page, view, and sparkline components"
```

---

## Task 5: Routing + nav

**Files:**
- Modify: `web_admin/src/presentation/router/routePaths.ts`
- Modify: `web_admin/src/presentation/router/routeGuards.ts`
- Modify: `web_admin/src/presentation/router/routes.tsx`
- Modify: `web_admin/src/presentation/components/common/Sidebar.tsx`

- [ ] **Step 1: Add the route path**

In `web_admin/src/presentation/router/routePaths.ts`, add inside the `RoutePaths` object, after the `productDetail` line:

```ts
  priceHistory: '/inventory/price-history',
```

- [ ] **Step 2: Guard it (exact match wins over the generic /inventory/:id regex)**

In `web_admin/src/presentation/router/routeGuards.ts`, add to the `protectedRoutes`
`Map` (after the `productAdd` entry):

```ts
  [RoutePaths.priceHistory, Permission.viewProductCost],
```

- [ ] **Step 3: Register the route**

In `web_admin/src/presentation/router/routes.tsx`, add the import after the
`BulkReceivingPage` import:

```tsx
import { PriceHistoryPage } from '@/presentation/features/inventory/PriceHistoryPage';
```

Then add this route inside the protected `children` array, right after the
`RoutePaths.productEdit` placeholder line:

```tsx
        { path: RoutePaths.priceHistory, element: <PriceHistoryPage /> },
```

> Note: `RoutePaths.productDetail` (`/inventory/:id`) is NOT registered as a route,
> so `/inventory/price-history` has no dynamic-segment conflict in the router.

- [ ] **Step 4: Add the nav item**

In `web_admin/src/presentation/components/common/Sidebar.tsx`, add a nav item to the
`'Stock'` section's `items` array, after the `Bulk Receiving` entry (`ClockIcon` is
already imported):

```tsx
      { label: 'Price History', path: RoutePaths.priceHistory, icon: ClockIcon },
```

> The sidebar filters items through `canAccess`, so this entry only shows for admins
> (it requires `viewProductCost`).

- [ ] **Step 5: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

Run: `cd web_admin && npm run build`
Expected: build succeeds. (If esbuild errors: `npm rebuild esbuild` then retry.)

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/router/ web_admin/src/presentation/components/common/Sidebar.tsx
git commit -m "feat(web-admin): /inventory/price-history route + nav (admin via viewProductCost)"
```

---

## Task 6: Final gates

- [ ] **Step 1: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 2: Unit tests**

Run: `cd web_admin && npx vitest run --environment=node`
Expected: all suites pass (existing 53 + the new priceHistory suite).

- [ ] **Step 3: Build**

Run: `cd web_admin && npm run build`
Expected: succeeds.

- [ ] **Step 4: Manual smoke (optional, via /run or deployed preview)**

As an admin: open `/inventory/price-history` (or "Price History" in the Stock nav),
search a product with recorded changes, select it, confirm the sparkline + table
render, the All/Price/Cost filter works, and source/actor render. Confirm the nav
item is absent for a non-admin.

---

## Self-Review notes (author)

- **Spec coverage (§7 Phase 2):** ported helpers → Task 1; new `price_history` read path → Task 2; table + inline-SVG sparkline (no new dep) → Task 4; minimal product search→page host → Task 4; admin-gated via `viewProductCost` → Task 5. §5 contract (combined view, All/Price/Cost filter, sparkline + table, source labels, actor names) → Tasks 1 + 4.
- **Parity with mobile:** identical helper logic (`buildPriceHistoryRows`, `sparklineSeries`, `derivePriceHistorySource`); same metric semantics (origin entry always kept; EPS guard); same source-label mapping; actor UID resolved to `displayName` via `useUsers`.
- **Deviation (deliberate, matches existing code):** no `priceHistoryConverter` file — `listPriceHistory` maps inline, mirroring the existing inline `recordPriceChange` write path. Repo methods aren't unit-tested (Firestore); verified by tsc + build + manual smoke. The high-value logic is the pure helpers, fully unit-tested in node env.
- **Out of scope:** web inventory browse/edit + receiving history (separate queued work); staff price-only view.
- **Type consistency:** `PriceMetric`, `PriceHistoryRow{entry,priceDelta,costDelta,hasPrior}`, `sparklinePath(values,width,height)`, `derivePriceHistorySource(reason,note)`, `PriceHistoryEntry.note?` used identically across helper, hook, components, and tests.
