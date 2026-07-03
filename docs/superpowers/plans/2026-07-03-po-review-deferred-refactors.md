# PO Deferred Review Refactors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three deferred PO-redesign review findings: move+tokenize the segmented control, extract one shared add-products sheet for PO + Job Orders, and split `coverDays` out of the reorder-suggestions fetch so cover stepping is instant.

**Architecture:** Three independent refactors on one branch, ordered lowest-risk first: (c) a pure widget move with a new color token, (b) a widget extraction replacing two near-identical private sheets, (a) a provider split — `reorderMovementProvider(windowDays)` owns the sales fetch, `reorderSuggestionsProvider` keeps its public shape but becomes a synchronous derivation, and the screen's debounce machinery is deleted.

**Tech Stack:** Flutter (root app), Riverpod, `fake_cloud_firestore` widget tests. All commands run from the repo root. Spec: `docs/superpowers/specs/2026-07-03-po-review-deferred-refactors-design.md`. Branch: `refactor/po-review-deferred` (already checked out).

## Global Constraints

- **Zero visual change** anywhere except cover stepping losing its spinner. Both sheets' approved copy ('Add parts' / 'Add products', 'N added this session', tooltip 'Close', 'Done') is byte-preserved.
- Test keys (`po-window-*`, `po-view-*`, `po-check-*`, `po-cover-*`, `po-create-button`) must not change.
- No Firestore write path, rules, or entity schema changes; `reorderSalesCap` (10000) and the fetch semantics stay identical.
- `reorderSuggestionsProvider` keeps its name, `ReorderParams` family key, and `AsyncValue<ReorderResult>` watch result.
- Gate per task: named `flutter test` targets green; final task adds `flutter analyze` + full `flutter test`.
- Commit after every task; do not push.

---

### Task 1: PoSegmentedCells — move to po_widgets.dart + segmentedSelectedWash token

