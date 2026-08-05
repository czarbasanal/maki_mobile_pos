# Receiving "units" Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Six receiving displays label a quantity sum "items"; make them say "units".

**Architecture:** Six string literals. No helper, no logic, no data dependency, no schema change. The work is split by surface because the two have entirely separate test harnesses, and neither surface has any test for these screens today — both tasks build their harness from scratch.

**Tech Stack:** Flutter (`flutter test`, `flutter analyze`); React + Vite + TypeScript + Vitest + Testing Library (`npm run typecheck`, `npm run test`, `npm run build` from `web_admin/`).

**Spec:** `docs/superpowers/specs/2026-08-05-receiving-unit-label-design.md`

## Global Constraints

- The word is **`units`**, lowercase, except where it begins a label — the two web column headers become `Units` and the detail label becomes `Total units`, matching the sentence case already used around them.
- **Do not show the product's real unit.** This deliberately differs from the purchase-order screens, which show the order's shared unit. Half these sites are column headers or section labels that cannot carry a per-row unit, and a receiving can span suppliers and products. The spec's "Why 'units' and not the real unit" section is binding.
- **Do not reuse, move or reference `sharedUnitOf` / `poQuantityLabel`** (`lib/domain/entities/purchase_order_entity.dart`). Because "units" was chosen, receiving is not a second consumer, so the relocation a prior review anticipated is explicitly **not** triggered.
- **Do not touch `totalQuantity`** on either surface. The sum is correct; only its label is wrong.
- **Do not touch these two already-correct sites:** `lib/presentation/mobile/screens/receiving/receiving_drafts_screen.dart:105` (`'… item(s) · … units · …'`) and `lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart:556` (`'… total units'`).
- Every new test pairs a positive with a negative — asserts `units` appears **and** that `items` does not. A positive-only test passes while a sibling site still says "items", which is the exact failure this change is guarding against.
- Branch `fix/receiving-unit-label` is already checked out and holds the spec commit. Stay on it. Do not push, do not deploy.

## File Structure

| Path | Responsibility |
|---|---|
| `lib/presentation/mobile/screens/receiving/receiving_screen.dart:204` | *(modify)* inline label |
| `lib/presentation/mobile/screens/receiving/receiving_history_screen.dart:198` | *(modify)* inline label |
| `test/presentation/mobile/screens/receiving/receiving_screen_test.dart` | *(create)* first test for this screen |
| `test/presentation/mobile/screens/receiving/receiving_history_screen_test.dart` | *(create)* first test for this screen |
| `web_admin/src/presentation/features/receiving/ReceivingDashboardPage.tsx:68,102` | *(modify)* inline label in the Drafts table; column header in the completed table |
| `web_admin/src/presentation/features/receiving/ReceivingHistoryPage.tsx:63` | *(modify)* column header |
| `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx:111` | *(modify)* summary label |
| `web_admin/src/presentation/features/receiving/*.test.tsx` | *(create)* first tests in this folder |

---

### Task 1: The two mobile screens

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/receiving_screen.dart:204`
- Modify: `lib/presentation/mobile/screens/receiving/receiving_history_screen.dart:198`
- Create: `test/presentation/mobile/screens/receiving/receiving_screen_test.dart`
- Create: `test/presentation/mobile/screens/receiving/receiving_history_screen_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: nothing other tasks depend on. Task 2 is independent.

Both screens are plain `ConsumerWidget`s watching exactly two providers each, so the harness is small:

| Screen | Providers to override |
|---|---|
| `ReceivingScreen` | `currentWeekReceivingsProvider`, `currentUserProvider` |
| `ReceivingHistoryScreen` | `recentReceivingsProvider`, `currentUserProvider` |

Read each screen's imports to find where those providers are declared before writing the harness.

- [ ] **Step 1: Write the failing tests**

Create `test/presentation/mobile/screens/receiving/receiving_screen_test.dart`. The fixture builds a receiving of 3 lines totalling 12 — so the "12" cannot be mistaken for a line count:

All three providers are `StreamProvider`s, so each override returns a stream:
`currentWeekReceivingsProvider` and `recentReceivingsProvider` are
`StreamProvider<List<ReceivingEntity>>`, and `currentUserProvider` is
`StreamProvider<UserEntity?>`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_screen.dart';

ReceivingItemEntity _item(String id, int qty) => ReceivingItemEntity(
      id: id,
      sku: 'SKU-$id',
      name: 'Item $id',
      quantity: qty,
      unit: 'pcs',
      unitCost: 10,
      costCode: 'AB',
    );

