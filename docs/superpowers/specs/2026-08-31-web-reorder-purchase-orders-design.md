# Web reorder page + purchase orders as a buying list

**Date:** 2026-08-31
**Status:** approved design, pending implementation plan
**Surface:** web admin only (`web_admin/`). Mobile is untouched.

## Why

Two gaps sit on opposite sides of the same workflow.

The web reorder page (`/inventory/reorder`) can show velocity-based suggestions and export a
CSV — and nothing else. Web has no purchase-order feature at all, so a list of what to buy is a
dead end.

Worse, the reorder engine has a blind spot that costs real money: it excludes any product with
**zero velocity**.

```ts
const velocityPerDay = (unitsSold.get(product.id) ?? 0) / params.windowDays;
const suggestedQty   = Math.max(0, Math.ceil(velocityPerDay * coverDays) - product.quantity);
if (suggestedQty <= 0) continue;      // ← a sold-out part is invisible here
```

A part that sold out early in the window has no sales left to measure, so the engine hides it
precisely when it is most urgently needed.

Separately, every product carries a `reorderLevel` that the shop maintains by hand and **neither
engine reads** — mobile's `reorder_suggestions.dart` and web's `computeReorderSuggestions.ts`
both ignore it. Two unconnected answers to "does this need ordering".

## The workflow this serves

> "We just list all items in one PO regardless of supplier, then we manually decide where to
> purchase each item depending on our route."

A purchase order here is **a buying list for one trip**, not a supplier order. Supplier is decided
on the road, per item, in whatever order the route takes. This is the fact that drives every
decision below.

## Decisions

| Question | Decision |
|---|---|
| Do out-of-stock parts appear regardless of sales? | Yes — always, ahead of the suggestions |
| Default quantity for a part with no velocity | Its `reorderLevel`, falling back to 1 |
| Select-all control | Checkbox in the header cell of the checkbox column; tri-state |
| Extra column | "Bought last" — qty + date of the most recent completed receiving |
| What Confirm produces | **One** purchase order, no supplier, all ticked parts |
| Where supplier is recorded | On each PO **line**, set while buying |
| PO actions | Save as draft · Confirm PO |
| PO log tabs | Pending · Completed · Cancelled |
| Receiving | **Unchanged.** Out of scope. |

## Design

### 1. Reorder page

One table, supplier headings used for **scanning only** — they group who normally stocks what and
no longer decide anything.

```
☑/–  Part                     On hand   Bought last   Qty   Cost      Amount
     ── Out of stock (3) ──
 ☑   Oil filter, Mio               0     6 · Jul 28   [ 4]  ₱95.00    ₱380.00
     ── Suggested · Maxxis (2) ──
 ☑   Tire TL MAV6 90/90-14         1     8 · Aug 03   [ 6]  ₱670.00   ₱4,020.00
                                        5 of 6 parts · 21 units · ₱8,630.00
                                        [ Save as draft ]  [ Confirm PO ]
```

- **Out-of-stock section first**, `quantity <= 0`, active products only, regardless of velocity.
  A part can appear here *and* have a velocity suggestion; out-of-stock wins and it is listed once.
- **Header checkbox is tri-state**: checked → all, unchecked → none, dash → some.
- **Bought last** = quantity and date from the most recent **completed** receiving containing that
  product. "never" when there is none — never a `0`, which would read as a real figure.
- **Amount** = qty × cost. The footer totals only ticked rows.
- Quantities stay editable per row (the page already supports overrides).

Gated on `Permission.viewProductCost` as today — the page shows cost.

### 2. Purchase order = supplier-less buying list

The existing model already permits this and needs no migration:

- `PurchaseOrder.supplierId` / `supplierName` are **nullable** → left null.
- `PurchaseOrderItem` gains **optional** `supplierId` / `supplierName`, set while buying. Purely
  additive: no existing code reads it, so mobile is unaffected.
- The item's doc comment already frames cost as provisional — *"expected cost, prefilled from the
  product; the real cost is set on the receiving at delivery time."*

**Statuses map onto what exists.** No new status values.

| Tab | Status | Meaning |
|---|---|---|
| Pending | `draft`, `ordered` | still building the list · out buying |
| Completed | `received` | everything came back |
| Cancelled | `cancelled` | trip called off; kept, not deleted |

`Save as draft` → `draft`. `Confirm PO` → `ordered`.

### 3. Reference numbers — must be fixed, not inherited

`generateReferenceNumber()` counts today's documents and adds one, the same pattern as receivings.
Two clients creating a PO in the same moment get the same number. Web must not copy it.

Use a counter document under `settings/`, allocated in a transaction, the way sale numbers already
are. Mobile keeps its current implementation for now; the collision it has today is pre-existing and
out of scope here, but the two must not disagree about format: `PO-YYYYMMDD-NNN`.

### 4. Routing

Per the standing gotcha, a new gated web route needs **three** edits: `routePaths.ts`,
`routes.tsx`, `routeGuards.ts`.

- `/purchase-orders` — the log, three tabs
- `/purchase-orders/:id` — one list, with the per-line supplier picker

Gated on `Permission.accessReceiving` (buying is the receiving side of the business), to be
confirmed against `RolePermissions` when planning.

## Out of scope

**Receiving is not touched.** Mobile's "receive this PO" copies the order's single supplier onto one
receiving draft containing every item. On a supplier-less list that yields one receiving with no
supplier and everything in it — wrong for a route where goods arrive from several places on
different days. Stock continues to enter through the normal receiving flow.

Worth revisiting later: because each line now records where it was *actually* bought, receiving a
completed list could split into one receiving draft **per supplier**. Only worth building once the
list has earned its place.

## Testing

- Engine: an out-of-stock, zero-velocity product is suggested at its `reorderLevel`; at
  `reorderLevel` 0 it defaults to 1; an inactive product never appears; a part that is both
  out of stock and velocity-suggested appears once, in the out-of-stock section.
- Selection: header checkbox drives all/none; goes to dash when partially selected; totals count
  only ticked rows and follow quantity edits.
- Bought last: reads the most recent **completed** receiving only; drafts are ignored; a product
  never received renders "never", never "0".
- PO write: Confirm produces exactly one document, `supplierId` null, every ticked line present,
  status `ordered`; Save as draft writes the same with status `draft`.
- Reference numbers: two allocations in the same transaction window do not collide.
- Log: each tab shows only its statuses; cancelled are listed, not hidden.
- Per-line supplier: setting one writes only that line and leaves the PO's own supplier null.

## Rollout

Additive throughout. **No `firestore.rules` change** — `purchase_orders` already allows staff and
admin to read, create and update. No migration: the new per-line supplier field is optional and
absent on existing documents.

Order: reorder page → PO write + log → per-line supplier picker. The first is useful on its own
with the existing CSV export still in place.
