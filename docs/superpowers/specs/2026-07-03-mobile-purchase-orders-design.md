# Mobile Purchase Orders — Design

**Date:** 2026-07-03
**Status:** Approved
**Surface:** Flutter mobile app (`lib/`). Web admin is untouched.

## Problem

Mobile has no way to plan purchases. The web admin has a velocity-based reorder
page (`web_admin/src/domain/reorder/computeReorderSuggestions.ts`), but on
mobile the only inbound-stock tool is Receiving, which records purchases after
the fact. The shop wants to draft what to buy — driven by inventory levels and
the last 60 days of stock movement — and have that draft flow into Receiving
when the delivery arrives.

## Decision summary

Dedicated `purchase_orders` Firestore collection with a real lifecycle
(Approach B; chosen over reusing receiving drafts). Key user decisions:

| Decision | Choice |
|---|---|
| Access | Staff + admin (same gate as Receiving) |
| Multi-supplier drafting | One PO per supplier |
| Suggestion parameters | Window preset 30/60/90 days (default 60) AND cover days (default 30), both adjustable |
| Beyond suggestions | Search-to-add any inventory product |
| Sharing | CSV via system share; SKU/Name/Qty/Unit only, no costs |
| Partial deliveries | Not supported — one delivery per PO (approved assumption) |

## Data model

New shared collection `purchase_orders/{poId}`, modeled after receivings
(entity + data model + converter in the same layered style):

- `referenceNumber` — `PO-YYYYMMDD-NNN`, generated like receiving reference numbers
- `supplierId`, `supplierName` — optional; one supplier per PO
- `items[]` embedded: `id, productId, sku, name, quantity` (ordered qty),
  `unit, unitCost` (expected cost, prefilled from the product), `costCode`
- `totalCost`, `totalQuantity` — recalculated from items
- `status` — `draft | ordered | received | cancelled`
- `notes`
- `createdAt`, `createdBy`, `createdByName`
- `orderedAt`, `receivedAt`, `receivingId` (link to the fulfilling receiving)

### Lifecycle

```
draft ⇄ ordered → received
  \        \
   → cancelled
```

- **draft** — fully editable (items, quantities, supplier, notes).
- **ordered** — items locked; stamps `orderedAt`. Can revert to draft for edits.
- **received** — terminal; set atomically when the linked receiving completes.
- **cancelled** — terminal; allowed from draft or ordered.
- **Receive** is available on `ordered` POs only.

No partial fulfillment: if the supplier shorts an order, actual quantities are
corrected on the receiving before completion and the PO still closes as
`received`. Missing items go on a new PO. The ordered-vs-received audit trail
is the diff between the PO's items and the linked receiving's items.

## Suggestion engine

Pure function in `lib/core/utils/reorder_suggestions.dart`, a Dart port of the
web formula:

```
velocity  = unitsSold(window) / windowDays
target    = ceil(velocity × coverDays)
suggested = max(0, target − currentStock)
```

- Active products only; rows with `suggested <= 0` excluded.
- Grouped by supplier name, no-supplier group last; qty desc within a group.
- Units sold: `getSalesByDateRange(status: completed, limit: 10000)` aggregated
  per `productId` — the same pattern `getTopSellingProducts` already uses.
  No new query or Firestore index.

## Screens & flow

Entry: a **Purchase Orders** tile on the Receiving dashboard.

### `/receiving/purchase-orders` — list
Status filter chips (Draft / Ordered / Received / Cancelled), newest first.
Client-side filtering at shop volume — no composite index. FAB → new PO.

### `/receiving/purchase-orders/new` — suggestions
- Window preset chips 30/60/90 (default 60) + cover-days field (default 30).
- Suggestion rows grouped by supplier: name/SKU, current stock, velocity
  (units/day), editable suggested qty, checkbox (checked by default).
- Search-to-add row: pull in any inventory product with a manual quantity.
- **Save** creates one draft PO per supplier that has selected items
  (no-supplier items form their own PO).

### `/receiving/purchase-orders/:id` — detail
Items list; quantities editable while draft. Actions:
- **Share CSV** (draft and ordered)
- **Mark ordered** / **Back to draft**
- **Receive** (ordered only)
- **Cancel** (draft or ordered); **Delete** admin-only (any status)

Styling follows the existing AppCard / app_colors / app_shadows token system.

## Receiving integration

`ReceivingEntity` gains an optional `purchaseOrderId` field (model + converter).

**Receive** on an ordered PO:
1. Creates a receiving **draft** prefilled from the PO items (qty, unitCost,
   costCode), with `purchaseOrderId` set; stamps `receivingId` on the PO.
2. Navigates to the existing Bulk Receiving screen (`/receiving/bulk/:id`)
   where actual arrived quantities/costs are adjusted as usual.
3. `completeReceiving`'s existing transaction additionally marks the PO
   `received` (+ `receivedAt`) when the receiving carries a `purchaseOrderId`
   — atomic, no best-effort race.

Guards:
- If the PO already has a linked draft receiving, **Receive** navigates to it
  instead of creating a second one.
- Cancelling or deleting the linked receiving clears the PO's `receivingId`
  so it can be received again.
- Receivings without `purchaseOrderId` behave exactly as today (covered by
  tests — this touches the shared `completeReceiving` write path).

## Routes, permissions, rules

- Route guards: `/receiving/purchase-orders`, `/new`, and the dynamic `/:id`
  all gated by `Permission.accessReceiving` (staff + admin). Delete action
  additionally admin-only in UI and rules.
- `firestore.rules`: new `purchase_orders` block identical to `receivings` —
  staff/admin read/create/update, admin delete, `isActiveUser()` required.
- **Rules deploy is production-affecting: confirm with the user before
  deploying.** Until rules are deployed the feature cannot write; old APKs
  simply don't show the feature. Web admin never touches this collection, so
  there is no cross-surface risk.

## CSV share

`buildPurchaseOrderCsv` in the style of `report_csv.dart`, shared through the
existing `saveReportCsv` helper (`lib/core/utils/report_export.dart`).

- Header block: PO reference, supplier, date.
- Columns: `SKU, Name, Qty, Unit`. No costs.
- Filename: `PO-20260703-001.csv` (the reference number).

## Error handling

- Sales fetch capped at 10,000; if the cap is hit, the suggestions screen shows
  a "movement data may be incomplete" note instead of silently under-suggesting.
- Save / Mark ordered / Receive use the existing `runWithWaiting` dialog and
  double-submit button-lock patterns.
- Receive is idempotent per the linked-receiving guard above.

## Testing (TDD)

- Pure suggestion math: port the web test cases (`computeReorderSuggestions.test.ts`)
  plus grouping/exclusion edges.
- Entity/model ↔ Firestore round-trip tests.
- Repository tests with fake Firestore: create, update, status transitions,
  reference-number generation, receive-link guards.
- `completeReceiving` transaction: marks linked PO received; unchanged when no
  `purchaseOrderId`.
- Provider and widget tests mirroring existing receiving screen tests.
- Done = `flutter analyze` clean + `flutter test` green.

## Out of scope

- Partial deliveries / multiple receivings per PO.
- PDF export (CSV only).
- Web admin changes (its reorder page stays read-only suggestions).
- Lead-time or seasonality in the suggestion math (velocity-only, matching web).
