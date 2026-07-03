# Purchase Orders / "Reorder" — Current UI & Flow (redesign handoff)

_Documented 2026-07-03, against `main` (`ed3e394`). Written so a future session can redesign this feature without re-exploring the codebase._

> ℹ️ **`reference_current-ui.html` in this folder previews the as-shipped UI** (light mode, 9 self-contained panels). Use it for a quick visual read; **this markdown is authoritative for behavior, wiring, and exact code references.** The feature shipped 2026-07-03 and has NOT had a design pass yet — the screens below are functional Material defaults awaiting the elevated-theme treatment that Job Orders already got.

## What it is

Velocity-based **reorder suggestions drafted into per-supplier purchase orders that flow into Receiving**. The suggestion engine is a Dart port of the web admin's reorder formula (`velocity = unitsSold(window)/windowDays`, `target = ceil(velocity × coverDays)`, `suggested = max(0, target − stock)`); the user reviews/edits suggestions plus out-of-stock / low-stock top-ups plus manual adds, saves **one draft PO per supplier**, marks it ordered, shares a costs-free CSV with the supplier, and — when the delivery arrives — "Receive" spawns a linked Bulk Receiving draft whose completion atomically marks the PO received.

Data lives in a dedicated shared Firestore collection `purchase_orders` with a real lifecycle (`draft ⇄ ordered → received / cancelled`). Design spec: `docs/superpowers/specs/2026-07-03-mobile-purchase-orders-design.md` (approved; the spec is the source of truth for lifecycle semantics and the Receiving integration guards).

## Entry point & routes

| Entry point | Where | Goes to |
|---|---|---|
| Dashboard QuickActions **"Reorder"** pill | `lib/presentation/shared/widgets/dashboard/quick_actions.dart:58-63` — `LucideIcons.clipboardList` + "Reorder", an outlined quick-action pill (50px tall, radius `AppRadius.field` = 16, hairline border, muted 20px icon; anatomy at :95-180). Wired in `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart:295-297` (`context.go(RoutePaths.purchaseOrders)`), shown only when `_canAccessReceiving` (dashboard_screen.dart:89) — **staff + admin**, same gate as Receiving. | `/reorder` |
| List FAB / list rows | see screens below | `/reorder/new`, `/reorder/:id` |

Routes (`lib/config/router/route_names.dart:71-78` names, `:220-223` paths; wired in `lib/config/router/app_routes.dart:273-291`):

- `/reorder` (name `purchaseOrders`) → `PurchaseOrdersScreen`
- `/reorder/new` (name `purchaseOrderNew`) → `NewPurchaseOrderScreen`
- `/reorder/:id` (name `purchaseOrderDetail`) → `PurchaseOrderDetailScreen(purchaseOrderId)`

Guards (`lib/config/router/route_guards.dart`): `/reorder` in `protectedRoutes` with `Permission.accessReceiving` (:35-36); the dynamic `/reorder/…` prefix (new + detail) checked in `checkDynamicRoute` (:186-189). Nav-menu metadata at :251-257 ("Reorder", **`Icons.shopping_cart_checkout`** — a Material icon, see Redesign starting points).

## Screens

### 1. Reorder list — `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart` (`/reorder`)

`ConsumerStatefulWidget` (local `_filter` state) watching `purchaseOrdersProvider` (live stream, newest first).

