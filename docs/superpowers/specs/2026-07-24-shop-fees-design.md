# Shop fees: outside-item charges, electric charge, tire changer, air

Date: 2026-07-24
Surface: Flutter mobile + one new firestore.rules block (deploy user-gated).
Web admin untouched (read-side tolerant; parity is a follow-up).

## Problem

The shop charges fees that are neither product sales nor mechanic labor:
servicing customer-supplied ("outside") items — charged ON TOP of the
mechanic's labor fee — and equipment/utility fees (electric charge, tire
changer, air, …). There is nowhere to record them, so they either go
untracked or get shoehorned into items/labor, corrupting money routing.

## Decisions (confirmed with user)

- Fee money belongs to the SHOP/management. An outside-item job carries a
  normal labor line (mechanic's) PLUS a shop-fee line (management's).
- Managed fee catalog with per-entry optional default amount; amount
  editable at charge time (outside-item fee varies per item).
- Fee-only checkout is allowed (no items, no labor, no mechanic).
- Job Orders carry fee lines too — full parity with labor lines (saved on
  ticket, survive bill-out, shown on JO detail).
- Approach A: first-class `feeLines` — NOT pseudo-products (would pollute
  inventory/velocity/reorder/top-selling), NOT flagged labor lines (would
  corrupt the labor→mechanic EOD handoff routing).

## Design

### 1. Fee catalog

- `ShopFeeEntity { id, name, defaultAmount (double?, null = no default),
  isActive, createdAt }` + model/converter, `shop_fees` Firestore
  collection, repository + providers mirroring the mechanics data layer
  (all/active streams + operations notifier with create/update/
  deactivate/reactivate; nameExists guard like mechanics).
- Settings → Lists: "Shop Fees" tile alongside Mechanics/Motorcycle Models,
  gated by `editLists` (route) with deactivate affordances gated by
  `manageCategories` — identical to the other editors (SettingsCrudRow;
  the edit dialog gets a name field + optional default-amount field).
- firestore.rules: new `shop_fees` block using the 2026-07-24 shared-list
  pattern verbatim (read any active user; create/update any active user
  with `isActive` flips staff+admin; delete admin-only). Emulator tests
  clone the shared-list describe entries for `shop_fees`.
  **Deploy is a separate user-confirmed step.**

### 2. Fee lines on cart, JO, sale

- `FeeLineEntity { id, name, amount }` (Equatable; converter for maps).
- CartState gains `feeLines: List<FeeLineEntity>` + `feesTotal`;
  `grandTotal = partsRevenue + laborRevenue + feesTotal`. Checkout-guard
  update: a cart with ONLY fee lines may check out; the existing
  labor-only block stays (labor without items is still blocked UNLESS
  fees or items are present — exact rule: checkout requires items OR
  fees; labor alone remains blocked).
- `DraftEntity` gains `feeLines` (default const []); draft converter
  round-trips them; bill-out conversion copies them into the sale.
- `SaleEntity` gains `feeLines` + `feesTotal` getter;
  `grandTotal = partsRevenue + laborRevenue + feesTotal`. Sale model
  persists `feeLines` (old docs read back as empty list). `cashCollected`
  and tender math are unchanged (tenders already cover the grand total).

### 3. POS + JO UI

- POS checkout flow: "Shop Fees" section beside the Labor section — add
  opens a picker of active catalog fees (name + default amount shown),
  amount pre-filled from default and editable (required if no default);
  rows removable like labor rows. Same section in the JO save dialog,
  JO edit screen, and read-only rows on the JO detail sheet.
- Sale detail screen: fee lines listed in their own block between items
  and labor (name + amount, amounts in mono per today's identifier rules
  only where they are identifiers — fee names are prose, normal font).
- Receipt: fee lines printed after labor lines, included in totals.

### 4. Money + EOD

- Drawer/tender math unchanged — fees are part of the tendered total.
- EOD: `SalesSummary` gains `feesRevenue` (sum of feeLines across
  completed sales; parts gross/net stay PARTS-ONLY). `DailyClosingDraft`/
  `DailyClosingEntity` gain `feesRevenue` (display + snapshot, like
  `laborRevenue`; old closing docs read back 0). EOD Sales card shows
  "Shop fees" when > 0. Handoff math NEEDS NO CHANGE: mechanics get
  `laborRevenue`, management keeps everything else — fees included
  automatically. `PostCloseActivity` gains `feesDelta` display in the
  After-close card ONLY IF trivial; otherwise fees ride the existing
  gross/cash deltas (they are cash-tendered) — decide in planning, do not
  expand hasChanged semantics.
- Void: voiding a sale reverses nothing fee-specific (no stock, no
  mechanic); fee revenue simply drops out of summaries like labor does.

### 5. Reporting

- Sales report (mobile): "Shop fees" line beside Labor revenue; CSV gains
  a fees column/row consistent with the existing layout. Labor report
  untouched. Top-selling/velocity/reorder untouched (fees are not
  products).

### 6. Out of scope

- Web admin UI (stored totals keep web reports correct; web sale detail
  won't itemize fees yet — follow-up).
- Fee analytics beyond the daily/report lines.
- Migrating old sales (none carry fees; wiped DB starts clean).

## Testing (TDD; tests mirror lib/)

- Entities: FeeLine/Sale/Draft/Cart totals math incl. fee-only checkout
  guard and labor-only-still-blocked; converters round-trip (incl. legacy
  docs without feeLines).
- Catalog: repo/notifier unit tests mirroring mechanics'; editor widget
  tests (add/edit dialog with default amount; cashier sees no deactivate).
- POS/JO widget tests: add-fee flow (default prefilled, editable,
  required-if-no-default), JO save/bill-out carries fees, sale detail and
  receipt render fee blocks.
- EOD: summary aggregation feeds feesRevenue; closing snapshot stores it;
  Sales card shows the line.
- Rules: emulator describe for `shop_fees` cloned from the shared-list
  pattern (incl. inactive-user + cashier-delete denials).
