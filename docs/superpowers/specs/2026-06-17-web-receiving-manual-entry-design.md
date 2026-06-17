# Web Receiving — Manual Entry + Dashboard + Drafts (Design)

**Date:** 2026-06-17
**Surface:** Web admin (`web_admin/`, React) only. **Mobile unchanged.**
**Status:** Design — pending user review, then `writing-plans`.

## 1. Problem & intent

Today the web admin conflates two ideas under confusing names:

- **"Receiving"** (`/receiving`) is a *read-only history list*.
- **"Bulk Receiving"** (`/receiving/bulk`) is a *CSV importer* that both creates
  products and records stock — the only way to receive on web. The manual,
  line-item entry that mobile has was never built (`create`/`complete`/`update`/
  `list` are thrown stubs on `FirestoreReceivingRepository`).

Mobile, by contrast, already has the desired shape: a Receiving landing screen,
a **manual line-item entry** screen (`BulkReceivingScreen`), a **Receiving
History** screen, **Drafts**, and a **CSV import** that lives *under* receiving.

**Goal:** make the web Receiving area mean "this is where you receive incoming
stock," with a manual entry form as the primary action, a dashboard landing, a
history sub-view, and the CSV import kept as a secondary action — mirroring
mobile. Bring web to full parity including **drafts** and **inline new-product
creation**.

### Decisions locked in brainstorming
- CSV import **stays under Receiving** (not moved to Inventory). No Inventory or
  mobile changes.
- Web manual entry is **built now**, with **full parity**: `create`/`complete`/
  `update` + **drafts** (save partial, resume).
- Web Receiving landing = a **dashboard** (summary cards + recent + actions),
  mirroring mobile's `ReceivingScreen`.
- The manual form can add **existing products (match / cost-mismatch)** *and*
  **create brand-new products inline**.
- **No Firestore rules change** — `receivings` create/update is already allowed
  for staff+admin; a draft is just a `status:'draft'` doc.

## 2. Information architecture (routes)

| Route | Page | Change |
|-------|------|--------|
| `/receiving` | `ReceivingDashboardPage` — summary cards + recent receivings + `[+ New Receiving]` `[Import CSV]` | **new** |
| `/receiving/new` | `ReceivingEntryPage` — manual line-item form | **new** |
| `/receiving/new/:id` | Same form, resuming a draft by id | **new** |
| `/receiving/history` | `ReceivingHistoryPage` — date-filtered read-only list | **relocate** existing `ReceivingListPage` |
| `/receiving/bulk` | `BulkReceivingPage` — CSV import | unchanged |
| `/receiving/:id` | `ReceivingDetailPage` — read-only detail | **move** from `/receiving/bulk/:id` |

Static segments (`new`, `history`, `bulk`) are matched before the `:id` param,
and receiving ids are Firestore random ids, so `/receiving/:id` cannot collide.
Sidebar keeps a single **Receiving** entry → `/receiving` (the "Bulk Receiving"
sidebar item was already removed).

## 3. Domain model (no schema change)

The existing `Receiving` / `ReceivingItem` entities + `receivingConverter` cover
completed and draft docs already (`status: 'draft' | 'completed' | 'cancelled'`).

