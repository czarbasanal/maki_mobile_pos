# Cart Reset + Inventory Totals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web POS gets a confirm-guarded reset-sale button; mobile's existing reset gets honest dialog copy; both inventory screens get an admin-only, filter-aware totals strip (stock cost / retail value / expected profit).

**Architecture:** Pure `stockTotals` helper per surface reduced over the already-rendered filtered product list (zero extra Firestore reads). Web reset reuses `cartStore.clear()`; mobile reset already exists (`CartNotifier.reset()`).

**Tech Stack:** React+TS+Vitest (`web_admin/`), Flutter+Riverpod (`lib/`, `test/`).

**Spec:** `docs/superpowers/specs/2026-07-22-cart-reset-and-inventory-totals-design.md` (authoritative).

## Global Constraints

- Branch `feat/cart-reset-inventory-totals` (already checked out).
- Web commands from `web_admin/`: `npm run test` / `npm run typecheck`. Mobile from repo root: `flutter test` / `flutter analyze`.
- Admin gating idiom: mobile `ref.watch(currentUserProvider).value?.role == UserRole.admin` (as in `inventory_screen.dart:38-39`); web `useAuthStore((s) => s.user)` + `user?.role === UserRole.admin` (UserRole enum from `@/domain/entities`; check its exact import/name in `router/routeGuards.ts` before use).
- Formatters: mobile `num.toCurrency()`; web `formatMoney` from `@/core/utils/money`.
- Neutral styling (no status colors) per the app's color discipline; match neighboring class/token usage.
- Dialog copy (exact strings, spec §Decisions 1–2):
  - Mobile message: `This clears the whole sale — items, labor & service, mechanic, and payment amounts.`
  - Web title `Clear this sale?`, body `This clears the whole sale — items, labor & service, and mechanic.`, buttons Cancel / Clear.
- Do NOT touch the shared `CartBuilder.tsx` or `/drafts/:id` flow.

---

### Task 1: Web `stockTotals` helper

**Files:**
- Create: `web_admin/src/domain/products/stockTotals.ts`
- Test: `web_admin/src/domain/products/stockTotals.test.ts`

**Interfaces:**
- Produces: `stockTotals(products: Pick<Product, 'cost' | 'price' | 'quantity'>[]) -> { cost: number; retail: number; profit: number }`.

- [ ] **Step 1: Write the failing tests**

```ts
import { describe, expect, it } from 'vitest';
import { stockTotals } from './stockTotals';

describe('stockTotals', () => {
  it('returns zeros for an empty list', () => {
    expect(stockTotals([])).toEqual({ cost: 0, retail: 0, profit: 0 });
  });

  it('sums cost*qty and price*qty and derives profit', () => {
    const totals = stockTotals([
      { cost: 100, price: 250, quantity: 2 },
      { cost: 50, price: 80, quantity: 10 },
    ]);
    expect(totals).toEqual({ cost: 700, retail: 1300, profit: 600 });
  });

  it('counts zero-quantity items as zero contribution', () => {
    expect(stockTotals([{ cost: 999, price: 1999, quantity: 0 }])).toEqual({
      cost: 0,
      retail: 0,
      profit: 0,
    });
  });
});
```

- [ ] **Step 2: Run to verify failure** — `cd web_admin && npx vitest run src/domain/products/stockTotals.test.ts` → FAIL (module not found)

- [ ] **Step 3: Implement**

```ts
import type { Product } from '@/domain/entities';

export interface StockTotals {
  cost: number;
  retail: number;
  profit: number;
}

/** Inventory valuation over whatever list the screen is rendering. */
export function stockTotals(
  products: Pick<Product, 'cost' | 'price' | 'quantity'>[],
): StockTotals {
  let cost = 0;
  let retail = 0;
  for (const p of products) {
    cost += p.cost * p.quantity;
    retail += p.price * p.quantity;
  }
  return { cost, retail, profit: retail - cost };
}
```

- [ ] **Step 4: Run to verify pass** — same command → PASS

- [ ] **Step 5: Commit** — `git add web_admin/src/domain/products/stockTotals.ts web_admin/src/domain/products/stockTotals.test.ts && git commit -m "feat(web): stockTotals inventory valuation helper"`

---

