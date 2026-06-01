# Web Admin — Manage Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A web `/settings/lists` page that manages the four admin-configurable Firestore lists (product categories, units, expense categories, void reasons), plus read hooks the inventory form (Slice 2) will consume.

**Architecture:** A generic `Category` entity + converter + `CategoryRepository` parameterized by `CategoryKind` (kind → collection). Live `watchAll` feeds the management page, so mutations reflect automatically (no manual invalidation). Mirrors `SuppliersListPage` / `CostCodeSettingsPage` / `useSupplierMutations`.

**Tech Stack:** React, TypeScript, React Router v6, TanStack Query v5, Firebase Firestore, Tailwind, Vitest. Spec: `docs/superpowers/specs/2026-06-01-web-admin-manage-lists-design.md`. Run all commands from `web_admin/`.

**Toolchain:** typecheck `npx tsc --noEmit -p tsconfig.json`; logic tests `--environment=node`; unit-tested modules use **relative imports**.

---

## Context verified

- 4 collections to add to `collections.ts`: `product_categories`, `expense_categories`, `units`, `void_reasons`.
- Mobile `CategoryModel` = id, name, isActive, createdAt, updatedAt, createdBy, updatedBy (**no sortOrder**).
- Patterns: `supplierConverter` (FirestoreDataConverter using `requireDate`/`toDate`); `useSupplierMutations` (`useMutation` + `useAuthStore((s)=>s.user)`, no invalidation — live sub auto-updates); `Dialog` props `{open,onClose,title,description?,children,dismissable?}`; `Spinner` takes `className`.
- React Query **v5** → mutations expose `isPending`.
- `domain/entities/index.ts` uses `export * from './X';`.
- DI: `Container` interface + `buildDefaultContainer()` + `useXRepo()` in `infrastructure/di/container.tsx`.
- `Permission` admin set ends `…editCostCodeMapping, viewUserLogs ]);` (line ~142-144).
- `SettingsPage` rows: `<Row to icon tone title subtitle />`; icons imported from heroicons.
- Categories are tiny collections → repo filters/sorts **client-side** (no composite index needed).

## File Structure

**Create:** `domain/entities/Category.ts`, `domain/categories/categoryKind.ts` (+test), `data/converters/categoryConverter.ts`, `domain/repositories/CategoryRepository.ts`, `data/repositories/FirestoreCategoryRepository.ts`, `presentation/hooks/useCategories.ts`, `presentation/hooks/useCategoryMutations.ts`, `presentation/features/settings/ManageListsPage.tsx`.

**Modify:** `infrastructure/firebase/collections.ts`, `domain/entities/index.ts`, `domain/permissions/Permission.ts`, `infrastructure/di/container.tsx`, `presentation/router/{routePaths,routeGuards,routes}.tsx`, `presentation/features/settings/SettingsPage.tsx`.

---

## Task 1: Collections, `Category` entity, `CategoryKind` helper

**Files:**
- Modify: `web_admin/src/infrastructure/firebase/collections.ts`
- Create: `web_admin/src/domain/entities/Category.ts`, modify `domain/entities/index.ts`
- Create: `web_admin/src/domain/categories/categoryKind.ts`
- Test: `web_admin/src/domain/categories/categoryKind.test.ts`

- [ ] **Step 1: Add the 4 collections**

In `collections.ts`, inside `FirestoreCollections`, after `products: 'products',` add:

```ts
  productCategories: 'product_categories',
  expenseCategories: 'expense_categories',
  units: 'units',
  voidReasons: 'void_reasons',
```

- [ ] **Step 2: Add the Category entity**

Create `web_admin/src/domain/entities/Category.ts`:

```ts
// Mirror of lib/data/models/category_model.dart (CategoryEntity). Used for the
// admin-managed product_categories / units / expense_categories / void_reasons.
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

Append to `web_admin/src/domain/entities/index.ts`:

```ts
export * from './Category';
```

- [ ] **Step 3: Write the failing test for the kind helper**

Create `web_admin/src/domain/categories/categoryKind.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { CategoryKind, collectionForKind, labelForKind } from './categoryKind';

describe('collectionForKind', () => {
  it('maps each kind to its Firestore collection', () => {
    expect(collectionForKind(CategoryKind.product)).toBe('product_categories');
    expect(collectionForKind(CategoryKind.unit)).toBe('units');
    expect(collectionForKind(CategoryKind.expense)).toBe('expense_categories');
    expect(collectionForKind(CategoryKind.voidReason)).toBe('void_reasons');
  });
});

