# Inventory Migration (Bundle 04) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the three Inventory mobile screens (list, product form, price history) onto the redesigned global theme — exactly matching the prototype `design/handoff/04-inventory/design_handoff_inventory/MAKI POS Inventory.dc.html` (the source of truth) — and adopt grouped currency formatting app-wide.

**Architecture:** Presentation-layer restyle + one shared-formatter change. No domain/data/provider edits; same widgets, data, and role-gating. Surfaces → shared `AppCard`; icons → `LucideIcons`; product form regrouped into sectioned `AppCard`s with a live margin line and a pinned submit (sale-detail footer pattern); price history wrapped in cards. Currency display moves to the existing `num.toCurrency()` extension (already grouped) plus a new `toCurrencyCompact()`.

**Tech Stack:** Flutter, Riverpod, `lucide_icons: ^0.257.0`, `fl_chart`, `intl` (`NumberFormat`), shared theme in `lib/core/theme/` + `lib/presentation/shared/widgets/common/`.

## Global Constraints

- **Source of truth:** the prototype `.dc.html` + `screenshots/` in `design/handoff/04-inventory/design_handoff_inventory/`. Match colors, type, weight, spacing, radii, shadows, icons **exactly** — values are inlined per task below; when in doubt, open the prototype.
- **Currency formatting (decided):**
  - **Grouped thousands app-wide.** Replace inline `'${AppConstants.currencySymbol}${x.toStringAsFixed(2)}'` (and `currencySymbol + toCurrencyWithoutSymbol`-style concatenations) with `x.toCurrency()` (already `NumberFormat.currency(locale:'en_PH', symbol:'₱', decimalDigits:2)` → `₱1,234.56`).
  - **Decimals only when needed** for *secondary* amounts (cost pill, price-history values + deltas): new `num.toCurrencyCompact()` → `₱180` when whole, `₱180.50` when fractional, always grouped. Main/selling price + margin "per unit" keep 2 decimals (`.toCurrency()`).
- **Icons:** `LucideIcons.*` only. Verified members (0.257.0): `chevronLeft, eye, eyeOff, arrowUpDown, moreVertical, plus, download, package, checkCircle, alertTriangle, alertCircle, layoutGrid, search, x, slidersHorizontal, lock, qrCode, box, tag, trendingUp, hash, ruler, briefcase, list, info, clock, trash2, save, imagePlus, arrowUp, arrowDown, chevronDown, refreshCw`. **Substitutions** (target absent in 0.257.0): cost field keeps **`AppIcons.peso`** (`philippinePeso` missing); barcode-add uses **`LucideIcons.scanLine`** (`scanBarcode` missing). Icon stroke widths per prototype: app-bar/field icons 1.75; stat/leading/arrow icons 1.9; delta arrows 2.2; plus/save 2.
- **Theme-aware token pairs (light / dark)** used below:
  - canvas `#F6F5F3`/`#0C1415`; card `#FFFFFF`/`#18262A` (+1px `#243234`) — `AppCard` handles both.
  - field fill `#FAFAFA`/`#0C1415`; field border `#E2E2E2`/`#2C3C3E`; text `#16201F`/`#ECEFEF`; muted `#8A9296`/`#93A0A3`; hint `#9AA0A3`/`#6C797C`.
  - primary `#283E46`/gold `#E8B84C` (filled-button text on gold = `#121C1D`).
  - **stat icon** Total `#2196F3`/`#5AA9F0`, In `#4CAF50`/`#5FC86A`, Low `#F57C00`/`#F5B547`, Out `#F44336`/`#FF6B5E`.
  - **stat value** Total `#16201F`/`#ECEFEF`, In `#2E7D32`/`#8FE39A`, Low `#F57C00`/`#F5B547`, Out `#F44336`/`#FF6B5E`.
  - **stock color** (tile icon + badge border/text + count): in `#4CAF50`/`#5FC86A` (badge border `#4CAF50` both), low `#F57C00`/`#F5B547`, out `#F44336`/`#FF6B5E` (badge border `#F44336` light). Leading tint = stock hue at α .10 light / .16 dark; **low tint** uses warning `rgba(255,193,7,.14)` light / `rgba(245,181,71,.16)` dark.
