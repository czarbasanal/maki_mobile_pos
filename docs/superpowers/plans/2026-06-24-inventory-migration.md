# Inventory Migration (Bundle 04) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the three Inventory mobile screens (list, product form, price history) onto the redesigned global theme — consistent `AppCard` soft-shadow surfaces, Lucide icons, sectioned product form with a live margin line and pinned submit, and an `AppCard`-wrapped price-history view.

**Architecture:** Pure presentation-layer restyle. No domain/data/provider changes — same widgets, same data, same role-gating. Swap Material `Card`/flat `Container` surfaces for the shared `AppCard`; swap `CupertinoIcons`/`Icons` for `LucideIcons`; regroup the product form into sectioned `AppCard`s and pin its submit via the sale-detail footer pattern (`Column` → `Expanded(scroll)` + footer with `AppShadows.pinnedFooter`).

**Tech Stack:** Flutter, Riverpod, `lucide_icons: ^0.257.0`, `fl_chart`, shared theme in `lib/core/theme/` + `lib/presentation/shared/widgets/common/`.

## Global Constraints

- **Source of truth:** `design/handoff/04-inventory/design_handoff_inventory/` — `MAKI POS Inventory.dc.html` + `README.md` + `screenshots/`. High-fidelity: match colors, type, spacing, radii, shadows, icons.
- **Surfaces:** neutral cards → `AppCard` (light soft shadow `AppShadows.card`; dark `#18262A` + 1px `#243234` — `AppCard` handles both). Never hand-roll the light/dark duality.
- **Icons:** `LucideIcons.*` only. Exact members (verified in 0.257.0): `chevronLeft, eye, eyeOff, arrowUpDown, moreVertical, plus, download, package, checkCircle, alertTriangle, alertCircle, layoutGrid, search, x, slidersHorizontal, lock, qrCode, box, tag, trendingUp, hash, ruler, scanLine, briefcase, list, info, clock, trash2, save, imagePlus, arrowUp, arrowDown, chevronDown, refreshCw`. **Two substitutions** (target members absent in 0.257.0): cost field keeps **`AppIcons.peso`** (app-wide ₱ glyph; `philippinePeso` does not exist); barcode-add uses **`LucideIcons.scanLine`** (`scanBarcode` does not exist).
- **Must-keep (no behavior change):** all role-gating (admin/staff/cashier on price·cost·SKU·delete·export; `addProduct`); cost visibility = password + 5-min auto-hide; cost-code pill for non-cost viewers; SKU-change + delete confirm dialogs and their copy; barcode multi-code + dedupe; CSV export; pull-to-refresh; all validation messages and field labels verbatim.
- **Stat counts:** small-hero `18/700`. **Stock badge:** outlined in stock color, qty `18/700` + unit `10`.
- **Verify each task:** `flutter analyze <changed files>` clean + the task's widget tests green. Pure icon/surface swaps are confirmed by analyze + the dark/light screenshots, not by assertions.

---

## File Structure

**Modify (lib):**
- `lib/presentation/mobile/widgets/inventory/product_list_tile.dart` — `Card` → `AppCard`; `_stockStyle` Cupertino → Lucide.
- `lib/presentation/mobile/screens/inventory/inventory_screen.dart` — summary stat cards → `AppCard` (18/700 counts); all Cupertino → Lucide; cost toggle / state views stay.
- `lib/presentation/mobile/widgets/inventory/cost_display_toggle.dart` — `eye`/`eye_slash` Cupertino → `eye`/`eyeOff` Lucide.
- `lib/presentation/mobile/screens/inventory/product_form_screen.dart` — regroup into sectioned `AppCard`s (`IDENTITY · PRICING · STOCK · CLASSIFICATION · AUDIT`), two-up field pairs, live margin line, pinned submit footer, Lucide icons, locked-field treatment replacing `Opacity(0.38)`.
- `lib/presentation/mobile/screens/inventory/price_history_screen.dart` — sparklines into an `AppCard` (with from→to labels), history rows into an `AppCard`; Cupertino → Lucide.