**Item classification** (mirrors the CSV path's `classifyReceivingRows`): each
form line is one of —
- **match** — existing product, cost == current cost → increment stock.
- **mismatch** — existing product, cost != current cost → create a
  `<baseSku>-N` variation product, then add stock to the variation.
- **new** — brand-new product (name, category, unit, cost, price, qty,
  reorder level, SKU or auto-generate) → create the product, then add stock.

**Draft persistence of "new" items.** A draft must round-trip a not-yet-created
product. Persist the new-product *spec* on the draft item (the create fields
above) and create the real product only at **complete** time — mirroring CSV
import, so abandoned drafts never leave orphan products. This requires a small
draft-only extension to the persisted item shape (a `pendingNewProduct` sub-
object, or equivalent); the exact shape is settled in the plan.

## 4. Repository — implement the stubs (`FirestoreReceivingRepository`)

**Refactor first (no behavior change):** the per-item **stock engine** already
exists inside `bulkReceive` — match → `increment` stock; mismatch → allocate
`<baseSku>-N` with `DuplicateSkuError` collision-retry + `recordPriceChange` +
stock; new → `products.create` + initial `recordPriceChange` + stock. Extract it
into one shared private method (e.g. `applyReceivedItems(rows, actor)`), and
route both `bulkReceive` and the new `complete` through it. `bulkReceive`'s
existing tests must stay green.

The engine operates on a **normalized "receivable item"** shape (productId-or-
new, sku, name, qty, cost, classification) that *both* the CSV
`ClassifiedReceivingRow`s **and** persisted draft items map into — so `complete`
reconstructs that shape from the stored draft items (including a draft item's
`pendingNewProduct` spec) and feeds the same engine. Defining this normalized
type is the first task of the plan.

Then implement:
- **`create(input, actorId)`** — write a `receivings` doc with `status` from
  input (`'draft'` or `'completed'`), `serverTimestamp` `createdAt`, per-item
  ids (`crypto.randomUUID()`, consistent with the existing fix). For a
  `completed` create, run the item engine first; for a `draft`, persist as-is
  (no stock effects). Returns the `Receiving`.
- **`update(id, input, actorId)`** — replace a **draft's** items/supplier/notes.
  Refuse if the doc is already `completed` (guard).
- **`complete(id, actor)`** — load the doc, run the shared item engine over its
  items (applying stock / variations / price history), then set
  `status:'completed'`, `completedAt`, `completedBy`. **Idempotency guard:**
  throw/no-op if already completed so stock can't double-apply.
- **`list(start?, end?)`** and a **drafts query** (`where status == 'draft'`,
  any age) — feed the history page and the dashboard Drafts card.

Stock writes reuse the existing product `adjustStock`/`increment` path; variation
creation reuses `nextVariationNumber`/`variationSku`/`products.create`/
`recordPriceChange`. No new Firestore rules.

## 5. Manual entry form (`ReceivingEntryPage`)

Mirrors mobile `BulkReceivingScreen`:

- **Supplier** dropdown (optional; `useSuppliers`).
- **Add item** = a product search over existing products (reuse the products
  query + client-side filter). Results show matches; a `"+ New product
  '<typed>'"` affordance appears when the user wants to create one.
  - Existing match → qty + unit cost (admin only sees cost; default = product's
    current cost). A cost ≠ current shows a "creates variation `<sku>-N`" badge.
  - New product → inline fields: name (prefilled), category & unit dropdowns
    (`useActiveCategories('product')`/`('unit')`), price, reorder level, SKU
    (auto-generate toggle default ON via `generateSku`, or manual), cost, qty.
    `costCode` derived from cost via `encodeCostCode`.
- **Items list** (edit / remove) + live totals (qty, ₱).
- **Actions:** **Save draft** (`create`/`update` with `status:'draft'`) ·
  **Receive** (create-if-needed → `complete`). On Receive: success toast with
  the `RCV-…` reference → navigate to `/receiving/:id`.

New-product creation in this form is web-only (mobile creates new products only
via CSV); the actor is an admin (web is admin-only), so the mobile
`Permission.addProduct` gate is satisfied implicitly.

## 6. Dashboard (`ReceivingDashboardPage`)

- **Summary cards** (mirror mobile): **This month** (completed count + ₱ total),
  **Drafts** (open count, any age), **Received** (₱ this month). Computed from a
  this-month realtime `useReceivings` + a `useDraftReceivings` query.
- **Recent receivings** (latest N) → row click = detail; `[View all →]` =
  history.
- Actions: `[+ New Receiving]` → `/receiving/new`; `[Import CSV]` →
  `/receiving/bulk`.

## 7. History (`ReceivingHistoryPage`)

The current realtime, date-filtered `ReceivingListPage`, relocated to
`/receiving/history`. Status badge includes `draft`. Row → detail.

## 8. Hooks

- Reuse `useReceivings` (history + dashboard recent) and `useReceiving` (detail).
- Add `useDraftReceivings` (status == 'draft'), mutation hooks
  `useCreateReceiving` / `useUpdateReceiving` / `useCompleteReceiving`, and
  `useReceivingSummary` (dashboard cards).

## 9. Testing & gates

- **Repository:** unit-test the extracted item engine — match→increment,
  mismatch→variation+stock+price-history, new→product-create+stock,
  collision-retry, and **idempotent `complete`** (second call is a no-op). Test
  `update` refuses on completed docs.
- **Domain:** the per-line classify helper (match / mismatch / new) gets vitest.
- **Converter:** existing tests stay green; add coverage for a draft item with a
  `pendingNewProduct` spec if that shape lands.
- Gates: `npm run typecheck` + `npm run test` (vitest) + `npm run build`.

## 10. Out of scope

- **No mobile changes.** No Firestore rules change. No Inventory CSV import.
- New-product *image upload* and *multiple barcodes* remain deferred (as in the
  inventory create slice) — the inline new-product form omits them.

## 11. Risks

- **Shared `receivings` writes** are production-affecting (CLAUDE.md). The
  `bulkReceive` refactor must be behavior-preserving (guarded by its existing
  tests); `complete` must be idempotent so stock never double-applies.
- **Draft new-product persistence** adds a draft-only item shape; keep it
  additive so `receivingConverter` reads of completed docs are unaffected.
- **Detail route move** (`/receiving/bulk/:id` → `/receiving/:id`) updates the
  internal link; no external/deep links exist to break.