- **AppBar** "Reorder" (:31-39), back chevron `goBackOr(RoutePaths.dashboard)` — top-level destination, the dashboard pill uses `go` so there may be nothing to pop (:34-36).
- **FAB** (:40-43): default `FloatingActionButton` with `LucideIcons.plus` → `push(/reorder/new)`. (Themed slate fill / white glyph, radius `AppRadius.xl` = 24, elevation 0 — `app_theme.dart:175-185`.)
- **Status filter chips** (:44-66): a horizontally scrolling row (padding 16h/8v) of Material `ChoiceChip`s — "All" + one per `PurchaseOrderStatus.displayName` (Draft / Ordered / Received / Cancelled), 8px gaps. Filtering is client-side over the streamed list (:72-74). Chip look comes from the global `chipTheme` (`app_theme.dart:252-261`): `#FAFAFA` fill, `#ECECEC` hairline, pill radius, `labelSmall`; the selected chip gets the M3 checkmark + `secondaryContainer` `#EDEFF1` fill (`app_theme.dart:30`).
- **States** (:67-90): loading `LoadingView`; error `ErrorStateView('Failed to load: …')` (no retry wired); **empty** `EmptyStateView` (`clipboardList`, "No purchase orders yet", "Draft one from stock movement with +") — bare 64px glyph, `tiled` not set.
- **List** (:82-87): `ListView.separated`, padding 16, 8px separators.
- **`_OrderCard`** (:97-128): `AppCard` (tap → `push('/reorder/{id}')`) — **no `padding` argument is passed, so the row content sits flush against the card edge** (`app_card.dart:39-41` only applies padding when given). Left column: `referenceNumber` (`titleSmall`), then a one-line meta caption `'{supplierName ?? 'No supplier'} • {totalQuantity} pcs • {createdAt.toIsoDate()}'` (`bodySmall`; `toIsoDate` = `yyyy-MM-dd`, `datetime_extensions.dart:48-50`). Right: `PurchaseOrderStatusPill`.

### 2. New Purchase Order — `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` (`/reorder/new`)

`ConsumerStatefulWidget` watching `reorderSuggestionsProvider((windowDays, coverDays))`. Local state (:60-82): `_windowDays` (default 60), `_coverController` (text "30", clamped 1–365 via `_coverDays`), `_manual` (search-added products), `_qty` / `_checkedOverride` maps **keyed by productId** so user edits survive params changes and re-grouping (:71-77), `_byStatus` view flag, `_saving` lock.

- **AppBar** (:96-110): back chevron (`pop`), "New Purchase Order", right **`search` icon action** (tooltip "Add product") → add-product bottom sheet.
- **Params row** (:199-226, padding 16h/8v): three `ChoiceChip`s "30d / 60d / 90d" (8px gaps) + `Spacer` + an 88px-wide dense `TextField` "Cover days" (number keyboard). **The field recomputes only `onSubmitted`** (:221) — typing alone doesn't refresh suggestions until submit or another rebuild.
- **View toggle row** (:227-244, padding 16h): two more `ChoiceChip`s — "By status" (default) / "By supplier". Grouping only; selection, quantities, and Save are identical in both views.
- **Capped note** (:245-249): when the 10,000-sale fetch cap is hit (`reorderSalesCap`, provider :29), a plain unstyled `Text('Movement data may be incomplete (sales cap reached)')`.
- **Line building** (`_buildLines`, :130-151): four buckets in priority order — an item appears once, in the first bucket it qualifies for (`_LineSource`, :15-28):
  1. **Recommended** — velocity suggestions, qty prefilled with `suggestedQty`, **checked by default**;
  2. **Out of stock** — active, zero-stock, non-recommended; **unchecked**, qty prefilled to top up: `reorderLevel − stock`, min 1 (`topUp`, :133-136);
  3. **Low stock** — at/below `reorderLevel`, not zero, not already listed; **unchecked**, same top-up qty;
  4. **Added** — search-to-add rows, **checked** (a deliberate add is always checked, :368-371).
  Unchecked-by-default low/out rows exist so zero-velocity items never silently pad an order (:26-27).