### Task 2: Web inventory totals strip (admin-only, filter-aware)

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryListPage.tsx` (filtered list built at ~line 61: `const filtered = useMemo(() => filterProducts(active, { search, stock, category }), ...)`)
- Test: extend the page's existing test file (find it; if none exists for InventoryListPage, create `InventoryListPage.test.tsx` following the render/harness pattern of a neighboring page test such as `ReorderSuggestionsPage`'s).

**Interfaces:**
- Consumes: `stockTotals` (Task 1), `formatMoney`, `useAuthStore`, `UserRole`.

- [ ] **Step 1: Write the failing test** — three cases, using the file's existing mock harness idiom (mock `useProducts` with 2 products of known cost/price/qty and the auth store with an admin user):

```tsx
// Case 1: admin sees the three figures computed from the visible list
//   expect Stock Cost ₱700.00, Retail Value ₱1,300.00, Expected Profit ₱600.00
// Case 2: staff role -> queryByText('Stock Cost') is null
// Case 3: category filter applied -> totals recompute to the filtered subset
```

Write these as real assertions in the harness style of the neighboring tests (getByText on the formatted figures; fire the category select change for case 3). The exact mock helpers differ per file — mirror the existing test file's setup verbatim.

- [ ] **Step 2: Run to verify failure** — `npx vitest run src/presentation/features/inventory/` → new tests FAIL (strip not rendered)

- [ ] **Step 3: Implement the strip** — inside InventoryListPage, after `filtered` is computed:

```tsx
const user = useAuthStore((s) => s.user);
const isAdmin = user?.role === UserRole.admin;
const totals = useMemo(() => stockTotals(filtered), [filtered]);
```

Render above the table (below the filter controls), admin-only, matching the page's card/token classes:

```tsx
{isAdmin ? (
  <div className="flex flex-wrap gap-tk-xl rounded-lg border border-light-hairline bg-light-card px-tk-lg py-tk-md">
    <div>
      <p className="text-caption text-light-textSecondary">Stock Cost</p>
      <p className="text-bodyLarge font-semibold tabular-nums">{formatMoney(totals.cost)}</p>
    </div>
    <div>
      <p className="text-caption text-light-textSecondary">Retail Value</p>
      <p className="text-bodyLarge font-semibold tabular-nums">{formatMoney(totals.retail)}</p>
    </div>
    <div>
      <p className="text-caption text-light-textSecondary">Expected Profit</p>
      <p className="text-bodyLarge font-semibold tabular-nums">{formatMoney(totals.profit)}</p>
    </div>
  </div>
) : null}
```

(Adapt class names to the exact tokens used by sibling cards in this file — copy a neighboring card's classes rather than inventing new ones.)

- [ ] **Step 4: Run to verify pass** — `npx vitest run src/presentation/features/inventory/` → PASS; `npm run typecheck` clean

- [ ] **Step 5: Commit** — `git add -A web_admin/src/presentation/features/inventory && git commit -m "feat(web): admin-only filter-aware inventory totals strip"`

---

### Task 3: Web POS reset-sale button

**Files:**
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx` (header `<h1>` at ~line 81; `lines` already selected from the store)
- Test: extend `web_admin/src/presentation/features/pos/PosPage.test.tsx`

**Interfaces:**
- Consumes: `useCartStore` (`clear()`, `lines`, `laborLines`), existing `Dialog` component (`@/presentation/components/common/Dialog` — read its props and mirror an existing usage such as `AdjustStockDialog` for open/close/action wiring), Lucide `RotateCcw` (import from the same icon package neighboring files use).

- [ ] **Step 1: Write the failing tests** (PosPage.test.tsx, existing harness):

```tsx
// 1. empty cart -> queryByLabelText('Reset sale') is null
// 2. with a line in the store: click 'Reset sale' -> dialog appears -> click 'Clear'
//    -> store lines/laborLines empty, mechanicId null
// 3. with a line: click 'Reset sale' -> click 'Cancel' -> store unchanged
```

Real assertions in the file's established store-seeding + render idiom.

- [ ] **Step 2: Run to verify failure** — `npx vitest run src/presentation/features/pos/PosPage.test.tsx` → new tests FAIL

- [ ] **Step 3: Implement** — in PosPage:

```tsx
const laborLines = useCartStore((s) => s.laborLines);
const clearCart = useCartStore((s) => s.clear);
const [confirmReset, setConfirmReset] = useState(false);
const hasTicket = lines.length > 0 || laborLines.length > 0;
```