**Test (create/extend):**
- `test/presentation/widgets/product_list_tile_test.dart` — extend: tile renders on `AppCard`, not `Card`.
- `test/presentation/mobile/screens/inventory/inventory_screen_test.dart` — create: summary counts + AppCard surfaces.
- `test/presentation/widgets/product_form_screen_test.dart` — extend: section headers, live margin line, pinned submit, locked-field helper.
- `test/presentation/mobile/screens/inventory/price_history_screen_test.dart` — extend: from→to labels, rows on `AppCard`.

**Reference (read-only):** `lib/presentation/shared/widgets/common/app_card.dart`, `summary_row.dart`, `lib/core/theme/app_shadows.dart` (`pinnedFooter`), `lib/core/theme/app_icons.dart` (`peso`), `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (pinned-footer pattern, lines ~82-99 + `_buildVoidFooter`).

---

## Task 1: Inventory list — AppCard surfaces + Lucide

**Files:**
- Modify: `lib/presentation/mobile/widgets/inventory/product_list_tile.dart`
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart`
- Modify: `lib/presentation/mobile/widgets/inventory/cost_display_toggle.dart`
- Test: `test/presentation/widgets/product_list_tile_test.dart`, `test/presentation/mobile/screens/inventory/inventory_screen_test.dart`

**Interfaces:**
- Consumes: `AppCard({child, padding, margin, radius, onTap})`, `AppColors`, `AppSpacing`, `AppRadius`, `LucideIcons`, `AppIcons`.
- Produces: a migrated `ProductListTile` and inventory list — no API/signature changes (props unchanged), so later tasks and existing call sites are unaffected.

- [ ] **Step 1: Write failing test — tile renders on AppCard, not Material Card**

In `test/presentation/widgets/product_list_tile_test.dart`, add inside `group('ProductListTile', …)`:

```dart
testWidgets('renders on AppCard, not Material Card', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ProductListTile(
            product: testProduct, showCost: false, onTap: () {},
          ),
        ),
      ),
    ),
  );
  expect(find.byType(AppCard), findsOneWidget);
  expect(find.byType(Card), findsNothing);
});
```

Add imports at top of the test file:
```dart
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/product_list_tile_test.dart -p vm`
Expected: FAIL — `find.byType(AppCard)` finds nothing (tile still uses `Card`).

- [ ] **Step 3: Migrate ProductListTile to AppCard + Lucide**

In `product_list_tile.dart`:
- Replace `import 'package:flutter/cupertino.dart';` with `import 'package:lucide_icons/lucide_icons.dart';` and add `import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';`.
- Replace the outer `Card(margin: …, child: InkWell(onTap, onLongPress, borderRadius, child: Padding(padding: EdgeInsets.all(AppSpacing.sm + 4), child: Row(…))))` with:

```dart
return AppCard(
  margin: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
  padding: const EdgeInsets.all(AppSpacing.sm + 4),
  onTap: onTap,
  child: Row(/* unchanged children */),
);
```

  > Note: `AppCard.onTap` covers tap; `onLongPress` is not supported by `AppCard`. Wrap the `Row` child in a `GestureDetector(onLongPress: onLongPress, child: …)` when `onLongPress != null` so admin long-press-to-delete is preserved.

- In `_stockStyle`, swap icons: `CupertinoIcons.exclamationmark_circle` → `LucideIcons.alertCircle`; `CupertinoIcons.exclamationmark_triangle` → `LucideIcons.alertTriangle`; `CupertinoIcons.checkmark_circle` → `LucideIcons.checkCircle`.

- [ ] **Step 4: Run tile tests to verify they pass**

Run: `flutter test test/presentation/widgets/product_list_tile_test.dart -p vm`
Expected: PASS (new test + existing `displays product information`, `shows cost code when showCost is false`).

- [ ] **Step 5: Write failing test — inventory summary counts render**