- **Sections** (`_sections`, :156-191): plain `titleSmall` headers (padding top 16 / bottom 4). Status view walks the bucket order; supplier view groups the same lines by `supplierName`, alphabetical, no-supplier ("No supplier") last.
- **Row anatomy** (`_row`, :279-320): a plain `Row` — Material `Checkbox`; expanded column of name (1 line, ellipsized) + caption `'{sku} • …'` (`bodySmall`) where the caption varies by bucket: recommended = `'Stock {n} • {velocity.toStringAsFixed(1)}/day'`, out/low = `'Stock {n} • reorder at {reorderLevel}'`, added = `'Stock {n} • added manually'`; then bare 16px `minus` `IconButton` (disabled at qty 1), qty `Text`, 16px `plus` `IconButton`. No card, no stepper pill.
- **Empty state** (:251-256): `EmptyStateView` (`packageCheck`, "No suggestions — everything is stocked", "Add products manually with the search button").
- **Add-product bottom sheet** (`_showAddProductSheet`, :322-384): `showModalBottomSheet` + `StatefulBuilder`, fixed **420px** height, keyboard-inset padded. A plain autofocused `TextField` ("Search name or SKU") over a `ListView` of plain `ListTile`s (name / SKU subtitle) — active products not already added, first 30 matches. Tapping a result adds it checked and **closes the sheet** (one product per open, unlike the Job Orders add-parts sheet which stays open). The search controller is owned by the screen state, not the sheet, to avoid a dispose race (:65-67).
- **Save** (:262-274 + `_save` :386-446): full-width `FilledButton` **"Save drafts"** in a bottom `SafeArea`, disabled when nothing is checked or while saving. Saving groups checked lines by `supplierId` and creates **one draft PO per supplier group** (no-supplier lines form their own PO), each with a generated `PO-YYYYMMDD-NNN` reference; runs behind `runWithWaiting('Saving purchase orders…')`, then success snackbar `'Created N purchase order(s)'` and `pop` back to the list. Item lines carry `sku/name/qty/unit/unitCost/costCode` prefilled from the product; totals recalculated via `recalculateTotals()`.

### 3. Purchase order detail — `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart` (`/reorder/:id`)

`ConsumerStatefulWidget` watching `purchaseOrderProvider(id)` (live stream). Draft edits are **buffered locally** in `_pending` (a nullable items list, :36-41) and flushed with **one write**; `_busy` locks buttons during mutations.

- **AppBar** (:50-74): back chevron, static title "Purchase Order", and an **overflow `PopupMenuButton`** (Material `⋮`) shown only when the PO `canCancel` or the user is admin — items **Cancel** (draft/ordered only) and **Delete** (admin-only, any status).
- **Header card** (:100-131): `AppCard` (again **no padding passed** — flush content) with `referenceNumber` (`titleMedium`) + `PurchaseOrderStatusPill` on the first row, then `supplierName ?? 'No supplier'`, `'Created {yyyy-MM-dd} by {createdByName}'`, and conditional `'Ordered {date}'` / `'Received {date}'` lines + notes (`bodySmall`).
- **Items** (:133-137): `'{n} items • {m} pcs'` (`titleSmall`, recomputed from the pending buffer) over plain `Row` item rows (`_itemRow`, :145-178): name (1 line) + SKU (`bodySmall`); while `canEdit` (draft only) — bare 16px `minus`/`plus` `IconButton` steppers (min qty 1) + a 16px `trash2` remove button (all disabled while busy); otherwise a static `'{qty} {unit}'` text. Removing the last item is blocked with snackbar "Last item — delete the purchase order instead" (:188-196). Stepper/remove taps only **stage** into `_pending` (:180-196).
- **Edit bar** (:198-217, replaces the action bar while dirty, :140): expanded `FilledButton` **"Save changes"** + `OutlinedButton` **"Discard"** (drops the buffer). Save = one `updatePurchaseOrder` with recalculated totals behind `'Saving…'` (:219-228).
- **Action bar** (`_actionBar`, :230-278): a `Wrap` (spacing 8) of per-status buttons —
  - **draft:** `FilledButton` "Mark ordered" (`markOrdered`, `'Marking ordered…'`);
  - **ordered:** `FilledButton` "Receive" + `OutlinedButton` "Back to draft" (`revertToDraft`, `'Reopening…'`);
  - **any non-cancelled:** `OutlinedButton.icon` `share2` "Share CSV";
  - **received with `receivingId`:** `OutlinedButton` "View receiving" → `push('/receiving/bulk/{receivingId}')`;
  - cancelled with nothing else → the bar collapses to nothing (:273).
