# PO Quantity Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the four purchase-order quantity displays show the unit the order's lines actually share, instead of a hardcoded `pcs`.

**Architecture:** Two pure functions and one extension getter, all in `lib/domain/entities/purchase_order_entity.dart` beside the existing `totalQuantity` extension. `sharedUnitOf` reduces a list of unit strings to the one they all share, or null. `poQuantityLabel` renders the total with that unit, or bare. Four display sites call them. No new files, no schema change, no web work.

**Tech Stack:** Flutter, Dart. `flutter test`, `flutter analyze`.

**Spec:** `docs/superpowers/specs/2026-08-05-po-unit-label-design.md`

## Global Constraints

- **Flutter only.** The web admin has no purchase-order screens. Do not touch `web_admin/`.
- **The unit string is used exactly as stored** — no pluralising, no special-casing, no mapping table. If the Lists entry says `set`, the display says `set`.
- **Do NOT route this through `sellingOptionRateSuffix`** (`lib/core/utils/selling_options.dart:16`, which maps `pcs` → `pc`). That helper is for a **rate** (`₱110.00/pc`) and wants the singular. This is a **quantity** (`12 pcs`) and wants the plural. Using it here would render `12 pc`, which is wrong.
- `PurchaseOrderEntity.totalQuantity` and the `totalQuantity` extension are **correct and must not change**. Only the label beside the number is wrong.
- Every purchase order whose lines are all `pcs` — nearly all of them — must render byte-identically to today.
- Mixed-unit orders do not occur in practice per the shop, but the data model permits them; the mixed branch is a safety net and must still be implemented and tested.
- Checks before each commit: `flutter test` (full suite) and `flutter analyze` (no issues).
- Branch `fix/po-unit-label` is already checked out and holds the spec commit. Stay on it. Do not push.

## File Structure

| Path | Responsibility |
|---|---|
| `lib/domain/entities/purchase_order_entity.dart` | *(modify)* add `sharedUnitOf`, `poQuantityLabel`, and a `sharedUnit` getter on the existing `PurchaseOrderItemsTotals` extension |
| `test/domain/entities/purchase_order_entity_test.dart` | *(modify)* unit tests for all three |
| `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart` | *(modify)* line 223 — the PO list row |
| `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart` | *(modify)* lines 123 and 354 — header trailing and footer |
| `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` | *(modify)* line 384 — the drafting summary |
| `test/presentation/mobile/screens/receiving/purchase_orders/*.dart` | *(modify)* the three existing screen test files |

---

### Task 1: The domain helpers

**Files:**
- Modify: `lib/domain/entities/purchase_order_entity.dart:194-200`
- Test: `test/domain/entities/purchase_order_entity_test.dart`

**Interfaces:**
- Produces, all top-level in `purchase_order_entity.dart`:
  - `String? sharedUnitOf(Iterable<String> units)` — the unit every entry shares; `null` when they differ, when the iterable is empty, or when any entry is blank.
  - `String poQuantityLabel(int total, String? unit)` — `'12 pcs'` when `unit` is non-null, `'12'` when null. No trailing space.
  - `String? get sharedUnit` on the existing `extension PurchaseOrderItemsTotals on List<PurchaseOrderItemEntity>`.

- [ ] **Step 1: Write the failing test**

Add to `test/domain/entities/purchase_order_entity_test.dart`. Note the existing `item()` builder in that file hardcodes `unit: 'pcs'` — widen it with a `unit` parameter rather than writing a second builder:

```dart
  // Widen the existing builder — add this parameter and pass it through:
  //   PurchaseOrderItemEntity item({String id = 'p1', int qty = 2,
  //       double cost = 50, String unit = 'pcs'}) => PurchaseOrderItemEntity(
  //     ... unit: unit, ...);

  group('sharedUnitOf', () {
    test('returns null for no units at all', () {
      expect(sharedUnitOf(const <String>[]), isNull);
    });

    test('returns the only unit when there is one', () {
      expect(sharedUnitOf(const ['set']), 'set');
    });

    test('returns the shared unit when every entry agrees', () {
      expect(sharedUnitOf(const ['set', 'set', 'set']), 'set');
    });

    test('returns null when entries disagree', () {
      expect(sharedUnitOf(const ['pcs', 'set']), isNull);
    });

    test('returns null when a later entry disagrees', () {
      expect(sharedUnitOf(const ['set', 'set', 'box']), isNull);
    });

    test('trims surrounding whitespace before comparing', () {
      expect(sharedUnitOf(const ['set', ' set ']), 'set');
    });

    test('returns null when any entry is blank — an unknown unit cannot agree', () {
      expect(sharedUnitOf(const ['set', '']), isNull);
      expect(sharedUnitOf(const ['   ']), isNull);
    });
  });

  group('poQuantityLabel', () {
    test('appends the unit when there is one', () {
      expect(poQuantityLabel(12, 'set'), '12 set');
    });

    test('renders a bare count when there is no shared unit', () {
      expect(poQuantityLabel(12, null), '12');
    });

    test('leaves no trailing space on the bare form', () {
      expect(poQuantityLabel(12, null).endsWith(' '), isFalse);
    });
  });

  group('PurchaseOrderItemsTotals.sharedUnit', () {
    test('returns the unit when every item agrees', () {
      final items = [item(unit: 'set'), item(id: 'p2', unit: 'set')];
      expect(items.sharedUnit, 'set');
    });

    test('returns null when items disagree', () {
      final items = [item(unit: 'pcs'), item(id: 'p2', unit: 'set')];
      expect(items.sharedUnit, isNull);
    });

    test('returns null for an empty list', () {
      expect(<PurchaseOrderItemEntity>[].sharedUnit, isNull);
    });
  });
```