// 3 lines, 12 pieces — so "12" can never be mistaken for a line count.
ReceivingEntity _receiving() => ReceivingEntity(
      id: 'r1',
      referenceNumber: 'RCV-20260805-001',
      items: [_item('a', 5), _item('b', 4), _item('c', 3)],
      totalCost: 120,
      totalQuantity: 12,
      status: ReceivingStatus.completed,
      createdAt: DateTime(2026, 8, 5),
      createdBy: 'u1',
      createdByName: 'Admin',
    );

final _admin = UserEntity(
  id: 'u1',
  email: 'a@test',
  displayName: 'Alice Admin',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  testWidgets('labels the quantity sum "units", not "items"', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentWeekReceivingsProvider
            .overrideWith((ref) => Stream.value([_receiving()])),
        currentUserProvider.overrideWith((ref) => Stream.value(_admin)),
      ],
      child: const MaterialApp(home: ReceivingScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('12 units'), findsOneWidget);
    expect(find.textContaining('12 items'), findsNothing);
  });
}
```

Create the sibling `receiving_history_screen_test.dart` with the same fixtures
and the same two assertions, swapping `currentWeekReceivingsProvider` for
`recentReceivingsProvider` and `ReceivingScreen` for `ReceivingHistoryScreen`
(imported from `.../receiving/receiving_history_screen.dart`).

If a screen turns out to read a provider beyond the two listed, add its
override rather than reshaping the test — the harness is deliberately minimal.

The negative assertion is the point: a positive-only test would pass while the other screen still said "items".

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/mobile/screens/receiving/`
Expected: FAIL — both screens render `12 items`, so `find.textContaining('12 units')` finds nothing.

- [ ] **Step 3: Write minimal implementation**

`lib/presentation/mobile/screens/receiving/receiving_screen.dart:204` — currently:

```dart
                '${receiving.totalQuantity} items',
```

becomes:

```dart
                '${receiving.totalQuantity} units',
```

`lib/presentation/mobile/screens/receiving/receiving_history_screen.dart:198` has the identical line; make the identical change.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS across the full suite, analyzer clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/ test/presentation/mobile/screens/receiving/
git commit -m "fix(receiving): label the quantity sum units, not items (mobile)"
```

---

### Task 2: The four web sites

**Files:**
- Modify: `web_admin/src/presentation/features/receiving/ReceivingDashboardPage.tsx:68` and `:102`
- Modify: `web_admin/src/presentation/features/receiving/ReceivingHistoryPage.tsx:63`
- Modify: `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx:111`
- Create: `web_admin/src/presentation/features/receiving/ReceivingDashboardPage.test.tsx`
- Create: `web_admin/src/presentation/features/receiving/ReceivingHistoryPage.test.tsx`
- Create: `web_admin/src/presentation/features/receiving/ReceivingDetailPage.test.tsx`

**Interfaces:**
- Consumes: nothing from Task 1. These tasks are independent and may be done in either order.

**Four sites, three of which are a header or label rather than inline text:**

| Site | Current | After |
|---|---|---|
| `ReceivingDashboardPage.tsx:68` | `{r.totalQuantity} items` — inline, in the **headerless** Drafts table | `{r.totalQuantity} units` |
| `ReceivingDashboardPage.tsx:102` | `<th …>Items</th>`, over the bare value at `:119` | `<th …>Units</th>` |
| `ReceivingHistoryPage.tsx:63` | `<th …>Items</th>`, over the bare value at `:84` | `<th …>Units</th>` |
| `ReceivingDetailPage.tsx:111` | `<span …>Total items</span>`, over the bare value at `:112` | `<span …>Total units</span>` |

Leave the bare value cells alone — only the header or label changes at those three.

**The harness.** These three pages are hook-driven and routed:

| Page | Hook | Router need |
|---|---|---|
| `ReceivingDashboardPage` | `useReceivingSummary(now)` | `useNavigate` |
| `ReceivingHistoryPage` | `useReceivings(range)` | `useNavigate` |
| `ReceivingDetailPage` | `useReceiving(id)` | `useParams` — needs a route param |

Follow the established pattern in `web_admin/src/presentation/features/inventory/InventoryListPage.test.tsx`: a `QueryClient` built with `{ defaultOptions: { queries: { retry: false } } }`, wrapped in `QueryClientProvider`, inside a `MemoryRouter` with `initialEntries`. Supply data by mocking the page's hook module with `vi.mock` — these are label tests and do not need repository plumbing.

- [ ] **Step 1: Write the failing tests**

One file per page. The dashboard, which carries two of the four sites:

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { ReceivingDashboardPage } from './ReceivingDashboardPage';

`useReceivingSummary` returns `{ isLoading, completedCount, receivedTotal, draftCount, drafts, recent }`. The page reads `summary.drafts` for the headerless Drafts table (site `:68`) and `summary.recent` for the completed table (header at `:102`). **Both lists must be non-empty**: the completed table is gated on `summary.recent.length === 0`, which renders an `EmptyState` instead of the table — so an empty `recent` means the `Items` header never renders and the header test would pass vacuously.

```tsx
const row = (id: string) => ({
  id,
  referenceNumber: `RCV-2026080${id}`,
  supplierName: 'Acme',
  totalQuantity: 12, // 3 lines, 12 pieces — never a line count
  totalCost: 120,
  status: 'completed',
  createdAt: new Date('2026-08-05'),
  completedAt: new Date('2026-08-05'),
});