- **Receive** (`_receive`, :295-322): generates a receiving reference, calls `repo.startReceiving(...)` (creates a receiving **draft** prefilled from PO items + stamps `receivingId` on the PO; idempotent — an already-linked draft is navigated to instead, per spec) behind `'Preparing receiving…'`, then pushes the existing Bulk Receiving screen. Completing that receiving marks the PO `received` atomically inside `completeReceiving`'s transaction (spec §Receiving integration).
- **Cancel / Delete confirm** (`_onMenu`, :327-358): `showAppConfirmDialog` (`app_dialog.dart:191-257`) — destructive `AppDialog` with the action glyph chip (`trash2` / `ban`), titles "Delete this purchase order?" / "Cancel this purchase order?", messages `'{ref} will be permanently removed.'` / `'{ref} will be marked cancelled.'`, confirm "Delete" / "Cancel order" (red filled), cancel **"Keep"**, and — when a receiving draft is linked — the red warning line **"Its in-progress receiving draft will be cancelled too."** (otherwise the default "This action cannot be undone."). Delete pops back to the list on success.
- **States**: loading `LoadingView`; error `ErrorStateView`; null doc → `EmptyStateView` (`fileX`, "Purchase order not found") (:76-86). Mutations run behind `runWithWaiting`; failures snackbar `'Failed: …'` (`_run`, :282-293).

### 4. Status pill — `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_pill.dart` + `purchase_order_status_style.dart`

The one pill both the list card and the detail header render: a tinted pill (padding 10h/4v, radius `AppRadius.pill` = 999) with a 12px status glyph + `displayName` at 12/600 (pill :17-36). The color language (`PurchaseOrderStatusStyle.of`, style :20-54) — **draft neutral, ordered amber (in flight), received green, cancelled red**:

| Status | Icon | Text (light / dark) | Tint (light / dark) |
|---|---|---|---|
| Draft | `pencilLine` | `lightTextSecondary` `#6A7378` / `darkTextSecondary` `#93A0A3` | `0x14000000` (8% black) / `0x1FFFFFFF` (12% white) |
| Ordered | `send` | **`#C8881A`** (literal — "deep amber has no token", comment :32-34) / `warningOnDark` `#F5B547` | `0x1FF57C00` / `0x24F5B547` |
| Received | `packageCheck` | `successDark` `#2E7D32` / `successOnDark` `#8FE39A` | `successLight` `#E8F5E9` / `0x294CAF50` |
| Cancelled | `ban` | `error` `#F44336` / `errorOnDark` `#FF6B5E` | `0x1AF44336` / `0x24FF6B5E` |

Labels come from `PurchaseOrderStatus.displayName` (`purchase_order_entity.dart:7-15`), not from the style.

## Lifecycle semantics (brief — spec is authoritative)

`draft ⇄ ordered → received / cancelled` (`purchase_order_entity.dart:3-15`, gates :60-65: `canEdit` = draft, `canReceive` = ordered, `canCancel` = draft|ordered). `received` is set **only from `ordered`**, atomically when the linked receiving completes — a stale receiving under a cancelled/re-drafted PO never resurrects it. **Cleanup invariant:** cancel, revert-to-draft, and delete all cancel the linked receiving draft (while still a draft) and clear `receivingId` in the same batch — an orphan "From PO-…" receiving draft must never stay completable. No partial deliveries: quantities are corrected on the receiving before completion; shorted items go on a new PO. Full detail: `docs/superpowers/specs/2026-07-03-mobile-purchase-orders-design.md` §Lifecycle / §Receiving integration.

## State management (Riverpod)

`lib/presentation/providers/purchase_order_provider.dart`:

- `purchaseOrderRepositoryProvider` (:11-13) → `PurchaseOrderRepositoryImpl` (Firestore `purchase_orders`, items embedded).
- `purchaseOrdersProvider` (:17-20) — `StreamProvider.autoDispose<List<PurchaseOrderEntity>>`, newest first; status filtering is client-side (no composite index). Drives the **list**.
- `purchaseOrderProvider(id)` (:22-25) — `StreamProvider.autoDispose.family<PurchaseOrderEntity?, String>`. Drives the **detail** (live — external status changes appear in place).
- `reorderSuggestionsProvider(params)` (:51-86) — `FutureProvider.autoDispose.family<ReorderResult, ReorderParams>` where `ReorderParams` is the **record** `({int windowDays, int coverDays})` (value-equal family key, `reorder_suggestions.dart:9`). Fetches products + completed sales for the window (`getSalesByDateRange`, capped at `reorderSalesCap` 10,000), computes suggestions, and derives `lowStock` / `outOfStock` lists **from the products it already fetched** — no extra queries. Drives the **new-PO screen**.
- `ReorderResult` (:31-49): `suggestions` (`List<ReorderSuggestion>`), `lowStock` / `outOfStock` (name-sorted `ProductEntity` lists), `capped` flag.

