# +17 quad batch — lists lockdown, list delete, void-request notifications, received-amount fix

Approved 2026-07-25. Four independent mobile-app items bundled for the 1.0.0+17 APK.
Rules changes and the data backfill are deploy-time actions confirmed separately.

## 1. Product Categories editor becomes staff+admin

Cashiers keep `editLists` (all other lists + inline mechanic add at POS). Only the
Product Categories editor is locked down.

- New `Permission.editProductCategories`, granted to staff and admin only
  (`lib/core/constants/role_permissions.dart`).
- `category_settings_screen.dart` ("Manage Lists" hub): hide the Product Categories
  tile when the user lacks the permission.
- `route_guards.dart`: the `/settings/categories/productCategories` subpath requires
  `editProductCategories`; other kinds keep requiring `editLists`.
- `firestore.rules` `product_categories`: `create` and `update` require
  `isStaffOrAdmin()` (read stays all roles; delete per §2).
- Known consequence: +15 cashiers get a permission-denied snackbar if they try to
  add/rename a product category after the rules deploy. Acceptable; nothing else breaks.

## 2. Hard delete on shared-list items (staff + admin)

Current rows offer edit + deactivate/reactivate only. Add permanent delete.

- `SettingsCrudRow` (`lib/presentation/mobile/widgets/settings/settings_crud_row.dart`)
  gains an optional `onDelete`; when provided, render a delete action (trash icon)
  alongside the existing buttons. Hidden when null.
- Each list editor (category/mechanic/motorcycle-model/shop-fee screens) passes
  `onDelete` only when the user has `manageCategories` (staff+admin), wired through a
  confirm dialog ("permanently deleted", destructive style) to a new provider method.
- New `delete(String id)` on each ops provider + repository
  (categories all four kinds via `CategoryKind`, mechanics, motorcycle models, shop fees).
- `firestore.rules`: `allow delete` loosens from `isAdmin()` to `isStaffOrAdmin()` on
  the seven list collections (`product_categories`, `expense_categories`, `units`,
  `void_reasons`, `mechanics`, `shop_fees`, `motorcycle_models`).
- No in-use guard, consistent with deactivate: historical records snapshot names as
  plain text. Deactivate remains the "hide but keep" option; the confirm dialog copy
  points at it.

## 3. Void requests — notification sheet, status cards, date filter, paged loading

### Bell → notification sheet
- `VoidRequestsBell` keeps the unread badge (all-time unread, date-independent).
  Tap opens a bottom sheet of notification entries instead of navigating directly.
- Entry layout: "**{requestedByName}** sent a void request" · `{saleNumber} ·
  ₱{saleGrandTotal} · {itemsSummary}` · relative time. Unread entries highlighted.
- Tapping an entry or a "View all" footer navigates to the void-requests screen
  (existing route). Entries mark read on tap (existing `markRead`).
- `itemsSummary`: new optional string field on `void_requests` docs (e.g.
  "2× Brake Shoe, 1× Bulb", truncated), written at request-creation time by the
  mobile client. Old docs without it simply omit the detail line — no per-entry
  sale fetches.

### Void-requests screen
- Three tappable count cards — Pending / Approved / Rejected — mirroring the
  Inventory summary-card pattern (`inventory_screen.dart` `_buildSummaryRow`):
  tap selects, tap again clears (no selection = all statuses).
- Shared report date filter (`DateRangePicker` + `dateRangeForPreset`) above the
  list, defaulting to **Today**. Applies to both the list and the card counts.
- List: status+date-filtered query, `createdAt` desc, page size 20, "Load more"
  button using a `startAfterDocument` cursor (new repo method, modeled on
  `sale_repository_impl.getSales`).
- Counts: Firestore `count()` aggregate queries per status within the date range —
  no bulk loading.
- New composite index `void_requests (status ASC, createdAt DESC)` in
  `firestore.indexes.json`; **prod-precheck the query shape** (emulator does not
  enforce composite indexes — prior gotcha).
- Resolve flow (bottom sheet, approve w/ password, reject w/ reason) unchanged.
  Status labels stay Pending / Approved / Rejected.

## 4. Received amount — write fix + historical backfill

Regression since `ae42b75` (2026-05-28): `toSale()` at `cart_provider.dart:713`
stores `state.collectedToday` (= grand total for cash) as `amountReceived`,
discarding the typed cash. `changeGiven` is computed from the real typed amount,
so docs are internally inconsistent (received 320 / change 680 for a ₱1,000 tender).

- **Fix**: new tested `CartState` getter `amountReceivedForSale` mirroring web
  `payment.ts amountReceivedFor` semantics — cash → typed `state.amountReceived`,
  salmon → split amount (preserve `collectedToday`'s salmon branch), digital/mixed →
  collected total. `toSale()` uses it.
- **Pre-ship check**: grep all consumers of `amountReceived` (EOD, reports, CSV,
  receipt) to confirm none treat it as "collected today" in a way the fix would shift.
- **Backfill** (`scripts/backfill-amount-received.mjs`, dry-run first, execute on
  user go-ahead): for completed sales where `paymentMethod == 'cash'`,
  `changeGiven > 0`, **and** `amountReceived == tenders.cash` (the bug's signature —
  correctly-written web docs fail this guard), set
  `amountReceived = amountReceived + changeGiven`. Log every change; verify a sample
  after.

## Testing & verification

- TDD per item: widget tests (hub tile gating, crud-row delete, bell sheet, count
  cards, date filter, load-more), provider/repo tests (delete methods, paged query,
  itemsSummary write), `CartState.amountReceivedForSale` unit tests, rules tests for
  §1/§2 changes (`firestore-rules` test suite).
- `flutter test` + `flutter analyze` green before done; rules suite green.

## Deploy order

1. App code merged to main for the +17 APK (no behavior depends on rules landing first).
2. Rules + index deploy (confirm before deploying — production-affecting).
3. Backfill dry-run → user reviews → execute.
