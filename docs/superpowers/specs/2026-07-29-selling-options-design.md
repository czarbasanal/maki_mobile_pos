# Selling options (sell by set, half set, or piece)

**Date:** 2026-07-29
**Surfaces:** Flutter app (`lib/`) + web admin (`web_admin/`)
**Status:** Design approved, ready for planning

## Problem

Some products arrive packed by set but are sold in more than one size. A pulley
ball is packed by 6; the shop sells it by 6 or by 3 depending on what the
customer needs. Today a product has exactly one price for one unit, so there is
no way to say "a set of 3 costs ₱330" — the cashier has to ring 3 pieces at the
single-piece price and lose the set pricing, or the shop has to create a second
product and split the stock.

## Solution in one line

A product may carry an optional, ordered list of **selling options** (label,
piece count, set price). Stock stays a single piece count. When a product has
options, the POS requires the cashier to pick one.

This is separate from, and stacks with, the existing cost **variation**
mechanism (`ABC-1`, `ABC-2`), which creates distinct product docs when the same
item is received at a different cost. Selling options never create a product
doc and never split stock.

## Decisions

| Question | Decision |
|---|---|
| What does stock count? | Pieces. One shared pool per product. Receiving 2 packs of 6 is +12. |
| Can a cashier sell at the base price when options exist? | No. Options fully define how the item may be sold. A "By 1" option must be added explicitly if singles are allowed. |
| Where does the picker appear? | POS (mobile + web) and Job Orders (mobile + web). Not Receiving or Purchase Orders. |
| Where are options authored? | Product form on both web and mobile. Admin only. |
| What does a sale line store? | `quantity` in **pieces**, unchanged in meaning, plus an option snapshot for display and audit. |

### Why the sale line stays in pieces

Every report sums `item.quantity` and treats it as pieces —
`topSellingProducts`, the profit report, the reorder engine, Avg Daily, the CSV
export, stock deduction, and both receipt renderers. Keeping `quantity` in
pieces means all of that stays correct with no changes. The alternative
(`quantity` = number of sets) would require finding and rewriting roughly twenty
call sites across both surfaces, and a missed one silently undercounts a report
— the same failure shape as the Avg Daily bug.

The cost is a cosmetic one: the derived per-piece `unitPrice` can be a repeating
decimal (a set of 3 at ₱100 stores ₱33.3333…). That number is never shown —
receipts and cart tiles display the set price the user typed — and the resulting
drift is under a hundredth of a centavo per line.

## Data model

### `SellingOption` (new value object, mirrored Dart + TS)

| field | type | rules |
|---|---|---|
| `id` | `String` | stable, client-generated at creation, never reused |
| `label` | `String` | trimmed, non-empty, ≤ 24 chars, unique within the product (case-insensitive) |
| `pieces` | `int` | ≥ 1 |
| `price` | `double` | > 0; the price of the **whole** set |

Array order is display order. Maximum 10 options per product.

### `ProductEntity` / `Product`

Gains `sellingOptions: List<SellingOption>`, defaulting to `[]`. Stored on the
product doc as an array of maps under `sellingOptions`. A missing field reads as
`[]`, so all ~1,240 existing products keep behaving exactly as they do now.

The product's existing `price` is untouched and stays required. It remains the
per-piece figure used by inventory valuation (`inventoryValueAtPrice`,
`potentialProfit`) and by the reorder engine. It simply stops being directly
sellable once options exist. The product form must label it so this is obvious.

### `SaleItemEntity` / `SaleItem`

Gains four optional fields, all `null` when no option was used:

- `optionId: String?`
- `optionLabel: String?` — e.g. `By 3`
- `optionPieces: int?` — e.g. `3`
- `optionPrice: double?` — e.g. `330.00`, the price of one set

`quantity` continues to mean pieces. Selling one "By 3" writes
`quantity: 3, unitPrice: 110.0, optionPieces: 3, optionPrice: 330.0`. Selling
two writes `quantity: 6`; the tile derives sets as `quantity / optionPieces`.

