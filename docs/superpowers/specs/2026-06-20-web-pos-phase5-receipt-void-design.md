# Web POS — Phase 5: Receipt + Void — Design

**Date:** 2026-06-20
**Surface:** React web admin (`web_admin/`).
**Status:** Design — approved-in-brainstorm, pending `writing-plans`.
**Epic:** Web POS (full mobile parity, phased). Intent: **remote / back-office
sales**. **This is the FINAL phase of the POS epic.**

**Phase plan:** 1) cart + cash checkout ✅ · 2) tenders ✅ · 3) labor + mechanic
✅ · 4) drafts ✅ · **5) receipt + void (this doc)**.

## 1. Problem & intent

Two independent finishing features, both landing on the existing
`SaleDetailPage` (`/reports/sale/:id`):

1. **Void** — reverse a completed sale: mark it voided **and restore stock**, so
   it drops out of reports and inventory is made whole. `voidSale` is currently
   a stub.
2. **Receipt** — produce a print-friendly receipt for a sale via the browser
   (`window.print()`), works to any printer including thermal.

### What already exists

- **`SaleRepository.voidSale(id, reason, actorId, actorName)`** is in the
  interface but `FirestoreSaleRepository.voidSale()` throws "not implemented yet
  (phase 11)".
- The Sale entity carries `voidedAt / voidedBy / voidedByName / voidReason`, and
  `SaleStatus.voided` exists; `saleIsVoided(sale)` helper exists.
- **`SaleDetailPage`** already renders the full sale breakdown (items, labor,
  totals, tenders, change) and shows a **"Voided"** badge when `voidedAt` is set.
- **`summarizeSales`** already filters out voided sales
  (`completed = sales.filter((s) => !saleIsVoided(s))`), so a void instantly
  removes the sale from all report totals — no reporting change needed.
- **`void_reasons`** is an admin-managed list (`CategoryKind.voidReason`, edited
  in Manage Lists at `/settings/lists`); `useActiveCategories('voidReason')`
  streams the active reasons.
- **`Permission.voidSale`** exists (admin-only) — every web user is an admin.

### Locked decisions (from brainstorming)

| # | Decision |
|---|----------|
| 1 | **Direct admin void** — web is admin-only (`ProtectedRoute`), so there is **no request/approve/notify workflow** (that is mobile-only, for non-admin roles). |
| 2 | **Void gate = reason + confirm dialog**, no password re-entry. The reason is required and chosen from the active `void_reasons` list. |
| 3 | **Void restores stock** — `quantity: increment(+qty)` per item, the exact reverse of the sale-create decrement, inside the void transaction. |
| 4 | **Receipt = browser print** — a styled `Receipt` component + `window.print()`, scoped with Tailwind `print:` variants. No PDF, no new dependency, no route. |
| 5 | **No `firestore.rules` change** — `sales` update is `isAdmin()`; the stock-restore write touches only the 4 product keys (`quantity/updatedAt/updatedBy/updatedByName`) the existing products rule already allows. |
| 6 | Void is **irreversible** (no un-void; `sales` delete is `false` — audit trail). |

## 2. Void

### 2.1 Repository — implement `FirestoreSaleRepository.voidSale`

Signature (unchanged): `voidSale(id: string, reason: string, actorId: string,
actorName: string): Promise<void>`.

1. **Load items** for the sale via the existing private `loadItems(saleId)`
   (the `sales/{id}/items` subcollection) — items are immutable once written, so
   reading them before the transaction is safe.
