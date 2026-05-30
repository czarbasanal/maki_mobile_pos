# POS Service-Draft: Labor Lines & Configurable Mechanics

**Date:** 2026-05-30
**Status:** Design approved, pending spec review
**Roadmap:** Activates parked §25 (mechanic labor); touches §27 groundwork only as out-of-scope.

## 1. Summary

A service draft (a motorcycle parked in the shop with an ongoing job) needs to capture
**mechanic labor** on top of the parts already in the cart. Today the POS is parts-only:
`DraftEntity`/`SaleEntity`/`CartState` carry a list of product line items and nothing else.

This adds two things:

1. **Labor lines** — a list of `{description, fee}` charges on a draft/sale/cart, plus a
   single **mechanic** assigned to the whole job. Labor is full price (never discounted) and
   reported as a **separate revenue/profit track** from merchandise.
2. **A configurable Mechanics list** — an admin-managed `name + isActive` list (its own
   `MechanicEntity`, mirroring the existing category-list pattern), surfaced as its own
   Settings entry and consumed by a cashier-facing mechanic picker.

The draft remains the single "ongoing job" object — no new service-vs-sale flag. Labor is an
optional section that is simply empty for normal held sales.

## 2. Locked decisions

| # | Decision | Choice |
|---|----------|--------|
| 1 | Labor structure | **Multiple free-form labor lines** (`description` + `fee`), **one mechanic per job** |
| 2 | When labor is editable | **Anytime on the draft** (and in the POS cart); the checkout screen is the "finishing" review |
| 3 | Mechanic record fields | **Name + isActive only** (audit fields included); commission/contact deferred |
| 4 | Labor & discounts | **Never discounted** — full price, structurally (labor lives on a different code path from item discounts) |
| 5 | Labor data model | **Dedicated `LaborLineEntity`** (not a tagged `SaleItemEntity`) |
| 6 | Labor-only ticket | **Not allowed** — a ticket still requires ≥1 part; today's `items.isEmpty → invalid` rule is unchanged |
| 7 | Mechanic admin infra | **Dedicated `MechanicEntity`/repo/provider/screen** (not reusing `CategoryKind`) — clean naming, room to grow |
| 8 | Labor persistence | **Inline array** on the draft and sale documents (matches how drafts already store items; avoids extra reads) |
| 9 | Report rollup | **Parts-only top-line.** Existing dashboards/closing stay parts-only; labor is a **separate** revenue/profit track. Cash reconciliation is the only crossover (drawer holds labor cash). |

## 3. Domain model

### 3.1 New entity — `LaborLineEntity`

`lib/domain/entities/labor_line_entity.dart` (Equatable, immutable, `copyWith`, `props`):

```dart
class LaborLineEntity extends Equatable {
  final String id;          // uuid, like cart items
  final String description; // "Engine tune-up", "Brake bleed"
  final double fee;         // peso amount; full price, never discounted
  // No cost field — labor cost is always zero (pure margin).
}
```

Export via `lib/domain/entities/entities.dart` (the barrel `cart_provider`, `sale_model`,
`draft_model` all import).

### 3.2 New entity — `MechanicEntity`

`lib/domain/entities/mechanic_entity.dart`, a near-copy of `CategoryEntity`:

```dart
class MechanicEntity extends Equatable {
  final String id;
  final String name;        // display + match key
  final bool isActive;      // soft-delete; inactive drops off the picker, stays valid on history
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  // + copyWith, props, MechanicEntity.empty()
}
```

A standalone entity (vs reusing `CategoryKind`) so fields can grow (commission %, contact)
without entangling category code. See §5.

### 3.3 Fields added to `CartState`, `DraftEntity`, `SaleEntity`

All three gain the same three fields:

```dart
final List<LaborLineEntity> laborLines; // default const []
final String? mechanicId;               // null until assigned
final String? mechanicName;             // snapshot, like cashierName / createdByName
```

`mechanicName` is snapshotted (existing denormalization convention — cashier/supplier names are
stored inline) so deactivating or renaming a mechanic never rewrites history.

Each must update: constructor, `copyWith` (with a `clearMechanic` flag for the nullable
mechanic fields), and `props`.

### 3.4 Money math — the getters

