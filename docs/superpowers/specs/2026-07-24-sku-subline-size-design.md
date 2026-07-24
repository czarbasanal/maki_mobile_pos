# SKU sub-lines smaller than product names

Date: 2026-07-24
Surface: Flutter mobile, styling only. Follows the same-day mono-identifiers spec.

## Problem

Product names render at 13px (`AppTextStyles.productName`) while the SKU
sub-line under them uses `bodySmall` (14px) — the identifier is larger than
the name, exaggerated by RobotoMono's wide glyphs. User: SKUs must be
visibly smaller than names, everywhere the pair appears.

## Decision (confirmed, revised by user)

Product names = **12px** (`AppTextStyles.productName` 13 → 12, and per-site
`copyWith(fontSize: 14)` / `13.5` overrides on productName are REMOVED so
every name renders the token size). Identifier sub-lines = **10px mono**.
Prices in their own elements and standalone identifier displays
(sale-number headers, JO titles, receipt #, JO save dialog) are untouched.

## Design

1a. `AppTextStyles.productName`: `fontSize: 13` → `12` (weight/height keep).
Remove name-size overrides at call sites so the token governs:
`checkout_screen.dart` (two `copyWith(fontSize: 14)`), `cart_item_tile.dart`
(`copyWith(fontSize: 14)`), `rank_row.dart` (`copyWith(fontSize: 13.5)`).
Other `productName` call sites already use it bare.

1b. Repurpose the unused `AppTextStyles.code` as the canonical sub-line token:

```dart
  /// Identifier sub-line under a product name (SKU • price rows, list
  /// subtitles): visibly smaller than productName (12), mono. Color is
  /// applied per-site (usually the muted variant).
  static const TextStyle code = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    fontFamily: monoFontFamily,
    height: 1.35,
  );
```

(Replaces the old unused 14px/letterSpacing-1.0 definition.)

2. Convert each SKU/identifier sub-line to
`AppTextStyles.code.copyWith(color: <site's existing color>)` — dropping
their previous `bodySmall?.copyWith(...)`/inline styles. Sites:

- `product_list_tile.dart` (inventory row SKU)
- `pos_screen.dart` product tile subtitle
- `product_search_field.dart` search result SKU line
- `cart_item_tile.dart` SKU • price / unit line
- `checkout_screen.dart` cart line SKU
- `sale_detail_screen.dart` item SKU • price line
- `draft_detail_sheet.dart` item SKU • price line
- `void_requests_screen.dart` `_lineRow` sub when `mono: true` (12 → 10;
  the non-mono labor sub keeps its current 12px style)
- `receiving_item_row.dart` SKU line
- `bulk_receiving_screen.dart` picker subtitle
- `import_preview.dart` SKU • line
- `purchase_order_detail_screen.dart` "SKU: …" line and
  `new_purchase_order_screen.dart` picker SKU line

`rank_row.dart`'s mono subtitle (11.5) switches to the token (→ 10) so the
size lives in one place.

3. Tests: extend the sale-detail SKU-line mono test to also assert
`fontSize == 10`; add token unit tests (`AppTextStyles.code.fontSize == 10`,
`.fontFamily == 'RobotoMono'`, `AppTextStyles.productName.fontSize == 12`).

## Not changing

Name weight/height (only size 13→12), standalone identifiers, receipt print
rows, web admin (mobile-only per user — web parity is a possible follow-up).
