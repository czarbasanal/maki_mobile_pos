# SKU sub-lines smaller than product names

Date: 2026-07-24
Surface: Flutter mobile, styling only. Follows the same-day mono-identifiers spec.

## Problem

Product names render at 13px (`AppTextStyles.productName`) while the SKU
sub-line under them uses `bodySmall` (14px) — the identifier is larger than
the name, exaggerated by RobotoMono's wide glyphs. User: SKUs must be
visibly smaller than names, everywhere the pair appears.

## Decision (confirmed)

Canonical identifier sub-line = **11.5px mono** (matches the existing
RankRow precedent). Names, prices in their own elements, and standalone
identifier displays (sale-number headers, JO titles, receipt #, JO save
dialog) are untouched.

## Design

1. Repurpose the unused `AppTextStyles.code` as the canonical token:

```dart
  /// Identifier sub-line under a product name (SKU • price rows, list
  /// subtitles): visibly smaller than productName (13), mono. Color is
  /// applied per-site (usually the muted variant).
  static const TextStyle code = TextStyle(
    fontSize: 11.5,
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
- `void_requests_screen.dart` `_lineRow` sub when `mono: true` (12 → 11.5;
  the non-mono labor sub keeps its current 12px style)
- `receiving_item_row.dart` SKU line
- `bulk_receiving_screen.dart` picker subtitle
- `import_preview.dart` SKU • line
- `purchase_order_detail_screen.dart` "SKU: …" line and
  `new_purchase_order_screen.dart` picker SKU line

`rank_row.dart` already renders 11.5 mono — switch it to the token too
(no visual change) so the size lives in one place.

3. Tests: extend the existing three mono style tests (sale-detail SKU line,
sales-list — N/A size there; instead product-list-tile if a test exists, else
sale-detail + draft sheet) to assert `fontSize == 11.5` on the SKU line; add
a token unit test (`AppTextStyles.code.fontSize == 11.5`,
`.fontFamily == 'RobotoMono'`).

## Not changing

Name styles, standalone identifiers, receipt print rows, web admin.
