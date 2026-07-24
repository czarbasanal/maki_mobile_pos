# Mono Identifier Fonts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every SKU, sale series number, and JO series number renders in the bundled RobotoMono font, via one canonical token.

**Architecture:** Repoint `AppTextStyles.monoFontFamily` to `'RobotoMono'` (all existing mono sites unify silently), replace font-family string literals with the token, then add the token to the enumerated not-yet-mono identifier sites. Two shared widgets grow a tiny opt-in (`AppBottomSheet.titleStyle`, receipt `_buildInfoRow` mono flag). Styling only — sizes/weights/colors/layout unchanged.

**Tech Stack:** Flutter; RobotoMono already bundled in pubspec (`family: RobotoMono`).

**Spec:** `docs/superpowers/specs/2026-07-24-mono-identifiers-design.md`

## Global Constraints

- Branch: `feat/mono-identifiers` (created; spec committed).
- Styling-only: no data/flow/schema/rules/layout changes; keep each site's existing fontSize/weight/color; only add/replace `fontFamily`.
- Prose exclusions stay untouched: `request_void_dialog.dart` sentence, `price_change_report_screen.dart` "Name (SKU)" labels, delete-confirm dialogs, all Receiving "Draft" wording.
- After Task 1, `grep -rn "fontFamily: 'RobotoMono'\|fontFamily: 'monospace'" lib/` must return ZERO hits (token-only).
- Verify per task with the named test files; full `flutter test` + `flutter analyze` in Task 3.

---

### Task 1: Canonical token + literal cleanup

**Files:**
- Modify: `lib/core/theme/app_text_styles.dart:22` (token) + doc comment
- Modify (literal→token): `lib/presentation/mobile/widgets/inventory/product_list_tile.dart`, `lib/presentation/mobile/widgets/inventory/cost_code_pill.dart`, `lib/presentation/mobile/widgets/receiving/receiving_item_row.dart`, `lib/presentation/mobile/widgets/receiving/import_preview.dart`, `lib/presentation/shared/widgets/dashboard/rank_row.dart`, `lib/presentation/shared/widgets/dashboard/recent_sale_widget.dart`, `lib/presentation/mobile/screens/sales/void_requests_screen.dart`, `lib/presentation/mobile/screens/reports/sales_list_screen.dart`, `lib/presentation/mobile/widgets/pos/checkout_success_dialog.dart` — plus ANY other hit from the grep below
- Test: `test/core/theme/app_text_styles_test.dart` (create if absent)

**Interfaces:**
- Produces: `AppTextStyles.monoFontFamily == 'RobotoMono'` — Task 2 uses this token at every new site.

- [ ] **Step 1: Write the failing test**

Create (or extend) `test/core/theme/app_text_styles_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/app_text_styles.dart';

void main() {
  test('mono token is the bundled RobotoMono family', () {
    expect(AppTextStyles.monoFontFamily, 'RobotoMono');
  });

  test('code and costCode styles carry the mono family', () {
    expect(AppTextStyles.code.fontFamily, 'RobotoMono');
    expect(AppTextStyles.costCode.fontFamily, 'RobotoMono');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/theme/app_text_styles_test.dart`
Expected: FAIL — `monoFontFamily` is `'monospace'`.

- [ ] **Step 3: Implement**

(a) In `lib/core/theme/app_text_styles.dart`, replace the token line and its comment:

```dart
  /// Bundled monospace family (RobotoMono Medium/SemiBold in pubspec) — the
  /// canonical font for identifiers (SKU / sale no / JO no), cost codes,
  /// and any code-like UI text. Always use this token, never a literal.
  static const String monoFontFamily = 'RobotoMono';
```

(b) Find every font-family literal:

Run: `grep -rn "fontFamily: 'RobotoMono'\|fontFamily: 'monospace'" lib/`