vi.mock('@/presentation/hooks/useReceivingSummary', () => ({
  useReceivingSummary: () => ({
    isLoading: false,
    completedCount: 1,
    receivedTotal: 120,
    draftCount: 1,
    drafts: [row('1')],
    recent: [row('2')],
  }),
}));

function renderPage() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter initialEntries={['/receiving']}>
        <ReceivingDashboardPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('ReceivingDashboardPage quantity label', () => {
  it('labels the drafts row quantity "units", not "items"', () => {
    renderPage();
    expect(screen.getByText('12 units')).toBeInTheDocument();
    expect(screen.queryByText('12 items')).toBeNull();
  });

  it('heads the completed-table quantity column "Units", not "Items"', () => {
    renderPage();
    expect(screen.getByRole('columnheader', { name: 'Units' })).toBeInTheDocument();
    expect(screen.queryByRole('columnheader', { name: 'Items' })).toBeNull();
  });
});
```

`ReceivingHistoryPage.test.tsx` asserts the column header the same way, mocking `useReceivings`. `ReceivingDetailPage.test.tsx` asserts `Total units` present and `Total items` absent, mocking `useReceiving` and giving `MemoryRouter` a route that supplies the `:id` param the page reads via `useParams`.

Use `getByRole('columnheader', …)` rather than `getByText` for the two headers — it asserts the string is actually a table header, not merely present somewhere on the page.

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `web_admin/`): `npm run test -- Receiving`
Expected: FAIL — the pages render `items` / `Items`, so the positive assertions find nothing.

- [ ] **Step 3: Write minimal implementation**

`ReceivingDashboardPage.tsx:68`:

```tsx
                        <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.totalQuantity} items</td>
```
becomes
```tsx
                        <td className="px-tk-md py-tk-sm text-right tabular-nums">{r.totalQuantity} units</td>
```

`ReceivingDashboardPage.tsx:102` and `ReceivingHistoryPage.tsx:63` — both currently:

```tsx
                      <th className="px-tk-md py-tk-sm text-right font-medium">Items</th>
```
become
```tsx
                      <th className="px-tk-md py-tk-sm text-right font-medium">Units</th>
```

`ReceivingDetailPage.tsx:111`:

```tsx
          <span className="text-light-text-secondary">Total items</span>
```
becomes
```tsx
          <span className="text-light-text-secondary">Total units</span>
```

Change no other attribute on any of these lines — the classes stay exactly as they are.

- [ ] **Step 4: Run the tests to verify they pass**

Run (from `web_admin/`): `npm run typecheck && npm run test && npm run build`
Expected: PASS on all three.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/receiving/
git commit -m "fix(receiving): label the quantity sum units, not items (web)"
```

---

## Final verification

- [ ] `flutter test` — full suite green; `flutter analyze` — no issues
- [ ] From `web_admin/`: `npm run typecheck`, `npm run test`, `npm run build` — all green
- [ ] Sweep for stragglers: `rg -n "totalQuantity} items|>Items<|Total items" lib/ web_admin/src/` returns nothing
- [ ] Confirm the two already-correct sites are untouched: `receiving_drafts_screen.dart:105` still reads `item(s) · … units`, `bulk_receiving_screen.dart:556` still reads `total units`

## Non-goals

Confirmed in the spec; do not build these:

- Showing the product's real unit on any receiving surface
- Reusing, moving or referencing `sharedUnitOf` / `poQuantityLabel`
- Adding a line count anywhere it isn't already shown
- Any change to `totalQuantity` on either surface