describe('labelForKind', () => {
  it('returns the UI labels', () => {
    expect(labelForKind(CategoryKind.product)).toBe('Product categories');
    expect(labelForKind(CategoryKind.unit)).toBe('Units');
    expect(labelForKind(CategoryKind.expense)).toBe('Expense categories');
    expect(labelForKind(CategoryKind.voidReason)).toBe('Void reasons');
  });
});
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd web_admin && npx vitest run --environment=node src/domain/categories/categoryKind.test.ts`
Expected: FAIL — cannot resolve `./categoryKind`.

- [ ] **Step 5: Write the kind helper**

Create `web_admin/src/domain/categories/categoryKind.ts` (RELATIVE import — it's unit-tested):

```ts
import { FirestoreCollections } from '../../infrastructure/firebase/collections';

export const CategoryKind = {
  product: 'product',
  unit: 'unit',
  expense: 'expense',
  voidReason: 'voidReason',
} as const;
export type CategoryKind = (typeof CategoryKind)[keyof typeof CategoryKind];

/** The Firestore collection backing a given list kind. */
export function collectionForKind(kind: CategoryKind): string {
  switch (kind) {
    case CategoryKind.product:
      return FirestoreCollections.productCategories;
    case CategoryKind.unit:
      return FirestoreCollections.units;
    case CategoryKind.expense:
      return FirestoreCollections.expenseCategories;
    case CategoryKind.voidReason:
      return FirestoreCollections.voidReasons;
  }
}

/** The human label for a list kind. */
export function labelForKind(kind: CategoryKind): string {
  switch (kind) {
    case CategoryKind.product:
      return 'Product categories';
    case CategoryKind.unit:
      return 'Units';
    case CategoryKind.expense:
      return 'Expense categories';
    case CategoryKind.voidReason:
      return 'Void reasons';
  }
}
```

- [ ] **Step 6: Run test + typecheck**

Run: `cd web_admin && npx vitest run --environment=node src/domain/categories/categoryKind.test.ts`
Expected: PASS (2 describe blocks).
Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/infrastructure/firebase/collections.ts web_admin/src/domain/entities/Category.ts web_admin/src/domain/entities/index.ts web_admin/src/domain/categories/
git commit -m "feat(web-admin): Category entity + CategoryKind helper + collections"
```

---

## Task 2: categoryConverter

**Files:**
- Create: `web_admin/src/data/converters/categoryConverter.ts`

- [ ] **Step 1: Write the converter**

Create `web_admin/src/data/converters/categoryConverter.ts`:

```ts
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Category } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on the
// write path.
export const categoryConverter: FirestoreDataConverter<Category> = {
  toFirestore(c) {
    return {
      name: c.name,
      isActive: c.isActive,
      createdBy: c.createdBy,
      updatedBy: c.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Category {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      isActive: d.isActive ?? true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
    };
  },
};
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/data/converters/categoryConverter.ts
git commit -m "feat(web-admin): categoryConverter"
```

---

## Task 3: CategoryRepository + Firestore impl + DI

**Files:**
- Create: `web_admin/src/domain/repositories/CategoryRepository.ts`
- Create: `web_admin/src/data/repositories/FirestoreCategoryRepository.ts`
- Modify: `web_admin/src/infrastructure/di/container.tsx`

- [ ] **Step 1: Repository interface**

Create `web_admin/src/domain/repositories/CategoryRepository.ts`:

```ts
import type { Category } from '../entities';
import type { CategoryKind } from '../categories/categoryKind';
import type { Unsubscribe } from './AuthRepository';

export interface CategoryUpdateInput {
  name?: string;
  isActive?: boolean;
}

export interface CategoryRepository {
  list(kind: CategoryKind, opts?: { includeInactive?: boolean }): Promise<Category[]>;
  watchAll(
    kind: CategoryKind,
    cb: (categories: Category[]) => void,
    opts?: { includeInactive?: boolean },
  ): Unsubscribe;
  create(kind: CategoryKind, name: string, actorId: string): Promise<Category>;
  update(kind: CategoryKind, id: string, input: CategoryUpdateInput, actorId: string): Promise<void>;
}
```

- [ ] **Step 2: Firestore implementation**