- **Must-keep (no behavior change):** all role-gating (admin/staff/cashier on price·cost·SKU·delete·export; `addProduct`); cost visibility = password + 5-min auto-hide; cost-code pill for non-cost viewers; SKU-change + delete confirm dialogs and their copy; barcode multi-code + dedupe; CSV export; pull-to-refresh; all **validation messages** verbatim; date format `MMM d, y • h:mm a`; price-history source derivation (`derivePriceHistorySource`).
- **Verify each task:** `flutter analyze <changed files>` clean + the task's tests green. Pure icon/surface swaps are gated by analyze + the light/dark screenshots.

---

## File Structure

**Modify (lib):**
- `lib/core/extensions/num_extensions.dart` — add `toCurrencyCompact()`.
- ~app-wide call sites — swap inline `currencySymbol + toStringAsFixed(2)` → `.toCurrency()` (grep-driven; ~38 files touch `currencySymbol`).
- `lib/presentation/mobile/widgets/inventory/product_list_tile.dart` — `Card`→`AppCard`; filled price pill; filled margin badge; compact cost; theme-aware low color; Lucide; radii (card 16, leading 11, badge 12).
- `lib/presentation/mobile/screens/inventory/inventory_screen.dart` — summary stats → `AppCard` (18/700, icon/value color split); Lucide; pinned Add (already bottom bar).
- `lib/presentation/mobile/widgets/inventory/cost_display_toggle.dart` — `eye`/`eyeOff` Lucide.
- `lib/presentation/mobile/screens/inventory/product_form_screen.dart` — sectioned `AppCard`s, two-up pairs, live margin line, pinned submit, Lucide, shortened labels + SKU helper, locked-field treatment.
- `lib/presentation/mobile/screens/inventory/price_history_screen.dart` — sparkline `AppCard` (two-part trend labels), rows `AppCard`, compact values, Lucide.

**Test:** `test/core/extensions/num_extensions_test.dart` (create/extend), `test/presentation/widgets/product_list_tile_test.dart`, `test/presentation/mobile/screens/inventory/inventory_screen_test.dart` (create), `test/presentation/widgets/product_form_screen_test.dart`, `test/presentation/mobile/screens/inventory/price_history_screen_test.dart`.

**Reference (read-only):** `app_card.dart`, `summary_row.dart`, `app_shadows.dart` (`pinnedFooter`, `primaryButton`), `app_icons.dart` (`peso`), `sale_detail_screen.dart` `_buildVoidFooter` (pinned-footer pattern), `num_extensions.dart` (`toCurrency`).

---

## Task 1: Grouped currency app-wide + compact variant

**Files:**
- Modify: `lib/core/extensions/num_extensions.dart`
- Modify: app-wide call sites (grep-driven)
- Test: `test/core/extensions/num_extensions_test.dart`

**Interfaces:**
- Produces: `num.toCurrency()` (existing — grouped, 2 decimals) and **new** `num.toCurrencyCompact()` (grouped, 0 decimals when whole else 2). Tasks 2–4 consume both.

- [ ] **Step 1: Write failing test for `toCurrencyCompact`**

In `test/core/extensions/num_extensions_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';

void main() {
  group('toCurrencyCompact', () {
    test('drops decimals when whole, groups thousands', () {
      expect(1250.toCurrencyCompact(), '₱1,250');
      expect(180.0.toCurrencyCompact(), '₱180');
    });
    test('keeps 2 decimals when fractional', () {
      expect(180.5.toCurrencyCompact(), '₱180.50');
    });
  });
  test('toCurrency groups thousands with 2 decimals', () {
    expect(1250.0.toCurrency(), '₱1,250.00');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/extensions/num_extensions_test.dart`
Expected: FAIL — `toCurrencyCompact` undefined.

- [ ] **Step 3: Implement `toCurrencyCompact`**

Add to `extension NumExtensions on num` in `num_extensions.dart`:
```dart
/// Currency with grouped thousands; shows decimals only when the value
/// has a fractional part (₱180, ₱180.50). For secondary amounts (cost
/// pill, price-history rows) where the primary price keeps full decimals.
String toCurrencyCompact() {
  final hasCents = ((this * 100).round() % 100) != 0;
  final formatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: AppConstants.currencySymbol,
    decimalDigits: hasCents ? AppConstants.currencyDecimalPlaces : 0,
  );
  return formatter.format(this);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/extensions/num_extensions_test.dart`
Expected: PASS.

- [ ] **Step 5: Adopt `.toCurrency()` at inline call sites (grouping app-wide)**

