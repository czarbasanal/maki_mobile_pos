# Web Admin — Receiving History + Detail — Design

> **Status:** approved design (brainstormed 2026-06-08). Turns the two `phase 8`
> placeholders (`/receiving`, `/receiving/bulk/:id`) into a realtime, date-filtered
> **receiving history** list and a read-only **detail** page. Read-only — no stock writes.

## Context

The web admin's only working receiving path today is **Bulk Receiving** (`/receiving/bulk`,
`BulkReceivingPage`) — the CSV import → preview → commit flow shipped in
`2026-06-01-web-admin-bulk-receiving-design.md`. Its repository method `bulkReceive()` writes a
completed `receivings` record and applies stock.

Everything else on the receiving read-side is still stubbed. In
`web_admin/src/data/repositories/FirestoreReceivingRepository.ts`, `getById`, `list`, `watchAll`,
`create`, and `complete` all `throw "not implemented yet (phase 8)"`. The two routes that surface
them render `<PagePlaceholder phase="phase 8">`:

- `RoutePaths.receiving` → `/receiving`
- `RoutePaths.bulkReceivingDetail` → `/receiving/bulk/:id`

The web already has a faithful `Receiving`/`ReceivingItem` entity
(`web_admin/src/domain/entities/Receiving.ts`) that mirrors `lib/domain/entities/receiving_entity.dart`,
and the DI container already constructs the receiving repo
(`web_admin/src/infrastructure/di/container.tsx`, `useReceivingRepo()`). What's missing is the
read implementations, a converter, the hooks, and the two pages.

For reference, the **mobile** app splits receiving into a hub screen (summary cards + this-week list +
"New Receiving"), a manual line-item builder, a CSV batch-import screen, a drafts list, and a full
history screen (`lib/presentation/mobile/screens/receiving/`). This slice builds only the web
equivalent of the **hub/history list + a record detail view**.

## Goals

1. **Receiving history** at `/receiving`: a realtime, date-filtered list of past receivings, ordered
   newest-first, with entry buttons to Bulk Import and a disabled "New Receiving".
2. **Receiving detail** at `/receiving/bulk/:id`: a read-only view of one committed receiving —
   line items, totals, supplier, and who/when. Clicking a list row opens it.
3. Build the web receiving **read-layer** (`getById` + date-bounded `watchAll` + a converter) that
   replaces the phase-8 stubs, reusing the existing realtime/Query patterns.

## Non-goals (out of scope)

- **Manual (non-CSV) receiving entry** (`create` / `complete`) — a separate later slice. The
  "New Receiving" button is present but **disabled** with a "Coming soon" tooltip.
- Receiving **drafts** list; editing or **cancelling** a committed receiving; reversing stock.
- **Day-grouping** of the history list (mobile groups by day) — this slice ships a flat
  reverse-chronological list. Grouping can be added later as a pure, TDD'd helper.
- Linking the Bulk-Receiving **result** screen to the new detail page — `bulkReceive()` returns a
  `referenceNumber`, not the new doc id, so deep-linking the result needs extra plumbing. Later.

## Architecture

Mirrors the existing inventory/reports split exactly (see
`web_admin/src/presentation/hooks/useFirestoreSubscription.ts` header): **live lists use Firestore
subscriptions; one-shot reads use TanStack Query.**

- **List = realtime subscription.** `useReceivings(range)` → `useFirestoreSubscription` →
  `repo.watchAll(range, onData)` → `onSnapshot` on the `receivings` collection, filtered to
  `createdAt ∈ [range.start, range.end)`, ordered `createdAt desc`. New receivings appear live within
  the chosen window — same shape as `useProducts` / the inventory list.
- **Detail = one-shot Query.** A committed receiving is immutable, so `useReceiving(id)` uses
  `useQuery` → `repo.getById(id)` (no subscription). Matches `useReportData`'s use of `useQuery` for
  bounded reads.

### Data flow

```
/receiving           → ReceivingListPage
                         ├─ <DateRangePicker/>  (default preset 'last7')  → range
                         └─ useReceivings(range) → watchAll(range, cb) → onSnapshot → Receiving[]

/receiving/bulk/:id  → ReceivingDetailPage
                         └─ useReceiving(id)     → getById(id)         → Receiving | null
```

## Data-layer changes

### `receivingConverter` (new — `web_admin/src/data/converters/receivingConverter.ts`)

A `FirestoreDataConverter<Receiving>` mirroring `productConverter`:

- `fromFirestore(snap)` maps the stored doc to the `Receiving` entity: scalar fields, the nested
  `items[]` → `ReceivingItem[]`, timestamps via `toDate` / `requireDate`
  (`data/converters/timestamps.ts`), and `id` from `snap.id`. The shape `bulkReceive()` writes
  (`items.map(it => ({ ...it, notes: null }))`, `status: 'completed'`, `createdAt`/`completedAt`
  server timestamps) maps cleanly; `completedAt` / `completedBy` / `supplierId` / `supplierName` /
  `notes` are nullable.
- `toFirestore` is provided for symmetry/typing but not used by the read paths in this slice.

### `ReceivingRepository` interface (modify — `domain/repositories/ReceivingRepository.ts`)

Change `watchAll(callback)` → `watchAll(range: DateRange, onData, onError?)`. The method is currently
stubbed with **no callers**, so the signature change is free. The optional `onError` lets the hook
forward `onSnapshot` errors to `ErrorView` (see Error handling). `DateRange` is imported from
`@/domain/reports/dateRange`. `getById(id)` and `list(start?, end?)` keep their signatures.