Every positive case uses `'set'`, not `'pcs'`. A test using `'pcs'` cannot tell the new code from the hardcoded string it replaces.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/purchase_order_entity_test.dart`
Expected: FAIL — `sharedUnitOf`, `poQuantityLabel` and `sharedUnit` are undefined.

- [ ] **Step 3: Write minimal implementation**

In `lib/domain/entities/purchase_order_entity.dart`, add above the existing extension:

```dart
/// The unit every entry shares, or null when they differ, the iterable is
/// empty, or any entry is blank.
///
/// A purchase order's total quantity is a bare sum across its lines, so it
/// only has a meaningful unit when every line agrees. A blank entry counts as
/// disagreement: an unknown unit cannot be claimed to match anything.
String? sharedUnitOf(Iterable<String> units) {
  String? shared;
  for (final raw in units) {
    final unit = raw.trim();
    if (unit.isEmpty) return null;
    if (shared == null) {
      shared = unit;
    } else if (shared != unit) {
      return null;
    }
  }
  return shared;
}

/// Renders a PO total with its unit when the lines agree, bare when they
/// don't. One definition so the four display sites can't drift apart.
///
/// Deliberately NOT routed through `sellingOptionRateSuffix`: that maps
/// `pcs` -> `pc` for a per-piece RATE, while this is a QUANTITY and wants
/// the plural. "12 pcs", never "12 pc".
String poQuantityLabel(int total, String? unit) =>
    unit == null ? '$total' : '$total $unit';
```

And add to the existing extension (do not disturb the two members already there):

```dart
extension PurchaseOrderItemsTotals on List<PurchaseOrderItemEntity> {
  int get totalQuantity => fold(0, (sum, item) => sum + item.quantity);
  double get totalCost => fold(0.0, (sum, item) => sum + item.totalCost);

