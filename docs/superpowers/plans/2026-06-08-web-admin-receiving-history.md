# Web Admin Receiving History + Detail — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the two `phase 8` placeholders into a realtime, date-filtered **receiving history** list at `/receiving` and a read-only **detail** page at `/receiving/bulk/:id`.

**Architecture:** Mirror the existing inventory/reports split — the live list uses a Firestore `onSnapshot` subscription (`useFirestoreSubscription`) bounded to a `DateRangePicker` window; the immutable detail uses a one-shot TanStack `useQuery`. A new `receivingConverter` maps Firestore docs → the existing `Receiving` entity. Replace the read-side stubs in `FirestoreReceivingRepository`; leave `create`/`complete` (manual entry) for a later slice.

**Tech Stack:** React + Vite + TypeScript, Firebase JS v9 modular SDK (`onSnapshot`, `getDoc`, `query`, `where`, `orderBy`, `Timestamp`, `withConverter`), TanStack Query, Vitest, Tailwind (project `tk-*` spacing + `light-*`/`success-*`/`warning-*`/`info-*` color tokens). Spec: `docs/superpowers/specs/2026-06-08-web-admin-receiving-history-design.md`. **Run all commands from inside `web_admin/`.**

---

## Context verified (exact current code)

- `web_admin/src/domain/entities/Receiving.ts` — exports `Receiving`, `ReceivingItem`, `ReceivingStatus` (`'draft' | 'completed' | 'cancelled'`). Re-exported by `domain/entities/index.ts` (`export * from './Receiving'`), so `@/domain/entities` resolves all three.
- `web_admin/src/data/repositories/FirestoreReceivingRepository.ts` — `bulkReceive()` is implemented; `getById`/`list`/`watchAll`/`create`/`complete` all `throw "...not implemented yet (phase 8)"`. Current `firebase/firestore` import list: `collection, doc, getDocs, increment, query, serverTimestamp, Timestamp, where, writeBatch, type Firestore`. `Unsubscribe` and `Receiving` are already imported.
- `web_admin/src/domain/repositories/ReceivingRepository.ts` — `watchAll(callback: (records: Receiving[]) => void): Unsubscribe;` (no callers anywhere — verified, the only impl is the stub).
- `web_admin/src/data/converters/saleConverter.test.ts` — converters are unit-tested with a mock snapshot stub `{ id, data: () => data } as never` and `opts = {} as never`. We mirror this exactly.
- `web_admin/src/data/converters/timestamps.ts` — `toDate(value): Date | null` and `requireDate(value, field): Date`.
- `web_admin/src/presentation/hooks/useFirestoreSubscription.ts` — `useFirestoreSubscription<T>(subscribe, deps)`; `subscribe` is `(onData, onError) => Unsubscribe`; returns `{ data: T | null, error: Error | null, isLoading }`.
- `web_admin/src/infrastructure/di/container.tsx` — exports `useReceivingRepo(): ReceivingRepository`.
- `web_admin/src/domain/reports/dateRange.ts` — `interface DateRange { start: Date; end: Date }`, `resolvePreset('last7') → DateRange`.
- `web_admin/src/presentation/components/common/DateRangePicker.tsx` — `<DateRangePicker onChange={(range: DateRange) => void} />`, internal default preset `'last7'`.
- `web_admin/src/presentation/router/routes.tsx` — imports `BulkReceivingPage`; has `{ path: RoutePaths.receiving, element: placeholder('Receiving', 'phase 8') }` and `{ path: RoutePaths.bulkReceivingDetail, element: placeholder('Bulk receiving', 'phase 8') }`. `RoutePaths.receiving = '/receiving'`, `RoutePaths.bulkReceivingDetail = '/receiving/bulk/:id'`, `RoutePaths.bulkReceiving = '/receiving/bulk'`.
- `web_admin/src/core/utils/money.ts` — `formatMoney(amount: number): string`.
- npm scripts: `typecheck` = `tsc -b --noEmit`, `test` = `vitest run`, `build` = `tsc -b && vite build`.

## File Structure

