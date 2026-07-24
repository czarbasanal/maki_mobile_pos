# SKU Sub-line Size Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Product names render at 12px and SKU/identifier sub-lines at 10px mono, everywhere on mobile, via two tokens.

**Architecture:** `AppTextStyles.productName` 13→12 with per-site size overrides removed; the unused `AppTextStyles.code` becomes the canonical 10px mono sub-line token and replaces every SKU sub-line's `bodySmall`/inline style (color preserved per site).

**Tech Stack:** Flutter.

**Spec:** `docs/superpowers/specs/2026-07-24-sku-subline-size-design.md`

## Global Constraints

- Branch: `feat/sku-subline-size` (created; spec committed).
- Styling only; each site keeps its existing color and max-lines/overflow behavior. Only fontSize sources change (plus fontWeight/height coming from the `code` token on sub-lines).
- Names: token governs — remove `copyWith(fontSize: ...)` overrides on `productName` call sites. Sub-lines: always `AppTextStyles.code.copyWith(color: <site's existing color>)`; never re-specify fontFamily/size inline.
- The void-request labor sub-line (non-mono) and receipt print rows are untouched.

---

### Task 1: Tokens + sweep + tests

**Files:**
- Modify: `lib/core/theme/app_text_styles.dart` (productName 13→12; code → 10px mono token per spec §1b)
- Modify (name-override removals): `lib/presentation/mobile/screens/pos/checkout_screen.dart` (×2 `copyWith(fontSize: 14)` on productName), `lib/presentation/mobile/widgets/pos/cart_item_tile.dart` (×1), `lib/presentation/shared/widgets/common/rank_row.dart` (title `copyWith(fontSize: 13.5)`)
- Modify (sub-line → `AppTextStyles.code.copyWith(color: ...)`): `lib/presentation/mobile/widgets/inventory/product_list_tile.dart`, `lib/presentation/mobile/screens/pos/pos_screen.dart`, `lib/presentation/mobile/widgets/pos/product_search_field.dart`, `lib/presentation/mobile/widgets/pos/cart_item_tile.dart`, `lib/presentation/mobile/screens/pos/checkout_screen.dart`, `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (item SKU line only — NOT the header), `lib/presentation/mobile/widgets/drafts/draft_detail_sheet.dart`, `lib/presentation/mobile/screens/sales/void_requests_screen.dart` (`_lineRow` mono branch: `fontSize: 12` → use the token; keep the non-mono branch at its current 12px style — restructure the conditional so mono rows use `AppTextStyles.code.copyWith(color: muted)` and non-mono rows keep `TextStyle(fontSize: 12, color: muted)`), `lib/presentation/mobile/widgets/receiving/receiving_item_row.dart`, `lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart` (picker subtitle), `lib/presentation/mobile/widgets/receiving/import_preview.dart`, `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart`, `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart`, `lib/presentation/shared/widgets/common/rank_row.dart` (mono subtitle → token)
- Test: `test/core/theme/app_text_styles_test.dart` (extend), `test/presentation/widgets/sale_detail_screen_item_card_test.dart` (extend)

**Interfaces:**
- Produces: `AppTextStyles.code` = `TextStyle(fontSize: 10, fontWeight: FontWeight.w500, fontFamily: monoFontFamily, height: 1.35)`; `AppTextStyles.productName.fontSize == 12`.

- [ ] **Step 1: Write the failing tests**

Extend `test/core/theme/app_text_styles_test.dart` `main()`:

```dart
  test('identifier sub-line token is 10px mono', () {
    expect(AppTextStyles.code.fontSize, 10);
    expect(AppTextStyles.code.fontFamily, 'RobotoMono');
  });

  test('product names are 12px', () {
    expect(AppTextStyles.productName.fontSize, 12);
  });
```

Extend the existing mono test in `test/presentation/widgets/sale_detail_screen_item_card_test.dart` (READ it; it finds the SKU line via `find.textContaining('SKU-001')`) with a size assertion in the same test or a sibling:

```dart
    expect(skuText.style?.fontSize, 10);
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/theme/app_text_styles_test.dart test/presentation/widgets/sale_detail_screen_item_card_test.dart`
Expected: FAIL — code is 14/spacing-1.0 style, productName 13, SKU line 14.

- [ ] **Step 3: Implement**

(a) `app_text_styles.dart`: `productName` fontSize 13→12 (weight w600 + height 1.25 keep). Replace `code` with the spec §1b definition verbatim (10px, w500, mono, height 1.35, comment included; drop old letterSpacing).

(b) Name overrides: in `checkout_screen.dart` change both `AppTextStyles.productName.copyWith(fontSize: 14)` → `AppTextStyles.productName`; same in `cart_item_tile.dart`; in `rank_row.dart` the title `AppTextStyles.productName.copyWith(fontSize: 13.5)` → `AppTextStyles.productName`.

(c) Sub-lines: at each listed site replace the sub-line's current style with `AppTextStyles.code.copyWith(color: X)` where X is the site's existing color expression (usually `muted` / `theme.colorScheme.onSurfaceVariant`; `import_preview`/`receiving_item_row` may use their own greys — keep them). Where the old style set nothing but fontFamily+color, the swap is direct. In `rank_row.dart` the mono subtitle style keeps its existing color logic but sources size/family from the token: `AppTextStyles.code.copyWith(color: <existing color>)` (drop its `fontSize: 11.5` and `fontFamily` args). In `void_requests_screen.dart` restructure `_lineRow`'s sub style to:

```dart
              style: mono
                  ? AppTextStyles.code.copyWith(color: muted)
                  : TextStyle(fontSize: 12, color: muted),
```

(d) Grep gate: `grep -rn "fontSize: 11.5" lib/presentation/shared/widgets/common/rank_row.dart` → empty; `grep -rn "productName.copyWith(fontSize" lib/` → empty.

- [ ] **Step 4: Run to verify**

Run: `flutter test test/core/theme/app_text_styles_test.dart test/presentation/widgets/sale_detail_screen_item_card_test.dart test/presentation/widgets/product_list_tile_test.dart test/presentation/widgets/cart_item_tile_test.dart test/presentation/widgets/rank_row_test.dart` → ALL PASS.
Run: `flutter analyze` → No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "style(mobile): product names 12px; SKU sub-lines 10px via AppTextStyles.code token"
```

---

### Task 2: Full verification

- [ ] **Step 1:** `flutter test` → ALL pass (~1254). `flutter analyze` → clean.
- [ ] **Step 2:** `git status --short` clean apart from the two pre-existing untracked scripts.

After Task 2: `/code-review` the branch diff, then finish per `superpowers:finishing-a-development-branch`. Distribution stays HELD (batch).