Find them: `grep -rn "currencySymbol}\${" lib/` and `grep -rn "currencySymbol)\}\${\|toStringAsFixed(2)" lib/`. For each inline `'${AppConstants.currencySymbol}${x.toStringAsFixed(2)}'`, replace with `x.toCurrency()` (import the extension). **Do not** change: percentage/non-currency `toStringAsFixed`; the `CurrencyInputFormatter` (text-field input); receipt-internal alignment math that depends on fixed-width strings — restyle those only if the rendered total is unchanged. Work file-by-file; analyze after each.

> Scope note: this is the broad part of the "app-wide grouping" decision. If a call site is in the **print-styled receipt** (`ReceiptWidget`), keep its layout and only swap the number formatting if column widths still align — flag in the commit if a receipt line shifts.

- [ ] **Step 6: Analyze + targeted tests**

Run: `flutter analyze lib/` (expect clean) and `flutter test test/ -p vm` (expect green; fix any test asserting the old un-grouped string by updating to the grouped expectation).

- [ ] **Step 7: Commit**

```bash
git add lib/core/extensions/num_extensions.dart test/core/extensions/num_extensions_test.dart lib/
git commit -m "feat(core): grouped currency app-wide via toCurrency + add toCurrencyCompact (bundle 04)"
```

---

## Task 2: Inventory list — AppCard surfaces, filled pills, Lucide

**Files:**
- Modify: `product_list_tile.dart`, `inventory_screen.dart`, `cost_display_toggle.dart`
- Test: `product_list_tile_test.dart`, `inventory_screen_test.dart` (create)

**Interfaces:** Consumes `AppCard`, `LucideIcons`, `AppColors`, `.toCurrency()`/`.toCurrencyCompact()`. No prop changes.

**Exact spec (from prototype):**
- **Tile** (`AppCard`, radius **16**, padding 12, row gap 11, align flex-start). Leading 40×40, radius **11**, bg = stock tint (in `rgba(76,175,80,.10/.16)`, low `rgba(255,193,7,.14)`/`rgba(245,181,71,.16)`, out `rgba(244,67,54,.10/.16)`), icon 21px stroke 1.9 in stock color. Name 13/600 line-height 1.25. SKU mono 12 muted; category chip 10 muted, border hairline, radius 7, padding 1×6. Pills row margin-top 8, gap 6, wrap.
  - **Price pill — FILLED**: text 12/700; light bg `#283E46`/text `#fff`, dark bg `#E8B84C`/text `#121C1D`; radius **8**, padding 3×9. Value = `product.price.toCurrency()`.
  - **Cost pill**: 11px; "Cost " muted + value bold (light `#16201F`/dark `#ECEFEF`); border hairline, radius 8, padding 3×8. Value = `product.cost.toCurrencyCompact()` (no colon).
  - **Margin badge — FILLED**: 11/600; light bg `#E8F5E9`/text `#2E7D32`, dark bg `rgba(76,175,80,.18)`/text `#8FE39A`; radius 8, padding 3×8. Text `'${margin.toStringAsFixed(0)}%'`.
  - **Cost-code pill** (non-cost): 11px muted, border hairline, radius 8, padding 3×8; `lock` 11px stroke 1.9 + "Code " + mono bold code.
  - **Stock badge**: border 1.4px stock color, radius **12**, padding 6×11; qty 18/700 line-height 1, unit 10. (low border/text `#F57C00`/`#F5B547`.)
- **Summary stat card** (`AppCard`, radius **14**, padding 11×4, col gap 4): icon 19px stroke 1.9 (stat icon color); count **18/700** line-height 1 (stat value color); label 10 muted. Selected card adds a **1.5px** colored border in the stock hue (keep the existing selected-filter logic).
- **Search** (`AppCard`, radius 16, height 46, padding 0×14): `search` 18 muted + hint `Search by name, SKU, or barcode…` 14 hint.
- **Chips**: 13px, unselected 500 on card + 1px hairline, selected 600 primary-fill/onPrimary; radius pill, padding 7×13; Category chip `layoutGrid` 14.
- **Active-filters**: `slidersHorizontal` 15 muted + `Filters active` 13 muted + `Clear all` 13/600 primary.
- **Bottom bar** (already `bottomNavigationBar`): bg canvas + `AppShadows.pinnedFooter`; button height 50, radius 16, primary fill, 15/600, `AppShadows.primaryButton`, `plus` 18 + `Add Product`.

- [ ] **Step 1: Failing test — tile on AppCard with filled price pill**