  /// The unit shared by every line, or null when they differ. See
  /// [sharedUnitOf].
  String? get sharedUnit => sharedUnitOf(map((item) => item.unit));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/purchase_order_entity_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/purchase_order_entity.dart test/domain/entities/purchase_order_entity_test.dart
git commit -m "feat(po): shared-unit helpers for the quantity label"
```

---

### Task 2: The four display sites

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart:223`
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart:123`
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart:354`
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart:384`
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart`
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart`
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`

**Interfaces:**
- Consumes from Task 1: `sharedUnitOf(Iterable<String>)`, `poQuantityLabel(int, String?)`, and `List<PurchaseOrderItemEntity>.sharedUnit`.

**The three routes to the unit.** These sites look alike on screen but reach the unit differently, so none can be inferred from another:

| Site | Route |
|---|---|
| `purchase_orders_screen.dart:223` | `order.items.sharedUnit` — off the entity |
| `purchase_order_detail_screen.dart:123`, `:354` | `items.sharedUnit` — off a **local** list that may be `_pending` (staged unsaved edits) rather than `po.items` |
| `new_purchase_order_screen.dart:384` | `sharedUnitOf(checked.map((l) => l.product.unit))` — the pure function, off drafting `_Line`s which hold a `ProductEntity`, not a PO item |

The detail screen's two sites share a route; one test may cover both provided the other is still asserted to render the same string.

**Do not touch** `new_purchase_order_screen.dart`'s `_supplierHeader` (around line 206). It renders a currency subtotal, not a quantity — it has no `pcs` to fix.

- [ ] **Step 1: Write the failing tests**

**The three test files use different harnesses — read each before writing:**

| File | Harness |
|---|---|
| `purchase_orders_screen_test.dart` (108 lines) | Overrides a provider from `purchase_order_provider.dart` with locally-built entities. Its existing builder takes `{double totalCost = 0}` — widen it with per-item units. |
| `purchase_order_detail_screen_test.dart` (195 lines) | Seeds `fake_cloud_firestore` and uses the real `PurchaseOrderRepositoryImpl`. A `set`-unit order must be seeded as **documents**, with `unit: 'set'` on the item maps — building an entity in memory will not reach the screen. |
| `new_purchase_order_screen_test.dart` (380 lines) | Also `fake_cloud_firestore`, and it drafts from products via `reorder_suggestions`. The unit comes from the seeded **product** documents (`_Line` holds a `ProductEntity`), not from PO item docs. |

In each file, add a pair. The shape, using the detail screen as the example — adapt the setup to that file's harness per the table above:

```dart
  testWidgets('shows the shared unit when every line agrees', (tester) async {
    // Build a PO whose items are all unit: 'set', quantity summing to 12.
    await pumpDetail(tester, poWith(units: ['set', 'set'], quantities: [5, 7]));
    expect(find.textContaining('12 set'), findsWidgets);
    expect(find.textContaining('12 pcs'), findsNothing);
  });

  testWidgets('shows a bare count when lines disagree', (tester) async {
    await pumpDetail(tester, poWith(units: ['set', 'pcs'], quantities: [5, 7]));
    expect(find.textContaining('12 pcs'), findsNothing);
    expect(find.textContaining('12 set'), findsNothing);
    expect(find.textContaining('· 12'), findsWidgets);
  });
```

Both halves matter. The first fails against the hardcoded `pcs`. The second fails against any implementation that picks the first line's unit instead of detecting disagreement.

Use `'set'` in every positive case. A test built on `'pcs'` products passes against the old hardcoded string and proves nothing.

If a screen's existing test harness has no PO builder taking per-item units, widen the one that's there rather than adding a parallel builder.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/`
Expected: FAIL — the screens render `12 pcs` in both cases.

- [ ] **Step 3: Write minimal implementation**

`purchase_orders_screen.dart:223` — currently:

```dart
                  '$items ${items == 1 ? 'item' : 'items'} · '
                  '${order.totalQuantity} pcs · by ${order.createdByName}',
```

becomes:

```dart
                  '$items ${items == 1 ? 'item' : 'items'} · '
                  '${poQuantityLabel(order.totalQuantity, order.items.sharedUnit)}'
                  ' · by ${order.createdByName}',
```

`purchase_order_detail_screen.dart:123` — currently:

```dart
                trailing: '${items.length} '
                    '${items.length == 1 ? 'item' : 'items'} · '
                    '$totalQuantity pcs',
```

becomes:

```dart
                trailing: '${items.length} '
                    '${items.length == 1 ? 'item' : 'items'} · '
                    '${poQuantityLabel(totalQuantity, items.sharedUnit)}',
```

`purchase_order_detail_screen.dart:354` — currently:

```dart
                    text: '(${items.length} '
                        '${items.length == 1 ? 'item' : 'items'} · '
                        '$totalQuantity pcs)',
```

becomes:

```dart
                    text: '(${items.length} '
                        '${items.length == 1 ? 'item' : 'items'} · '
                        '${poQuantityLabel(totalQuantity, items.sharedUnit)})',
```

`new_purchase_order_screen.dart:384` — currently:

```dart
                    text: '${checked.length} '
                        '${checked.length == 1 ? 'item' : 'items'} '
                        'checked · $pcs pcs',
```

becomes:

```dart
                    text: '${checked.length} '
                        '${checked.length == 1 ? 'item' : 'items'} '
                        'checked · '
                        '${poQuantityLabel(pcs, sharedUnitOf(checked.map((l) => l.product.unit)))}',
```

The local variable is named `pcs` at that site. Rename it to `totalQty` in the same edit — leaving a variable called `pcs` holding a possibly-non-pcs quantity is exactly the confusion this task exists to remove. Update its declaration and every reference in that method.

Add the import of `purchase_order_entity.dart` to any of the three screen files that doesn't already have it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS across the full suite — the screens' existing tests must still pass, since a `pcs` order renders byte-identically.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/purchase_orders/ test/presentation/mobile/screens/receiving/purchase_orders/
git commit -m "fix(po): show the order's real unit beside its total quantity"
```

---

## Final verification

- [ ] `flutter test` — full suite green
- [ ] `flutter analyze` — no issues
- [ ] Grep for any remaining hardcoded quantity unit in the PO screens: `rg -n "pcs" lib/presentation/mobile/screens/receiving/purchase_orders/` should return nothing, or only matches that are genuinely a default unit rather than a label
- [ ] Confirm a `pcs`-only order renders byte-identically to before the change

## Non-goals

Confirmed in the spec; do not build these:

- A breakdown for mixed orders (`6 pcs + 2 box`) — the list line is `maxLines: 1` and elides
- Pluralising unit strings in code — the Lists entry is the source of truth
- Any change to `totalQuantity` or the `totalCost` extension member
- The web admin — it has no purchase-order screens
