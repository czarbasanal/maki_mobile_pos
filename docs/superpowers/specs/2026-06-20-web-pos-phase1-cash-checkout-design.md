# Web POS — Phase 1: Cart + Cash Checkout — Design

**Date:** 2026-06-20
**Surface:** React web admin (`web_admin/`).
**Status:** Design — approved-in-brainstorm, pending `writing-plans`.
**Epic:** Web POS (full mobile parity, phased). Intent: **remote / back-office
sales** (phone/B2B orders, corrections from the office — not a live counter
register, so no barcode-scanner dependency).

**Phase plan (this is Phase 1):** 1) cart + cash checkout · 2) tenders
(gcash/maya/salmon/mixed) · 3) labor + mechanic · 4) drafts · 5) receipt · void.

## 1. Problem & intent

`/pos`, `/pos/checkout`, `/drafts` are placeholders and
`FirestoreSaleRepository.create()` is an unimplemented stub. Phase 1 builds a
working cash register: a cart, cash payment, and the **atomic sale write** that
every later phase extends. The sale appears in the existing Reports immediately.

### Decisions locked in brainstorming
- **Atomic stock decrement** — per-line `products/{id}` decrements live INSIDE
  the sale transaction (diverges from mobile's best-effort-after pattern;
  matches the web receiving `complete()` precedent). No drift.
- **Warn-but-allow oversell** (mobile parity) — a line exceeding on-hand stock
  shows a UI warning but never blocks checkout; stock may go negative.
- **Cash only** this phase: `paymentMethod = 'cash'`, `tenders = { cash:
  grandTotal }`, `amountReceived`, `changeGiven = amountReceived − grandTotal`.
- Cart state in a **Zustand `cartStore`** (sets up Phase 4 drafts); ephemeral
  (lost on refresh — drafts are Phase 4).

## 2. Cross-surface contract (from the mobile POS map — replicate exactly)

**Sale number:** `SALE-YYYYMMDD-NNN` (NNN zero-padded, 3+ digits). Counter at
`settings/sale_counters`, one integer field per day keyed `YYYYMMDD`,
read-incremented-written inside the sale transaction (daily reset).

**`sales/{id}` doc fields:** `saleNumber, discountType ('amount'|'percentage'),
paymentMethod ('cash'), tenders ({cash: grandTotal}), amountReceived,
changeGiven, status ('completed'), cashierId, cashierName, laborLines ([]),
mechanicId (null), mechanicName (null), draftId (null), notes (null|string),
createdAt/updatedAt (serverTimestamp), voidedAt/voidedBy/voidedByName/voidReason
(null)`.

**`sales/{id}/items/{itemId}` (subcollection, one per line):** `productId, sku,
name, unitPrice, unitCost, quantity, discountValue, unit`. Item id =
`doc(collection).id` (pre-allocated).

**Discount:** sale-level `discountType` chooses interpretation; each line stores
a `discountValue` (peso amount OR percent). Switching `discountType` resets all
line discounts to 0 (mobile behavior).

**Stock decrement:** `products/{productId}` `quantity: increment(-qty)` +
`updatedAt/updatedBy/updatedByName` — **in the transaction** (our divergence).

## 3. The atomic write — implement `FirestoreSaleRepository.create()`

Signature stays `create(sale: Omit<Sale,'id'|'createdAt'|'updatedAt'>, actorId):
Promise<Sale>`. The passed `sale.saleNumber` is ignored (generated inside). One
`runTransaction`:
1. **Read** `settings/sale_counters` (the only read) → current `seq =
   data[YYYYMMDD] ?? 0` → `next = seq + 1` → `saleNumber =
   formatSaleNumber(now, next)`. (`now` passed in from the caller — scripts
   can't call `Date.now()`, but the app can; the repo uses `new Date()` at call
   time.)
2. **Writes** (blind, after the read): `set sales/{id}` (all fields, server
   timestamps); `set sales/{id}/items/{itemId}` per line; `set
   settings/sale_counters` (merge) `{ [YYYYMMDD]: next }`; `update
   products/{productId}` `{ quantity: increment(-qty), updatedAt, updatedBy,
   updatedByName }` per line.
3. Return the created `Sale` (re-read via `getById`, or compose locally).