Create `web_admin/src/data/repositories/FirestoreCategoryRepository.ts`:

```ts
import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type {
  CategoryRepository,
  CategoryUpdateInput,
} from '@/domain/repositories/CategoryRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Category } from '@/domain/entities';
import type { CategoryKind } from '@/domain/categories/categoryKind';
import { collectionForKind } from '@/domain/categories/categoryKind';
import { categoryConverter } from '@/data/converters/categoryConverter';

// Categories are small collections, so we read the whole list and filter/sort
// client-side — no composite index required.
export class FirestoreCategoryRepository implements CategoryRepository {
  constructor(private readonly db: Firestore) {}

  private col(kind: CategoryKind) {
    return collection(this.db, collectionForKind(kind)).withConverter(categoryConverter);
  }

  private shape(cats: Category[], includeInactive: boolean): Category[] {
    const out = includeInactive ? cats : cats.filter((c) => c.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  async list(kind: CategoryKind, opts?: { includeInactive?: boolean }): Promise<Category[]> {
    const snap = await getDocs(this.col(kind));
    return this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false);
  }

  watchAll(
    kind: CategoryKind,
    cb: (categories: Category[]) => void,
    opts?: { includeInactive?: boolean },
  ): Unsubscribe {
    return onSnapshot(this.col(kind), (snap) => {
      cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
    });
  }

  async create(kind: CategoryKind, name: string, actorId: string): Promise<Category> {
    const ref = await addDoc(collection(this.db, collectionForKind(kind)), {
      name,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(categoryConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created category');
    return created;
  }

  async update(
    kind: CategoryKind,
    id: string,
    input: CategoryUpdateInput,
    actorId: string,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    await updateDoc(doc(this.db, collectionForKind(kind), id), data);
  }
}
```

- [ ] **Step 3: Register in the DI container**

In `web_admin/src/infrastructure/di/container.tsx`:

(a) After the `FirestoreSupplierRepository` import, add:

```tsx
import { FirestoreCategoryRepository } from '@/data/repositories/FirestoreCategoryRepository';
```

(b) After the `SupplierRepository` type import, add:

```tsx
import type { CategoryRepository } from '@/domain/repositories/CategoryRepository';
```

(c) In the `Container` interface, after `supplierRepo: SupplierRepository;` add:

```tsx
  categoryRepo: CategoryRepository;
```

(d) In `buildDefaultContainer()`, after `supplierRepo: new FirestoreSupplierRepository(db),` add:

```tsx
    categoryRepo: new FirestoreCategoryRepository(db),
```

(e) After the `useSupplierRepo` function, add:

```tsx
export function useCategoryRepo(): CategoryRepository {
  return useContainer().categoryRepo;
}
```

- [ ] **Step 4: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/CategoryRepository.ts web_admin/src/data/repositories/FirestoreCategoryRepository.ts web_admin/src/infrastructure/di/container.tsx
git commit -m "feat(web-admin): CategoryRepository + Firestore impl + DI"
```

---

## Task 4: Hooks

**Files:**
- Create: `web_admin/src/presentation/hooks/useCategories.ts`
- Create: `web_admin/src/presentation/hooks/useCategoryMutations.ts`

- [ ] **Step 1: Read hooks**

Create `web_admin/src/presentation/hooks/useCategories.ts`:

```ts
import { useCategoryRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Category } from '@/domain/entities';
import type { CategoryKind } from '@/domain/categories/categoryKind';

/** Live list for a kind. Pass includeInactive for the management screen. */
export function useCategories(kind: CategoryKind, opts?: { includeInactive?: boolean }) {
  const repo = useCategoryRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<Category[]>(
    (onData) => repo.watchAll(kind, onData, { includeInactive }),
    [repo, kind, includeInactive],
  );
}

/** Active, name-sorted entries — the dropdown source for the inventory form. */
export function useActiveCategories(kind: CategoryKind) {
  return useCategories(kind, { includeInactive: false });
}
```

- [ ] **Step 2: Mutation hooks**

Create `web_admin/src/presentation/hooks/useCategoryMutations.ts`:

```ts
import { useMutation } from '@tanstack/react-query';
import { useCategoryRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Category } from '@/domain/entities';
import type { CategoryKind } from '@/domain/categories/categoryKind';

export function useCreateCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Category, Error, { name: string }>({
    mutationFn: async ({ name }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(kind, name, actor.id);
    },
  });
}

