# Purchase-order quantity label reads the real unit

**Date:** 2026-08-05
**Surface:** Flutter app (`lib/`) only — the web admin has no purchase-order screens
**Status:** Design approved, ready for planning

## Problem

Four purchase-order displays print the order's total quantity with a hardcoded
`pcs`:

- `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart:223`
- `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart:123`
- `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart:354`
- `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart:384`

All four render the same shape: `3 items · 12 pcs`.

`PurchaseOrderEntity.totalQuantity` is a plain `fold` over every line's
`quantity`, so the number is a bare sum. The `pcs` beside it is a guess.

Units are not free text — they come from a managed list (`CategoryKind.unit`,
the same Lists settings that hold categories), and the shop confirms products
exist today with units other than `pcs`. So a purchase order made up of
set-measured products currently reads `12 pcs`, which is simply wrong.

**Mixed units within one order do not occur** — the shop counts a given product
by piece or by set, never both on one order. The mixed case still needs a
defined behaviour because the data model permits it, but it is a safety net
rather than a feature.

This is a different defect from the two unit labels fixed in
`fix/selling-option-units` (commit `85ed80e`). Those were per-item field
lookups with an obvious substitution. This one is an aggregate with no single
correct unit once lines disagree, which is why it was deliberately left out of
that change.

## Solution

Show the unit the order's lines share; omit it when they don't.

| Case | Renders |
|---|---|
| every line `pcs` | `12 pcs` — unchanged, and this is nearly every order |
| every line `set` | `12 set` — wrong today, correct after |
| lines disagree | `12` — a bare count, never wrong |

A bare number is honest where a guessed unit is misleading, and the line
already says `3 items`, so the shape of the order is still legible.

## Design

### The helper

A pure function in `lib/domain/entities/purchase_order_entity.dart`, beside the
existing `totalQuantity` extension:

```dart
/// The unit every item shares, or null when they differ or there are none.
String? sharedUnitOf(Iterable<String> units);
```

Empty input returns `null`. A single unit returns that unit. Two or more
distinct units return `null`.

### The extension getter

On the existing `List<PurchaseOrderItemEntity>` extension in the same file,
delegating to the helper — mirroring exactly how `totalQuantity` already works
there:

```dart
String? get sharedUnit => sharedUnitOf(map((i) => i.unit));
```

Three of the four sites already hold that list, so they use this directly.

### The drafting screen

`new_purchase_order_screen.dart` holds `List<_Line>`, not
`List<PurchaseOrderItemEntity>`. `_Line` carries a full `ProductEntity`, so the
unit is reachable: it calls the pure function with
`checked.map((l) => l.product.unit)`.

### Display

All four sites render `<total> <unit>` when a shared unit exists, and `<total>`
alone when it does not. No trailing space in the bare case.

### The unit string is used exactly as stored

No pluralising, no special-casing. This matches `SaleItemEntity.optionSetsCaption`,
fixed the same week in `85ed80e`, which also reads its `unit` field verbatim.
If the Lists entry says `set` and the shop would rather see `sets`, that is an
edit in Lists settings, not a code change — one rule, one place to change it.

Note this deliberately differs from `sellingOptionRateSuffix`, which maps
`pcs` → `pc`. That helper is for a **rate** (`₱110.00/pc`), which wants the
singular. This is a **quantity** (`12 pcs`), which wants the plural. Do not
route this through that helper.

## Non-goals

- **A breakdown for mixed orders** (`6 pcs + 2 box`). More code, and a real
  overflow risk — the list line is `maxLines: 1` and elides — for a case the
  shop says does not occur.
- **Pluralising unit strings in code.** The Lists entry is the source of truth.
- **Touching `totalQuantity` itself.** The sum is correct; only its label is wrong.
- **The web admin.** It has no purchase-order screens.

## Testing

TDD: failing test first.

**`sharedUnitOf`** — empty input yields null; one unit yields it; two distinct
units yield null; several items all sharing a unit yield it. Use a non-`pcs`
unit in the positive cases: a test using `pcs` cannot distinguish the helper
from the hardcoded string it replaces.

**The extension getter** — a list of `PurchaseOrderItemEntity` sharing a unit
yields it; a mixed list yields null.

**The display sites** — cover all four. Each asserts that a set-measured order
renders `12 set` and a mixed order renders `12` with no trailing unit.

They reach the unit by three different routes, so none of the three can be
inferred from another:

| Site | Route to the unit |
|---|---|
| `purchase_orders_screen.dart:223` | `order.items.sharedUnit` — off the entity |
| `purchase_order_detail_screen.dart:123` and `:354` | `items.sharedUnit` — off a local list that may be `_pending` rather than `po.items` |
| `new_purchase_order_screen.dart:384` | `sharedUnitOf(checked.map((l) => l.product.unit))` — the pure function, off drafting `_Line`s |

The detail screen's two sites share a route, so one may cover both provided the
other is still asserted to render the same string.

**Commands:** `flutter test`, `flutter analyze`.
