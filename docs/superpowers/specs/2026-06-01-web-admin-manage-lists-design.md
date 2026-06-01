# Web Admin — Manage Lists (product categories · units · expense categories · void reasons) — Design

**Date:** 2026-06-01
**Status:** Approved (brainstorm complete)
**Context:** Prerequisite for web inventory **Slice 2** (the edit form's category/unit
dropdowns read this feature's active-list hooks). Sequence: **Manage Lists →
inventory Slice 2 (edit/stock/deactivate) → inventory Slice 3 (create)**.

## 1. Overview

Mobile has admin-configurable lists in four Firestore collections —
`product_categories`, `units`, `expense_categories`, `void_reasons` — managed by a
single "Manage Lists" settings screen (§13/§18). The web admin has **no**
category/unit layer. This feature ports it: a `/settings/lists` page that manages
all four lists (list + add + edit + deactivate/reactivate), plus read hooks the
inventory form and future expense/POS web features consume.

The four collections are already seeded and in active use by the mobile app; the
web reads and writes the **same** documents.

## 2. Scope

In:
- A `Category` entity + converter + a `CategoryRepository` parameterized by kind.
- Read hooks (`useCategories`, `useActiveCategories`) and mutation hooks.
- A `/settings/lists` management page covering all four kinds.
- `Permission.manageCategories` (web), route + guard + a SettingsPage link.

Out (non-goals):
- **Seed defaults** — skipped on web (collections already seeded in prod via
  mobile; a web seed would risk duplicates). Web manages existing entries only.
- Consuming the lists in the inventory form — that is **Slice 2**.
- Expense/POS web features that would also use these lists — separate, future.
- Firestore **rules changes** — none; these collections are read by `isValidUser`
  and written by `isAdmin`, and the web admin user is an admin.

## 3. Data model

### 3.1 `Category` entity (`domain/entities/Category.ts`)
Mirrors mobile `CategoryModel`:

```ts
export interface Category {
  id: string;
  name: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
```

No `sortOrder` (the mobile model has none); lists sort by `name`.

### 3.2 `CategoryKind` (`domain/categories/categoryKind.ts`)
A string-union map of the four kinds → collection name + UI label, mirroring the
mobile `category_provider.dart` mapping:

```ts
export const CategoryKind = {
  product: 'product',
  unit: 'unit',
  expense: 'expense',
  voidReason: 'voidReason',
} as const;
export type CategoryKind = (typeof CategoryKind)[keyof typeof CategoryKind];

export function collectionForKind(kind: CategoryKind): string // -> FirestoreCollections.*
export function labelForKind(kind: CategoryKind): string      // 'Product categories' | 'Units' | …
```

`collections.ts` gains: `productCategories: 'product_categories'`,
`expenseCategories: 'expense_categories'`, `units: 'units'`,
`voidReasons: 'void_reasons'`.

### 3.3 `categoryConverter` (`data/converters/categoryConverter.ts`)
FirestoreDataConverter<Category> using the existing `toDate` timestamp helper.

### 3.4 `CategoryRepository` (`domain/repositories/CategoryRepository.ts` + Firestore impl)
Parameterized by kind (the kind selects the collection):

```ts
export interface CategoryRepository {
  list(kind: CategoryKind, opts?: { includeInactive?: boolean }): Promise<Category[]>;
  watchAll(kind: CategoryKind, cb: (c: Category[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  create(kind: CategoryKind, name: string, actorId: string): Promise<Category>;
  update(kind: CategoryKind, id: string, input: { name?: string; isActive?: boolean }, actorId: string): Promise<void>;
}
```

- `list`/`watchAll` order by `name`; filter to active unless `includeInactive`.
- `create` writes `{ name, isActive:true, createdAt, updatedAt (serverTimestamp),
  createdBy, updatedBy }`.
- `update` writes the provided fields + `updatedAt`/`updatedBy`. **Deactivate /
  reactivate are `update(kind, id, { isActive })`** — no separate methods.
- Registered in the DI container (`categoryRepo` + `useCategoryRepo()`).

## 4. Hooks (`presentation/hooks/`)

- `useCategories(kind, { includeInactive })` — live `watchAll` (via the existing
  `useFirestoreSubscription`); drives the management list.
- `useActiveCategories(kind)` — active-only, name-sorted. **This is the dropdown
  source Slice 2 consumes** for category/unit selects. (May derive from
  `useCategories(kind)` filtered to active.)
- `useCreateCategory(kind)`, `useUpdateCategory(kind)` — React Query mutations
  that invalidate / are observed by the kind's live query.

## 5. Page `/settings/lists` (`features/settings/ManageListsPage.tsx`)

- A segmented control selects the active `CategoryKind`: **Product categories ·
  Units · Expense categories · Void reasons**.
- Below it, that kind's list via `useCategories(kind, { includeInactive: true })`:
  active rows first, inactive rows greyed; each row has **Edit** and
  **Deactivate** (active) / **Reactivate** (inactive).
- An **Add** button opens the shared `Dialog` with a name field (and, on edit, an
  active toggle). Validation: name required, trimmed, non-empty (zod or inline).
- States: `LoadingView` / `ErrorView` / `EmptyState` per the established pattern.
- Mirrors mobile `category_settings_screen.dart` + the web `CostCodeSettingsPage`
  / `SuppliersListPage` conventions.

## 6. Routing / permission / nav

- Add **`Permission.manageCategories`** to the web `Permission` map's **admin** set
  (mirrors mobile; admin-only).
- `RoutePaths.manageLists = '/settings/lists'`.
- `routeGuards.ts`: exact `protectedRoutes` entry `[manageLists,
  manageCategories]`.
- `routes.tsx`: register `{ path: manageLists, element: <ManageListsPage /> }`.
- `SettingsPage.tsx`: add a "Manage Lists" link (next to Cost Codes), gated by
  `manageCategories`.

## 7. Testing

- `categoryKind.test.ts` (vitest, node): `collectionForKind` maps each kind to the
  correct collection string; `labelForKind` returns the expected labels.
- Repository, hooks, and page verified via `npx tsc --noEmit -p tsconfig.json` +
  `npm run build` + manual smoke (no jsdom component tests, consistent with prior
  web slices).

## 8. Files

**Create:**
- `domain/entities/Category.ts`
- `domain/categories/categoryKind.ts` + `categoryKind.test.ts`
- `data/converters/categoryConverter.ts`
- `domain/repositories/CategoryRepository.ts`
- `data/repositories/FirestoreCategoryRepository.ts`
- `presentation/hooks/useCategories.ts`
- `presentation/hooks/useCategoryMutations.ts`
- `presentation/features/settings/ManageListsPage.tsx`

**Modify:**
- `infrastructure/firebase/collections.ts` (+4 collection names)
- `domain/entities/index.ts` (export `Category`)
- `domain/permissions/Permission.ts` (+`manageCategories` in admin set)
- `infrastructure/di/container.tsx` (register `categoryRepo` + `useCategoryRepo`)
- `presentation/router/routePaths.ts` (+`manageLists`)
- `presentation/router/routeGuards.ts` (+exact guard entry)
- `presentation/router/routes.tsx` (+route + import)
- `presentation/features/settings/SettingsPage.tsx` (+link)

## 9. Acceptance criteria

1. An admin opens Settings → "Manage Lists" → can switch among the four kinds; each
   shows its active + inactive entries; Add creates a new entry; Edit renames /
   toggles active; Deactivate greys an entry and Reactivate restores it — all
   persisted to the correct collection and reflected live.
2. `useActiveCategories('product')` / `('unit')` return the active, name-sorted
   entries (ready for Slice 2's dropdowns).
3. A non-admin cannot reach `/settings/lists` (guard + admin-only shell).
4. Gates green: `categoryKind` vitest passes; `tsc --noEmit -p tsconfig.json` and
   `npm run build` succeed; full vitest suite stays green.

## 10. Resolved decisions

- Scope: **all four kinds** (product categories, units, expense categories, void
  reasons), full CRUD on web.
- **Read + manage** on web (not read-only); mobile keeps its own Manage Lists.
- **No seed defaults** on web; **no rules change**.
- Deactivate/reactivate via `update({ isActive })` (no dedicated methods).