In `product_list_tile_test.dart` add (import `app_card.dart`):
```dart
testWidgets('renders on AppCard with filled price pill', (tester) async {
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
    body: ProductListTile(product: testProduct, showCost: true, onTap: () {})))));
  expect(find.byType(AppCard), findsOneWidget);
  expect(find.byType(Card), findsNothing);
  expect(find.text('₱100.00'), findsOneWidget); // price keeps decimals + grouping
});
```

- [ ] **Step 2: Run — fails** (`flutter test test/presentation/widgets/product_list_tile_test.dart -p vm`).

- [ ] **Step 3: Migrate `product_list_tile.dart`** per Exact spec: `Card`→`AppCard(radius:16, padding: EdgeInsets.all(12), margin: …, onTap:onTap, child: GestureDetector(onLongPress:onLongPress, child: Row(...)))`. Swap cupertino import → `lucide_icons` + add `app_card` import. `_PricePill`→filled (theme-aware bg/text). `_CostPill`→"Cost " + `cost.toCurrencyCompact()`, no colon. `_MarginBadge`→filled tint. Price pill value→`product.price.toCurrency()`. `_stockStyle`→Lucide icons **and** theme-aware low color: make it `(_stockStyle(product, isDark))` returning `#F57C00`/`#F5B547` for low, `#5FC86A`/`#4CAF50` etc. — thread `isDark` through `_LeadingVisual`/`_StockBadge`. Apply radii 11/12.

- [ ] **Step 4: Run tile tests — pass.**

- [ ] **Step 5: Failing test — inventory summary on AppCard** (create `inventory_screen_test.dart`; harness mirrors `price_history_screen_test.dart`, overriding the real providers read by `inventory_screen.dart` — read them first; seed admin user + a few products + summary counts; `tester.view.physicalSize = const Size(1200, 2600)`):
```dart
expect(find.text('Total'), findsOneWidget);
expect(find.text('In Stock'), findsWidgets);
expect(find.byType(AppCard), findsWidgets);
```
Fallback if a provider can't be overridden: assert `ProductListTile`/`AppCard` presence with `productsProvider` seeded; drop the count asserts (note it).

- [ ] **Step 6: Run — fails.**

- [ ] **Step 7: Migrate `inventory_screen.dart` + `cost_display_toggle.dart`** per Exact spec: stat `Container`→`AppCard(onTap:…, radius:AppRadius.md, padding: EdgeInsets.symmetric(vertical:11,horizontal:4))`; count `18/700` with the icon-vs-value color split; selected = 1.5px colored border (inner). Swap all `CupertinoIcons.*`→Lucide (`back→chevronLeft`, `arrow_up_arrow_down→arrowUpDown`, `arrow_up/down→arrowUp/arrowDown`, `add→plus`, `cloud_download→download`, `cube_box→package`, `checkmark_circle→checkCircle`, `exclamationmark_triangle→alertTriangle`, `exclamationmark_circle→alertCircle`, `square_grid_2x2→layoutGrid`, `xmark→x`, `search→search`, `line_horizontal_3_decrease→slidersHorizontal`, overflow→`moreVertical`, empty-filter `Icons.filter_alt_off_outlined`→`slidersHorizontal`). `cost_display_toggle.dart`: `eye`/`eye_slash`→`eye`/`eyeOff` Lucide.

- [ ] **Step 8: Run inventory + tile tests — pass.**

- [ ] **Step 9: Analyze** the three files — clean.

- [ ] **Step 10: Commit** `feat(inventory): list + tile → AppCard, filled pills, Lucide (bundle 04)`.

---

## Task 3: Product form — sectioned cards, margin line, pinned submit, Lucide

**Files:** Modify `product_form_screen.dart`; Test `product_form_screen_test.dart`.

**Interfaces:** Consumes `AppCard`, `AppShadows.pinnedFooter`/`primaryButton`, `LucideIcons`, `AppIcons.peso`, `.toCurrency()`. New private helpers `_sectionHeader`, `_sectionCard`, `_marginLine`, `_buildSubmitFooter`.