Math (`lib/core/utils/reorder_suggestions.dart`): `unitsSoldByProduct` (:34-42) sums qty per productId across sale items; `computeReorderSuggestions` (:51-79) — active products only, `velocity = unitsSold/windowDays`, `target = ceil(velocity × coverDays)`, `suggested = max(0, target − stock)`, rows ≤ 0 excluded; sorted by supplier name (nulls last) then qty desc. Mirrors `web_admin/src/domain/reorder/computeReorderSuggestions.ts`.

Also read: `productsProvider` (sheet + suggestions), `currentUserProvider` (creator stamps, admin gate), `saleRepositoryProvider` (movement window), `receivingRepositoryProvider` (receiving reference on Receive).

## Data model

`PurchaseOrderEntity` (`lib/domain/entities/purchase_order_entity.dart`): `id, referenceNumber (PO-YYYYMMDD-NNN), supplierId?, supplierName?, items[], totalCost, totalQuantity, status, notes?, createdAt/By/ByName, orderedAt?, receivedAt?, receivingId?` + `recalculateTotals()`. `PurchaseOrderItemEntity` (:142-195): `id, productId, sku, name, quantity, unit, unitCost` (expected cost — real cost is set on the receiving at delivery), `costCode`. Model/converter/repo mirror the receivings layering (`lib/data/models/purchase_order_model.dart`, `lib/data/repositories/purchase_order_repository_impl.dart`).

## CSV share

`buildPurchaseOrderCsv` (`lib/core/utils/purchase_order_csv.dart:9-19`): header block (`Purchase Order {ref}` / `Supplier` / `Date {yyyy-MM-dd}`), blank row, then columns **`SKU, Name, Qty, Unit` — no costs by design** (the CSV goes to the supplier). Shared through the existing `saveReportCsv` helper (`lib/core/utils/report_export.dart`), filename `{referenceNumber}.csv` (detail :324-325).

## Theming

Shared pieces used: `AppCard` (list card + detail header), `state_views.dart` (`LoadingView` / `ErrorStateView` / `EmptyStateView`), `showAppConfirmDialog` (`app_dialog.dart`), `AppWaitingDialog` via `context.runWithWaiting` (all mutations), snackbar extensions (`navigation_extensions.dart:91,117`), `toIsoDate()` dates, Lucide icons throughout the screens, global `chipTheme` / `inputDecorationTheme` / button themes / FAB theme from `app_theme.dart`. **Not yet used:** the elevated-theme row patterns (glyph tiles, stepper pills, recessed previews), `tiled:` empty states, `AppSpacing`-tokenized paddings — this feature shipped on functional Material defaults (see below).

## Permissions

Everything gated by `Permission.accessReceiving` (staff + admin): the dashboard pill, `/reorder` (route_guards.dart:35-36), and `/reorder/…` dynamics (:186-189). **Delete is additionally admin-only** — in UI (detail :46-47, :67-68) and in `firestore.rules` (the `purchase_orders` block mirrors `receivings`: staff/admin read/create/update, admin delete).

---

## Redesign starting points

Concrete, code-observable friction points (no invented user complaints):