Create `test/presentation/mobile/screens/inventory/inventory_screen_test.dart`. Harness pattern (mirror `price_history_screen_test.dart`): wrap `InventoryScreen` in `ProviderScope` + `MaterialApp`, override `productsProvider` (→ a small product list), `inventorySummaryProvider` (→ counts), and `currentUserProvider` (→ an admin `UserEntity`). Set `tester.view.physicalSize = const Size(1200, 2400)`.

```dart
testWidgets('summary stats show counts and use AppCard surfaces', (tester) async {
  await _pump(tester); // seeds 128 total / 96 in / 21 low / 11 out
  await tester.pump(const Duration(seconds: 1));
  expect(find.text('Total'), findsOneWidget);
  expect(find.text('In Stock'), findsWidgets);
  expect(find.byType(AppCard), findsWidgets); // stat cards + rows
});
```

> Read the real provider names/signatures in `lib/presentation/providers/` + `inventory_screen.dart` before finalizing the overrides; copy the exact provider identifiers. If a provider can't be overridden cleanly in a widget test, narrow this test to assert on `ProductListTile`/`AppCard` presence with `productsProvider` seeded and drop the summary-count asserts (note the reduction).

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/presentation/mobile/screens/inventory/inventory_screen_test.dart -p vm`
Expected: FAIL — `find.byType(AppCard)` for stat cards finds nothing (stats still flat `Container`s).

- [ ] **Step 7: Migrate inventory_screen surfaces + icons**

In `inventory_screen.dart`:
- Replace `import 'package:flutter/cupertino.dart';` → `import 'package:lucide_icons/lucide_icons.dart';`; add `import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';`.
- Summary stat cards (the `InkWell`+`Container` in `_buildSummaryRow`): replace each `Container(decoration: BoxDecoration(border: hairline …))` with `AppCard(onTap: …, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), radius: AppRadius.md, child: …)`. Selected state: keep the 1.5px colored border by wrapping the `AppCard` child column or, simpler, retain a thin `Container` border *inside* the card for the selected color ring (don't reintroduce the outer flat container for unselected). Bump the count `Text` to `fontSize: 18, fontWeight: FontWeight.w700`.
- Swap every `CupertinoIcons.*` in this file to its Lucide member per the icon map in Global Constraints (`back→chevronLeft`, `eye/eye_slash` handled in cost toggle, `arrow_up_arrow_down→arrowUpDown`, `arrow_up/down→arrowUp/arrowDown`, `add→plus`, `cloud_download→download`, `cube_box→package`, `checkmark_circle→checkCircle`, `exclamationmark_triangle→alertTriangle`, `exclamationmark_circle→alertCircle`, `square_grid_2x2→layoutGrid`, `xmark→x`, `search→search`, `line_horizontal_3_decrease→slidersHorizontal`). The 3-dot overflow `PopupMenuButton` icon → `LucideIcons.moreVertical`. Empty-state `Icons.filter_alt_off_outlined` → `LucideIcons.slidersHorizontal` (or keep — note choice).
- In `cost_display_toggle.dart`: `CupertinoIcons.eye`/`eye_slash` → `LucideIcons.eye`/`LucideIcons.eyeOff`; replace the cupertino import.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/inventory/inventory_screen_test.dart test/presentation/widgets/product_list_tile_test.dart -p vm`
Expected: PASS.

- [ ] **Step 9: Analyze**

Run: `flutter analyze lib/presentation/mobile/widgets/inventory/product_list_tile.dart lib/presentation/mobile/screens/inventory/inventory_screen.dart lib/presentation/mobile/widgets/inventory/cost_display_toggle.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/mobile/widgets/inventory/product_list_tile.dart \
        lib/presentation/mobile/screens/inventory/inventory_screen.dart \
        lib/presentation/mobile/widgets/inventory/cost_display_toggle.dart \
        test/presentation/widgets/product_list_tile_test.dart \
        test/presentation/mobile/screens/inventory/inventory_screen_test.dart
git commit -m "feat(inventory): list + tile → AppCard surfaces, Lucide icons (bundle 04)"
```

---

## Task 2: Product form — sectioned cards, margin line, pinned submit, Lucide

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`
- Test: `test/presentation/widgets/product_form_screen_test.dart`

**Interfaces:**
- Consumes: `AppCard`, `AppShadows.pinnedFooter`, `LucideIcons`, `AppIcons.peso`, `product.profitMargin` (`double`, % from `ProductEntity`), existing controllers (`_priceController`, `_costController`).
- Produces: same screen route + same submit/delete behavior; new private helpers `_sectionCard`, `_sectionHeader`, `_marginLine`, `_buildSubmitFooter`.

- [ ] **Step 1: Write failing tests — sections, margin line, pinned submit**

Read the existing harness in `test/presentation/widgets/product_form_screen_test.dart` and reuse it (admin override). Add:

```dart
testWidgets('groups fields under section headers', (tester) async {
  await pumpForm(tester, editing: true); // existing helper or inline harness
  await tester.pump(const Duration(seconds: 1));
  expect(find.text('IDENTITY'), findsOneWidget);
  expect(find.text('PRICING'), findsOneWidget);
  expect(find.text('STOCK'), findsOneWidget);
  expect(find.text('CLASSIFICATION'), findsOneWidget);
});

testWidgets('shows a live margin line under the pricing pair', (tester) async {
  await pumpForm(tester, editing: true); // price 250, cost 180 seeded
  await tester.pump(const Duration(seconds: 1));
  // profitMargin = (250-180)/250 = 28%; unit profit = 70.00
  expect(find.textContaining('Margin'), findsOneWidget);
  expect(find.textContaining('28%'), findsWidgets);
});

testWidgets('submit button is pinned in a footer bar', (tester) async {
  await pumpForm(tester, editing: true);
  await tester.pump(const Duration(seconds: 1));
  expect(find.byKey(const Key('product-form-submit')), findsOneWidget);
});
```

> If `pumpForm` doesn't exist, inline a `ProviderScope`+`MaterialApp(home: ProductFormScreen(productId: …))` harness, overriding `currentUserProvider` with an admin `UserEntity` and any product/category/supplier providers the screen reads (copy exact identifiers from the screen). Seed an existing product with `price: 250, cost: 180`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/presentation/widgets/product_form_screen_test.dart -p vm`
Expected: FAIL — no `IDENTITY` header, no margin line, no submit key.

- [ ] **Step 3: Add section + margin + footer helpers**

In `product_form_screen.dart` add imports (`lucide_icons`, `app_card`, `app_shadows` via `core/theme/theme.dart` which is already imported) and these private helpers:

```dart
Widget _sectionHeader(String text) => Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8, top: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.8, color: AppColors.lightTextMuted)),
    );

Widget _sectionCard({required List<Widget> children}) => AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

/// Live margin recap under the Pricing pair. Reads the price/cost controllers.
Widget _marginLine(ThemeData theme) {
  final price = double.tryParse(_priceController.text) ?? 0;
  final cost = double.tryParse(_costController.text) ?? 0;
  if (price <= 0 || cost <= 0 || cost > price) return const SizedBox.shrink();
  final pct = ((price - cost) / price * 100).toStringAsFixed(0);
  final unit = (price - cost).toStringAsFixed(2);
  return Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm, left: 2),
    child: Row(children: [
      const Icon(LucideIcons.trendingUp, size: 14, color: AppColors.successDark),
      const SizedBox(width: 6),
      Text('Margin $pct% · ${AppConstants.currencySymbol}$unit per unit',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: AppColors.successDark)),
    ]),
  );
}
```

Footer (mirror `sale_detail_screen.dart`'s `_buildVoidFooter`):
```dart
Widget _buildSubmitFooter(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      boxShadow: AppShadows.pinnedFooter(dark: isDark),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _buildSubmitButton(), // existing FilledButton, add Key('product-form-submit')
      ),
    ),
  );
}
```

Rebind the margin line to rebuild on edits: add a listener in `initState` — `_priceController.addListener(() => setState(() {}));` and the same for `_costController` (guard with `mounted`).

- [ ] **Step 4: Regroup the form body + pin the footer**

Wrap the scroll body in the pinned-footer layout. Where `build` currently returns `Scaffold(appBar: …, body: SingleChildScrollView(…))`, change the body to:

```dart
body: _isLoading
    ? const Center(child: CircularProgressIndicator())
    : Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: Form(key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (/* edit role banner cond */) _roleBanner(),
              _imageUploader(),
              _sectionHeader('IDENTITY'),
              _sectionCard(children: [/* SKU field, auto-gen switch, Name */]),
              _sectionHeader('PRICING'),
              _sectionCard(children: [/* Selling + Cost two-up Row */, _marginLine(theme)]),
              _sectionHeader('STOCK'),
              _sectionCard(children: [/* Qty + Reorder two-up Row, Unit, Barcodes */]),
              _sectionHeader('CLASSIFICATION'),
              _sectionCard(children: [/* Category, Supplier (admin), Notes */]),
              if (widget.isEditing && _existingProduct != null) ...[
                _sectionHeader('AUDIT'), _AuditInfoCard(product: _existingProduct!),
              ],
              if (/* price-history link cond */) _priceHistoryLink(),
            ]),
          ),
        )),
        _buildSubmitFooter(context),
      ]),
```

Two-up pairs use `Row(children: [Expanded(child: sellingField), SizedBox(width: AppSpacing.md), Expanded(child: costField)])`. Keep every field's existing controller, validator, `enabled` gate, label, hint, and helper **verbatim** — only their container/grouping changes. Move the existing field widgets into the section cards; do not duplicate logic.

- [ ] **Step 5: Lucide icons + locked-field treatment**

- Swap all `CupertinoIcons.*` prefixes to Lucide per the map: `back→chevronLeft`, `trash→trash2`, `qrcode→qrCode`, `arrow_2_circlepath→refreshCw`, `cube_box→box`, `tag→tag`, `number→hash`, `exclamationmark_triangle→alertTriangle`, `barcode_viewfinder→scanLine`, `list_bullet→list`, `briefcase→briefcase`, `lock→lock`, `info_circle→info`, `clock→clock`, `tray_arrow_down→save`, `add→plus`, `square_grid_2x2→layoutGrid`. **Keep `AppIcons.peso`** for the Cost field; `Icons.straighten` (Unit) → `LucideIcons.ruler`. Image-uploader placeholder icon → `LucideIcons.imagePlus` (only if defined inside this file; otherwise leave `ProductImageUploader` for its own bundle).
- Locked fields: replace `AbsorbPointer + Opacity(0.38)` wrappers (Unit/Category for cashier) with the field rendered `enabled: false` plus a helper line stating the reason (e.g. `'Only admin can change this'` for price is already present; for cashier-locked fields add `'Cashiers can edit name and image only'`). Remove the `Opacity` wrapper.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/presentation/widgets/product_form_screen_test.dart -p vm`
Expected: PASS (new section/margin/footer tests + all existing form tests).

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/product_form_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart \
        test/presentation/widgets/product_form_screen_test.dart
git commit -m "feat(inventory): product form → sectioned AppCards, margin line, pinned submit, Lucide (bundle 04)"
```

---

## Task 3: Price history — AppCard rows + sparkline card + Lucide

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/price_history_screen.dart`
- Test: `test/presentation/mobile/screens/inventory/price_history_screen_test.dart`

**Interfaces:**
- Consumes: `AppCard`, `LucideIcons`. Existing `_Sparkline`, `_MetricLine`, `derivePriceHistorySource`, `sparklineSeries` are reused unchanged.
- Produces: same screen behavior; sparklines + rows now wrapped in `AppCard`s with from→to labels.

- [ ] **Step 1: Write failing tests — from→to labels + AppCard wrap**

In `price_history_screen_test.dart`, add (the multi-entry `_pump` already exists):

```dart
testWidgets('sparkline card shows from→to labels and rows use AppCard',
    (tester) async {
  await _pump(tester, [
    _e('e1', 250, 180, DateTime(2026, 6, 18), reason: 'Price + cost update'),
    _e('e2', 230, 170, DateTime(2026, 5, 30), reason: 'Price update'),
    _e('e3', 225, 170, DateTime(2026, 5, 12), reason: 'Initial price'),
  ]);
  expect(find.byType(AppCard), findsWidgets);
  expect(find.textContaining('→'), findsWidgets); // from→to on sparkline labels
});
```

Add import: `import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';`

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/mobile/screens/inventory/price_history_screen_test.dart -p vm`
Expected: FAIL — no `AppCard`, no `→` label.

- [ ] **Step 3: Migrate price_history_screen**

In `price_history_screen.dart`:
- Replace `import 'package:flutter/cupertino.dart';` → `import 'package:lucide_icons/lucide_icons.dart';`; add the `app_card` import.
- App-bar leading `CupertinoIcons.back` → `LucideIcons.chevronLeft`. Delta arrows `CupertinoIcons.arrow_up`/`arrow_down` (in `_MetricLine`) → `LucideIcons.arrowUp`/`LucideIcons.arrowDown`.
- Wrap the sparkline section in an `AppCard(padding: const EdgeInsets.all(AppSpacing.md), child: Column(...))`. For each sparkline, change `_SparklineLabel('Price')` to a label that appends the from→to: `'Price  ${cur}${first}→${cur}${last}'` (compute first/last from the same series used to draw the line — oldest→newest). Keep the `'Not enough changes to chart'` fallback.
- Wrap the list of history rows in a single `AppCard(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), child: Column(children: [...rows]))`. Keep the existing first-row-no-top-border / hairline-between-rows logic inside the card.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/inventory/price_history_screen_test.dart -p vm`
Expected: PASS (new test + existing empty/single-entry/delta tests).

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/price_history_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/price_history_screen.dart \
        test/presentation/mobile/screens/inventory/price_history_screen_test.dart
git commit -m "feat(inventory): price history → AppCard rows + sparkline card, Lucide (bundle 04)"
```

---

## Task 4: Full verification + branch finish

- [ ] **Step 1: Full analyze + test sweep**

Run: `flutter analyze` (expect clean for changed files) and `flutter test test/presentation/ -p vm` (expect all green). Investigate any failures before proceeding.

- [ ] **Step 2: `/code-review`** the branch diff vs `main`.

- [ ] **Step 3: `/verify`** — launch the app (or widget-level), confirm Inventory list / form / price-history render on the new surfaces in light AND dark, and that role-gating + dialogs still work.

- [ ] **Step 4: Finish branch** via `superpowers:finishing-a-development-branch` (merge to `main` / push, since Claude Design reads the repo).

---

## Self-Review

**Spec coverage** (against handoff README "The migration changes"):
1. Consistent elevation — stat cards + product rows → `AppCard`, counts 18/700 → Task 1. ✓
2. Cupertino → Lucide everywhere → Tasks 1–3 (icon map in Global Constraints). ✓
3. Product form sectioned cards + two-up + live margin + pinned submit → Task 2. ✓
4. Price history rows in `AppCard` + sparkline card with from→to labels → Task 3. ✓
- Locked-field treatment (replace `Opacity(0.38)`) → Task 2 Step 5. ✓
- Must-keeps (role-gating, password cost, cost-code pill, dialogs+copy, barcode dedupe, CSV, pull-to-refresh, dark parity) → Global Constraints + "keep verbatim" instructions; no provider/logic edits. ✓

**Known deviations from the handoff icon map (documented, intentional):** cost = `AppIcons.peso` (no `philippinePeso` in 0.257.0); barcode-add = `LucideIcons.scanLine` (no `scanBarcode`).

**Open risk:** widget-test overrides for `inventory_screen` / `product_form_screen` depend on exact provider identifiers — each task's first step says to read them from the screen before finalizing, and gives a narrower fallback assertion if a provider can't be overridden cleanly. TDD value on a visual migration is partial; pure icon/surface swaps are gated by `flutter analyze` + the dark/light screenshots, stated per task.
