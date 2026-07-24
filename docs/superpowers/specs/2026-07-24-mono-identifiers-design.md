# Mono font for identifiers: SKU, Sale No, JO No

Date: 2026-07-24
Surface: Flutter mobile app only. Styling-only — no data, flow, schema, or rules changes.

## Problem

SKUs, sale series numbers (`SALE-…`), and job-order series numbers
(`JO-MMDDYY-NNN`, stored as the draft name — always auto-generated since the
2026-07-23 parity batch; the free-form name input no longer exists and the
2026-07-24 prod wipe removed all legacy-named tickets) should read as
code-like identifiers. Today about half their render sites are monospace and
half are the normal font — and the mono half is split between two fonts: the
bundled `RobotoMono` and the platform `'monospace'` fallback that
`AppTextStyles.monoFontFamily` currently resolves to.

## Decisions (confirmed with user)

- Approach A: **one canonical token** — `AppTextStyles.monoFontFamily`
  becomes `'RobotoMono'`; every mono site (existing and new) uses the token.
- **Standalone displays only**: identifier-led data lines (e.g.
  "SKU • ₱price / unit") go mono whole-line, matching existing precedent;
  prose sentences embedding an identifier stay in the normal font.
- **JO names mono unconditionally** — all are auto-generated series numbers.
- No drafts-flow changes: JO auto-numbering already shipped; out of scope.

## Design

### 1. Canonical token (`lib/core/theme/app_text_styles.dart`)

`static const String monoFontFamily = 'RobotoMono';` (was `'monospace'`).
Doc comment updated: bundled RobotoMono (Medium/SemiBold), used for every
identifier (SKU / sale no / JO no), cost codes, and mono UI. This silently
upgrades all existing `monoFontFamily` consumers (cost-code pill, cost-code
settings/editor, POS search rows, PO rows, draft item lines) to RobotoMono —
intended.

### 2. Literal → token cleanup

Every `fontFamily: 'RobotoMono'` and `fontFamily: 'monospace'` literal in
`lib/presentation/` switches to `AppTextStyles.monoFontFamily`. Known sites:
`product_list_tile.dart`, `receiving_item_row.dart`, `import_preview.dart`,
`rank_row.dart`, `recent_sale_widget.dart`, `void_requests_screen.dart`
(list row + detail title), `sales_list_screen.dart`,
`checkout_success_dialog.dart`, `cost_code_pill.dart`. (Implementer greps to
catch any others; `lib/core/theme/` keeps no literals either.)

### 3. New mono sites (add `fontFamily: AppTextStyles.monoFontFamily` to the
existing style — size/weight/color unchanged)

SKU:
- `sale_detail_screen.dart` item card SKU•price line (~321)
- `checkout_screen.dart` cart line SKU (~201)
- `pos_screen.dart` product tile subtitle SKU•price (~205)
- `bulk_receiving_screen.dart` product picker subtitle SKU•stock (~332) —
  currently default style; give it the surrounding muted bodySmall + mono
- `cart_item_tile.dart` SKU•price line (~85)
- `void_requests_screen.dart` item sub-line SKU•price (`_lineRow` sub, ~552)
- `product_form_screen.dart` SKU input field (~653): input style becomes
  `AppTextStyles.fieldInput.copyWith(fontFamily: AppTextStyles.monoFontFamily)`

Sale number:
- `sale_detail_screen.dart` header title (~202)
- `receipt_widget.dart` "Receipt #" info-row value: value style gains mono
  ONLY for the receipt-number row (other info rows — date, cashier — stay
  normal; parameterize `_buildInfoRow` with a `mono` flag or pass a style)
- `void_sale_dialog.dart` header sale number (~173)

JO number (draft name):
- `draft_list_tile.dart` name/title (~68)
- `draft_detail_sheet.dart` sheet title (~46) — check how the sheet title
  style is provided; apply mono to the title text only
- `draft_edit_screen.dart` AppBar title (~186)

### 4. Excluded (prose / mixed labels — stay normal font)

- `request_void_dialog.dart` "Sale X will be sent…" sentence
- `price_change_report_screen.dart` "Name (SKU)" combined label
- Delete-confirm dialogs quoting the JO name mid-sentence
- Receiving "Draft" wording (different feature; untouched)

## Not changing

- Web admin, receipts' other info rows, any layout/size/weight/color.
- Draft/JO flows, entities, providers, rules.

## Testing (tests mirror lib/)

- Unit: `app_text_styles` test pinning `monoFontFamily == 'RobotoMono'`.
- Widget style assertions (new precedent, keep small): sale-detail item SKU
  line, sales-history sale-number row, drafts-list JO title — each finds the
  Text and asserts `style.fontFamily == 'RobotoMono'`. Existing tests assert
  no fonts, so none break.
- Full `flutter test` + `flutter analyze` before merge.