For EACH hit (the Files list above is the known set), replace the literal with `AppTextStyles.monoFontFamily` and add
`import 'package:maki_mobile_pos/core/theme/theme.dart';` (or the file's existing theme import style — many already import the barrel; do not double-import) if the symbol is unresolved.

- [ ] **Step 4: Run to verify**

Run: `flutter test test/core/theme/app_text_styles_test.dart` → PASS.
Run: `grep -rn "fontFamily: 'RobotoMono'\|fontFamily: 'monospace'" lib/` → no output.
Run: `flutter analyze` → No issues.
Run: `flutter test test/presentation/` → all pass (no test asserts fonts yet, so this catches only compile breaks).

- [ ] **Step 5: Commit**

```bash
git add lib/ test/core/theme/app_text_styles_test.dart
git commit -m "refactor(mobile): canonical RobotoMono token; replace font-family literals"
```

---

### Task 2: New mono sites (SKU / Sale No / JO No) + style tests

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (~202 header, ~321 item line)
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart` (~201)
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart` (~205)
- Modify: `lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart` (~332)
- Modify: `lib/presentation/mobile/widgets/pos/cart_item_tile.dart` (~85)
- Modify: `lib/presentation/mobile/screens/sales/void_requests_screen.dart` (`_lineRow` sub text ~552)
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart` (SKU field style ~653)
- Modify: `lib/presentation/mobile/widgets/pos/receipt_widget.dart` (`_buildInfoRow` mono flag)
- Modify: `lib/presentation/mobile/widgets/pos/void_sale_dialog.dart` (~173)
- Modify: `lib/presentation/mobile/widgets/drafts/draft_list_tile.dart` (~68)
- Modify: `lib/presentation/shared/widgets/common/app_bottom_sheet.dart` (optional `titleStyle`)
- Modify: `lib/presentation/mobile/widgets/drafts/draft_detail_sheet.dart` (~46)
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (~186)
- Test (extend, follow each file's existing harness): `test/presentation/widgets/sale_detail_screen_item_card_test.dart`, `test/presentation/widgets/draft_list_tile_test.dart`, and the sales-history row test in `test/presentation/widgets/sales_list_role_test.dart` (or the file that pumps `SalesListScreen` rows — grep first)

**Interfaces:**
- Consumes: `AppTextStyles.monoFontFamily` from Task 1.
- Produces: `AppBottomSheet` gains `final TextStyle? titleStyle;` (constructor param, merged over its default title style) — other sheets unaffected (null default).

- [ ] **Step 1: Write the failing style tests**

READ each named test file first and reuse its existing harness/fixtures. Add, adapting finders to the fixture data:

In `sale_detail_screen_item_card_test.dart` (fixture item has a known SKU string — reuse it):

```dart
  testWidgets('item SKU line renders in RobotoMono', (tester) async {
    // ...pump exactly as the neighboring tests do...
    final skuText = tester.widget<Text>(
      find.textContaining('<FIXTURE-SKU>'), // the harness's item SKU
    );
    expect(skuText.style?.fontFamily, 'RobotoMono');
  });
```

In `draft_list_tile_test.dart`:

```dart
  testWidgets('JO number renders in RobotoMono', (tester) async {
    // ...pump as neighboring tests do; fixture draft name e.g. 'JO-072426-001'...
    final nameText = tester.widget<Text>(find.text('<FIXTURE-NAME>'));
    expect(nameText.style?.fontFamily, 'RobotoMono');
  });
```

In the sales-history test file (grep `SalesListScreen` under `test/` to locate; reuse its harness):

```dart
  testWidgets('sale number renders in RobotoMono', (tester) async {
    // ...pump; fixture saleNumber e.g. 'SALE-0001'...
    final noText = tester.widget<Text>(find.text('<FIXTURE-SALE-NO>'));
    expect(noText.style?.fontFamily, 'RobotoMono');
  });
```

(If the sales-history harness can't cheaply render rows, put the third test on `recent_sale_widget_test.dart` instead — same assertion shape — and say so in your report.)

- [ ] **Step 2: Run to verify the new tests fail**

Run: `flutter test test/presentation/widgets/sale_detail_screen_item_card_test.dart test/presentation/widgets/draft_list_tile_test.dart <third-file>`
Expected: the three new tests FAIL on `fontFamily` (null or non-mono); note `sales_list` row is ALREADY mono from Task 1's literal swap — if its test passes immediately, that is correct; say so and keep the test.

- [ ] **Step 3: Implement each site**

Mechanical rule everywhere: add `fontFamily: AppTextStyles.monoFontFamily,` into the site's EXISTING style expression (`copyWith(...)` gains the arg; a `const TextStyle(...)` loses `const` if needed). Import the theme barrel where unresolved. Site specifics:

(a) `sale_detail_screen.dart` ~202 (header):
```dart
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: AppTextStyles.monoFontFamily,
              ),