export function useUpdateCategory(kind: CategoryKind) {
  const repo = useCategoryRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; name?: string; isActive?: boolean }>({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(kind, id, patch, actor.id);
    },
  });
}
```

(No cache invalidation needed — the `useCategories` live `watchAll` reflects writes automatically, same as `useSupplierMutations`.)

- [ ] **Step 3: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/hooks/useCategories.ts web_admin/src/presentation/hooks/useCategoryMutations.ts
git commit -m "feat(web-admin): category read + mutation hooks"
```

---

## Task 5: ManageListsPage

**Files:**
- Create: `web_admin/src/presentation/features/settings/ManageListsPage.tsx`

- [ ] **Step 1: Write the page**

Create `web_admin/src/presentation/features/settings/ManageListsPage.tsx`:

```tsx
import { useEffect, useState } from 'react';
import { EyeIcon, EyeSlashIcon, PencilIcon, PlusIcon } from '@heroicons/react/24/outline';
import { CategoryKind, labelForKind } from '@/domain/categories/categoryKind';
import { useCategories } from '@/presentation/hooks/useCategories';
import { useCreateCategory, useUpdateCategory } from '@/presentation/hooks/useCategoryMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import type { Category } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

const KINDS: CategoryKind[] = [
  CategoryKind.product,
  CategoryKind.unit,
  CategoryKind.expense,
  CategoryKind.voidReason,
];

export function ManageListsPage() {
  useEffect(() => {
    document.title = 'Manage Lists · MAKI POS Admin';
  }, []);

  const [kind, setKind] = useState<CategoryKind>(CategoryKind.product);
  const { data: categories, isLoading, error } = useCategories(kind, { includeInactive: true });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [name, setName] = useState('');
  const [active, setActive] = useState(true);

  const create = useCreateCategory(kind);
  const update = useUpdateCategory(kind);
  const busy = create.isPending || update.isPending;

  const openAdd = () => {
    setEditing(null);
    setName('');
    setActive(true);
    setDialogOpen(true);
  };
  const openEdit = (c: Category) => {
    setEditing(c);
    setName(c.name);
    setActive(c.isActive);
    setDialogOpen(true);
  };

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    if (editing) {
      await update.mutateAsync({ id: editing.id, name: trimmed, isActive: active });
    } else {
      await create.mutateAsync({ name: trimmed });
    }
    setDialogOpen(false);
  };

  const toggleActive = async (c: Category) => {
    await update.mutateAsync({ id: c.id, isActive: !c.isActive });
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Manage Lists</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Admin-managed dropdown values used across the app.
          </p>
        </div>
        <button
          type="button"
          onClick={openAdd}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add
        </button>
      </header>

      <div className="inline-flex flex-wrap rounded-md border border-light-hairline p-[2px]">
        {KINDS.map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => setKind(k)}
            className={cn(
              'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
              kind === k
                ? 'bg-light-subtle font-semibold text-light-text'
                : 'text-light-text-secondary hover:text-light-text',
            )}
          >
            {labelForKind(k)}
          </button>
        ))}
      </div>

      {error ? (
        <ErrorView title="Could not load list" message={error.message} />
      ) : isLoading || !categories ? (
        <LoadingView label="Loading…" />
      ) : categories.length === 0 ? (
        <EmptyState title="No entries yet" description="Add the first entry for this list." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {categories.map((c) => (
              <li key={c.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                <span
                  className={cn(
                    'text-bodySmall',
                    c.isActive ? 'text-light-text' : 'text-light-text-hint line-through',
                  )}
                >
                  {c.name}
                  {c.isActive ? '' : ' (inactive)'}
                </span>
                <span className="flex items-center gap-tk-xs">
                  <button
                    type="button"
                    onClick={() => openEdit(c)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    <PencilIcon className="h-3.5 w-3.5" /> Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => toggleActive(c)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    {c.isActive ? (
                      <EyeSlashIcon className="h-3.5 w-3.5" />
                    ) : (
                      <EyeIcon className="h-3.5 w-3.5" />
                    )}
                    {c.isActive ? 'Deactivate' : 'Reactivate'}
                  </button>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Dialog
        open={dialogOpen}
        onClose={() => {
          if (!busy) setDialogOpen(false);
        }}
        title={editing ? 'Edit entry' : 'Add entry'}
        dismissable={!busy}
      >
        <div className="space-y-tk-md">
          <div>
            <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
          {editing ? (
            <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
              <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
              Active
            </label>
          ) : null}
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button
              type="button"
              onClick={() => setDialogOpen(false)}
              disabled={busy}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSave}
              disabled={busy || !name.trim()}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              {busy ? <Spinner className="h-3.5 w-3.5" /> : null} Save
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
```