### `FirestoreReceivingRepository` (modify)

Replace the phase-8 stubs for the two read methods this slice needs:

- `getById(id)`: `getDoc(doc(db, receivings, id).withConverter(receivingConverter))` → `data()` or
  `null`.
- `watchAll(range, onData, onError?)`: `onSnapshot(query(col.withConverter(receivingConverter), where('createdAt','>=', Timestamp.fromDate(range.start)), where('createdAt','<', Timestamp.fromDate(range.end)), orderBy('createdAt','desc')), snap => onData(snap.docs.map(d => d.data())), onError)`.

`list` / `create` / `complete` stay stubbed (out of scope).

### Firestore index

The range filter and the `orderBy` are both on **`createdAt`** (the same field), so Firestore needs
only the default single-field index — no composite index. (`generateReferenceNumber()` already runs a
`createdAt` range query, confirming this works against the live data.)

## Hooks (new)

- `presentation/hooks/useReceivings.ts` — `useReceivings(range: DateRange)` wraps
  `useFirestoreSubscription<Receiving[]>((onData, onError) => repo.watchAll(range, onData, onError), [repo, range.start, range.end])`.
- `presentation/hooks/useReceiving.ts` — `useReceiving(id: string)` wraps
  `useQuery({ queryKey: ['receiving', id], queryFn: () => repo.getById(id) })`.

## Pages

### `ReceivingListPage` (new — replaces `/receiving` placeholder)

- **Header:** title + two actions — **Bulk Import** (`<Link to={RoutePaths.bulkReceiving}>`, works)
  and **+ New Receiving** (disabled button, `title="Coming soon"` tooltip).
- **Filter:** `<DateRangePicker onChange={setRange} />`. The page owns `range`, initialized to
  `resolvePreset('last7')` to match the picker's internal default preset.
- **List:** a table — **Ref # · Date · Supplier · Items (qty) · Total · Status**. `Total` uses
  `formatMoney` (`core/utils/money.ts`); `Status` is a small colored badge
  (completed=green, draft=amber, cancelled=grey — matching mobile's status visuals). Each row is a
  `<Link to={`/receiving/bulk/${r.id}`}>`.
- **States:** `isLoading` → `LoadingView`; `error` → `ErrorView`; empty → `EmptyState`
  ("No receivings in this range"). All from `presentation/components/common/`.

### `ReceivingDetailPage` (new — replaces `/receiving/bulk/:id` placeholder)

- `useParams<{ id }>` → `useReceiving(id)`.
- **Header:** reference number, status badge, supplier name (or "—"), created-by + created date, and
  completed-by/date when present. A back link to `/receiving`.
- **Line items:** table of name · sku · qty × unit cost · line total, then footer totals
  (`totalQuantity` items, `formatMoney(totalCost)`).
- **States:** loading → `LoadingView`; error → `ErrorView`; `null` (not found) → `EmptyState`.

## Routing & navigation

- `presentation/router/routes.tsx`: replace `placeholder('Receiving', 'phase 8')` with
  `<ReceivingListPage/>`, and the `RoutePaths.bulkReceivingDetail` `placeholder('Bulk receiving', 'phase 8')`
  with `<ReceivingDetailPage/>`.
- Verify the `Sidebar` "Receiving" entry already targets `RoutePaths.receiving` (`/receiving`); the
  admin shell is navigable from day one, so this should already be wired — confirm, don't assume.

## Error handling

- Subscription errors surface through `useFirestoreSubscription`'s `onError` → `ErrorView` on the list.
- `getById` returning `null` (deleted/bad id) → `EmptyState`, not an error.
- Query errors on detail → `ErrorView`.

## Testing

Two layers, two approaches:

- **`receivingConverter` is TDD'd.** `fromFirestore` is a pure mapping over a plain object, and this
  repo already unit-tests converters with a mock snapshot stub — see `saleConverter.test.ts`
  (`{ id, data: () => ({...}) }`, no emulator). So `receivingConverter.test.ts` is written test-first,
  covering the `bulkReceive()`-written shape, the nested `items[]`, nullable `completedAt`/supplier,
  and timestamp parsing.
- **The repo query methods are not unit-tested** (`getById` / `watchAll` need live Firestore; no
  emulator/mock, per CLAUDE.md). They're verified by `npm run typecheck` + `npm run build`, an
  adversarial review against the shape `bulkReceive()` writes, and manual `/verify`: open
  `/receiving`, change the date range, confirm the live list + row → detail.

`npm run test` must stay green (existing suite + the new converter test). If a future slice adds
day-grouping, that pure helper (`groupReceivingsByDay`) would also be TDD'd.

## File manifest

- **New:**
  - `web_admin/src/data/converters/receivingConverter.ts`
  - `web_admin/src/presentation/hooks/useReceivings.ts`
  - `web_admin/src/presentation/hooks/useReceiving.ts`
  - `web_admin/src/presentation/features/receiving/ReceivingListPage.tsx`
  - `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx`
- **Modify:**
  - `web_admin/src/domain/repositories/ReceivingRepository.ts` (`watchAll` signature)
  - `web_admin/src/data/repositories/FirestoreReceivingRepository.ts` (`getById` + `watchAll`)
  - `web_admin/src/presentation/router/routes.tsx` (swap two placeholders)