**Exact spec (from prototype):**
- **Section header**: render UPPERCASE, 11/600, letter-spacing 0.8, muted, margin `top 18, left 2, bottom 8`. Titles: `IDENTITY · PRICING · STOCK · CLASSIFICATION · AUDIT`.
- **Section card**: `AppCard(radius:16, padding: EdgeInsets.all(14))`, margin-bottom via header spacing.
- **Field**: label 12 muted, margin `bottom 5, left 2`, required `*` in error color. Input min-height 46, fill `#FAFAFA`/`#0C1415`, border 1px `#E2E2E2`/`#2C3C3E`, radius **14**, padding 0×13 (two-up 0×12), icon 18 (two-up 17) muted stroke 1.75, value 14 text (SKU mono).
- **Two-up pairs** (gap 10): Selling+Cost; Quantity+Reorder.
- **Labels (shortened to match prototype):** `SKU *`, `Product Name *`, **`Selling (₱) *`**, `Cost (₱) *`, **`Quantity *`**, **`Reorder at`**, `Unit`, `Barcodes`, `Category`, `Supplier`, `Notes`. (Validation messages unchanged.)
- **SKU helper (shortened):** `Changing the SKU keeps past sales & receiving history intact.`
- **Margin line** (margin-top 10): `trendingUp` 15 stroke 1.9 in successText + text 12 muted: `Margin ` + **bold** `28%` (successText, 700) + ` · ` + `${(price-cost).toCurrency()} per unit`. Hidden when price≤0/cost≤0/cost>price.
- **View price history**: outlined button height 46, radius 14, card bg + 1px field-border, primary text, 14/600, margin-top 14, `clock` 16.
- **Submit footer**: `Container(bg: scaffoldBg, boxShadow: AppShadows.pinnedFooter)` → `SafeArea(top:false)` → padding 12×16×16 → button height 50, radius 16, primary fill, 15/600, `AppShadows.primaryButton`, `save` 18 + `Add Product`/`Update Product`, `Key('product-form-submit')`.
- **Icons:** `back→chevronLeft, trash→trash2, qrcode→qrCode, arrow_2_circlepath→refreshCw, cube_box→box, tag→tag, number→hash, exclamationmark_triangle→alertTriangle, barcode_viewfinder→scanLine, list_bullet→list, briefcase→briefcase, lock→lock, info_circle→info, clock→clock, tray_arrow_down→save, square_grid_2x2→layoutGrid`; **Cost keeps `AppIcons.peso`**; Unit `Icons.straighten→LucideIcons.ruler`.
- **Locked fields:** replace `AbsorbPointer`+`Opacity(0.38)` (cashier Unit/Category) with `enabled:false` field + helper reason line (`Cashiers can edit name and image only`). Keep the existing price helper `Only admin can change price`.

- [ ] **Step 1: Failing tests — sections, margin line, pinned submit** (reuse/extend existing admin harness; seed product price 250 cost 180):
```dart
expect(find.text('IDENTITY'), findsOneWidget);
expect(find.text('PRICING'), findsOneWidget);
expect(find.textContaining('Margin'), findsOneWidget);
expect(find.textContaining('28%'), findsWidgets);     // (250-180)/250
expect(find.textContaining('₱70.00 per unit'), findsOneWidget);
expect(find.byKey(const Key('product-form-submit')), findsOneWidget);
expect(find.text('Selling (₱) *'), findsOneWidget);    // shortened label
```

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Add `_sectionHeader`/`_sectionCard`/`_marginLine`/`_buildSubmitFooter` helpers** (margin line uses successText(isDark); add `_priceController`/`_costController` listeners in `initState` → `setState` guarded by `mounted` so margin updates live).

- [ ] **Step 4: Regroup body + pin footer** — `body: _isLoading ? spinner : Column(children:[Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: Form(key:_formKey, child: Column(children:[ roleBanner?, imageUploader, _sectionHeader('IDENTITY'), _sectionCard(children:[sku, name]), _sectionHeader('PRICING'), _sectionCard(children:[Row(Expanded(selling),SizedBox(width:10),Expanded(cost)), _marginLine(theme)]), _sectionHeader('STOCK'), _sectionCard(children:[Row(qty,reorder), unit, barcodes]), _sectionHeader('CLASSIFICATION'), _sectionCard(children:[category, supplier?, notes]), if(editing&&existing)...[_sectionHeader('AUDIT'), _AuditInfoCard(...)], priceHistoryLink? ])))), _buildSubmitFooter(context)])`. Move existing field widgets into cards unchanged except labels/helper/icons; keep controllers, validators, `enabled` gates.

- [ ] **Step 5: Apply shortened labels, SKU helper, Lucide icons, locked-field treatment** per Exact spec.

- [ ] **Step 6: Run form tests — pass** (new + all existing).

- [ ] **Step 7: Analyze** `product_form_screen.dart` — clean.

- [ ] **Step 8: Commit** `feat(inventory): product form → sectioned AppCards, margin line, pinned submit, Lucide (bundle 04)`.

---

## Task 4: Price history — sparkline card + rows card, Lucide