**Write budget:** `1 (sale) + N (items) + 1 (counter) + N (stock) = 2 + 2N`.
**Size guard:** reject a cart with more than **200 lines** loudly (well under
Firestore's 500-write cap) — a `TooManyLinesError`-style clear message.

Reads-before-writes holds (single counter read precedes all writes; increments
are blind writes needing no prior read).

## 4. Pure helpers (TDD, vitest)

- `src/domain/sales/saleNumber.ts`: `counterKey(date): string` (`YYYYMMDD`,
  local time), `formatSaleNumber(date, seq): string`
  (`SALE-{YYYYMMDD}-{seq padded ≥3}`).
- `src/domain/sales/cart.ts`: cart-line money + checkout math reusing the
  existing `Sale` helpers where possible — `cartGrandTotal(lines, discountType)`
  (= partsRevenue, labor=0), `changeFor(grandTotal, amountReceived)`
  (`max(0, received − total)`), `cashTenders(grandTotal)` (`{ cash: grandTotal
  }`). Validity: `amountReceived ≥ grandTotal`. (Reuse `saleSubtotal` /
  `saleTotalDiscount` / `salePartsRevenue` by passing a `Sale`-shaped object so
  the math stays single-sourced.)
- A pure `buildSaleItemsLowStock(lines, products)` → the list of lines whose
  qty exceeds on-hand (for the warning), if a helper reads cleaner than inline.

## 5. Cart store + UI

- **`src/presentation/stores/cartStore.ts` (Zustand):** `{ lines: CartLine[],
  discountType, addLine(product), setQty(productId, qty),
  setLineDiscount(productId, value), removeLine(productId),
  setDiscountType(type) [resets line discounts], clear() }`. `CartLine` carries
  the `SaleItem` snapshot fields (productId, sku, name, unitPrice, unitCost,
  quantity, discountValue, unit). `addLine` merges qty if the product is already
  in the cart (mobile behavior).
- **`/pos` page (`PosPage`):** two panes — left: product search (name/SKU via the
  existing `useProducts` stream) + results list (click to add; shows on-hand
  qty); right: the cart (editable qty + per-line discount, remove, a
  discount-type toggle, live subtotal/discount/grand-total), a low-stock warning
  chip per offending line, an `amountReceived` field with computed change, and a
  **Complete sale** button (disabled until the cart is non-empty and
  `amountReceived ≥ grandTotal`).
- **`useCheckout` mutation hook:** assembles the `Omit<Sale,…>` from the cart +
  actor, calls `saleRepo.create`, then `cartStore.clear()` and shows a success
  state (sale number). Errors surface inline (e.g. the size-guard message).
- Wire `/pos` to `PosPage` in `routes.tsx` (replace the placeholder); the
  existing `bagSale`/POS permission guard already covers it (confirm the
  permission key during planning). `/pos/checkout` + `/drafts` stay placeholders
  (later phases).

## 6. Testing & rollout

- **Unit (vitest):** `counterKey`, `formatSaleNumber` (padding, day rollover),
  `cartGrandTotal`/`changeFor`/`cashTenders`, the discount-type-reset behavior in
  the store reducer (pure-testable), low-stock detection.
- **Transaction path:** verified by `tsc -b` + `npm run build` + **manual smoke**
  (web has no Firestore-mock infra) — ring up a cash sale, confirm `sales` doc +
  `items` subcollection + `sale_counters` bump + stock decrement, and that it
  shows in `/reports`.
- **Rollout:** `cd web_admin && npm run build && firebase deploy --only hosting`.
  **No `firestore.rules` change IF** the existing `sales` create rule +
  `settings/sale_counters` write + `products` update already permit an
  admin/staff client write — **confirm `firestore.rules` during planning**; if a
  rule gap exists, that's a flagged production-affecting change (the user must
  approve a rules deploy). No new index expected (Reports already query `sales`).

## 7. Out of scope (later phases)

- Non-cash tenders / gcash / maya / salmon / mixed (Phase 2).
- Labor lines + mechanic (Phase 3).
- Drafts save/resume + `draftId` linkage + draft-mark-converted (Phase 4).
- Receipt print/PDF (Phase 5).
- Void (separate small slice; `voidSale()` stub).
- Barcode scan (no web camera; back-office is keyboard entry).

## 8. Risks

- **`firestore.rules` gap:** the `sales`/`sale_counters` write rules were written
  for the mobile client; if they gate on a field/shape the web omits, the write
  fails in prod. Must read the rules in planning and reconcile (production-
  affecting — confirm before any rules deploy).
- **No web transaction tests:** the atomic write is read-verified + manual-
  smoked, per precedent; the pure helpers (number format, totals, change) ARE
  unit-tested.
- **Negative stock:** warn-but-allow + atomic decrement means stock can go
  negative — intended (parity); surfaced via the existing low-stock UI.
- **Counter contention:** concurrent web+mobile sales on the same day both
  read-increment `sale_counters` in a transaction — Firestore retries on
  conflict, so sequence stays unique (same guarantee mobile relies on).