```
and ~321 item SKU•price line: add the same `fontFamily:` arg to its `bodySmall?.copyWith(...)`.

(b) `checkout_screen.dart` ~201 and (c) `pos_screen.dart` ~205 and (e) `cart_item_tile.dart` ~85: same — add the arg to the existing `bodySmall?.copyWith(...)`.

(d) `bulk_receiving_screen.dart` ~332 (currently unstyled subtitle): give it
```dart
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: AppTextStyles.monoFontFamily,
                    ),
```
(match the tile's surrounding muted color usage — READ the enclosing builder first; if the subtitle inherits a ListTile subtitle style, only add the fontFamily).

(f) `void_requests_screen.dart` `_lineRow` sub text ~552: `TextStyle(fontSize: 12, color: muted, fontFamily: AppTextStyles.monoFontFamily)`.

(g) `product_form_screen.dart` SKU field ~653: change the field's `style:` to
```dart
                style: AppTextStyles.fieldInput
                    .copyWith(fontFamily: AppTextStyles.monoFontFamily),
```
(ONLY the SKU field — other fields keep `AppTextStyles.fieldInput`).

(h) `receipt_widget.dart`: parameterize the row builder and use it for Receipt # only:
```dart
  Widget _buildInfoRow(String label, String value, {bool mono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ReceiptColors.label, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Colors.black,
            fontFamily: mono ? AppTextStyles.monoFontFamily : null,
          ),
        ),
      ],
    );
  }
```
and the call site: `_buildInfoRow('Receipt #', sale.saleNumber, mono: true),` — Date/Cashier/Payment/Mechanic rows unchanged.

(i) `void_sale_dialog.dart` ~173: add the arg to its `titleMedium?.copyWith(fontWeight: FontWeight.w600, ...)`.

(j) `draft_list_tile.dart` ~68: the name's `const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)` becomes
```dart
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTextStyles.monoFontFamily,
                      ),
```
(`monoFontFamily` is a const String, so the TextStyle stays const.)

(k) `app_bottom_sheet.dart`: add the opt-in param —
```dart
  /// Optional override merged over the default title style (e.g. mono for
  /// identifier titles like JO numbers). Null = unchanged default.
  final TextStyle? titleStyle;
```
constructor: `this.titleStyle,` — and at the title Text (~57):
```dart
                Text(title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1.2)
                        .merge(titleStyle)),
```

(l) `draft_detail_sheet.dart` ~46: pass
```dart
          titleStyle: const TextStyle(fontFamily: AppTextStyles.monoFontFamily),
```

(m) `draft_edit_screen.dart` ~186 AppBar title: add `fontFamily: AppTextStyles.monoFontFamily,` to its `const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)` (stays const).

- [ ] **Step 4: Run to verify**

Run the three test files from Step 2 → new tests PASS, all pre-existing tests still pass.
Run: `flutter analyze` → No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "feat(mobile): SKU, sale-number, and JO-number displays use RobotoMono"
```

---

### Task 3: Full verification

- [ ] **Step 1:** `flutter test` → ALL pass (~1250, was 1247 + new tests).
- [ ] **Step 2:** `flutter analyze` → No issues found.
- [ ] **Step 3:** `git status --short` clean apart from `scripts/create-user.mjs`, `scripts/rename-product-category.mjs`; commit any straggler fixes as `fix(mobile): mono sweep cleanups`.

After Task 3: `/code-review` the branch, then finish per `superpowers:finishing-a-development-branch`. (Distribution stays HELD per the user's batching instruction.)