1. **`AppCard` used with no padding — content flush to the card edge:** both the list `_OrderCard` (`purchase_orders_screen.dart:104-126`) and the detail header card (`purchase_order_detail_screen.dart:100-131`) pass no `padding` to `AppCard`, which only pads when asked (`app_card.dart:39-41`). Every other card in the app passes 12–16px.
2. **`ChoiceChip` plays two different roles on one screen:** on `/reorder/new` the window presets 30d/60d/90d (`new_purchase_order_screen.dart:203-208`) and the By status / By supplier **view toggle** (:231-242) are the same control — a mode switch styled identically to a parameter picker, stacked as two chip rows. Elsewhere the app uses `SegmentedButton` for mode toggles (e.g. `job_order_reports_screen.dart`). The list's status filter (`purchase_orders_screen.dart:51-63`) is a third ChoiceChip row.
3. **Params row density:** three chips + spacer + an 88px "Cover days" `TextField` in one row, then a second full row for the view toggle (`new_purchase_order_screen.dart:199-244`) — two control rows (plus the optional cap note) before any content. The cover field also only applies **on keyboard submit** (:221), so an edited value can silently not be what the list reflects.
4. **Plain `Row` item rows vs the app's card/stepper language:** suggestion rows (`new_purchase_order_screen.dart:289-319`) and detail item rows (`purchase_order_detail_screen.dart:145-177`) are bare Rows with Material `Checkbox` and naked 16px `IconButton` +/− steppers — no `AppCard`, no POS stepper pill, no qty-badge/SKU-mono treatment like `CartItemTile` / the receiving rows.
5. **Detail action bar is a `Wrap` of mixed buttons** (`purchase_order_detail_screen.dart:274-277`): up to three Filled/Outlined/Outlined-icon buttons that wrap into ragged lines on the ordered state; no pinned-footer hierarchy (compare the Job Orders editor summary footer). The dirty-state Save changes / Discard bar (:198-217) is a second, differently-shaped bar swapped into the same slot.
6. **Non-token colors in the status style** (`purchase_order_status_style.dart`): ordered-light text `#C8881A` (:34, comment admits "no token") and all eight tint literals (`0x14000000`, `0x1FFFFFFF` :29; `0x1FF57C00`, `0x24F5B547` :38; `0x294CAF50` :44; `0x1AF44336`, `0x24FF6B5E` :51) are inline rather than `AppColors` tokens.
7. **Add-product bottom sheet is off-pattern** (`new_purchase_order_screen.dart:342-380`): plain `TextField` + default `ListTile`s in a fixed 420px sheet, no grab handle / title / rounded-top shell, and it **closes after each pick** — the Job Orders `_AddPartsSheet` (grab handle, `ProductSearchField` with barcode scan, stays open to accumulate) is the established pattern for exactly this job.
8. **No search or supplier filter on the list** (`purchase_orders_screen.dart`): only the status chips; POs are found by scanning reference numbers. Cards show no cost total either (only `pcs`), though `totalCost` exists on the entity — possibly deliberate (CSV hides costs), worth an explicit decision.
9. **Machine dates:** every date renders as `toIsoDate()` → `2026-07-03` (list :117, detail :116-123) where sibling features use friendly `MMM d, h:mm a` formats.
10. **FAB vs app-bar create:** the list uses a `FloatingActionButton` (`purchase_orders_screen.dart:40-43`) while the theme redesign removed FABs elsewhere (Job Orders ships an app-bar `plus` action).
11. **Unstyled cap warning:** the "Movement data may be incomplete (sales cap reached)" note (`new_purchase_order_screen.dart:245-249`) is a bare `Text` with no padding rhythm or warning treatment (the theme has an amber-note pattern).
12. **Empty states are un-tiled:** both screens use `EmptyStateView` without `tiled: true` (bare 64px glyph; `purchase_orders_screen.dart:76-80`, `new_purchase_order_screen.dart:252-256`) while redesigned screens use the 86px soft-square tile.
13. **Material-icon straggler in nav metadata:** the drawer/menu item for `/reorder` uses `Icons.shopping_cart_checkout` (`route_guards.dart:253-255`) while the feature identity everywhere else is Lucide `clipboardList`.
14. **Naming split:** the dashboard pill and list app bar say **"Reorder"**, the detail app bar says **"Purchase Order"**, the create screen "New Purchase Order", copy says "purchase orders", the save button "Save drafts" (which actually creates one PO per supplier — the count is only revealed in the after-the-fact snackbar). Pick one user-facing name and make the save button say what it does.
15. **List error state has no retry** (`purchase_orders_screen.dart:70`): `ErrorStateView` is rendered without `onRetry`, unlike the drafts/receiving lists which invalidate-and-retry.