Header row becomes a flex row with the existing `<h1>` plus, when `hasTicket`:

```tsx
<button
  type="button"
  aria-label="Reset sale"
  title="Reset sale"
  onClick={() => setConfirmReset(true)}
  className="rounded-md border border-light-hairline p-tk-sm text-light-textSecondary hover:bg-light-card"
>
  <RotateCcw className="h-4 w-4" />
</button>
```

Confirm dialog (exact copy from Global Constraints), wired per the Dialog component's real API; Clear action calls `clearCart()` then closes.

- [ ] **Step 4: Run to verify pass** — `npx vitest run src/presentation/features/pos/PosPage.test.tsx` → PASS; `npm run typecheck` clean; full `npm run test` green

- [ ] **Step 5: Commit** — `git add web_admin/src/presentation/features/pos && git commit -m "feat(web): reset-sale button with confirm on /pos"`

---

### Task 4: Mobile `StockTotals` helper

**Files:**
- Create: `lib/core/utils/stock_totals.dart`
- Test: `test/core/utils/stock_totals_test.dart`

**Interfaces:**
- Produces: `class StockTotals { final double cost; final double retail; double get profit; static StockTotals of(Iterable<ProductEntity> products); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/stock_totals.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductEntity _p({required double cost, required double price, required int qty}) =>
    ProductEntity(
      id: 'x',
      sku: 'X-1',
      name: 'X',
      costCode: 'S',
      cost: cost,
      price: price,
      quantity: qty,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026),
    );

void main() {
  test('empty list is all zeros', () {
    final t = StockTotals.of(const []);
    expect(t.cost, 0);
    expect(t.retail, 0);
    expect(t.profit, 0);
  });

  test('sums cost*qty and price*qty; profit is the difference', () {
    final t = StockTotals.of([
      _p(cost: 100, price: 250, qty: 2),
      _p(cost: 50, price: 80, qty: 10),
    ]);
    expect(t.cost, 700);
    expect(t.retail, 1300);
    expect(t.profit, 600);
  });

  test('zero quantity contributes nothing', () {
    final t = StockTotals.of([_p(cost: 999, price: 1999, qty: 0)]);
    expect(t.cost, 0);
    expect(t.retail, 0);
  });
}
```

(If `ProductEntity`'s constructor requires different named params, mirror its actual signature — check `lib/domain/entities/product_entity.dart`; keep the three scenarios identical.)

- [ ] **Step 2: Run to verify failure** — `flutter test test/core/utils/stock_totals_test.dart` → FAIL (missing file)

- [ ] **Step 3: Implement**

```dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Inventory valuation over whatever product list the screen is rendering.
class StockTotals {
  final double cost;
  final double retail;

  const StockTotals({required this.cost, required this.retail});

  double get profit => retail - cost;

  static StockTotals of(Iterable<ProductEntity> products) {
    var cost = 0.0;
    var retail = 0.0;
    for (final p in products) {
      cost += p.cost * p.quantity;
      retail += p.price * p.quantity;
    }
    return StockTotals(cost: cost, retail: retail);
  }
}
```

- [ ] **Step 4: Run to verify pass** — same command → PASS

- [ ] **Step 5: Commit** — `git add lib/core/utils/stock_totals.dart test/core/utils/stock_totals_test.dart && git commit -m "feat(mobile): StockTotals inventory valuation helper"`

---

### Task 5: Mobile inventory totals strip (admin-only)

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart` (`isAdmin` already computed at :38-39 and :510-511; the product list renders from `filteredProductsProvider` at :509)
- Test: `test/presentation/mobile/screens/inventory/inventory_totals_strip_test.dart` (new; follow the ProviderScope-override widget-test pattern used by existing inventory widget tests under `test/presentation/`)

**Interfaces:**
- Consumes: `StockTotals` (Task 4), `filteredProductsProvider`, `currentUserProvider`, `num.toCurrency()`, `AppCard` (existing shared card widget).

- [ ] **Step 1: Write the failing widget test** — pump the totals strip host (or the inventory screen with overridden providers: `productsProvider`/`filteredProductsProvider` seeded with 2 products of known cost/price/qty; `currentUserProvider` overridden to an admin user, then a staff user):

```dart
// admin: finds 'Stock Cost', '₱700.00', 'Retail Value', '₱1,300.00', 'Expected Profit', '₱600.00'
// staff: finds nothing ('Stock Cost' absent)
```

Real assertions; mirror the existing inventory widget tests' override helpers.

- [ ] **Step 2: Run to verify failure** — `flutter test test/presentation/mobile/screens/inventory/` → FAIL

- [ ] **Step 3: Implement** — extract a small private widget in inventory_screen.dart and render it between the filter controls and the product list, only when `isAdmin`:

```dart
class _InventoryTotalsStrip extends ConsumerWidget {
  const _InventoryTotalsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final products = productsAsync.valueOrNull;
    if (products == null || products.isEmpty) return const SizedBox.shrink();
    final totals = StockTotals.of(products);
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _TotalsFigure(label: 'Stock Cost', value: totals.cost.toCurrency())),
          Expanded(child: _TotalsFigure(label: 'Retail Value', value: totals.retail.toCurrency())),
          Expanded(child: _TotalsFigure(label: 'Expected Profit', value: totals.profit.toCurrency())),
        ],
      ),
    );
  }
}