**Files:** Modify `price_history_screen.dart`; Test `price_history_screen_test.dart`.

**Exact spec (from prototype):**
- **Segmented** (`All/Price/Cost`) as a pill on an `AppCard` (radius pill, padding 4): selected primary-fill 13/600 onPrimary, unselected 13/500 muted.
- **Sparkline card** (`AppCard`, radius 18, padding 16, margin-top 14): per metric a header `Row(space-between, baseline)` — left `Price trend`/`Cost trend` 11 muted, right `${first.toCurrencyCompact()} → ${last.toCurrencyCompact()}` 13/600 text. Chart below (existing `_Sparkline`, height 40, stroke width 2.5 round caps): price stroke primary (`#283E46`/`#E8B84C`), cost stroke `#9AA0A3`/`#6C797C`. Keep `Not enough changes to chart` fallback (<2 pts).
- **Changes** section header (11/600 uppercase muted) then **rows `AppCard`** (radius 18, padding `4 × 16`): each row padding 12×0, hairline bottom border (`#F0F0F0`/`#243234`) except last. Metrics `Row(gap 18)`: per metric — label 12 muted + value 13/600 (`entry.price.toCurrencyCompact()`) + (delta) `arrowUp`/`arrowDown` 12 stroke 2.2 (up successText / down error-or-`#FF6B5E` dark) + delta `value.toCurrencyCompact()` 12/500 colored. Meta `Wrap(gap 7, top 7)`: date (`MMM d, y • h:mm a`) + `•` + who 12/500 text + source badge (11, border hairline, radius 7, padding 1×6) via `derivePriceHistorySource`.
- **Icons:** `back→chevronLeft`; delta `arrow_up/down→arrowUp/arrowDown`.

- [ ] **Step 1: Failing test — from→to labels + AppCard** (multi-entry `_pump` exists; import `app_card`):
```dart
expect(find.byType(AppCard), findsWidgets);
expect(find.textContaining('→'), findsWidgets);
```

- [ ] **Step 2: Run — fails.**

- [ ] **Step 3: Migrate `price_history_screen.dart`** per Exact spec: cupertino import → `lucide_icons` + `app_card`; wrap segmented/sparklines/rows in `AppCard`s; two-part trend labels using `toCurrencyCompact()` on series endpoints; `_MetricLine` values + deltas → `toCurrencyCompact()`; Lucide arrows + back.

- [ ] **Step 4: Run price-history tests — pass** (new + existing empty/single/delta).

- [ ] **Step 5: Analyze** — clean.

- [ ] **Step 6: Commit** `feat(inventory): price history → AppCard sparkline + rows, Lucide (bundle 04)`.

---

## Task 5: Full verification + branch finish

- [ ] **Step 1:** `flutter analyze` (clean for changed files) + `flutter test -p vm` (all green; update any test asserting old un-grouped currency strings).
- [ ] **Step 2:** `/code-review` the branch diff vs `main`.
- [ ] **Step 3:** `/verify` — run app; confirm all three Inventory screens match the prototype in **light AND dark**; role-gating + dialogs + receipt totals intact.
- [ ] **Step 4:** Finish branch via `superpowers:finishing-a-development-branch` (merge to `main` + push — Claude Design reads the repo).

---

## Self-Review

**Spec coverage** — every prototype change mapped: grouped currency + compact (Task 1, decided); consistent `AppCard` elevation + 18/700 stats + color split (Task 2); filled price pill + filled margin badge + compact cost + theme-aware low color + radii (Task 2); Lucide everywhere (Tasks 2–4); sectioned form + two-up + live margin line + pinned submit + shortened labels + short SKU helper + locked-field treatment (Task 3); price-history sparkline card with two-part trend labels + rows card + compact values (Task 4). ✓

**Decisions baked in:** decimals-only-when-needed (`toCurrencyCompact`), grouping app-wide (`toCurrency` adoption), short SKU helper — all from the user's answers.

**Documented deviations from prototype icon map:** cost = `AppIcons.peso` (no `philippinePeso` in 0.257.0); barcode-add = `LucideIcons.scanLine` (no `scanBarcode`).

**Risks:** (1) app-wide currency adoption may flip existing tests asserting `₱1234.00` → `₱1,234.00`; Task 1 Step 6 handles. (2) Receipt formatting is print-styled — Task 1 Step 5 keeps its layout, Task 5 Step 3 verifies totals. (3) Widget-test provider overrides need exact identifiers — read before finalizing; narrower fallback given.