- [ ] **Step 2: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/settings/ManageListsPage.tsx
git commit -m "feat(web-admin): Manage Lists page (4 kinds, add/edit/deactivate)"
```

---

## Task 6: Permission + route + guard + nav

**Files:**
- Modify: `Permission.ts`, `routePaths.ts`, `routeGuards.ts`, `routes.tsx`, `SettingsPage.tsx`

- [ ] **Step 1: Add the permission**

In `web_admin/src/domain/permissions/Permission.ts`, add to the `Permission` const object after `editCostCodeMapping: 'editCostCodeMapping',`:

```ts
  manageCategories: 'manageCategories',
```

And add to the **admin** set (the one ending `…viewUserLogs ]);`), after `Permission.editCostCodeMapping,`:

```ts
  Permission.manageCategories,
```

- [ ] **Step 2: Add the route path**

In `web_admin/src/presentation/router/routePaths.ts`, after `costCodeSettings: '/settings/cost-codes',` add:

```ts
  manageLists: '/settings/lists',
```

- [ ] **Step 3: Guard it**

In `web_admin/src/presentation/router/routeGuards.ts`, add to the `protectedRoutes` Map after the `costCodeSettings` entry:

```ts
  [RoutePaths.manageLists, Permission.manageCategories],
```

- [ ] **Step 4: Register the route**

In `web_admin/src/presentation/router/routes.tsx`, add the import after the inventory page imports:

```tsx
import { ManageListsPage } from '@/presentation/features/settings/ManageListsPage';
```

And add the route after the `RoutePaths.costCodeSettings` route line:

```tsx
        { path: RoutePaths.manageLists, element: <ManageListsPage /> },
```

- [ ] **Step 5: Add the SettingsPage link**

In `web_admin/src/presentation/features/settings/SettingsPage.tsx`, add `QueueListIcon` to the heroicons import, then add a `Row` after the cost-code `Row`:

```tsx
        <Row
          to={RoutePaths.manageLists}
          icon={QueueListIcon}
          tone="blue"
          title="Manage lists"
          subtitle="Categories, units, and other dropdown values"
        />
```

- [ ] **Step 6: Typecheck + build**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: tsc clean; build succeeds.

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/domain/permissions/Permission.ts web_admin/src/presentation/router/ web_admin/src/presentation/features/settings/SettingsPage.tsx
git commit -m "feat(web-admin): /settings/lists route + manageCategories guard + nav"
```

---

## Task 7: Final gates

- [ ] **Step 1: Typecheck**

Run: `cd web_admin && npx tsc --noEmit -p tsconfig.json`
Expected: clean.

- [ ] **Step 2: Unit tests**

Run: `cd web_admin && npx vitest run --environment=node`
Expected: all suites pass (existing 70 + `categoryKind`).

- [ ] **Step 3: Build**

Run: `cd web_admin && npm run build`
Expected: succeeds.

- [ ] **Step 4: Manual smoke (optional)**

As an admin: Settings → Manage Lists → switch among the 4 kinds; Add creates an
entry; Edit renames / toggles active; Deactivate greys it, Reactivate restores it;
changes persist and reflect live.

---

## Self-Review notes (author)

- **Spec coverage:** §3.1 entity → T1; §3.2 CategoryKind → T1; §3.3 converter → T2; §3.4 repository + DI → T3; §4 hooks → T4; §5 page → T5; §6 permission/route/guard/nav → T6; §7 testing → T1 + full-suite in T7.
- **Out of scope (per spec §2):** seed defaults, rules changes, inventory-form consumption (Slice 2).
- **Type consistency:** `Category`, `CategoryKind`, `collectionForKind`/`labelForKind`, `CategoryRepository.{list,watchAll,create,update}`, `CategoryUpdateInput`, `useCategories`/`useActiveCategories`/`useCreateCategory`/`useUpdateCategory` are used identically across tasks.
- **No composite index** — repo filters/sorts client-side (categories are tiny). React Query v5 `isPending` used in the page.