2. **One `runTransaction`:**
   - `tx.get(saleRef)` → if missing, throw `Sale not found`; if already voided
     (`status === 'voided'` or `voidedAt` present), throw `Sale is already
     voided` (idempotency / concurrent-void guard).
   - `tx.update(saleRef, { status: 'voided', voidedAt: serverTimestamp(),
     voidedBy: actorId, voidedByName: actorName, voidReason: reason,
     updatedAt: serverTimestamp(), updatedBy: actorId })`.
   - **Per item**, `tx.update(products/{productId}, { quantity:
     increment(+quantity), updatedAt: serverTimestamp(), updatedBy: actorId,
     updatedByName: actorName })` — restores the stock the sale removed. (A
     product deleted since the sale would fail the tx; acceptable — surfaced to
     the actor, the void simply doesn't proceed.)

Reads-before-writes holds (the single `tx.get` precedes all writes; item reads
happen before the transaction). Write budget: `1 (sale) + N (stock) = 1 + N`,
well under the 500-write cap for any real sale.

### 2.2 Pure helper — `canVoidSale`

`src/domain/sales/voiding.ts` (TDD): `canVoidSale(sale: Sale): boolean` →
`true` iff the sale is **not** voided and `status === completed`. Gates the
button so a voided (or non-completed) sale shows no Void action.

### 2.3 Mutation + UI

- `useVoidSale()` (`src/presentation/hooks/useVoidSale.ts`) — a TanStack
  mutation wrapping `repo.voidSale(id, reason, actor.id, actorName)`; on success
  it invalidates `['sales', id]` so `SaleDetailPage` re-fetches and re-renders
  Voided.
- On `SaleDetailPage`: a **"Void sale"** button (rendered only when
  `canVoidSale(sale)`), opening a **confirm dialog** (the common `Dialog`) with:
  - a **void-reason `<select>`** from `useActiveCategories('voidReason')`
    (required; the dialog's Void button is disabled until one is chosen);
  - if the active list is empty, a hint linking to `/settings/lists` ("Add void
    reasons in Manage lists") and no selectable reason;
  - Cancel / **Void sale** (destructive styling); disabled while pending; closes
    on success. `voidSale.error` is surfaced in the dialog.

## 3. Receipt

### 3.1 `Receipt` component — `src/presentation/features/reports/Receipt.tsx`

A self-contained, print-formatted block taking `{ sale }`, narrow
(`max-w-[320px]` ~ 80 mm), monospace-ish, reusing the existing money helpers:

- **Header:** a store-name constant (`RECEIPT_STORE_NAME = 'MAKI Mobile POS'` —
  a single const, swappable to a settings value later), then `saleNumber`, the
  formatted date, and `cashier` (+ `mechanic` when present).
- **Lines:** each item as `name` / `qty × unitPrice` → net; each labor line as
  its description → fee.
- **Totals:** Subtotal (`salePartsSubtotal`), Discount (`saleTotalDiscount`),
  Labor (`saleLaborSubtotal`), **Total** (`saleGrandTotal`).
- **Payment:** the per-method tender breakdown (`saleEffectiveTenders` over
  `realTenderMethods`, > 0), Amount received, Change.
- **Voided:** when `saleIsVoided(sale)`, a prominent `*** VOIDED ***` stamp +
  the void reason.
- **Footer:** a thank-you line.

### 3.2 Print wiring

On `SaleDetailPage`:

- Wrap the current on-screen content in a container with `print:hidden`.
- Render `<Receipt sale={sale} />` inside a `hidden print:block` container so it
  exists in the DOM but only shows when printing.
- A **"Print receipt"** button calls `window.print()`.

Tailwind already supports the `print:` variant; no global print stylesheet or
route is needed. (If the two `print:` containers prove fiddly, the fallback is a
body-level `@media print` rule in the existing global CSS — but start with the
variant approach.)

## 4. Validation & edge cases

- **Void requires a reason** — the dialog's confirm is disabled until a reason
  is selected.
- **Already-voided** — guarded in the UI (button hidden via `canVoidSale`) and
  in the repo transaction (throws), covering the concurrent-void race.
- **Irreversible** — no un-void; matches `sales` delete:false.
- **Product deleted since the sale** — the restock `tx.update` fails the
  transaction; the void doesn't proceed and the error surfaces. Rare; acceptable.
- **Receipt of a voided sale** — prints with the VOIDED stamp.
- Voiding a sale that originated from a draft does not touch the draft (the
  draft is already `isConverted`); out of scope to revert.

## 5. Testing

- **`voiding.test.ts`** — `canVoidSale`: completed-not-voided → true; voided →
  false; non-completed → false.
- **`voidSale` (atomic write + stock restore)** and the **`Receipt` rendering /
  print** are verified by **manual browser smoke** — the repo is Firestore
  (untested like `create()`, which was smoke-verified) and the receipt is
  presentational.
- **Manual browser smoke:** complete a sale → open Sale Detail → **Void sale**
  (pick a reason) → the sale shows Voided, drops out of Reports totals, and the
  product's stock went **back up** by the sold quantity; **Print receipt** opens
  the browser print dialog showing a clean receipt (and a VOIDED stamp for the
  voided one).

`npm run typecheck && npm run test` green before done.

## 6. Implementation sequencing

One spec, planned in two ordered slices:

- **5a — Void:** `canVoidSale` (+test), `FirestoreSaleRepository.voidSale`,
  `useVoidSale`, the Void button + reason dialog on `SaleDetailPage`.
- **5b — Receipt:** the `Receipt` component + the `print:` wrapping + the Print
  button on `SaleDetailPage`.

## 7. Out of scope

- The mobile void **request/approve/notify** workflow (web is admin-only).
- PDF or emailed receipts; a reprint counter.
- Wiring a configurable store-info setting into the receipt header (constant for
  now).
- Un-void / void reversal.
- Any change to reports (voids already excluded by `summarizeSales`).
