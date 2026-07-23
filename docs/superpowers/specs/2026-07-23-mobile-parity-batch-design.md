# Mobile parity batch — 7 items (labor rows, JO numbers, top-selling UI, EOD, plate amounts, scroll structure, dashboard)

**Date:** 2026-07-23
**Status:** Approved (user dictated the 7 items; plate-amounts storage decision: persist each amount)

A scout report with exact file:line anchors for every area is at
`.superpowers/sdd/scout-mobile-batch2.md` — plans/implementers should read it.

## 1. Labor-line row parity (POS adopts the Job Order style)

POS's `LaborLineTile` (swipe-to-dismiss + pencil-icon edit) and draft-edit's
`_buildLaborLineRow` (whole-card tap-to-edit + trailing ✕ remove) are two
implementations. **The Job Order style wins.**

- Extract ONE shared labor row widget (whole-card `AppCard(onTap: edit)`,
  wrench icon, description, fee, trailing ✕ `IconButton` remove — the
  draft-edit look) and ONE shared add/edit labor dialog (deduping
  `LaborLineTile._showEditDialog` and `_LaborLineDialog`, title flips
  Add/Edit, same validators: description required, fee > 0).
- Both screens use them. POS keeps its section structure (ExpansionTile,
  MotorcycleModelPicker + MechanicPicker, validation banner, bounded
  scrollable list, "Add labor line" button); draft-edit keeps its structure.
- `LaborLineTile` and the two private dialogs are retired. Callback-shape
  reconciliation (CartNotifier `(id, {description, fee})` vs DraftEntity
  whole-`LaborLineEntity`) happens at the call sites, not in the shared widget
  (widget exposes `onEdited(description, fee)` + `onRemove`).
- Update/replace `labor_line_tile_test.dart` for the shared widget (tap-to-edit,
  ✕ removes, dialog validation); keep pos_labor_section + draft_edit_labor
  tests green.

## 2. Auto JO number in the drafts-list "New Job Order" flow

`drafts_list_screen._createJobOrder` → `showNewJobOrderDialog` still has the
free-text "Customer / plate" field. Mirror the POS flow exactly:

- `_createJobOrder` fetches today's drafts
  (`getDraftsByDateRange(includeConverted: true)`) under `runWithWaiting`,
  computes `nextJobOrderNumber(now, names)`, passes `jobOrderNo` into the
  dialog; error path = snackbar + abort (same as pos_screen).
- `new_job_order_dialog` drops the TextField for the same read-only
  Job Order No. row used by `save_job_order_dialog`; Save returns
  `label = jobOrderNo`. Update `new_job_order_dialog_test.dart` to the new
  contract (read-only number, no label gate).

## 3. Dashboard Top Selling adopts the ranked/bar UI

- Extract the rank-row visual from `TopProductsCard._RankRow` into a shared
  widget parameterized on a plain display shape: rank, name, subtitle
  (SKU or "N sold"), quantity, revenue, maxQuantity (for the share bar),
  optional onTap, optional profit pill. Medal colors (gold/silver/bronze top
  3) + `LinearProgressIndicator` share bar come with it.
- `TopSellingTodayWidget` renders those rows fed from its EXISTING live
  `topSellingTodayProvider` data (no provider/data change, no permission
  gate, no profit pill on the dashboard). Keeps the 5/10 See-more collapse
  and the section header + "View All" link.
- `TopProductsCard` switches to the shared row (no visual change on the
  reports screens). Its tests and the top-selling screen tests stay green.

## 4. EOD Add Expense button joins the section heading row

- `ClosingSectionCard` gains an optional `trailing` widget slot
  (Spacer + trailing appended to the hard-coded header Row). Additive param;
  all other call sites unchanged.
- The Expenses card passes the existing compact Add Expense button as
  `trailing`; the button (and its 16px spacer) leave the children list.

## 5. Plate No DP / Delivery — multiple amounts, PERSISTED itemized

- `DailyClosingEntity` + `DailyClosingModel` gain `plateNoDpAmounts` and
  `plateNoDeliveryAmounts` (`List<double>`, default const []), round-tripped
  to Firestore arrays. The existing scalar `plateNoDp`/`plateNoDelivery`
  REMAIN and always equal the sum of their list (single source for
  `expectedCashFor` math and back-compat: old docs have scalars only, read
  back with empty lists).
- `CloseDayUseCase` + `DailyClosingOperationsNotifier.closeDay` accept the
  two lists; sums computed once in the use case; entity stamped with lists +
  sums. No firestore.rules change (closings writes already permitted).
- EOD screen: each field becomes an add-a-row amount list (amount input +
  add; rows removable while open) with a live sum line; the sums feed the
  existing expected-cash preview. Closed-day view: itemize each amount
  (e.g. "Plate No DP · 3 entries" with rows) when lists are non-empty, else
  the current single KV rows (old docs).
- Tests: model round-trip (lists + missing-field back-compat), use-case sum
  stamping, EOD widget add/remove/sum, closed-day itemized display.

## 6. Job Order POS scroll structure + keyboard-dismiss unfocus

- `draft_edit_screen` restructures to POS's pattern: ONE
  `SingleChildScrollView` containing draft header (model/notes), Parts
  header + list (list loses its own Expanded/scroll; shrinkWrap non-scrolling
  like POS's cart list), and the labor section; the summary + Bill-out block
  becomes the sticky bottom footer (AppShadows.pinnedFooter, like POS's
  action buttons). AppBar stays.
- Keyboard-dismiss → unfocus: when the software keyboard disappears while a
  search field has focus, drop the focus (closes cursor + any results
  overlay). Implement once in `ProductSearchField` (WidgetsBindingObserver
  `didChangeMetrics`: viewInsets bottom collapsing to ~0 while its focus node
  hasFocus → unfocus). Covers POS search + the add-parts sheet's inline field.
- Existing draft-edit widget tests updated for the new structure; new test for
  the unfocus-on-keyboard-dismiss behavior if testable via
  `tester.view.viewInsets` simulation (else document manual smoke).

## 7. Dashboard: unpin menu + calendar

- `_buildPinnedHeader()`'s contents (`_buildDateHeader()` + `QuickActions`)
  move into the top of the existing `CustomScrollView` as the first sliver
  items; the pinned Container (and its pinnedHeader shadow) is removed; body
  becomes the RefreshIndicator + CustomScrollView directly. AppBar remains
  fixed. Everything below the AppBar scrolls.
- New widget test pinning the structure: date header + QuickActions are
  inside the scrollable (e.g. scrolling moves them off-screen / they sit in
  the CustomScrollView subtree), since no dashboard structure test exists.

## Out of scope

- Web admin (untouched). firestore.rules (untouched). Reports/CSV changes.
- Any change to labor/cart/draft data models (item 1 is presentation-only).

## Verification

`flutter test` + `flutter analyze` green; per-item widget tests as above;
user device-smokes the batch on the A71 with the next APK.