`unitPrice` is derived as `optionPrice / optionPieces` at full double precision
with no rounding at storage time.

These are snapshots, following the existing `sku`/`name`/`unitPrice` pattern:
editing or deleting an option later never rewrites past receipts.

Job-order lines use the same `SaleItem` shape and inherit this automatically.

## Behaviour at the till

**Product without options** — unchanged. Tapping adds 1 piece at the base price.

**Product with options** — a picker sheet opens listing each option with its
label, piece count, set price, and a per-piece caption:

```
Pulley Ball                    12 pcs on hand
──────────────────────────────────────────────
By 6        6 pcs                     ₱600.00
                                  ₱100.00/pc
By 3        3 pcs                     ₱330.00
                                  ₱110.00/pc
```

The per-piece caption exists so a mis-typed option price is visible at the point
of sale. It uses the product's own `unit` string, so an item whose unit is not
`pcs` reads correctly.

**Existing tickets and drafts are unaffected.** Job-order and cart lines carry
their own snapshot, so a draft written before options existed keeps its base
price, and a draft that used an option keeps that option's price even if the
option is later edited or removed. Resuming a draft never re-opens the picker.

Rules:

1. **The picker always opens**, even when a product has exactly one option — it
   is the only place the set price is shown before committing.
2. **Barcode scan opens the picker too.** Otherwise the scanner becomes a back
   door around the "must pick an option" rule.
3. **The cart merges by `(productId, optionId)`**, not by `productId` alone.
   This is a change: `CartNotifier.addProduct` (mobile) and `cartStore` (web)
   currently merge on product identity, which would fold a By 6 and a By 3 of
   the same item into one line and silently lose one of the prices. Lines with
   no option merge on `productId` as today.
4. **Increment and decrement step by `optionPieces`.** Tapping `+` on a By 3
   line goes 3 → 6. Decrementing below `optionPieces` removes the line.
5. **Any direct quantity entry on an option line is in sets**, and is stored as
   `sets × optionPieces`.
6. **Short stock warns, it does not block.** This matches today's POS, where
   `lowStockLines` flags an over-sell rather than preventing it. An option
   needing 6 pieces with 4 on hand stays selectable and carries the existing
   low-stock flag. No new hard stop is introduced.
7. **Cancelling the picker adds nothing to the cart.**

Cart tiles and receipts render `Pulley Ball · By 3` with the set price. When
more than one set is on the line, the tile reads `By 3 × 2 (6 pcs)`.

## Authoring

The product form on both surfaces gains a **Selling options** section, visible
and editable to admins only. Rows can be added and removed; each row takes
label, pieces and price, and shows the derived per-piece price and the margin
against unit cost as a caption.

Validation (shared domain function, mirrored Dart + TS):

- label non-empty after trimming, ≤ 24 chars, unique within the product,
  case-insensitively
- `pieces` ≥ 1
- `price` > 0
- at most 10 options

### Permissions

Selling options set prices, so they must be locked exactly as `price` is:
admin-only.

**`firestore.rules`** — add `sellingOptions` to the denylist on both the staff
update rule and the cashier update rule under `match /products/{productId}`.

**Client update maps must omit `sellingOptions` for non-admin writers.** This is
load-bearing, not defensive. `ProductModel.toUpdateMap` calls
`toMap(forUpdate: true)`, which writes every product field; the web
`productWrites.ts` does the same. If `sellingOptions` were always written, a
staff or cashier edit to a product doc that lacks the field would add it, that
addition would land in `diff().affectedKeys()`, and the new denylist entry would
reject an edit the user was entitled to make. Omitting the key for non-admins
keeps it out of the diff entirely and needs no production backfill. The existing
cashier-rule comment documents this exact hazard for nullable fields.

## Price history

Price history is a `price_history` subcollection on each product, one doc per
change (`price`, `cost`, `changedAt`, `changedBy`, `reason`, `note`), read by
the product-detail sparkline and by the admin cross-product price-change report.
Both derive "what changed" by subtracting each entry from the previous one.