- **Create:**
  - `web_admin/src/data/converters/receivingConverter.ts` — Firestore doc ↔ `Receiving` mapping.
  - `web_admin/src/data/converters/receivingConverter.test.ts` — unit test (mock snapshot).
  - `web_admin/src/presentation/hooks/useReceivings.ts` — realtime list hook.
  - `web_admin/src/presentation/hooks/useReceiving.ts` — one-shot detail hook.
  - `web_admin/src/presentation/features/receiving/ReceivingStatusBadge.tsx` — shared status pill (used by both pages — DRY).
  - `web_admin/src/presentation/features/receiving/ReceivingListPage.tsx` — history list.
  - `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx` — read-only detail.
- **Modify:**
  - `web_admin/src/domain/repositories/ReceivingRepository.ts` — `watchAll` signature.
  - `web_admin/src/data/repositories/FirestoreReceivingRepository.ts` — `getById` + `watchAll` impls, imports.
  - `web_admin/src/presentation/router/routes.tsx` — swap two placeholders for the new pages.

---

## Task 1: `receivingConverter` (TDD)

**Files:**
- Create: `web_admin/src/data/converters/receivingConverter.test.ts`
- Create: `web_admin/src/data/converters/receivingConverter.ts`

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/data/converters/receivingConverter.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { receivingConverter } from './receivingConverter';

// Minimal QueryDocumentSnapshot stub — the converter only reads `.id`/`.data()`.
function snap(id: string, data: Record<string, unknown>) {
  return { id, data: () => data } as never;
}
const opts = {} as never;

describe('receivingConverter.fromFirestore', () => {
  it('maps a completed receiving with items, supplier, and timestamps', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-1', {
        referenceNumber: 'RCV-20260608-001',
        supplierId: 'sup-1',
        supplierName: 'Acme Supply',
        items: [
          {
            id: 'i1', productId: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg',
            quantity: 10, unit: 'kg', unitCost: 180, costCode: 'AB-CD',
            isNewVariation: false, newProductId: null, notes: null,
          },
        ],
        totalCost: 1800,
        totalQuantity: 10,
        status: 'completed',
        notes: null,
        createdAt: new Date('2026-06-08T10:00:00Z'),
        completedAt: new Date('2026-06-08T10:00:05Z'),
        createdBy: 'u1',
        createdByName: 'Czar',
        completedBy: 'u1',
      }),
      opts,
    );

    expect(r.id).toBe('rcv-1');
    expect(r.referenceNumber).toBe('RCV-20260608-001');
    expect(r.supplierName).toBe('Acme Supply');
    expect(r.items).toHaveLength(1);
    expect(r.items[0]).toEqual({
      id: 'i1', productId: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg',
      quantity: 10, unit: 'kg', unitCost: 180, costCode: 'AB-CD',
      isNewVariation: false, newProductId: null, notes: null,
    });
    expect(r.totalCost).toBe(1800);
    expect(r.totalQuantity).toBe(10);
    expect(r.status).toBe('completed');
    expect(r.createdAt).toEqual(new Date('2026-06-08T10:00:00Z'));
    expect(r.completedAt).toEqual(new Date('2026-06-08T10:00:05Z'));
  });

  it('defaults nullable supplier/notes/completion and empty items', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-2', {
        referenceNumber: 'RCV-20260608-002',
        status: 'draft',
        totalCost: 0,
        totalQuantity: 0,
        createdAt: new Date('2026-06-08T11:00:00Z'),
        createdBy: 'u1',
        createdByName: 'Czar',
      }),
      opts,
    );

    expect(r.items).toEqual([]);
    expect(r.supplierId).toBeNull();
    expect(r.supplierName).toBeNull();
    expect(r.notes).toBeNull();
    expect(r.completedAt).toBeNull();
    expect(r.completedBy).toBeNull();
    expect(r.status).toBe('draft');
  });

  it('coerces a Firestore Timestamp-like createdAt', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-3', {
        referenceNumber: 'RCV-20260608-003',
        status: 'completed',
        createdAt: { seconds: 1749376800, nanoseconds: 0 },
        createdBy: 'u1',
        createdByName: 'Czar',
      }),
      opts,
    );
    expect(r.createdAt).toBeInstanceOf(Date);
    expect(r.createdAt.getTime()).toBe(1749376800 * 1000);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run test -- src/data/converters/receivingConverter.test.ts`
Expected: FAIL — cannot resolve `./receivingConverter` (module does not exist yet).

- [ ] **Step 3: Write the converter**

Create `web_admin/src/data/converters/receivingConverter.ts`:

```ts
// Mirror of lib/data/models/receiving_model.dart fromFirestore/toMap. Reads the
// `receivings` docs that bulkReceive() writes (items embedded on the doc).
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Receiving, ReceivingItem, ReceivingStatus } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

