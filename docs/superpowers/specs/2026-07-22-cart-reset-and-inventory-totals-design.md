# Cart Reset + Inventory Totals — Design

**Date:** 2026-07-22
**Status:** Approved
**Branch:** feat/cart-reset-inventory-totals

## Goal

1. A one-tap "reset sale" control on both POS surfaces that clears the entire ticket —
   items, labor lines, mechanic, and cash-received/payment inputs — behind a confirm
   dialog.
2. Admin-only, filter-aware inventory totals: total stock cost, total retail value, and
   expected profit.

## Current state (verified 2026-07-22)

- **Mobile POS already has the full reset.** `pos_screen.dart:67-72` renders a Clear
  Cart button (trash2 icon, shown when `cart.isNotEmpty`) → `_showClearCartDialog`
  (`:623`) → `cartProvider.notifier.reset()` → `state = const CartState()`
  (`cart_provider.dart:695`), which already wipes items, laborLines, mechanic,
  amountReceived, split amounts, notes, draft link, motorcycleModel, and checkoutId.
  Only gap: the dialog copy says "remove all items from the cart" — understates what
  is cleared.
- **Web has the store method but no button.** `cartStore.clear()`
  (`presentation/stores/cartStore.ts:104`) resets lines, discountType, laborLines,
  mechanic, draft refs. Nothing on `/pos` calls it. Cash-received on web is page-local
  state on CheckoutPage (`usePaymentDraft`), and CheckoutPage redirects to `/pos` when
  the cart empties — clearing the store therefore also guarantees payment inputs can't
  survive.
- **Both inventory screens stream ALL products and render a client-filtered list**:
  mobile `filteredProductsProvider` (`inventory_provider.dart:122`, search + category +
  stock filters); web `filtered = filterProducts(active, {search, stock, category})`
  (`InventoryListPage.tsx:61`). Totals are a free client-side reduce — zero extra reads.
- **Admin detection**: mobile `ref.watch(currentUserProvider).value?.role ==
  UserRole.admin` (used in `inventory_screen.dart:38-39` already); web
  `useAuthStore(...).user?.role` with the `hasPermission`/UserRole mirror
  (`router/routeGuards.ts`).
- Formatters: mobile `num.toCurrency()` → "₱1,234.56"; web `formatMoney` in
  `core/utils/money.ts`.

## Decisions (user-approved)

1. **Mobile reset**: keep the existing button, icon, and placement (already shipped
   UI); fix the dialog copy to state the full-ticket clear: message becomes
   "This clears the whole sale — items, labor & service, mechanic, and payment
   amounts." Behavior unchanged (it is already a full reset).
2. **Web reset**: new icon button (Lucide `RotateCcw`, neutral styling, `aria-label
   "Reset sale"`) in the `/pos` page header row, rendered only when the store has
   lines OR laborLines. Click → confirm dialog ("Clear this sale?" / body "This clears
   the whole sale — items, labor & service, and mechanic." / Cancel + Clear) →
   `cartStore.clear()`. NOT added to the shared `CartBuilder` (also used by
   `/drafts/:id`, where wiping a held order would be a footgun).
3. **Totals helper per surface** — `stockTotals(list)`:
   `{cost: Σ cost×qty, retail: Σ price×qty, profit: retail − cost}`. Pure, unit-tested.
4. **Totals follow the filters**: computed over exactly the list the screen renders
   (mobile: `filteredProductsProvider` data; web: `filtered`). No filter → whole
   inventory. Web's Show-inactive toggle therefore includes inactive items in totals
   while on (totals always mirror the visible list; default view = active only).
5. **Admin-only** on both surfaces: non-admins see no totals UI at all.
6. **UI**: compact 3-figure strip (labels: Stock Cost / Retail Value / Expected
   Profit) — mobile between the filter row and the product list, neutral card per the
   color discipline; web above the inventory table.
7. No Firestore schema, rules, or route changes.
8. **Totals strip vs the mobile cost-lock (final-review finding, user-signed-off
   2026-07-22):** the mobile inventory screen's password-gated `showCost` toggle
   (5-min auto-hide) does NOT gate the totals strip — the user explicitly chose
   "always show for admins", accepting the on-screen glance exposure (including the
   filter-to-one-product cost inference). Revisit only if the shop's screen-privacy
   needs change.

## Testing

- Web (`web_admin/`): `stockTotals` unit tests (empty list, qty×cost math, profit);
  PosPage test — reset button hidden when empty, click→confirm→store cleared (items +
  labor + mechanic), cancel→untouched; InventoryListPage test — totals visible for
  admin, absent for staff, reacts to category filter. `npm run typecheck` + `npm run
  test`.
- Mobile: `stock_totals_test.dart` (same cases); cart provider test asserting
  `reset()` clears laborLines, mechanicId/Name, amountReceived, splitAmount, notes,
  sourceDraftId (add if not already covered); inventory widget test — strip rendered
  for admin, absent for staff. `flutter analyze` + `flutter test`.

## Out of scope

- Reset on `/drafts/:id` (held-order editor), receipts, discount model, any backend
  change, staff-visible partial totals.
