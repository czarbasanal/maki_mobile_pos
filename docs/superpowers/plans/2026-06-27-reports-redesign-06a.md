# Reports Redesign (Bundle 06a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the four Reports surfaces (Sales History, Sales Report, Profit Report, Top Selling) onto the elevated global theme — soft-shadow `AppCard` surfaces, Lucide icons, per-payment-method pill/bar visuals, refined rank medals — preserving all role gating and dark parity, pixel-faithful to the hifi handoff.

**Architecture:** Behavior-preserving restyle. No providers, repositories, use-cases, routes, or Firestore touched. One new pure helper (`PaymentMethodStyle`) centralizes per-method icon + pill colors + bar fill. Existing shared widgets (`DateRangePicker`, `SalesSummaryCard`, `TopProductsCard`) are restyled in place; the four screens are restyled to wrap their content in `AppCard`. Dead `reports_screen.dart` is deleted.

**Tech Stack:** Flutter, Riverpod, `lucide_icons ^0.257.0`, bundled Figtree + RobotoMono fonts, `flutter_test`.

## Global Constraints

- **Source of truth:** `design/design_handoff_reports/MAKI POS Reports.dc.html` — where this plan and the HTML disagree, the HTML wins. Match light + dark pixel-for-pixel.
- **Do not invent theme tokens.** Reuse `lib/core/theme/` (`AppColors`, `AppRadius`, `AppSpacing`, `AppShadows`). Component-specific literal radii not covered by a token (5, 7, 11, 13) are allowed inline; everything semantic comes from tokens.
- **`AppCard`** (`lib/presentation/shared/widgets/common/app_card.dart`, exported via `common_widgets.dart`): default radius `AppRadius.lg` (18); light = soft shadow, dark = `darkCard` + 1px `darkHairline`. Use it for every container surface — no leftover Material `Card`.
- **Icons → Lucide** (`package:lucide_icons/lucide_icons.dart`, `LucideIcons.camelCase`), stroke is package default. Migrate Reports off Cupertino entirely.
- **Primary flips by theme:** slate `#283E46` in light, gold `#E8B84C` in dark — already encoded as `theme.colorScheme.primary`. Use `theme.colorScheme.primary` for day totals, Net Sales value, card-head icons, date-picker icons, rank-1 medal.
- **Mono font:** sale numbers (`SALE-…`) and SKUs (`ngk-014`) use `fontFamily: 'RobotoMono'`.
- **Currency:** grouped `₱1,234.00` via existing `num` extension `.toCurrency()`. Do not change number formatting.
- **App bar stays flat** on the screen canvas (no `PreferredSize` shadow — Reports differ from POS here).
- **Color discipline:** neutral by default; color only for status (green profit, red voids) and the amber/silver/bronze rank medals. Dark parity on every screen.
- **Role gating must survive exactly** (see Task 3 & Task 5): daily-reports-only roles get the forced-today warning banner instead of the picker + an "Earlier days are not available for your role" footer on Sales History; `Total Cost` / `Gross Profit` (+ margin) / `Service Revenue` / `Service Profit` / `Average sale value` / per-row profit badge / the whole Profit Report are **admin-only**; cashier Sales Summary stops at Net Sales with a "Cost & profit are hidden for your role" lock note.
- Verify after every task: `flutter test` (changed files' tests) and `flutter analyze` (clean).

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `lib/presentation/mobile/widgets/reports/payment_method_style.dart` | Pure per-`PaymentMethod` visuals: Lucide icon, pill fg/bg (light+dark), progress-bar fill (light+dark) | Create |
| `lib/presentation/mobile/widgets/reports/reports_widgets.dart` | Barrel — add the new helper export | Modify |
| `lib/presentation/mobile/widgets/reports/date_range_picker.dart` | Two `AppCard` pills (preset dropdown + range), Lucide, gold-in-dark | Modify |
| `lib/presentation/mobile/widgets/reports/sales_summary_card.dart` | Metric mini-cards, tinted Net Sales panel, Admin-only lock divider, average row, cashier lock note | Modify |
| `lib/presentation/mobile/widgets/reports/top_products_card.dart` | Refined rank medals + share bars + admin profit badge, in `AppCard` | Modify |
| `lib/presentation/mobile/screens/reports/sales_list_screen.dart` | Per-day `AppCard` groups, tinted leading squares, payment pills, VOID, daily-only banner + earlier-days footer | Modify |
| `lib/presentation/mobile/screens/reports/sales_report_screen.dart` | `AppCard`s, per-method payment bars, EOD tile, daily-only warning card | Modify |
| `lib/presentation/mobile/screens/reports/top_selling_screen.dart` | Inherits restyled `TopProductsCard`; flat app bar | Modify |
| `lib/presentation/mobile/screens/reports/profit_report_screen.dart` | Date strip + "Change" pill, 4 metric cards, empty-state circle | Modify |
| `lib/presentation/mobile/screens/reports/reports_screen.dart` | Dead (0 bytes, 0 refs) | Delete |
| `lib/presentation/mobile/screens/reports/reports.dart` | Barrel — remove if it referenced the dead file (it only exports sales_list + sales_report) | Verify/Modify |
| `test/presentation/widgets/payment_method_style_test.dart` | Helper unit tests | Create |
| `test/presentation/widgets/sales_list_role_test.dart` | Daily-only banner + earlier-days footer + payment-pill presence | Create |
| `test/presentation/widgets/sales_summary_card_role_test.dart` | Cashier lock note + admin gating | Create |

---

## Task 0: Branch

- [ ] **Step 1: Create the feature branch**

Run:
```bash
cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos
git checkout -b feat/reports-redesign-06a
```
Expected: `Switched to a new branch 'feat/reports-redesign-06a'`

---

## Task 1: PaymentMethodStyle helper (TDD)

**Files:**
- Create: `lib/presentation/mobile/widgets/reports/payment_method_style.dart`
- Modify: `lib/presentation/mobile/widgets/reports/reports_widgets.dart`
- Test: `test/presentation/widgets/payment_method_style_test.dart`

**Interfaces:**
- Consumes: `PaymentMethod` (`lib/core/enums/enums.dart`), `LucideIcons`.
- Produces: `PaymentMethodStyle.iconFor(PaymentMethod) → IconData`, `.pillFg(PaymentMethod, {required bool dark}) → Color`, `.pillBg(PaymentMethod, {required bool dark}) → Color`, `.barFill(PaymentMethod, {required bool dark}) → Color`. All `static`, pure.

Exact values (from the handoff token tables — ARGB hex):

| Method | icon | pillFg light/dark | pillBg light/dark | barFill light/dark |
|---|---|---|---|---|
| cash | `banknote` | `0xFF2E7D32` / `0xFF8FE39A` | `0xFFE8F5E9` / `0x294CAF50` | `0xFF4CAF50` / `0xFF5FC86A` |
| gcash | `smartphone` | `0xFF024A99` / `0xFF7FB6FF` | `0xFFE3F0FF` / `0x33007DFE` | `0xFF007DFE` / `0xFF5AA9F0` |
| maya | `wallet` | `0xFF283E46` / `0xFFB8C4C4` | `0x12283E46` / `0x12FFFFFF` | `0xFF283E46` / `0xFF9FB0B0` |
| mixed | `layers` | `0xFF5A6468` / `0xFF9FB0B0` | `0x0F283E46` / `0x0FFFFFFF` | `0xFF283E46` / `0xFF9FB0B0` |
| salmon | `fish` | `0xFF5A6468` / `0xFFB8C4C4` | `0x0F283E46` / `0x12FFFFFF` | `0xFF283E46` / `0xFF9FB0B0` |

(Opacity→alpha: .06≈0x0F, .07≈0x12, .16≈0x29, .2≈0x33.)

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/widgets/payment_method_style_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/payment_method_style.dart';

void main() {
  group('PaymentMethodStyle', () {
    test('maps each method to its Lucide icon', () {
      expect(PaymentMethodStyle.iconFor(PaymentMethod.cash), LucideIcons.banknote);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.gcash), LucideIcons.smartphone);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.maya), LucideIcons.wallet);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.mixed), LucideIcons.layers);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.salmon), LucideIcons.fish);
    });

    test('pill colors differ by theme', () {
      expect(PaymentMethodStyle.pillFg(PaymentMethod.cash, dark: false),
          const Color(0xFF2E7D32));
      expect(PaymentMethodStyle.pillFg(PaymentMethod.cash, dark: true),
          const Color(0xFF8FE39A));
      expect(PaymentMethodStyle.pillBg(PaymentMethod.gcash, dark: false),
          const Color(0xFFE3F0FF));
    });

    test('every method resolves a non-null bar fill in both themes', () {
      for (final m in PaymentMethod.values) {
        expect(PaymentMethodStyle.barFill(m, dark: false), isA<Color>());
        expect(PaymentMethodStyle.barFill(m, dark: true), isA<Color>());
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/payment_method_style_test.dart`
Expected: FAIL — `payment_method_style.dart` / `PaymentMethodStyle` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/presentation/mobile/widgets/reports/payment_method_style.dart
import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// Per-[PaymentMethod] visual language for the Reports surfaces — the Lucide
/// glyph, the list-row pill (foreground + tinted fill), and the Sales-Report
/// breakdown bar fill. Light/dark values come straight from the 06a handoff.
class PaymentMethodStyle {
  const PaymentMethodStyle._();

  static IconData iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return LucideIcons.banknote;
      case PaymentMethod.gcash:
        return LucideIcons.smartphone;
      case PaymentMethod.maya:
        return LucideIcons.wallet;
      case PaymentMethod.mixed:
        return LucideIcons.layers;
      case PaymentMethod.salmon:
        return LucideIcons.fish;
    }
  }

  static Color pillFg(PaymentMethod m, {required bool dark}) {
    switch (m) {
      case PaymentMethod.cash:
        return dark ? const Color(0xFF8FE39A) : const Color(0xFF2E7D32);
      case PaymentMethod.gcash:
        return dark ? const Color(0xFF7FB6FF) : const Color(0xFF024A99);
      case PaymentMethod.maya:
        return dark ? const Color(0xFFB8C4C4) : const Color(0xFF283E46);
      case PaymentMethod.mixed:
        return dark ? const Color(0xFF9FB0B0) : const Color(0xFF5A6468);
      case PaymentMethod.salmon:
        return dark ? const Color(0xFFB8C4C4) : const Color(0xFF5A6468);
    }
  }

  static Color pillBg(PaymentMethod m, {required bool dark}) {
    switch (m) {
      case PaymentMethod.cash:
        return dark ? const Color(0x294CAF50) : const Color(0xFFE8F5E9);
      case PaymentMethod.gcash:
        return dark ? const Color(0x33007DFE) : const Color(0xFFE3F0FF);
      case PaymentMethod.maya:
        return dark ? const Color(0x12FFFFFF) : const Color(0x12283E46);
      case PaymentMethod.mixed:
        return dark ? const Color(0x0FFFFFFF) : const Color(0x0F283E46);
      case PaymentMethod.salmon:
        return dark ? const Color(0x12FFFFFF) : const Color(0x0F283E46);
    }
  }

  static Color barFill(PaymentMethod m, {required bool dark}) {
    switch (m) {
      case PaymentMethod.cash:
        return dark ? const Color(0xFF5FC86A) : const Color(0xFF4CAF50);
      case PaymentMethod.gcash:
        return dark ? const Color(0xFF5AA9F0) : const Color(0xFF007DFE);
      case PaymentMethod.maya:
      case PaymentMethod.mixed:
      case PaymentMethod.salmon:
        return dark ? const Color(0xFF9FB0B0) : const Color(0xFF283E46);
    }
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `lib/presentation/mobile/widgets/reports/reports_widgets.dart`:
```dart
export 'payment_method_style.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/presentation/widgets/payment_method_style_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/payment_method_style.dart \
        lib/presentation/mobile/widgets/reports/reports_widgets.dart \
        test/presentation/widgets/payment_method_style_test.dart
git commit -m "feat(reports): payment-method style helper (icon + pill + bar, dark parity)"
```

---

## Task 2: DateRangePicker → AppCard pills + Lucide

**Files:**
- Modify: `lib/presentation/mobile/widgets/reports/date_range_picker.dart`
- Test: `test/presentation/widgets/date_range_picker_test.dart` (existing — must stay green)

**Interfaces:**
- Consumes: nothing new. Keep the public constructor and `DateRangePreset` enum unchanged.
- Produces: same widget API. **Keep `DropdownButtonFormField<DateRangePreset>`** as the preset control (the existing test taps it) — only restyle it to look like the pill.

**Design (HTML lines 59–62):** a `Row`, `gap 8`, padding `EdgeInsets.fromLTRB(16,14,16,12)`, no bottom border now. Two children: preset pill `Expanded(flex: 1)`, range pill `Expanded(flex: 1` → use `flex: 13` vs `10` to mirror `1.3:1`, i.e. preset `flex:10`, range `flex:13`). Each pill = `AppCard(radius: AppRadius.md /*14*/, padding: EdgeInsets.symmetric(horizontal: 13), child: SizedBox(height: 46, child: Row(...)))`.
- Preset pill: `LucideIcons.calendarDays` (17px, `theme.colorScheme.primary`), label 14/w600 `colorScheme.onSurface` `nowrap`, trailing `LucideIcons.chevronDown` (16px, muted). The dropdown is transparent/borderless inside the pill.
- Range pill: `LucideIcons.calendar` (17px, primary), date label 13/w500 ellipsis, trailing `LucideIcons.chevronDown` (16px muted). `onTap` → `_showCustomDatePicker`.
- Remove the slate `OutlineInputBorder`; the `AppCard` is the surface. Set the dropdown `decoration` to `InputBorder.none`, `isDense`, no fill.

- [ ] **Step 1: Add the failing assertions to the existing test**

Append inside `group('DateRangePicker', ...)` in `test/presentation/widgets/date_range_picker_test.dart`:
```dart
    testWidgets('renders Lucide calendar icons inside AppCard pills',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _Harness(),
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
      expect(find.byIcon(LucideIcons.calendar), findsOneWidget);
      expect(find.byType(AppCard), findsNWidgets(2));
    });
```
Add imports at the top of the test file:
```dart
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```
And a small harness widget at the bottom of the file:
```dart
class _Harness extends StatelessWidget {
  const _Harness();
  @override
  Widget build(BuildContext context) => DateRangePicker(
        startDate: DateTime(2025, 2, 5),
        endDate: DateTime(2025, 2, 5),
        selectedPreset: DateRangePreset.today,
        onPresetChanged: (_) {},
        onCustomRangeSelected: (_, __) {},
      );
}
```

- [ ] **Step 2: Run to verify the new test fails**

Run: `flutter test test/presentation/widgets/date_range_picker_test.dart`
Expected: FAIL — `AppCard` not found / Cupertino icons present instead of Lucide.

- [ ] **Step 3: Restyle `date_range_picker.dart`**

Replace Cupertino imports with `package:lucide_icons/lucide_icons.dart` and import `common_widgets.dart`. Rebuild `_buildPresetDropdown` and `_buildDatePill` to wrap their content in `AppCard(radius: AppRadius.md, padding: const EdgeInsets.symmetric(horizontal: 13), child: SizedBox(height: 46, child: ...))`. Preset icons `LucideIcons.calendarDays` + `LucideIcons.chevronDown`; range icons `LucideIcons.calendar` + `LucideIcons.chevronDown`. Set the dropdown `decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)` and `icon: const SizedBox.shrink()` (render the chevron yourself as a trailing widget so layout matches). Keep `key: ValueKey('preset:${selectedPreset.name}')`, `isExpanded: true`, and the `onChanged` logic (custom → `_showCustomDatePicker`, else `onPresetChanged`). Container padding becomes `EdgeInsets.fromLTRB(16,14,16,12)`, remove the bottom hairline border. Use `flex: 10` (preset) and `flex: 13` (range).

- [ ] **Step 4: Run the full picker test file**

Run: `flutter test test/presentation/widgets/date_range_picker_test.dart`
Expected: PASS (all 4 tests — the 3 original + the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/date_range_picker.dart \
        test/presentation/widgets/date_range_picker_test.dart
git commit -m "style(reports): DateRangePicker → AppCard pills + Lucide (bundle 06a)"
```

---

## Task 3: SalesSummaryCard restyle + cashier lock note (TDD)

**Files:**
- Modify: `lib/presentation/mobile/widgets/reports/sales_summary_card.dart`
- Test: `test/presentation/widgets/sales_summary_card_role_test.dart` (create); keep `sales_summary_card_labor_test.dart` green.

**Interfaces:**
- Consumes: `salesSummaryProvider`, `currentUserProvider` (unchanged), `PaymentMethodStyle` not needed here, `AppCard`.
- Produces: same `SalesSummaryCard({startDate, endDate})` API.

**Design (HTML 127–149, cashier 553–565):**
- Outer = `AppCard(padding: EdgeInsets.all(16))`.
- Header: `LucideIcons.barChart3` (20px, `colorScheme.primary`) + "Sales Summary" 15/w700.
- Metric mini-card (reusable private `_MetricCard`): `Container(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(13), padding: EdgeInsets.symmetric(horizontal:12, vertical:11))`. Label row = 15px Lucide icon + 11/w500 label (muted, `nowrap`, `Expanded`+ellipsis); value 15–17/w700; optional 10px sub. `accent` (success/error) recolors border + icon + label + value; default border = `AppColors.lightHairline`/`darkHairline`, icon+label muted, value `onSurface`.
  - Row 1: **Total Sales** (`LucideIcons.fileText`, value 17) · **Voided** (`LucideIcons.xCircle`, `accent: AppColors.error` when count>0 else neutral, value 17).
  - Row 2: **Gross Sales** (`LucideIcons.banknote`, value 15, sub "Before discounts") · **Discounts** (`LucideIcons.tag`, value 15, `-₱…`).
- **Net Sales panel:** `Container(decoration: BoxDecoration(color: dark ? const Color(0x1AE8B84C) : const Color(0x0F283E46), borderRadius: BorderRadius.circular(13)), padding: EdgeInsets.symmetric(horizontal:15, vertical:13))`, Row spaceBetween: "Net Sales" 14/w600 · value 20/w700 letterSpacing −0.3 `colorScheme.primary`.
- **Admin-only block** (`if (isAdmin)`):
  - Divider row: `Expanded(Divider)` + centered chip `Row(LucideIcons.lock 11px + "ADMIN ONLY" 10/w600 letterSpacing .5 uppercase, color hint)` + `Expanded(Divider)`, margins `15,0,13`.
  - Average row: `LucideIcons.divide` (14px muted) + "Average sale value" 11.5 muted + `Spacer` + value 11.5/w700 `onSurface`.
  - Row: **Total Cost** (`LucideIcons.package`, value 15) · **Gross Profit** (`LucideIcons.trendingUp`, `accent: AppColors.success`, value 15, sub "31.2% margin").
  - Row: **Service Rev.** (`LucideIcons.wrench`, value 15, sub "Labor · no COGS") · **Service Profit** (`LucideIcons.trendingUp`, `accent: AppColors.success`, value 15).
- **Cashier (non-admin) note** (`else`): under Net Sales, `Row(LucideIcons.lock 13px muted + "Cost & profit are hidden for your role" 11.5 muted)`, `margin-top:13`.

Keep the success accent on profit using `AppColors.success` (border/icon) + `AppColors.successDark`/`successOnDark` for the value via `AppColors.successText(dark)`.

- [ ] **Step 1: Write the failing role test**

```dart
// test/presentation/widgets/sales_summary_card_role_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

// NOTE: align provider overrides with the existing
// sales_summary_card_labor_test.dart in this same folder — copy its
// SalesSummary fixture + currentUserProvider override pattern verbatim,
// changing only the role. (Read that file first.)

void main() {
  testWidgets('cashier sees the lock note and no Gross Profit', (tester) async {
    // ...build with currentUserProvider -> cashier and a non-zero summary...
    // expect(find.text('Cost & profit are hidden for your role'), findsOneWidget);
    // expect(find.text('Gross Profit'), findsNothing);
    // expect(find.byIcon(LucideIcons.lock), findsOneWidget);
  });

  testWidgets('admin sees the Admin only divider and Gross Profit',
      (tester) async {
    // ...build with currentUserProvider -> admin...
    // expect(find.text('Gross Profit'), findsOneWidget);
    // expect(find.text('ADMIN ONLY'), findsOneWidget);
  });
}
```
> Before running, open `test/presentation/widgets/sales_summary_card_labor_test.dart` and replicate its exact `ProviderScope` overrides (the `SalesSummary` fixture and how `currentUserProvider` / `salesSummaryProvider` are overridden). Fill the `// ...` bodies with that wiring. This avoids guessing provider signatures.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/sales_summary_card_role_test.dart`
Expected: FAIL — strings/icons not present (old layout).

- [ ] **Step 3: Restyle `sales_summary_card.dart`**

Swap Cupertino→Lucide, wrap in `AppCard`, build `_MetricCard` per the design above, the tinted Net Sales panel, the Admin-only lock divider + average row, and the cashier lock note. Preserve all existing data bindings (`summary.totalSalesCount`, `voidedSalesCount`, `grossAmount`, `totalDiscounts`, `netAmount`, `averageSaleAmount`, `totalCost`, `totalProfit`, `profitMargin`, `laborRevenue`, `laborProfit`) and the `isAdmin` gate.

- [ ] **Step 4: Run both summary-card tests**

Run: `flutter test test/presentation/widgets/sales_summary_card_role_test.dart test/presentation/widgets/sales_summary_card_labor_test.dart`
Expected: PASS (new role test + existing labor test).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/sales_summary_card.dart \
        test/presentation/widgets/sales_summary_card_role_test.dart
git commit -m "style(reports): SalesSummaryCard → AppCard metrics, Net Sales panel, admin/cashier gating (06a)"
```

---

## Task 4: TopProductsCard restyle (rank medals + bars + profit badge)

**Files:**
- Modify: `lib/presentation/mobile/widgets/reports/top_products_card.dart`
- Test: `test/presentation/widgets/top_selling_today_widget_test.dart` is a *different* widget; this card has no dedicated widget test. Add lightweight assertions to a new group only if needed — otherwise rely on Task 6/7 screen smoke + analyze. (No new test file required; keep existing green.)

**Interfaces:**
- Consumes: `topSellingProductsProvider`, `currentUserProvider.hasPermission(Permission.viewProfitReports)`, `AppCard`, `AppTextStyles.productName`.
- Produces: same `TopProductsCard({startDate, endDate, limit=10})` API.

**Design (HTML 151–165, 236–257):**
- Outer = `AppCard(padding: EdgeInsets.fromLTRB(16,16,16,12))`.
- Header: `LucideIcons.star` (19px primary) + "Top Selling Products" 15/w700 + `Spacer` + "Top $limit" 11/w600 muted.
- Rank row (private `_RankRow`):
  - Medal: `Container(width:28,height:28, decoration: BoxDecoration(shape: circle, border: Border.all(color: ring, width: rank<=3?1.5:1)))`, centered number 12/w700 in number-color.
  - Name 13.5/w600 ellipsis (`AppTextStyles.productName` ok) over SKU 11.5 mono muted.
  - Right column: "N sold" 13.5/w700 over `₱revenue` 11.5 muted.
  - Second line: `SizedBox(width:28)` spacer + `Expanded(progress bar h6 r999, fill=barColor, track hairline)` + (admin) profit badge `Container(color: successFill, borderRadius:7, padding: 2x7, child: "+₱${profit.toStringAsFixed(0)}" 11/w700 successText)`.
- Rank palette (private `_RankColors rankColors(int index, bool dark)`), index 0-based:

| rank | ring | number light/dark | bar light/dark |
|---|---|---|---|
| 1 | `0xFFE8B84C` | `0xFFB07A12`/`0xFFE8B84C` | `0xFFE8B84C`/`0xFFE8B84C` |
| 2 | `0xFF90A4AE` | `0xFF5E7079`/`0xFFAEC0C6` | `0xFF90A4AE`/`0xFF90A4AE` |
| 3 | `0xFFB08D6F` | `0xFF8A6244`/`0xFFCBA890` | `0xFFB08D6F`/`0xFFB08D6F` |
| 4+ | `lightHairline`/`0xFF2C3C3E` | `lightTextMuted`/`darkTextSecondary` | `0xFF283E46`/`0xFF5E7A84` |

- Empty state: `LucideIcons.package` (40px muted) + "No sales data available" muted, centered.

- [ ] **Step 1: Restyle `top_products_card.dart`**

Implement the above. Keep the `canViewProfit` gate around the profit badge (so cashier rows show full-width bar, no badge). Keep `progress = quantitySold / maxQuantity`.

- [ ] **Step 2: Run the related existing test**

Run: `flutter test test/presentation/widgets/top_selling_today_widget_test.dart`
Expected: PASS (unaffected — different widget). 

- [ ] **Step 3: Analyze the file**

Run: `flutter analyze lib/presentation/mobile/widgets/reports/top_products_card.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/top_products_card.dart
git commit -m "style(reports): TopProductsCard → AppCard, refined rank medals + dark parity (06a)"
```

---

## Task 5: Sales History restyle + daily-only gating (TDD)

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_list_screen.dart`
- Test: `test/presentation/widgets/sales_list_role_test.dart` (create)

**Interfaces:**
- Consumes: `salesByDateRangeProvider(DateRangeParams)`, `currentUserProvider`, `RolePermissions.isDailyReportsOnly`, `PaymentMethodStyle`, `AppCard`, `SaleEntity`, `SaleStatus`.
- Produces: same screen.

**Design (HTML 57–108; daily-only frame 502–535):**
- App bar: `LucideIcons.chevronLeft` back, title "Sales History", trailing `LucideIcons.barChart3` (Reports). Flat (no shadow).
- Body when NOT daily-only: `DateRangePicker`, then per-day groups.
- **Day group:** header Row, padding `EdgeInsets.fromLTRB(18,4,18,8)`, baseline-aligned: left Column(day label 14/w700 + "N sales" 12 muted), right day total 16/w700 `colorScheme.primary`. Then `AppCard(margin: EdgeInsets.fromLTRB(16,0,16,14), radius: AppRadius.lg, padding: EdgeInsets.symmetric(horizontal:14, vertical:2))` containing the day's sale rows, each `Padding(vertical:11)` separated by a `Divider(height:1, color: hairline)` except the last (build with a list + `Divider` between).
- **Sale row:** Row gap 12: leading `Container(38x38, borderRadius:11, color: tint)` where normal tint = `dark ? const Color(0x0DFFFFFF) : const Color(0x12283E46)` + `LucideIcons.fileText` (19px, primary/`#9FB0B0` dark); voided tint = `dark ? const Color(0x29F44336) : const Color(0x1AF44336)` + `LucideIcons.xCircle` (19px error). Middle: sale number 12.5/w600 mono (voided → muted + lineThrough + `VOID` badge: `Container(border: Border.all(color: AppColors.error), borderRadius:5, padding: 1x4, child: "VOID" 9/w600 ls.5 error)`); sub 12 muted `time • cashier • N items`. Trailing Column(crossAxisEnd): grand total 15/w700 (voided → muted + lineThrough), then payment pill 4px below: `Container(borderRadius: pill, padding: 2x7, color: PaymentMethodStyle.pillBg(m,dark:dark), child: Row(Icon(PaymentMethodStyle.iconFor(m),12, pillFg) + label 10/w600 ls.3 pillFg))`.
- **Daily-only role:** replace `DateRangePicker` with warning banner: `Container(margin: EdgeInsets.fromLTRB(16,14,16,6), padding: 12x14, decoration: warning bg/border, child: Row(LucideIcons.alertTriangle 19px warningIcon + Column("Showing today's sales only" 13/w600 + "Your role can view the current day's sales." 11.5)))`. Warning tokens: light bg `0xFFFFF6E6` border `0xFFF0C36B` title `0xFF8A5E12` sub `0xFFA07A2E`; dark via `AppColors.warningOnDark`-family (bg `0x1FF5B547`, border `0x66F5B547`, text `warningOnDark`). After the (single Today) group, append a footer: `Center(Row(LucideIcons.lock 13px + "Earlier days are not available for your role" 12 muted))`, padding `4,16,16`.

- [ ] **Step 1: Write the failing role test**

```dart
// test/presentation/widgets/sales_list_role_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';

// Build a helper that pumps SalesListScreen inside a ProviderScope with:
//  - currentUserProvider overridden to a given UserRole
//  - salesByDateRangeProvider overridden to return a fixed List<SaleEntity>
// Mirror the override style used elsewhere in test/ (grep for
// salesByDateRangeProvider / currentUserProvider AsyncValue overrides).

void main() {
  testWidgets('daily-only role shows the forced-today banner + lock footer',
      (tester) async {
    // role = cashier (isDailyReportsOnly == true)
    // expect(find.text("Showing today's sales only"), findsOneWidget);
    // expect(find.text('Earlier days are not available for your role'),
    //     findsOneWidget);
    // expect(find.byType(DateRangePicker), findsNothing);
  });

  testWidgets('admin role shows the DateRangePicker, no banner', (tester) async {
    // role = admin
    // expect(find.byType(DateRangePicker), findsOneWidget);
    // expect(find.text("Showing today's sales only"), findsNothing);
  });
}
```
> Fill the bodies using the project's established Riverpod test wiring (override `currentUserProvider` with an `AsyncData<UserEntity>` and `salesByDateRangeProvider` with sample sales). Grep `test/` for an existing screen test that overrides `salesByDateRangeProvider` and copy its pattern.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/sales_list_role_test.dart`
Expected: FAIL — banner/footer strings absent (current code only hides the picker).

- [ ] **Step 3: Restyle `sales_list_screen.dart`**

Implement the design. Swap all Cupertino icons → Lucide; build the per-day `AppCard` group + sale rows + payment pills; add the daily-only warning banner (replacing the picker) and the "Earlier days are not available" footer. Keep `_groupSalesByDate`, the per-day completed-only total, navigation (`_navigateToSaleDetail`, Reports action), and the daily-only forced-today logic. Replace `_paymentIcon` with `PaymentMethodStyle.iconFor`.

- [ ] **Step 4: Run the role test**

Run: `flutter test test/presentation/widgets/sales_list_role_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_list_screen.dart \
        test/presentation/widgets/sales_list_role_test.dart
git commit -m "feat(reports): Sales History → AppCard day groups, payment pills, daily-only gating (06a)"
```

---

## Task 6: Sales Report screen restyle

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/sales_report_screen.dart`

**Design (HTML 112–182; cashier 539–590):**
- App bar: `LucideIcons.chevronLeft` back, title "Sales Report". Flat.
- Body: `DateRangePicker` (or, for daily-only roles, the existing warning `Container` — restyle it to use Lucide `LucideIcons.lock`/`alertTriangle` + warning tokens, keep the copy).
- `SalesSummaryCard` (Task 3) — already an `AppCard`, so drop the outer `Padding(all:16)` → use `Padding(fromLTRB(16,2,16,12))` wrappers consistent with the 16-margin/12-gap rhythm. Then `TopProductsCard` (Task 4) with `Padding(symmetric(horizontal:16))` + 12 gap.
- **Payment Methods card:** rebuild `_buildPaymentBreakdown` as `AppCard(padding: all 16)`: header `LucideIcons.wallet` (19px primary) + "Payment Methods" 15/w700. Each row: Row(label 13/w600 + `Spacer` + Row(amount 12.5/w600 onSurface + " · NN.N%" 12.5 muted)), then `ClipRRect(r999, LinearProgressIndicator(value: pct/100, minHeight:7, backgroundColor: hairline, valueColor: PaymentMethodStyle.barFill(method, dark:dark)))`. Map the breakdown entry's `PaymentMethod` key to `barFill`. Keep the `total == 0 → SizedBox.shrink()` guard.
- **EOD tile:** `AppCard(radius: AppRadius.field /*16*/, padding: EdgeInsets.symmetric(horizontal:16, vertical:14), onTap: → pushNamed(RouteNames.endOfDay))`: Row(leading `Container(40x40, r11, color: dark? 0x1FE8B84C : 0x12283E46)` + `LucideIcons.circleDollarSign` 21px primary; Column("End-of-Day Closing" 14.5/w600 + "Reconcile the cash drawer" 12 muted); `LucideIcons.chevronRight` 18px muted).

- [ ] **Step 1: Restyle the screen**

Implement the above; preserve `RefreshIndicator` invalidations and the `dailyOnly` branch.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/reports/sales_report_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/sales_report_screen.dart
git commit -m "style(reports): Sales Report → AppCards, per-method payment bars, EOD tile (06a)"
```

---

## Task 7: Top Selling screen restyle

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/top_selling_screen.dart`

**Design (HTML 222–262):** App bar `LucideIcons.chevronLeft` + "Top Selling", flat. Body = `DateRangePicker` + `Padding(all:16, child: TopProductsCard(..., limit: 20))` + 24px bottom gap. Most of the visual change comes free from Task 4. Just swap the Cupertino back icon → Lucide and keep the `_limit = 20` and preset defaults (This Month).

- [ ] **Step 1: Restyle the screen** (icon swap + spacing parity).

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/reports/top_selling_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/top_selling_screen.dart
git commit -m "style(reports): Top Selling → Lucide back icon, inherits restyled card (06a)"
```

---

## Task 8: Profit Report screen restyle

**Files:**
- Modify: `lib/presentation/mobile/screens/reports/profit_report_screen.dart`

**Design (HTML 184–219):**
- App bar: `LucideIcons.chevronLeft` back, title "Profit Report", trailing `LucideIcons.calendar` (→ `_selectDateRange`).
- Date strip: `Padding(fromLTRB(16,14,16,4), child: AppCard(radius: AppRadius.md, padding: symmetric(horizontal:14), child: SizedBox(height:48, child: Row(LucideIcons.calendar 18px primary + range 13.5/w500 Expanded + Change pill))))`. **Change pill:** `OutlinedButton`-style `Container`/`InkWell`: `Row(LucideIcons.pencil 12px + "Change" 12/w600 primary)`, border `dark? darkInputBorder : const Color(0xFFD9DEDD)`, `borderRadius: pill`, padding `5x11`, `onTap: _selectDateRange`.
- 4 metric cards (2×2) reusing the same outlined mini-card look as Sales Summary (border hairline / success; radius 13; value 18/w700): **Total Revenue** (`LucideIcons.banknote`) · **Total Cost** (`LucideIcons.wallet`) · **Gross Profit** (`LucideIcons.trendingUp`, success) · **Profit Margin** (`LucideIcons.percent`, success). Values stay `₱0.00` / `0.0%` (data wiring out of scope). Each card optionally carries the tiny shadow `AppShadows.card(dark:dark)` — but prefer wrapping each in `AppCard` for parity (radius 13 → pass `radius: 13`).
- "Profit by Product" header 15/w700 + "View All" 13/w600 primary (right), padding `18,18,6`.
- Empty state (Expanded, centered): `Container(66x66, shape circle, color: dark? 0x0DFFFFFF : 0x0F283E46, child: LucideIcons.trendingUp 30px hint)` + "No profit data available" 15/w700 + "Make some sales to see profit reports" 13 hint.

- [ ] **Step 1: Restyle the screen.**

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/reports/profit_report_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/mobile/screens/reports/profit_report_screen.dart
git commit -m "style(reports): Profit Report → AppCard date strip + metrics + empty state (06a)"
```

---

## Task 9: Delete dead reports_screen.dart + barrel hygiene

**Files:**
- Delete: `lib/presentation/mobile/screens/reports/reports_screen.dart`
- Verify: `lib/presentation/mobile/screens/reports/reports.dart` (barrel)

- [ ] **Step 1: Confirm zero references**

Run:
```bash
grep -rn "reports_screen.dart\|class ReportsScreen\|ReportsScreen(" lib test
```
Expected: no matches (file is 0 bytes; barrel exports only `sales_list_screen` + `sales_report_screen`).

- [ ] **Step 2: Delete the file**

Run: `git rm lib/presentation/mobile/screens/reports/reports_screen.dart`

- [ ] **Step 3: Analyze the package**

Run: `flutter analyze lib/presentation/mobile/screens/reports`
Expected: No issues (no dangling import).

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(reports): remove dead empty reports_screen.dart (06a)"
```

---

## Task 10: Full verification

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all green (≥744 prior + new tests). Investigate any Cupertino-icon matcher failures introduced by the swap (none expected in reports per the theme map; fix if any surface).

- [ ] **Step 3: `/code-review`** the diff (correctness + cleanups), address findings.

- [ ] **Step 4: `/verify`** — run the app, smoke all four screens in light + dark, admin + cashier (daily-only), against the prototype frames.

- [ ] **Step 5: Finish branch** via `superpowers:finishing-a-development-branch` (merge to `main`; mobile ships via APK per release process). Update `design/handoff/ROADMAP.md` (mark 06a done) and the `project_mobile_theme_redesign` memory.

---

## Notes for the implementer

- The four screens share three spacing rhythms from the HTML: outer card margin **16**, inter-card gap **12**, card inner padding **16**. Keep them consistent.
- `theme.colorScheme.primary` already flips slate→gold by theme — never hardcode slate where the primary is intended (day totals, Net Sales value, card-head icons, rank-1 medal, date-picker icons).
- Dark hairline/track is `AppColors.darkHairline` (`#243234`); light is `AppColors.lightHairline` (`#ECECEC`). Bar tracks and metric borders use these.
- Success value text: use `AppColors.successText(dark)` (already exists). Success fill for the profit badge: `AppColors.successFill(dark)`.
- Do not add an app-bar shadow (`PreferredSize`/`pinnedHeader`) — Reports app bars are flat on canvas in the prototype.
- Watch the `find.byIcon(CupertinoIcons.*)` sweep: the theme map found none in reports tests, but run `grep -rn "CupertinoIcons" test/` after Task 9 to be sure.