const VALID_STATUS: ReceivingStatus[] = ['draft', 'completed', 'cancelled'];

function parseStatus(value: unknown): ReceivingStatus {
  return VALID_STATUS.includes(value as ReceivingStatus)
    ? (value as ReceivingStatus)
    : 'completed';
}

function parseItems(value: unknown): ReceivingItem[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const it = raw as Record<string, unknown>;
    return {
      id: (it.id as string) ?? '',
      productId: (it.productId as string | null) ?? null,
      sku: (it.sku as string) ?? '',
      name: (it.name as string) ?? '',
      quantity: Number(it.quantity ?? 0),
      unit: (it.unit as string) ?? 'pcs',
      unitCost: Number(it.unitCost ?? 0),
      costCode: (it.costCode as string) ?? '',
      isNewVariation: Boolean(it.isNewVariation ?? false),
      newProductId: (it.newProductId as string | null) ?? null,
      notes: (it.notes as string | null) ?? null,
    };
  });
}

export const receivingConverter: FirestoreDataConverter<Receiving> = {
  toFirestore(r) {
    return {
      referenceNumber: r.referenceNumber,
      supplierId: r.supplierId,
      supplierName: r.supplierName,
      items: r.items,
      totalCost: r.totalCost,
      totalQuantity: r.totalQuantity,
      status: r.status,
      notes: r.notes,
      createdBy: r.createdBy,
      createdByName: r.createdByName,
      completedBy: r.completedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Receiving {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      referenceNumber: d.referenceNumber ?? '',
      supplierId: d.supplierId ?? null,
      supplierName: d.supplierName ?? null,
      items: parseItems(d.items),
      totalCost: Number(d.totalCost ?? 0),
      totalQuantity: Number(d.totalQuantity ?? 0),
      status: parseStatus(d.status),
      notes: d.notes ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      completedAt: toDate(d.completedAt),
      createdBy: d.createdBy ?? '',
      createdByName: d.createdByName ?? '',
      completedBy: d.completedBy ?? null,
    };
  },
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npm run test -- src/data/converters/receivingConverter.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Typecheck**

Run: `npm run typecheck`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/data/converters/receivingConverter.ts web_admin/src/data/converters/receivingConverter.test.ts
git commit -m "$(cat <<'EOF'
feat(web): receivingConverter (Firestore doc -> Receiving entity)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Receiving repository read-layer (interface + impl)

No unit test — `getById`/`watchAll` need live Firestore (no emulator, per CLAUDE.md). Verified by typecheck. The interface change and impl must land together so the type stays consistent at commit.

**Files:**
- Modify: `web_admin/src/domain/repositories/ReceivingRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`

- [ ] **Step 1: Change the `watchAll` signature in the interface**

In `web_admin/src/domain/repositories/ReceivingRepository.ts`, add this import near the top (after the existing `import type` lines):

```ts
import type { DateRange } from '../reports/dateRange';
```

Then replace this line:

```ts
  watchAll(callback: (records: Receiving[]) => void): Unsubscribe;
```

with:

```ts
  watchAll(
    range: DateRange,
    onData: (records: Receiving[]) => void,
    onError?: (err: Error) => void,
  ): Unsubscribe;
```

- [ ] **Step 2: Add the new imports to the repository**

In `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`, replace the `firebase/firestore` import block:

```ts
import {
  collection,
  doc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  Timestamp,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
```

with (adds `getDoc`, `onSnapshot`, `orderBy`):

```ts
import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
```

Then add these two imports anywhere in the existing import group at the top of the file (e.g. just below the `DuplicateSkuError` import):

```ts
import { receivingConverter } from '@/data/converters/receivingConverter';
import type { DateRange } from '@/domain/reports/dateRange';
```

- [ ] **Step 3: Implement `getById` + `watchAll`, keep `create`/`complete`/`list` stubbed**

In the same file, replace this entire stub block:

```ts
  // Receiving-history methods land in phase 8 (the receiving list/detail views).
  async getById(): Promise<Receiving | null> {
    throw new Error('ReceivingRepository.getById not implemented yet (phase 8)');
  }
  async list(): Promise<Receiving[]> {
    throw new Error('ReceivingRepository.list not implemented yet (phase 8)');
  }
  watchAll(): Unsubscribe {
    throw new Error('ReceivingRepository.watchAll not implemented yet (phase 8)');
  }
  async create(): Promise<Receiving> {
    throw new Error('ReceivingRepository.create not implemented yet (phase 8)');
  }
  async complete(): Promise<void> {
    throw new Error('ReceivingRepository.complete not implemented yet (phase 8)');
  }
```

with:

```ts
  // --- Read side: history list + detail ---

  private receivingsCol() {
    return collection(this.db, FirestoreCollections.receivings).withConverter(
      receivingConverter,
    );
  }

  async getById(id: string): Promise<Receiving | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.receivings, id).withConverter(receivingConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  watchAll(
    range: DateRange,
    onData: (records: Receiving[]) => void,
    onError?: (err: Error) => void,
  ): Unsubscribe {
    // createdAt range filter + orderBy are on the SAME field, so this needs
    // only the default single-field index (no composite index).
    return onSnapshot(
      query(
        this.receivingsCol(),
        where('createdAt', '>=', Timestamp.fromDate(range.start)),
        where('createdAt', '<', Timestamp.fromDate(range.end)),
        orderBy('createdAt', 'desc'),
      ),
      (snap) => onData(snap.docs.map((d) => d.data())),
      onError,
    );
  }

  // Manual entry (create/complete) and the unbounded list() are a later slice.
  async list(): Promise<Receiving[]> {
    throw new Error('ReceivingRepository.list not implemented yet');
  }
  async create(): Promise<Receiving> {
    throw new Error('ReceivingRepository.create not implemented yet');
  }
  async complete(): Promise<void> {
    throw new Error('ReceivingRepository.complete not implemented yet');
  }
```

- [ ] **Step 4: Typecheck**

Run: `npm run typecheck`
Expected: no errors. (If it complains `watchAll` is missing the `range` arg somewhere, there are no other callers — re-check Step 1 landed.)

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/ReceivingRepository.ts web_admin/src/data/repositories/FirestoreReceivingRepository.ts
git commit -m "$(cat <<'EOF'
feat(web): receiving read-layer — getById + date-bounded watchAll

Replaces the phase-8 read stubs. watchAll subscribes to receivings within a
DateRange, ordered createdAt desc; getById reads one doc via the converter.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Hooks — `useReceivings` + `useReceiving`

No unit test — thin wrappers over infra (consistent with `useProducts` / `useReportData`, which are not unit-tested). Verified by typecheck.

**Files:**
- Create: `web_admin/src/presentation/hooks/useReceivings.ts`
- Create: `web_admin/src/presentation/hooks/useReceiving.ts`

- [ ] **Step 1: Write `useReceivings`**

Create `web_admin/src/presentation/hooks/useReceivings.ts`:

```ts
import { useReceivingRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Receiving } from '@/domain/entities';
import type { DateRange } from '@/domain/reports/dateRange';

/** Realtime list of receivings within `range`, newest first. */
export function useReceivings(range: DateRange) {
  const repo = useReceivingRepo();
  return useFirestoreSubscription<Receiving[]>(
    (onData, onError) => repo.watchAll(range, onData, onError),
    [repo, range.start.getTime(), range.end.getTime()],
  );
}
```

- [ ] **Step 2: Write `useReceiving`**

Create `web_admin/src/presentation/hooks/useReceiving.ts`:

```ts
import { useQuery } from '@tanstack/react-query';
import { useReceivingRepo } from '@/infrastructure/di/container';

/** One-shot fetch of a single (immutable) receiving by id. */
export function useReceiving(id: string) {
  const repo = useReceivingRepo();
  return useQuery({
    queryKey: ['receiving', id],
    queryFn: () => repo.getById(id),
    enabled: id.length > 0,
  });
}
```

- [ ] **Step 3: Typecheck**

Run: `npm run typecheck`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/hooks/useReceivings.ts web_admin/src/presentation/hooks/useReceiving.ts
git commit -m "$(cat <<'EOF'
feat(web): useReceivings (realtime list) + useReceiving (detail) hooks

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `ReceivingStatusBadge` + `ReceivingListPage` + route

**Files:**
- Create: `web_admin/src/presentation/features/receiving/ReceivingStatusBadge.tsx`
- Create: `web_admin/src/presentation/features/receiving/ReceivingListPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Write the shared status badge**

Create `web_admin/src/presentation/features/receiving/ReceivingStatusBadge.tsx`:

```tsx
import type { ReceivingStatus } from '@/domain/entities';

const TONE: Record<ReceivingStatus, string> = {
  completed: 'bg-success-light text-success-dark',
  draft: 'bg-warning-light text-warning-dark',
  cancelled: 'bg-light-subtle text-light-text-secondary',
};

export function ReceivingStatusBadge({ status }: { status: ReceivingStatus }) {
  return (
    <span
      className={`rounded-full px-tk-sm py-[2px] text-[11px] font-semibold uppercase tracking-wider ${TONE[status]}`}
    >
      {status}
    </span>
  );
}
```

- [ ] **Step 2: Write the list page**

Create `web_admin/src/presentation/features/receiving/ReceivingListPage.tsx`:

```tsx
import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReceivings } from '@/presentation/hooks/useReceivings';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ReceivingStatusBadge } from './ReceivingStatusBadge';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function ReceivingListPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { data: receivings, isLoading, error } = useReceivings(range);
  const navigate = useNavigate();

  useEffect(() => {
    document.title = 'Receiving · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Receiving
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Stock received from suppliers in the selected range.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-tk-sm">
          <DateRangePicker onChange={setRange} />
          <button
            type="button"
            disabled
            title="Coming soon"
            className="inline-flex cursor-not-allowed items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text opacity-50"
          >
            + New Receiving
          </button>
          <Link
            to={RoutePaths.bulkReceiving}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <ArrowUpTrayIcon className="h-4 w-4" />
            Bulk import
          </Link>
        </div>
      </header>

      {error ? (
        <ErrorView title="Could not load receivings" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading receivings…" />
        </div>
      ) : !receivings || receivings.length === 0 ? (
        <EmptyState
          title="No receivings in this range"
          description="Try a wider date range, or use Bulk import to record received stock."
        />
      ) : (
        <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <th className="px-tk-md py-tk-sm text-left font-medium">Reference</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Date</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Supplier</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Items</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Total</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {receivings.map((r) => (
                <tr
                  key={r.id}
                  onClick={() => navigate(`/receiving/bulk/${r.id}`)}
                  className="cursor-pointer hover:bg-light-subtle"
                >
                  <td className="px-tk-md py-tk-sm font-medium text-light-text">
                    {r.referenceNumber}
                  </td>
                  <td className="px-tk-md py-tk-sm text-light-text-secondary">
                    {dtFmt.format(r.completedAt ?? r.createdAt)}
                  </td>
                  <td className="px-tk-md py-tk-sm text-light-text-secondary">
                    {r.supplierName ?? '—'}
                  </td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.totalQuantity}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums">
                    {formatMoney(r.totalCost)}
                  </td>
                  <td className="px-tk-md py-tk-sm">
                    <ReceivingStatusBadge status={r.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </div>
  );
}
```

- [ ] **Step 3: Wire the route**

In `web_admin/src/presentation/router/routes.tsx`, add this import alongside the other feature imports (next to the `BulkReceivingPage` import):

```tsx
import { ReceivingListPage } from '@/presentation/features/receiving/ReceivingListPage';
```

Then replace:

```tsx
        { path: RoutePaths.receiving, element: placeholder('Receiving', 'phase 8') },
```

with:

```tsx
        { path: RoutePaths.receiving, element: <ReceivingListPage /> },
```

- [ ] **Step 4: Typecheck + full test suite**

Run: `npm run typecheck`
Expected: no errors.

Run: `npm run test`
Expected: PASS — all suites green (including Task 1's converter test).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/receiving/ReceivingStatusBadge.tsx web_admin/src/presentation/features/receiving/ReceivingListPage.tsx web_admin/src/presentation/router/routes.tsx
git commit -m "$(cat <<'EOF'
feat(web): receiving history list at /receiving (realtime, date-filtered)

Date-ranged realtime list with status badge; rows open the detail route.
+New Receiving disabled (coming soon); Bulk import links to /receiving/bulk.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `ReceivingDetailPage` + route

**Files:**
- Create: `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

- [ ] **Step 1: Write the detail page**

Create `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx`:

```tsx
import { useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useReceiving } from '@/presentation/hooks/useReceiving';
import { formatMoney } from '@/core/utils/money';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ReceivingStatusBadge } from './ReceivingStatusBadge';

const dtFmt = new Intl.DateTimeFormat('en-PH', { dateStyle: 'medium', timeStyle: 'short' });

export function ReceivingDetailPage() {
  const { id = '' } = useParams();
  const { data: receiving, isLoading, error } = useReceiving(id);

  useEffect(() => {
    document.title = 'Receiving detail · MAKI POS Admin';
  }, []);

  if (isLoading) {
    return (
      <div className="p-tk-xl">
        <LoadingView label="Loading receiving…" />
      </div>
    );
  }
  if (error) {
    return (
      <div className="p-tk-xl">
        <ErrorView title="Could not load receiving" message={(error as Error).message} />
      </div>
    );
  }
  if (!receiving) {
    return (
      <div className="p-tk-xl">
        <EmptyState
          title="Receiving not found"
          description="It may have been removed."
          action={
            <Link to={RoutePaths.receiving} className="text-light-text underline">
              Back to receiving
            </Link>
          }
        />
      </div>
    );
  }

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <header className="space-y-tk-xs">
        <Link
          to={RoutePaths.receiving}
          className="text-bodySmall text-light-text-secondary hover:underline"
        >
          ← Back to receiving
        </Link>
        <div className="flex items-center gap-tk-md">
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {receiving.referenceNumber}
          </h1>
          <ReceivingStatusBadge status={receiving.status} />
        </div>
        <p className="text-bodySmall text-light-text-secondary">
          {receiving.supplierName ?? 'No supplier'} ·{' '}
          {dtFmt.format(receiving.completedAt ?? receiving.createdAt)} · {receiving.createdByName}
        </p>
      </header>

      <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <th className="px-tk-md py-tk-sm text-left font-medium">Item</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Qty</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Unit cost</th>
              <th className="px-tk-md py-tk-sm text-right font-medium">Line total</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {receiving.items.map((it) => (
              <tr key={it.id}>
                <td className="px-tk-md py-tk-sm">
                  <span className="font-medium text-light-text">{it.name}</span>
                  <span className="ml-tk-sm text-light-text-hint">{it.sku}</span>
                  {it.isNewVariation ? (
                    <span className="ml-tk-sm rounded-full bg-info-light px-tk-sm py-[1px] text-[10px] font-semibold uppercase text-info-dark">
                      New variation
                    </span>
                  ) : null}
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">{it.quantity}</td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(it.unitCost)}
                </td>
                <td className="px-tk-md py-tk-sm text-right tabular-nums">
                  {formatMoney(it.unitCost * it.quantity)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="ml-auto w-full max-w-sm space-y-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
        <div className="flex justify-between">
          <span className="text-light-text-secondary">Total items</span>
          <span className="tabular-nums text-light-text">{receiving.totalQuantity}</span>
        </div>
        <div className="flex justify-between border-t border-light-hairline pt-tk-xs">
          <span className="font-semibold text-light-text">Total cost</span>
          <span className="tabular-nums font-semibold text-light-text">
            {formatMoney(receiving.totalCost)}
          </span>
        </div>
      </section>
    </div>
  );
}
```

- [ ] **Step 2: Wire the route**

In `web_admin/src/presentation/router/routes.tsx`, add this import (next to the `ReceivingListPage` import from Task 4):

```tsx
import { ReceivingDetailPage } from '@/presentation/features/receiving/ReceivingDetailPage';
```

Then replace:

```tsx
        { path: RoutePaths.bulkReceivingDetail, element: placeholder('Bulk receiving', 'phase 8') },
```

with:

```tsx
        { path: RoutePaths.bulkReceivingDetail, element: <ReceivingDetailPage /> },
```

- [ ] **Step 3: Typecheck + build**

Run: `npm run typecheck`
Expected: no errors.

Run: `npm run build`
Expected: builds cleanly (`tsc -b` then `vite build`).

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx web_admin/src/presentation/router/routes.tsx
git commit -m "$(cat <<'EOF'
feat(web): receiving detail at /receiving/bulk/:id (read-only)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Sidebar check + final verification

**Files:**
- Read (and only modify if wrong): `web_admin/src/presentation/components/common/Sidebar.tsx`

- [ ] **Step 1: Confirm the sidebar's Receiving entry targets `/receiving`**

Run: `grep -n -i "receiv" web_admin/src/presentation/components/common/Sidebar.tsx`
Expected: a nav item pointing at `RoutePaths.receiving` (`/receiving`), NOT `/receiving/bulk`.

- If it already points at `RoutePaths.receiving`: no change — the list is now the receiving landing page.
- If it points at `RoutePaths.bulkReceiving` (`/receiving/bulk`) or is missing: change/add it to `RoutePaths.receiving` so the sidebar opens the new history list. (Keep using the existing nav-item pattern in that file; do not restructure the sidebar.)

- [ ] **Step 2: Full verification suite**

Run: `npm run typecheck`
Expected: no errors.

Run: `npm run test`
Expected: PASS — all suites green.

Run: `npm run build`
Expected: builds cleanly.

- [ ] **Step 3: Manual verify (dev server)**

Run: `npm run dev`, sign in as admin, then:
- Open `/receiving` → history list renders; change the `DateRangePicker` preset and confirm the list refetches and stays newest-first.
- With at least one receiving committed via Bulk Receiving in range, confirm a row shows reference, date, supplier (or "—"), item count, total, and a status badge.
- Click a row → lands on `/receiving/bulk/:id` detail with line items + totals; the back link returns to `/receiving`.
- Confirm "+ New Receiving" is disabled with a "Coming soon" tooltip and "Bulk import" opens `/receiving/bulk`.
- Visit a bad id (`/receiving/bulk/does-not-exist`) → "Receiving not found" empty state, not a crash.

- [ ] **Step 4: Commit (only if Step 1 changed the sidebar)**

```bash
git add web_admin/src/presentation/components/common/Sidebar.tsx
git commit -m "$(cat <<'EOF'
fix(web): point sidebar Receiving nav at /receiving history list

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review notes (author)

- **Spec coverage:** history list (Tasks 3–4), detail (Tasks 3, 5), converter (Task 1), repo read-layer + `watchAll(range,onData,onError)` (Task 2), `DateRangePicker`-driven realtime (Task 4), disabled "+ New" + Bulk import buttons (Task 4), routing swap (Tasks 4–5), single-field index note (Task 2 Step 3 comment), sidebar (Task 6). All spec sections map to a task.
- **Out of scope (unchanged):** `create`/`complete` (manual entry), `list()`, drafts, day-grouping, linking the Bulk-Receiving result screen to detail.
- **Type consistency:** `watchAll(range, onData, onError?)` is identical in the interface (Task 2 Step 1), impl (Task 2 Step 3), and call site (Task 3 Step 1). `ReceivingStatusBadge` prop `status: ReceivingStatus` matches its consumers. Detail route `/receiving/bulk/${r.id}` (Task 4) matches `RoutePaths.bulkReceivingDetail = '/receiving/bulk/:id'` and the `useParams` id read (Task 5).