class _TotalsFigure extends StatelessWidget {
  final String label;
  final String value;
  const _TotalsFigure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
```

(Adapt text styles/paddings to the screen's neighboring widgets and app tokens — match, don't invent. `AppCard` import path: see its existing usages in this screen's imports or siblings.)

- [ ] **Step 4: Run to verify pass** — `flutter test test/presentation/mobile/screens/inventory/` → PASS; `flutter analyze` clean

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/inventory/inventory_screen.dart test/presentation/mobile/screens/inventory/inventory_totals_strip_test.dart && git commit -m "feat(mobile): admin-only inventory totals strip"`

---

### Task 6: Mobile clear-cart dialog copy + full-reset regression test

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart:626` (dialog message)
- Test: extend the cart provider test file (find `test/presentation/providers/cart_provider_test.dart` or equivalent; create following sibling provider-test patterns if missing)

- [ ] **Step 1: Write the failing/regression test** — seed a cart via the notifier: add an item, `addLaborLine(...)`, `setMechanic(...)`, `setAmountReceived(500)`, `setNotes('x')`; call `reset()`; assert items empty, laborLines empty, mechanicId/mechanicName null, amountReceived 0, splitAmount 0, notes null, sourceDraftId null, checkoutId empty. (Mirror the notifier's real method names — read the provider first.) If an equivalent full-reset assertion already exists, extend it to cover laborLines/mechanic/amountReceived rather than duplicating.

- [ ] **Step 2: Run** — `flutter test <that file>` → new assertions should PASS already (reset is state = const CartState()); this is a regression lock, not a bug fix. If anything FAILS, stop and report — that's a real bug.

- [ ] **Step 3: Update the dialog copy** in `_showClearCartDialog`:

```dart
      title: 'Clear Cart?',
      message:
          'This clears the whole sale — items, labor & service, mechanic, and payment amounts.',
```

(Only the `message:` line changes.)

- [ ] **Step 4: Run** — `flutter test` (full) + `flutter analyze` → green/clean

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/pos/pos_screen.dart test/ && git commit -m "fix(mobile): honest clear-cart copy + full-reset regression test"`

---

### Task 7: Final review + verify + finish (controller-run)

- [ ] Whole-branch code review (final reviewer subagent, most capable model)
- [ ] `cd web_admin && npm run typecheck && npm run test` — all green
- [ ] `flutter analyze && flutter test` — all green
- [ ] User smoke: web `/pos` reset (with items + labor + mechanic), web inventory totals as admin + as staff, filter reactivity; mobile totals strip + clear-cart dialog copy
- [ ] superpowers:finishing-a-development-branch (merge/push per user; web deploy decision is the user's)

## Self-Review Notes

- Spec coverage: reset web (T3), mobile copy+regression (T6), totals helper/UI both surfaces (T1/T2/T4/T5), admin gating (T2/T5 tests), filter-aware (T2 case 3; mobile inherits from filteredProductsProvider), confirm dialogs (T3 + existing mobile), no CartBuilder/drafts change (T3 constraint).
- Placeholder check: UI-integration steps intentionally defer exact class/token names and mock-harness idioms to the neighboring code they must match; all logic, copy strings, structures, and assertions are fully specified.
- Type consistency: `stockTotals(list) -> {cost, retail, profit}` (web fn) vs `StockTotals.of(list)` + `.profit` getter (Dart class) — intentionally idiomatic per surface; names match their tasks' tests.