**Files:**
- Modify: `lib/core/theme/app_colors.dart` (after the `amberNoteIcon` block)
- Modify: `lib/presentation/mobile/widgets/purchase_orders/po_widgets.dart` (append widget)
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` (delete `_SegmentedCells` at ~line 805, rename 2 usages)
- Test (modify): `test/presentation/mobile/widgets/purchase_orders/po_widgets_test.dart`

**Interfaces:**
- Consumes: existing `AppColors`/`AppShadows`, the private `_SegmentedCells<T>` currently at `new_purchase_order_screen.dart:805` (constructor: `values`, `labels`, `selected`, `onChanged`, `keyPrefix`, `icons?`, `radius = 12`, `elevated = false`; cells keyed `Key('$keyPrefix-$name')` with enum-`name` fallback `toString`; each cell wrapped in `Semantics(button: true, selected: isSel)`).
- Produces: `PoSegmentedCells<T>` in `po_widgets.dart` — identical constructor and rendering; `AppColors.segmentedSelectedWash(bool dark) → Color` (`0x1FE8B84C` dark / `0x1A283E46` light).

- [ ] **Step 1: Write the failing test**

Append to `po_widgets_test.dart` (inside `main`), and add the import `import 'package:maki_mobile_pos/core/theme/theme.dart';` at the top:

```dart
  testWidgets('PoSegmentedCells renders cells, keys, and fires onChanged',
      (tester) async {
    int? picked;
    await pump(
      tester,
      PoSegmentedCells<int>(
        values: const [30, 60, 90],
        labels: const {30: '30d', 60: '60d', 90: '90d'},
        selected: 60,
        keyPrefix: 'test-window',
        onChanged: (v) => picked = v,
      ),
    );
    expect(find.text('30d'), findsOneWidget);
    expect(find.byKey(const Key('test-window-90')), findsOneWidget);
    await tester.tap(find.byKey(const Key('test-window-30')));
    expect(picked, 30);
  });

  test('segmentedSelectedWash matches the PO mock values', () {
    expect(AppColors.segmentedSelectedWash(false), const Color(0x1A283E46));
    expect(AppColors.segmentedSelectedWash(true), const Color(0x1FE8B84C));
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/purchase_orders/po_widgets_test.dart`
Expected: FAIL — `PoSegmentedCells` and `segmentedSelectedWash` undefined (compile error).

- [ ] **Step 3: Implement**

**3a — `app_colors.dart`:** append after the `amberNoteIcon` function:

```dart
  /// Selected-cell wash for the PO bordered segmented control
  /// (PoSegmentedCells) — faint slate in light, faint gold in dark.
  static Color segmentedSelectedWash(bool dark) =>
      dark ? const Color(0x1FE8B84C) : const Color(0x1A283E46);
```

**3b — `po_widgets.dart`:** append the widget (verbatim move of `_SegmentedCells` with the class made public and the wash literals replaced by the token):

```dart
/// Bordered segmented control per the PO mock — equal cells, selected =
/// faint primary wash + 600 primary text. [elevated] fills with the card
/// surface + soft shadow (the view toggle); plain sits recessed on the
/// params card.
class PoSegmentedCells<T> extends StatelessWidget {
  const PoSegmentedCells({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.icons,
    this.radius = 12,
    this.elevated = false,
  });

  final List<T> values;
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final String keyPrefix;
  final Map<T, IconData>? icons;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border =
        dark ? AppColors.darkInputBorder : AppColors.lightInputBorder;
    return Container(
      decoration: BoxDecoration(
        color: elevated ? (dark ? AppColors.darkCard : Colors.white) : null,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? AppShadows.card(dark: dark) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: _cell(context, values[i], first: i == 0, border: border),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, T v,
      {required bool first, required Color border}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isSel = v == selected;
    final name = v is Enum ? v.name : v.toString();
    final icon = icons?[v];
    return Semantics(
      button: true,
      selected: isSel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(v),
        child: Container(
          key: Key('$keyPrefix-$name'),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: icons == null ? 8 : 10),
          decoration: BoxDecoration(
            color: isSel
                ? AppColors.segmentedSelectedWash(dark)
                : Colors.transparent,
            border: first ? null : Border(left: BorderSide(color: border)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSel
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                labels[v]!,
                style: TextStyle(
                  fontSize: icons == null ? 13 : 13.5,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                  color: isSel
                      ? theme.colorScheme.primary
                      : (icons == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**3c — `new_purchase_order_screen.dart`:** delete the entire private `_SegmentedCells<T>` class (both the class and its `_cell` method, ~lines 805-end-of-class) and rename the two usages: `_SegmentedCells<int>(` → `PoSegmentedCells<int>(` (params card) and `_SegmentedCells<_ViewMode>(` → `PoSegmentedCells<_ViewMode>(` (view toggle). The `po_widgets.dart` import already exists.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/presentation/mobile/widgets/purchase_orders/ test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`
Expected: ALL PASS (screen tests untouched — same keys).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart lib/presentation/mobile/widgets/purchase_orders/po_widgets.dart lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart test/presentation/mobile/widgets/purchase_orders/po_widgets_test.dart
git commit -m "refactor(po): move segmented control to po_widgets as PoSegmentedCells; tokenize selected wash

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Shared AddProductsSheet (PO + Job Orders)

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/add_products_sheet.dart`
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (replace `_onAddParts` body; delete `_AddPartsSheet` + `_AddPartsSheetState` at ~line 643; drop now-unused imports `dart:math` and `product_search_field.dart`)
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` (replace `_showAddProductSheet` body; delete `_AddProductsSheet` + `_AddProductsSheetState` at ~line 630; drop now-unused imports `dart:math` and `product_search_field.dart`)
- Test (create): `test/presentation/mobile/widgets/pos/add_products_sheet_test.dart`

**Interfaces:**
- Consumes: `ProductSearchField` (params: `controller`, `focusNode`, `inlineResults`, `showPrice`, `allowOutOfStock`, `addedIds`, `hintText`, `onProductSelected`, `onBarcodeScanned`), `productByBarcodeProvider(barcode)` (`lib/presentation/providers/product_provider.dart:109`), `context.showWarningSnackBar` (navigation_extensions).
- Produces: `AddProductsSheet` + `enum AddProductsSheetDismiss { closeIcon, doneButton }` — constructor: `{required String title, required void Function(ProductEntity) onProduct, AddProductsSheetDismiss dismiss = closeIcon, bool showSessionCount = false, bool showPrice = true, bool allowOutOfStock = false, bool dedupe = false, Set<String> initiallyAdded = const {}, bool clearQueryOnPick = false, String hintText = 'Search name, SKU, or scan barcode'}`.
- Accepted behavior delta (from spec): a JO **barcode** add now also clears the query + refocuses (previously only row-tap picks did); everything else is byte-identical.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/mobile/widgets/pos/add_products_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/add_products_sheet.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';

void main() {
  ProductEntity product(String id, {int qty = 5}) => ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: qty,
        reorderLevel: 2,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<void> pumpSheet(WidgetTester tester, AddProductsSheet sheet) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        productsProvider.overrideWith(
            (ref) => Stream.value([product('p1'), product('p2', qty: 0)])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'doneButton + dedupe: stays open, counts session, chips added rows, Done closes',
      (tester) async {
    final added = <String>[];
    await pumpSheet(
      tester,
      AddProductsSheet(
        title: 'Add products',
        dismiss: AddProductsSheetDismiss.doneButton,
        showSessionCount: true,
        showPrice: false,
        allowOutOfStock: true,
        dedupe: true,
        onProduct: (p) => added.add(p.id),
      ),
    );
    expect(find.text('Add products'), findsOneWidget);
    expect(find.text('0 added this session'), findsOneWidget);

    await search(tester, 'Item');
    // p2 is zero-stock and must be addable with allowOutOfStock.
    await tester.tap(find.text('Item p2'));
    await tester.pumpAndSettle();
    expect(added, ['p2']);
    expect(find.text('1 added this session'), findsOneWidget,
        reason: 'sheet stays open');
    expect(find.text('Added'), findsOneWidget);
    expect(find.textContaining('₱80'), findsNothing,
        reason: 'showPrice: false hides the sale price');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add products'), findsNothing);
  });

  testWidgets('closeIcon variant: X closes, prices show, no session count',
      (tester) async {
    await pumpSheet(
      tester,
      AddProductsSheet(title: 'Add parts', onProduct: (_) {}),
    );
    expect(find.text('Add parts'), findsOneWidget);
    expect(find.textContaining('added this session'), findsNothing);
    expect(find.text('Done'), findsNothing);

    await search(tester, 'Item p1');
    expect(find.textContaining('₱80'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Add parts'), findsNothing);
  });

  testWidgets('clearQueryOnPick clears the search after a pick',
      (tester) async {
    await pumpSheet(
      tester,
      AddProductsSheet(
          title: 'Add parts', clearQueryOnPick: true, onProduct: (_) {}),
    );
    await search(tester, 'Item p1');
    await tester.tap(find.text('Item p1').last);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/pos/add_products_sheet_test.dart`
Expected: FAIL — `add_products_sheet.dart` does not exist (compile error).

- [ ] **Step 3: Create the shared sheet**

Create `lib/presentation/mobile/widgets/pos/add_products_sheet.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';

/// How the shared add-products sheet is dismissed.
enum AddProductsSheetDismiss {
  /// X icon in the title row (Job Orders add-parts pattern).
  closeIcon,

  /// Pinned right-aligned Done button (PO add-products pattern).
  doneButton,
}

/// Product-picker bottom sheet shared by the Job Orders editor ("Add parts")
/// and the New Purchase Order screen ("Add products"): grab handle, title
/// row, [ProductSearchField] with inline results + barcode scan. Stays open
/// so several picks accumulate; the host screen updates live via [onProduct].
class AddProductsSheet extends ConsumerStatefulWidget {
  const AddProductsSheet({
    super.key,
    required this.title,
    required this.onProduct,
    this.dismiss = AddProductsSheetDismiss.closeIcon,
    this.showSessionCount = false,
    this.showPrice = true,
    this.allowOutOfStock = false,
    this.dedupe = false,
    this.initiallyAdded = const {},
    this.clearQueryOnPick = false,
    this.hintText = 'Search name, SKU, or scan barcode',
  });

  final String title;
  final void Function(ProductEntity) onProduct;
  final AddProductsSheetDismiss dismiss;

  /// Show "N added this session" in the title row.
  final bool showSessionCount;
  final bool showPrice;
  final bool allowOutOfStock;

  /// Skip repeat picks and chip already-added rows ("Added"); a duplicate
  /// barcode scan warns instead of silently doing nothing.
  final bool dedupe;

  /// Ids already on the host screen — seeds the dedupe set.
  final Set<String> initiallyAdded;

  /// Clear the query and refocus after each pick (JO behavior).
  final bool clearQueryOnPick;
  final String hintText;

  @override
  ConsumerState<AddProductsSheet> createState() => _AddProductsSheetState();
}

class _AddProductsSheetState extends ConsumerState<AddProductsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final Set<String> _added = {...widget.initiallyAdded};
  int _session = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(ProductEntity p) {
    if (widget.dedupe && _added.contains(p.id)) return;
    widget.onProduct(p);
    setState(() {
      _added.add(p.id);
      _session++;
    });
    if (widget.clearQueryOnPick) {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _onBarcode(String barcode) async {
    final p = await ref.read(productByBarcodeProvider(barcode).future);
    if (!mounted) return;
    if (p == null) {
      context.showWarningSnackBar('Product not found: $barcode');
    } else if (widget.dedupe && _added.contains(p.id)) {
      // A silent no-op reads as a failed scan — say why nothing changed.
      context.showWarningSnackBar('Already added: ${p.name}');
    } else {
      _add(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Fixed-height sheet with an in-flow scrollable results panel, clamped so
    // sheet + keyboard never exceed the screen. Upper bound floored at 0 — a
    // very short window (split-screen + keyboard) would otherwise make clamp
    // throw.
    final sheetHeight = (screenHeight * 0.62)
        .clamp(0.0, math.max(0.0, screenHeight - bottomInset - 120))
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.showSessionCount)
                    Text(
                      '$_session added this session',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (widget.dismiss == AddProductsSheetDismiss.closeIcon)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ProductSearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  inlineResults: true,
                  showPrice: widget.showPrice,
                  allowOutOfStock: widget.allowOutOfStock,
                  addedIds: widget.dedupe ? _added : const {},
                  hintText: widget.hintText,
                  onProductSelected: _add,
                  onBarcodeScanned: _onBarcode,
                ),
              ),
              if (widget.dismiss == AddProductsSheetDismiss.doneButton) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Swap the Job Orders call site**

In `draft_edit_screen.dart`: replace `_onAddParts` with

```dart
  void _onAddParts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => AddProductsSheet(
        title: 'Add parts',
        clearQueryOnPick: true,
        onProduct: _addProduct,
      ),
    );
  }
```

Delete the entire `_AddPartsSheet` + `_AddPartsSheetState` classes (~lines 643-760). Add `import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/add_products_sheet.dart';` and remove the now-unused `import 'dart:math' as math;` and `import ...pos/product_search_field.dart;`.

- [ ] **Step 5: Swap the PO call site**

In `new_purchase_order_screen.dart`: replace `_showAddProductSheet` with

```dart
  void _showAddProductSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => AddProductsSheet(
        title: 'Add products',
        dismiss: AddProductsSheetDismiss.doneButton,
        showSessionCount: true,
        showPrice: false,
        allowOutOfStock: true,
        dedupe: true,
        initiallyAdded: _manual.map((p) => p.id).toSet(),
        onProduct: (p) {
          if (_manual.any((m) => m.id == p.id)) return;
          setState(() {
            _manual.add(p);
            // A deliberate add is always checked, even when the product also
            // sits in a low/out bucket.
            _checkedOverride[p.id] = true;
          });
        },
      ),
    );
  }
```

Delete the entire `_AddProductsSheet` + `_AddProductsSheetState` classes (~lines 630-760). Add `import ...pos/add_products_sheet.dart;` and remove the now-unused `import 'dart:math' as math;` and `import ...pos/product_search_field.dart;`. (Keep `product_provider.dart` only if the analyzer still needs it — after this task nothing else in the file uses it, so it likely goes too; Task 3 does not reintroduce it.)

- [ ] **Step 6: Run the tests**

Run: `flutter test test/presentation/mobile/widgets/pos/add_products_sheet_test.dart test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart test/presentation/widgets/draft_edit_screen_addparts_test.dart test/presentation/widgets/product_search_field_inline_test.dart`
Expected: ALL PASS — the JO test's `find.byTooltip('Close')` and the PO tests' 'Done'/'Added'/session-count flows all still hold.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/add_products_sheet.dart lib/presentation/mobile/screens/drafts/draft_edit_screen.dart lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart test/presentation/mobile/widgets/pos/add_products_sheet_test.dart
git commit -m "refactor(pos): one shared AddProductsSheet for Job Orders and Purchase Orders

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Split coverDays out of the suggestions fetch

**Files:**
- Modify: `lib/presentation/providers/purchase_order_provider.dart:51-86` (replace `reorderSuggestionsProvider`, add `ReorderMovement` + `reorderMovementProvider`)
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` (delete debounce state; simplify `_setCover`; drop `dart:async` import)
- Test (create): `test/presentation/providers/reorder_suggestions_provider_test.dart`
- Test (modify): `test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`

**Interfaces:**
- Consumes: `productsProvider` (Stream of `List<ProductEntity>`), `saleRepositoryProvider.getSalesByDateRange`, `computeReorderSuggestions(products, unitsSold, params)`, `unitsSoldByProduct(sales)`, `reorderSalesCap`, `ReorderParams = ({int windowDays, int coverDays})`.
- Produces:
  - `typedef ReorderMovement = ({Map<String, int> unitsSold, bool capped});`
  - `reorderMovementProvider = FutureProvider.autoDispose.family<ReorderMovement, int>` (key = windowDays)
  - `reorderSuggestionsProvider = Provider.autoDispose.family<AsyncValue<ReorderResult>, ReorderParams>` — same name/key/watch-result as before; screen `.when` call sites unchanged.
- Screen contract change: test overrides become `reorderSuggestionsProvider.overrideWith((ref, params) => AsyncValue.data(...))` (no `async`).

- [ ] **Step 1: Write the failing provider test**

Create `test/presentation/providers/reorder_suggestions_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';

void main() {
  ProductEntity product(String id, {int qty = 0, int reorder = 2}) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: qty,
        reorderLevel: reorder,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  test('derives suggestions and buckets synchronously from movement', () async {
    final sold = product('sold'); // qty 0, 60 units sold → recommended
    final low = product('low', qty: 1, reorder: 5); // no sales → low bucket
    final out = product('out'); // qty 0, no sales → out bucket
    var fetches = 0;

    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value([sold, low, out])),
      reorderMovementProvider.overrideWith((ref, windowDays) async {
        fetches++;
        return (unitsSold: {'sold': 60}, capped: true);
      }),
    ]);
    addTearDown(container.dispose);

    const params30 = (windowDays: 60, coverDays: 30);
    // Keep the autoDispose graph alive while we read.
    final sub = container.listen(
        reorderSuggestionsProvider(params30), (_, __) {});
    addTearDown(sub.close);
    await container.read(productsProvider.future);
    await container.read(reorderMovementProvider(60).future);

    final result = container.read(reorderSuggestionsProvider(params30)).value!;
    // velocity 60/60 = 1 → target 30 → stock 0 → qty 30.
    expect(result.suggestions.single.product.id, 'sold');
    expect(result.suggestions.single.suggestedQty, 30);
    expect(result.lowStock.single.id, 'low');
    expect(result.outOfStock.single.id, 'out');
    expect(result.capped, true);

    // A different cover recomputes purely — same movement key, no new fetch.
    const params60 = (windowDays: 60, coverDays: 60);
    final sub2 = container.listen(
        reorderSuggestionsProvider(params60), (_, __) {});
    addTearDown(sub2.close);
    final more = container.read(reorderSuggestionsProvider(params60)).value!;
    expect(more.suggestions.single.suggestedQty, 60);
    expect(fetches, 1, reason: 'coverDays must never trigger a sales fetch');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/providers/reorder_suggestions_provider_test.dart`
Expected: FAIL — `reorderMovementProvider` undefined (compile error).

- [ ] **Step 3: Rewrite the providers**

In `purchase_order_provider.dart`, replace the whole `reorderSuggestionsProvider` block (keep `reorderSalesCap` and `ReorderResult` as-is) with:

```dart
/// Movement data for a window: units sold per product + whether the sales
/// fetch hit [reorderSalesCap]. Keyed by windowDays ONLY — coverDays never
/// affects the fetch, so cover changes must not refetch.
typedef ReorderMovement = ({Map<String, int> unitsSold, bool capped});

final reorderMovementProvider = FutureProvider.autoDispose
    .family<ReorderMovement, int>((ref, windowDays) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: windowDays - 1));
  final sales = await ref.watch(saleRepositoryProvider).getSalesByDateRange(
        startDate: start,
        endDate: now,
        status: SaleStatus.completed,
        limit: reorderSalesCap,
      );
  return (
    unitsSold: unitsSoldByProduct(sales),
    capped: sales.length >= reorderSalesCap,
  );
});

/// Suggestions + low/out buckets for the given params — a pure synchronous
/// derivation over [productsProvider] and [reorderMovementProvider], so
/// cover-days changes recompute instantly without refetching sales.
final reorderSuggestionsProvider = Provider.autoDispose
    .family<AsyncValue<ReorderResult>, ReorderParams>((ref, params) {
  final productsAsync = ref.watch(productsProvider);
  final movementAsync = ref.watch(reorderMovementProvider(params.windowDays));

  return productsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (products) => movementAsync.whenData((movement) {
      final suggestions =
          computeReorderSuggestions(products, movement.unitsSold, params);
      final suggestedIds = {for (final s in suggestions) s.product.id};
      final lowStock = <ProductEntity>[];
      final outOfStock = <ProductEntity>[];
      for (final product in products) {
        if (!product.isActive || suggestedIds.contains(product.id)) continue;
        if (product.quantity == 0) {
          outOfStock.add(product);
        } else if (product.quantity <= product.reorderLevel) {
          lowStock.add(product);
        }
      }
      int byName(ProductEntity a, ProductEntity b) => a.name.compareTo(b.name);
      lowStock.sort(byName);
      outOfStock.sort(byName);

      return ReorderResult(
        suggestions: suggestions,
        lowStock: lowStock,
        outOfStock: outOfStock,
        capped: movement.capped,
      );
    }),
  );
});
```

- [ ] **Step 4: Delete the screen's debounce machinery**

In `new_purchase_order_screen.dart`:

1. Delete the fields `_appliedCover` and `_coverDebounce` and the whole `dispose()` override (its only job was the timer). Delete `import 'dart:async';`.
2. Replace `_setCover` with:

```dart
  void _setCover(int value) => setState(() => _cover = value.clamp(1, 365));
```

3. In `build`, the params line becomes:

```dart
    final params = (windowDays: _windowDays, coverDays: _cover);
```

4. Update the `_cover` doc comment — it no longer has an "applied" twin:

```dart
  /// Cover days (clamped 1–365). Applied synchronously — the suggestions
  /// provider derives from cached movement data, so stepping never refetches.
  int _cover = 30;
```

- [ ] **Step 5: Update the screen tests**

In `new_purchase_order_screen_test.dart`:

1. In the `pump` helper and the cap-note test, change the override to the sync form:

```dart
        reorderSuggestionsProvider.overrideWith((ref, params) =>
            AsyncValue.data(ReorderResult(
                suggestions: suggestions,
                lowStock: lowStock,
                outOfStock: outOfStock,
                capped: false))),
```

(cap-note test: same shape with `capped: true`).

2. Replace the whole `'cover stepper applies after the debounce'` test with:

```dart
  testWidgets('cover stepping recomputes instantly without refetching sales',
      (tester) async {
    final fetchedWindows = <int>[];
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider.overrideWith((ref) => Stream.value([product('p1')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        // Real derivation runs; only the sales fetch is faked + counted.
        reorderMovementProvider.overrideWith((ref, windowDays) async {
          fetchedWindows.add(windowDays);
          return (unitsSold: {'p1': 30}, capped: false);
        }),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();

    // velocity 30/60 = 0.5 → cover 30 → target 15 → stock 0 → qty 15.
    expect(find.text('15'), findsOneWidget);
    expect(fetchedWindows, [60]);

    await tester.tap(find.byKey(const Key('po-cover-plus')));
    await tester.pumpAndSettle();
    // cover 31 → ceil(15.5) = 16 — same frame, no new fetch, no spinner.
    expect(find.text('16'), findsOneWidget);
    expect(fetchedWindows, [60]);

    await tester.tap(find.byKey(const Key('po-window-30')));
    await tester.pumpAndSettle();
    expect(fetchedWindows, [60, 30],
        reason: 'window changes still fetch (different date range)');
  });
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/presentation/providers/reorder_suggestions_provider_test.dart test/presentation/mobile/screens/receiving/purchase_orders/`
Expected: ALL PASS (no pending-timer failures remain — the Timer is gone).

- [ ] **Step 7: Full gate**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: ALL PASS (~1095+).

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/providers/purchase_order_provider.dart lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart test/presentation/providers/reorder_suggestions_provider_test.dart test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart
git commit -m "refactor(po): split reorder movement fetch from cover-days derivation — instant cover stepping, no debounce

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## After the plan

1. `/code-review` the branch diff.
2. Merge per `superpowers:finishing-a-development-branch` (no push unless asked). Visual smoke remains the user's gate — the only observable change is cover stepping without a spinner.