With options, "the price" is no longer a single number, and an option price
change would today be recorded nowhere while a base price change is recorded —
a hole in the audit trail the report was built to close.

### Schema

`price_history` docs gain three optional fields: `optionId`, `optionLabel`,
`optionPieces`. Absent means "base price", which is every existing doc, so no
backfill is required.

### What gets logged

| Event | Entry |
|---|---|
| Option price edited | set price + set cost (`pieces × unit cost`), reason `Price update`, with the option fields |
| Option added | as above, reason `Option added` |
| Option removed | last known set price and cost, reason `Option removed` |
| Option piece count changed | new price and pieces, reason `Option changed` |
| Base price/cost edited | unchanged from today; option fields absent |

Set cost is stored rather than unit cost so the margin column on the report
stays meaningful against the set price. Reason literals must be identical in
Dart and TS — `derivePriceHistorySource` maps them to the report's Source
column, and the two surfaces already mirror these strings.

`optionPieces` is stored so that a By 3 → By 4 change reads as a bigger set
rather than a price hike.

### Series separation — the load-bearing part

`buildPriceHistoryRows` computes `entry.price - prior.price` over a single
ordered stream, and the sparkline plots that same stream. If option entries land
in it, the chart zigzags between the ₱120 base and the ₱600 By-6 price and every
delta beside it is meaningless.

Entries must therefore be split into series — Base, By 6, By 3 — **before** the
delta math runs:

- **Product detail (both surfaces):** a series selector; the sparkline and the
  history list show the selected series, each with its own deltas.
- **Cross-product price-change report (web):** an Option column, blank for base
  rows, with deltas computed within each `(productId, optionId)` group.

### Deliberate omission

A receiving that changes unit cost still logs a **single base entry**, as today
— not one entry per option. Option cost is always `pieces × unit cost` and is
therefore reconstructible. Logging per option would write five history docs per
receiving on a four-option product.

## Reports

No report changes. Every existing rollup keeps working because `quantity` still
means pieces. A "sold by option" breakdown is possible later from the stored
`optionId` but is out of scope here.

## Migration

None. No backfill, no new Firestore index. The only production-affecting change
is the `firestore.rules` denylist addition, which must be confirmed before
deploying per `CLAUDE.md`.

## Non-goals

- Reusable option templates shared across products (options are typed per
  product; revisit if that proves painful at volume)
- Options in Receiving or Purchase Orders — piece counts are typed directly
- Per-option stock counts
- A "sold by option" analytics report
- Options on labor lines or shop fees

## Testing

TDD throughout: failing test first, mirrored on both surfaces where the logic is
mirrored.

**Domain**
- `SellingOption` validation: empty/long/duplicate labels, `pieces < 1`,
  `price <= 0`, the 10-option cap
- `unitPrice` derivation from `optionPrice / optionPieces`, including a
  non-terminating case (₱100 over 3 pieces) asserting the line total rounds to
  ₱100.00 at display precision
- Cart merge by `(productId, optionId)`: same product + same option merges,
  same product + different option stays two lines, no-option lines merge on
  product as before
- Increment/decrement stepping by `optionPieces`, and removal when stepping
  below one set
- Sale-line snapshot survives a later edit or deletion of the source option

**Price history**
- Series splitting: base and option entries produce independent delta streams
- Reason selection for each of the five events in the table above
- Receiving a cost change writes exactly one entry regardless of option count

**Converters**
- `Product` round-trip with options, with an empty list, and with the field
  absent
- `SaleItem` round-trip with and without option fields
- `price_history` round-trip with and without option fields

**Rules** (`tools/firestore-rules-test`)
- Admin may write `sellingOptions`
- Staff and cashier are denied when `sellingOptions` is in the diff
- Staff and cashier may still edit their permitted fields on a product doc that
  has no `sellingOptions` field, proving the client-side omission holds

**Commands** — `flutter test` and `flutter analyze` for the app;
`npm run typecheck`, `npm run test` and `npm run build` in `web_admin/`.