Today `grandTotal = subtotal − totalDiscount`. The new shape, **identical in all five places**
that compute it (`DraftEntity`, `SaleEntity`, `DraftModel`, `SaleModel`, `CartState`):

```dart
double get partsSubtotal => subtotal;                       // existing items gross; unchanged
double get totalDiscount  => /* unchanged — folds over items only */;
double get laborSubtotal  => laborLines.fold(0.0, (s, l) => s + l.fee);

double get partsRevenue   => partsSubtotal - totalDiscount; // net merchandise revenue
double get laborRevenue   => laborSubtotal;                 // pure margin (zero cost)

double get grandTotal     => partsRevenue + laborRevenue;   // == subtotal − discount + labor

double get totalCost      => /* unchanged — items only; labor has no cost */;
double get partsProfit    => partsRevenue - totalCost;
double get laborProfit    => laborRevenue;                  // zero cost
double get totalProfit    => partsProfit + laborProfit;     // true per-transaction profit
```

**Discount math is untouched** — it only ever folds over `items`, so labor structurally cannot
be discounted (decision #4 enforced by construction, not a special case). `totalCost` stays
items-only, so labor is pure margin.

> **Critical:** `grandTotal` is reimplemented in **five** places. All five must change together
> or persisted totals diverge from displayed totals.

## 4. Persistence (Firestore)

### 4.1 Labor lines — inline (decision #8)

- **Drafts** already store `items` inline as an array on the doc. Labor lines join them:
  the draft doc gains `laborLines: [ {id, description, fee}, … ]` plus `mechanicId` /
  `mechanicName` fields.
- **Sales** store `items` in a **subcollection** (`sales/{id}/items`) — but **labor lines are
  stored inline** on the sale doc (same `laborLines` array + mechanic fields). This is a
  deliberate divergence from how sale *items* are stored, justified because labor lines are few,
  always loaded with the sale, and inline avoids adding a second subcollection read to the
  existing item-load path.

  > **Breaking risk:** if labor is accidentally routed through the `items:` subcollection path,
  > `getSaleById` / `_loadSalesWithItems` (which only fetch the `items` subcollection) will
  > silently drop labor from every loaded sale and all reports. `SaleModel.fromMap` must parse
  > `map['laborLines']` **directly** and must not pass it via the `items:` parameter.

### 4.2 New model — `LaborLineModel`

`lib/data/models/labor_line_model.dart`: `fromMap(map, id)` / `toMap({includeId})` /
`toEntity()` / `fromEntity()`, mirroring `SaleItemModel.toMap(includeId: true)` so it serializes
inline inside the parent's `laborLines` array. Export via `lib/data/models/models.dart`.

### 4.3 Model changes

- **`DraftModel`** — add `laborLines` (`List<LaborLineModel>`), `mechanicId`, `mechanicName` to
  constructor / `fromMap` (parse `laborLines` array like `items`; default to `[]` and `null` for
  legacy docs) / `toMap` (emit them; flows through `toCreateMap`/`toUpdateMap`) / `toEntity` /
  `fromEntity` / `copyWith` / `create` / `empty`. Update `grandTotal` getter; add `laborSubtotal`.
- **`SaleModel`** — same field additions; `fromMap` parses `map['laborLines']` directly (see
  §4.1); update `grandTotal` getter.
- **Legacy data:** `fromMap` defaults `laborLines → []`, mechanic fields → `null`, so existing
  docs deserialize without throwing.

### 4.4 Mechanics collection

Add `static const String mechanics = 'mechanics';` to
`lib/core/constants/firestore_collections.dart`. No subcollection (labor is inline).

### 4.5 New model — `MechanicModel`

`lib/data/models/mechanic_model.dart`, mirroring `CategoryModel`:
`fromMap`/`fromFirestore`/`toMap({forCreate, forUpdate})`/`toEntity`/`fromEntity`. Export via barrel.

## 5. Mechanics admin list (dedicated entity)

Mirror the category-list pattern as **standalone** files (decision #7):

| Layer | File | Mirrors |
|-------|------|---------|
| Entity | `lib/domain/entities/mechanic_entity.dart` | `category_entity.dart` |
| Model | `lib/data/models/mechanic_model.dart` | `category_model.dart` |
| Repo (abstract) | `lib/domain/repositories/mechanic_repository.dart` | `category_repository.dart` |
| Repo (impl) | `lib/data/repositories/mechanic_repository_impl.dart` | `category_repository_impl.dart` |
| Provider | `lib/presentation/providers/mechanic_provider.dart` | `category_provider.dart` |
| Editor screen | `lib/presentation/mobile/screens/settings/mechanic_editor_screen.dart` | `category_editor_screen.dart` |

- **Repository interface** mirrors `CategoryRepository`: `watchActive()`, `watchAll()`,
  `create()`, `update()`, `setActive()`, `nameExists()`.
- **Providers** mirror the category ones (no `.family`, since there's a single mechanics
  collection): `mechanicRepositoryProvider`, `activeMechanicsProvider` (auth-gated stream of
  active mechanics, used by the picker), `allMechanicsProvider` (admin screen), and
  `MechanicOperationsNotifier` / `mechanicOperationsProvider` for create/update/deactivate/
  reactivate. Reuse `authGatedStream` and the `currentUserProvider` actor pattern.
- **Editor screen** is a near-copy of `category_editor_screen.dart` (list active + inactive,
  add/edit/deactivate/reactivate, name-exists validation) minus the "seed defaults" action
  (no default mechanics).
- **Settings entry:** add a **dedicated "Mechanics" tile** to the settings hub (its own route),
  **not** under "Categories" — a mechanic is staff, not a category. Subtitle: "Used to assign a
  mechanic to a service draft." Add the route alongside the existing category-editor routes.
- **Permission gating:** reuse whatever role gate guards the existing category/admin settings
  routes (admin-only), at the route layer.

### 5.1 Mechanic picker (cashier-facing)

`lib/presentation/mobile/widgets/pos/mechanic_picker.dart` — a dropdown that watches
`activeMechanicsProvider` and renders mechanic names; model it on the void-reason dropdown in
`void_sale_dialog.dart` (lines 264–290). On select, calls `cart.setMechanic(id, name)`.
Deactivated mechanics never appear (but remain valid on historical sales via the snapshot).

## 6. Reporting & money rollup (parts-only top-line — decision #9)

**Principle:** merchandise reporting stays parts-only and unchanged; labor is a parallel track;
cash reconciliation is the only place the two combine (because the drawer holds real cash);
per-transaction views always show the true labor-inclusive total.

### 6.1 `SalesSummary` (`lib/domain/repositories/sale_repository.dart`)

Keep existing fields meaning **parts-only** (zero dashboard disruption) and **add** a labor track:

- `grossAmount`, `netAmount`, `totalDiscounts`, `totalCost`, `totalProfit` → **parts-only**.
- **New:** `laborRevenue`, `laborProfit` (`= laborRevenue`, zero cost).
- Update constructor + `SalesSummary.empty()`; document that `totalCost` is items-only.

> **Naming note:** `SalesSummary.totalProfit` is **parts-only** (merchandise gross profit),
> whereas `SaleEntity.totalProfit` (§3.4) is the **combined** true profit of a single
> transaction (`partsProfit + laborProfit`). They are intentionally different scopes: the entity
> reports the truth of one sale; the summary keeps the merchandise track isolated. Combined
> aggregate profit, where needed, is `summary.totalProfit + summary.laborProfit`.

### 6.2 `getSalesSummary` (`sale_repository_impl.dart`, ~lines 483–501)

- `netAmount += sale.partsRevenue` (NOT `sale.grandTotal`) — keeps net sales parts-only.
- `grossAmount += sale.partsSubtotal`; `totalCost += sale.totalCost` (already parts-only);
  `totalProfit = netAmount − totalCost` (parts profit).
- **New:** `laborRevenue += sale.laborRevenue`; `laborProfit = laborRevenue`.
- **`byPaymentMethod` buckets keep summing `sale.effectiveTenders`** (now labor-inclusive) —
  this is the cash track. Reconciliation identity: `Σ byPaymentMethod = netAmount(parts) + laborRevenue`.

### 6.3 Per-surface resolution

| Surface | File | Reads | Behavior |
|---------|------|-------|----------|
| Mobile dashboard Gross Profit / COGS | `sales_summary_section.dart` (87–90) | parts `totalProfit`/`totalCost` | **unchanged numbers**; add a "Service / Labor" card reading `laborRevenue`/`laborProfit` |
| Web dashboard revenue/profit | `web_dashboard_screen.dart` (55) | parts | unchanged; add labor card |
| Sales summary card | `sales_summary_card.dart` (109/191/195) | parts | unchanged; optional labor rows (admin-only) |
| Top products | `top_products_card.dart` (239) | product-level | **no change** — labor is not product-level |
| Avg daily sales | `sale_provider.dart` `avgDailySalesProvider` | parts `grossAmount` | parts-only |
| Daily closing | `daily_closing_entity.dart` `DailyClosingDraft.fromData` (74–76) | see §6.4 | parts net sales + separate labor line; drawer includes labor |
| End-of-day screen | `end_of_day_screen.dart` (106–115) | closing fields | show "Net Sales (parts)" + "Labor revenue" → "Total collected" |
| Per-sale total / list | `sales_list_screen.dart` (139/245), `recent_sale_widget.dart` (155), `drafts_list_screen.dart` (220) | `grandTotal` | **labor-inclusive** (true total) — verify-only |
| Sale detail / receipt / checkout | see §7 | `grandTotal` + breakdown | labor-inclusive, itemized |

### 6.4 Daily closing

- `grossSales` / `netSales` = parts-only (read `summary.grossAmount` / `summary.netAmount`,
  which are now parts-only by §6.2).
- **New** `laborRevenue` field on the closing snapshot (`DailyClosingEntity` /
  `DailyClosingDraft.fromData`), surfaced as its own line.
- `byPaymentMethod` / `expectedCash` **include labor** (physical cash) — labor cash paid in cash
  raises expected drawer cash. This is correct; the EOD screen must show the labor line so the
  team understands the total rose. `close_day_usecase.dart` reads the shifted figures (verify-only,
  no logic change unless we add the labor line to its output).

## 7. UI / UX flow

### 7.1 Labor editing (anytime — decision #2)

A collapsible **"Labor & Service"** section appears below the items list in both:

- the POS cart — `pos_screen.dart` / `cart_summary.dart`, and
- the draft editor — `draft_edit_screen.dart`.

It contains the **mechanic picker** (§5.1, one per ticket) and an add/edit/remove list of labor
lines. Individual labor lines are editable (decision: individually editable), via a
`labor_line_tile.dart` widget modeled on `cart_item_tile.dart`.

New `CartNotifier` methods: `addLaborLine`, `updateLaborLine`, `removeLaborLine`, `setMechanic`,
`clearMechanic`. `CartNotifier.loadFromDraft` copies `laborLines` + mechanic from the draft;
`toDraft` and `toSale` pass them through.

> **Breaking risk:** `toDraft` / `toSale` currently construct `DraftEntity` / `SaleEntity`
> **without** labor/mechanic args. If not updated, a cashier can add labor and pick a mechanic
> and it is silently dropped on save-as-draft and on checkout. Both must be updated.

### 7.2 The "finishing" step (checkout summary)

`checkout_screen.dart` — `_buildItemsList` renders labor lines after products (description + fee,
no discount affordance); `_buildPaymentSummary` (~228–246) gains the breakdown:

```
Parts subtotal      ₱ 1,250.00
Discount           −₱   100.00
Labor (2 services)  ₱   450.00   ← Mechanic: Juan Dela Cruz
─────────────────────────────
Grand total         ₱ 1,600.00
```

### 7.3 Receipt

`receipt_widget.dart` — `_buildItemsSection` prints a labor section (mechanic, description, fee)
after products; `_buildTotalsSection` (~335–341) adds the labor subtotal line so the higher total
is explained; `_buildTransactionInfo` adds a `Mechanic: <name>` line when present.

### 7.4 Draft views

- `draft_edit_screen.dart` `_buildSummarySection` (~277–290): add labor subtotal + mechanic; render editable labor section.
- `draft_detail_sheet.dart` `_buildSummaryCard` (~317–335): add labor subtotal; append labor lines; `_buildInfoCard` shows a "Mechanic" row when present.
- `draft_list_tile.dart` `_buildItemsPreview`: add a "service job" badge/icon when `laborLines` is non-empty.

### 7.5 Sale detail

`sale_detail_screen.dart` (~366–377): add labor line items + labor subtotal before grand total;
show mechanic name.

### 7.6 Validation rules

- If any labor line exists, a **mechanic must be assigned** before checkout/save (block with a
  clear message). No labor lines → mechanic optional.
- Each labor fee must be `> 0`.
- A ticket still requires **≥1 part** to check out (decision #6) — `items.isEmpty → invalid`
  unchanged; labor adds nothing to that gate.
- Discount controls remain bound to items only; labor rows have no discount affordance.

## 8. Files

### 8.1 Create

- `lib/domain/entities/labor_line_entity.dart`
- `lib/data/models/labor_line_model.dart`
- `lib/domain/entities/mechanic_entity.dart`
- `lib/data/models/mechanic_model.dart`
- `lib/domain/repositories/mechanic_repository.dart`
- `lib/data/repositories/mechanic_repository_impl.dart`
- `lib/presentation/providers/mechanic_provider.dart`
- `lib/presentation/mobile/screens/settings/mechanic_editor_screen.dart`
- `lib/presentation/mobile/widgets/pos/mechanic_picker.dart`
- `lib/presentation/mobile/widgets/pos/labor_line_tile.dart`

### 8.2 Modify (grounded in the impact map)

- **Barrels/constants:** `domain/entities/entities.dart`, `data/models/models.dart`,
  `core/constants/firestore_collections.dart`.
- **Domain money math:** `draft_entity.dart`, `sale_entity.dart`.
- **Data models:** `draft_model.dart`, `sale_model.dart`.
- **Repositories:** `sale_repository.dart` (`SalesSummary`), `sale_repository_impl.dart`
  (`getSalesSummary`, `createSale`, `getSaleById`, `_loadSalesWithItems`).
- **Cart:** `cart_provider.dart` (fields, getters, helpers, `loadFromDraft`/`toDraft`/`toSale`).
- **Draft persistence path:** route labor edits through the full `updateDraft`
  (`draft_repository.dart` / `_impl` / `draft_provider.dart`), not the narrow `updateDraftItems`
  (which writes only the `items` field and would drop labor).
- **POS/checkout UI:** `pos_screen.dart`, `cart_summary.dart`, `checkout_screen.dart`,
  `receipt_widget.dart` (`payment_section.dart` is verify-only).
- **Drafts UI:** `draft_edit_screen.dart`, `draft_detail_sheet.dart`, `draft_list_tile.dart`.
- **Sales/reporting UI:** `sale_detail_screen.dart`, `sales_summary_section.dart`,
  `web_dashboard_screen.dart`, `sales_summary_card.dart`, `end_of_day_screen.dart`.
- **Daily closing:** `daily_closing_entity.dart` (add `laborRevenue`), `close_day_usecase.dart`
  (verify), `daily_closing_history_screen.dart` (verify).
- **Settings:** add Mechanics tile + route to the settings hub screen.
- **Verify-only (no code change, behavior shifts):** `process_sale_usecase.dart` (inventory
  iterates items only — labor correctly skipped), `void_sale_usecase.dart` (restock iterates
  items only — labor correctly not restocked), `request_void_sale_usecase.dart` (snapshot now
  labor-inclusive), `sales_list_screen.dart`, `recent_sale_widget.dart`, `drafts_list_screen.dart`.

## 9. Breaking risks (from impact analysis)

1. **Five-way `grandTotal` desync** — `DraftEntity`/`SaleEntity`/`DraftModel`/`SaleModel`/`CartState` must change together.
2. **Sale labor in wrong storage** — labor must be inline, not in the `items` subcollection, or it vanishes on load (§4.1).
3. **Cart → Draft/Sale drop** — `toDraft`/`toSale` must be updated or labor is silently lost (§7.1).
4. **Drawer reconciliation shift** — labor cash raises expected drawer cash; the EOD must show the labor line, and `close_day_usecase_test` fixtures (e.g. `expectedCash`) will change.
5. **Enum exhaustiveness** — *not applicable* under decision #7 (we use a dedicated `MechanicEntity`, so no `CategoryKind` switches to extend).
6. **Legacy data** — `fromMap` must default `laborLines → []`, mechanic fields → `null`.
7. **Hard-coded test totals** — many fixtures assume `grandTotal == parts subtotal`; these are expected breaks to update, not bugs (§10).
8. **Margin/avg recompute** — parts-only summary fields are unchanged by design, so dashboards stay stable; verify no surface accidentally reads `grandTotal` where it means "merchandise sales."

## 10. Testing

TDD per the project convention (tests precede implementation per layer). New + updated tests:

- **New:** `test/domain/entities/labor_line_entity_test.dart`, `test/data/models/labor_line_model_test.dart`,
  `test/domain/entities/mechanic_entity_test.dart`, `test/data/models/mechanic_model_test.dart`,
  `test/data/repositories/mechanic_repository_impl_test.dart`, cart labor tests
  (extend `test/presentation/providers/cart_provider_test.dart`: `addLaborLine`/`removeLaborLine`/
  `setMechanic`, `laborSubtotal`, parts-vs-labor split, `toSale`/`toDraft` carry labor+mechanic).
- **Update money-math expectations** (these break by design — hard-coded `grandTotal`/profit/expectedCash):
  `sale_entity_test.dart`, `draft_entity_test.dart`, `cart_provider_test.dart`, `cart_tenders_test.dart`,
  `sale_repository_impl_test.dart`, `sales_summary_tenders_test.dart`, `get_profit_report_usecase_test.dart`,
  `get_sales_report_usecase_test.dart`, `close_day_usecase_test.dart`,
  `get_daily_closing_summary_usecase_test.dart`, `daily_closing_draft_test.dart`,
  `post_close_activity_test.dart`, `process_sale_usecase_test.dart`,
  `process_sale_tender_validation_test.dart`, `void_sale_usecase_test.dart`.
- **Key behavioral assertions:** parts-only summary fields are unchanged when labor is present;
  `laborRevenue`/`laborProfit` aggregate correctly; checkout-with-labor does **not** deduct
  inventory for labor; void-with-labor does **not** restock labor; draft round-trips labor + mechanic;
  `Σ byPaymentMethod == netAmount(parts) + laborRevenue`.
- **Integration:** extend the `integration_test/` harness with a service-draft flow (add parts,
  add labor, assign mechanic, save draft, reload, checkout, verify receipt + parts-only report
  unchanged + labor in its own track).

## 11. Out of scope (YAGNI)

- Per-labor-line mechanic attribution (one mechanic per job only — decision #1).
- Mechanic commission %, payout reports, contact info (deferred — decision #3; roadmap §25 later).
- Labor-only / service-only tickets (decision #6).
- Structured customer / plate-number fields (use the draft's existing `name` + `notes`; roadmap §26).
- Discountable labor (decision #4).
- Predefined labor/service catalog (labor lines are free-form for now).

## 12. Implementation sequence

1. **Foundation** — `LaborLineEntity` + `LaborLineModel` + barrels; `FirestoreCollections.mechanics`.
2. **Domain money math** — labor/mechanic fields + new getters + updated `grandTotal` on
   `DraftEntity`/`SaleEntity`; labor helper methods. Update entity unit tests first (TDD).
3. **Data models** — mirror fields + serialization (inline labor + mechanic) + `grandTotal` in
   `DraftModel`/`SaleModel`; round-trip tests. Update `SaleRepositoryImpl` for inline labor.
4. **Reporting** — `SalesSummary` labor fields + `getSalesSummary` (parts-only top-line, labor
   track, labor-inclusive tenders); update report/repo tests.
5. **Cart layer** — fields/getters/helpers on `CartState`/`CartNotifier`; wire
   `loadFromDraft`/`toDraft`/`toSale`; update cart tests.
6. **Mechanics admin** — `MechanicEntity`/model/repo/provider/editor screen + Settings tile/route;
   repo tests.
7. **POS/checkout UI** — labor management + mechanic picker; labor in `cart_summary`/`checkout_screen`/`receipt_widget`.
8. **Drafts UI** — labor + mechanic in `draft_edit_screen`/`draft_detail_sheet`/`draft_list_tile`.
9. **Sales + reporting UI** — `sale_detail_screen` breakdown; dashboard "Service / Labor" card;
   daily closing + end-of-day labor line.
10. **Final test sweep** — fix all hard-coded total/profit/expectedCash fixtures; add labor
    integration coverage.
