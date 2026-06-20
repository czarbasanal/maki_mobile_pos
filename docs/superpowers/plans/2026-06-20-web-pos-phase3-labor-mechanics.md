# Web POS Phase 3 — Labor + Mechanic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add mechanic labor to the web POS — a configurable Mechanics admin plus a POS labor-lines editor + mechanic picker — feeding the already-built sale-write, reporting, and display paths.

**Architecture:** Slice 3a adds a dedicated `Mechanic` entity/converter/repo (mirroring the existing `Category` data layer) on the shared `mechanics` collection, plus a `/settings/mechanics` admin page. Slice 3b adds pure labor helpers, labor + mechanic state in `cartStore`, a `LaborSection` UI, and wires labor/mechanic through `CheckoutInput`/`buildSaleInput`. The sale write, `saleConverter`, reporting (`summarizeSales` labor track), Sale Detail display, and `firestore.rules` are unchanged.

**Tech Stack:** React + Vite + TypeScript, Zustand, TanStack Query, Firestore, Vitest. Run all commands from `web_admin/`.

## Global Constraints

- All commands run from `web_admin/`. Verify with `npm run typecheck` (`tsc -b`) and `npm run test` (vitest); `npm run build` for the UI tasks.
- Vitest resolves the `@/` alias.
- Mirror the existing `Category` data layer (`Category.ts` / `categoryConverter.ts` / `FirestoreCategoryRepository.ts` / `useCategories.ts` / `useCategoryMutations.ts` / `ManageListsPage.tsx`) for the Mechanic equivalents.
- Mechanics live in the **shared `mechanics` Firestore collection** that mobile reads/writes — keep field names identical (`name`, `isActive`, `createdAt`, `updatedAt`, `createdBy`, `updatedBy`).
- **No `firestore.rules` change** — `mechanics` is `read: isValidUser() && isActiveUser()` / `write: isAdmin() && isActiveUser()`; the web admin is admin-only.
- **No per-route permission gate** — all routes sit behind the admin-only `ProtectedRoute`; just add the route + a `SettingsPage` nav link (mobile gates `/settings/mechanics` by `Permission.manageCategories`, which every web admin already has).
- Product rules: **mechanic optional always** (nullable); **labor-only ticket blocked** (the Complete gate already requires `lines.length > 0` parts — unchanged); **labor never discounted, zero cost** (structural); a labor line **counts/writes iff `description.trim() !== ''`**.
- Money inputs are **string-backed** so decimals (`150.50`) type cleanly (the Phase-2 lesson).
- Do NOT touch: `saleConverter`, `FirestoreSaleRepository.create` (already writes labor/mechanic), `summarizeSales`, `SaleDetailPage`, `firestore.rules`.

---

## Slice 3a — Mechanic infrastructure + admin

### Task 1: Mechanic data layer (entity, converter, repo, DI)

**Files:**
- Create: `web_admin/src/domain/entities/Mechanic.ts`
- Modify: `web_admin/src/domain/entities/index.ts`
- Modify: `web_admin/src/infrastructure/firebase/collections.ts`
- Create: `web_admin/src/domain/repositories/MechanicRepository.ts`
- Create: `web_admin/src/data/converters/mechanicConverter.ts`
- Test: `web_admin/src/data/converters/mechanicConverter.test.ts`
- Create: `web_admin/src/data/repositories/FirestoreMechanicRepository.ts`
- Modify: `web_admin/src/infrastructure/di/container.tsx`

**Interfaces:**
- Consumes: `requireDate` / `toDate` (`@/data/converters/timestamps`), `Unsubscribe` (`@/domain/repositories/AuthRepository`), `FirestoreCollections` (`@/infrastructure/firebase/collections`).
- Produces:
  - `interface Mechanic { id: string; name: string; isActive: boolean; createdAt: Date; updatedAt: Date | null; createdBy: string | null; updatedBy: string | null }`
  - `interface MechanicUpdateInput { name?: string; isActive?: boolean }`
  - `interface MechanicRepository { watchAll(cb: (m: Mechanic[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe; create(name: string, actorId: string): Promise<Mechanic>; update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void> }`
  - `mechanicConverter: FirestoreDataConverter<Mechanic>`
  - `useMechanicRepo(): MechanicRepository`

- [ ] **Step 1: Write the failing converter test**

Create `web_admin/src/data/converters/mechanicConverter.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { mechanicConverter } from './mechanicConverter';

// Minimal fake snapshot — the converter only reads `.id` and `.data()`.
const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

describe('mechanicConverter.fromFirestore', () => {
  it('reads name / isActive / audit fields and timestamps', () => {
    const created = Timestamp.fromDate(new Date('2026-01-02T03:04:05Z'));
    const updated = Timestamp.fromDate(new Date('2026-01-03T03:04:05Z'));
    const m = mechanicConverter.fromFirestore(
      snap('m1', {
        name: 'Juan',
        isActive: true,
        createdAt: created,
        updatedAt: updated,
        createdBy: 'u1',
        updatedBy: 'u2',
      }),
    );
    expect(m).toEqual({
      id: 'm1',
      name: 'Juan',
      isActive: true,
      createdAt: created.toDate(),
      updatedAt: updated.toDate(),
      createdBy: 'u1',
      updatedBy: 'u2',
    });
  });

  it('defaults name/isActive and tolerates a missing updatedAt + audit', () => {
    const created = Timestamp.fromDate(new Date('2026-01-02T03:04:05Z'));
    const m = mechanicConverter.fromFirestore(snap('m2', { createdAt: created }));
    expect(m.name).toBe('');
    expect(m.isActive).toBe(true);
    expect(m.updatedAt).toBeNull();
    expect(m.createdBy).toBeNull();
    expect(m.updatedBy).toBeNull();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run test -- mechanicConverter`
Expected: FAIL — cannot resolve `./mechanicConverter`.

- [ ] **Step 3: Create the entity + barrel export**

Create `web_admin/src/domain/entities/Mechanic.ts`:

```ts
// Mirror of lib/domain/entities/mechanic_entity.dart. Admin-managed list of
// mechanics in the shared `mechanics` collection; assigned (optionally) to a
// service sale.
export interface Mechanic {
  id: string;
  name: string;        // display + match key
  isActive: boolean;   // soft-delete; inactive drops off the picker, stays valid on history
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
```

In `web_admin/src/domain/entities/index.ts`, add after the `./Category` line:

```ts
export * from './Mechanic';
```

- [ ] **Step 4: Add the collection constant**

In `web_admin/src/infrastructure/firebase/collections.ts`, add inside the `FirestoreCollections` object (after `suppliers: 'suppliers',`):

```ts
  mechanics: 'mechanics',
```

- [ ] **Step 5: Create the repository interface**

Create `web_admin/src/domain/repositories/MechanicRepository.ts`:

```ts
import type { Mechanic } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface MechanicUpdateInput {
  name?: string;
  isActive?: boolean;
}

export interface MechanicRepository {
  watchAll(cb: (mechanics: Mechanic[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  create(name: string, actorId: string): Promise<Mechanic>;
  update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void>;
}
```

- [ ] **Step 6: Create the converter (makes the test pass)**

Create `web_admin/src/data/converters/mechanicConverter.ts`:

```ts
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Mechanic } from '@/domain/entities';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on write.
export const mechanicConverter: FirestoreDataConverter<Mechanic> = {
  toFirestore(m) {
    return {
      name: m.name,
      isActive: m.isActive,
      createdBy: m.createdBy,
      updatedBy: m.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Mechanic {
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

- [ ] **Step 7: Run the converter test (passes)**

Run: `npm run test -- mechanicConverter`
Expected: PASS (2 tests).

- [ ] **Step 8: Create the Firestore repository**

Create `web_admin/src/data/repositories/FirestoreMechanicRepository.ts`:

```ts
import {
  addDoc,
  collection,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type {
  MechanicRepository,
  MechanicUpdateInput,
} from '@/domain/repositories/MechanicRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Mechanic } from '@/domain/entities';
import { mechanicConverter } from '@/data/converters/mechanicConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `mechanics` is a small collection — read the whole list and filter/sort
// client-side (no composite index), mirroring FirestoreCategoryRepository.
export class FirestoreMechanicRepository implements MechanicRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.mechanics).withConverter(mechanicConverter);
  }

  private shape(items: Mechanic[], includeInactive: boolean): Mechanic[] {
    const out = includeInactive ? items : items.filter((m) => m.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  watchAll(cb: (mechanics: Mechanic[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe {
    return onSnapshot(this.col(), (snap) => {
      cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
    });
  }

  async create(name: string, actorId: string): Promise<Mechanic> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.mechanics), {
      name,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(mechanicConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created mechanic');
    return created;
  }

  async update(id: string, input: MechanicUpdateInput, actorId: string): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    await updateDoc(doc(this.db, FirestoreCollections.mechanics, id), data);
  }
}
```

- [ ] **Step 9: Register in the DI container**

In `web_admin/src/infrastructure/di/container.tsx`:
- Add the import next to the other repos: `import { FirestoreMechanicRepository } from '@/data/repositories/FirestoreMechanicRepository';`
- Add the type import: `import type { MechanicRepository } from '@/domain/repositories/MechanicRepository';`
- Add to the `Container` interface (after `categoryRepo: CategoryRepository;`): `mechanicRepo: MechanicRepository;`
- Add to `buildDefaultContainer()` return (after `categoryRepo: new FirestoreCategoryRepository(db),`): `mechanicRepo: new FirestoreMechanicRepository(db),`
- Add the accessor at the end of the file:

```ts
export function useMechanicRepo(): MechanicRepository {
  return useContainer().mechanicRepo;
}
```

- [ ] **Step 10: Typecheck + test**

Run: `npm run typecheck && npm run test -- mechanicConverter`
Expected: typecheck clean (repo implements the interface, DI wired); converter test PASS.

- [ ] **Step 11: Commit**

```bash
git add web_admin/src/domain/entities/Mechanic.ts web_admin/src/domain/entities/index.ts \
  web_admin/src/infrastructure/firebase/collections.ts \
  web_admin/src/domain/repositories/MechanicRepository.ts \
  web_admin/src/data/converters/mechanicConverter.ts web_admin/src/data/converters/mechanicConverter.test.ts \
  web_admin/src/data/repositories/FirestoreMechanicRepository.ts \
  web_admin/src/infrastructure/di/container.tsx
git commit -m "feat(web): Mechanic entity + converter + repo + DI (shared mechanics collection)"
```

---

### Task 2: Mechanic hooks + /settings/mechanics admin page

**Files:**
- Create: `web_admin/src/presentation/hooks/useMechanics.ts`
- Create: `web_admin/src/presentation/hooks/useMechanicMutations.ts`
- Create: `web_admin/src/presentation/features/settings/MechanicsPage.tsx`
- Modify: `web_admin/src/presentation/router/routePaths.ts`
- Modify: `web_admin/src/presentation/router/routes.tsx`
- Modify: `web_admin/src/presentation/features/settings/SettingsPage.tsx`

**Interfaces:**
- Consumes: `useMechanicRepo` (Task 1), `useFirestoreSubscription`, `Mechanic`, the common components `LoadingView`/`Spinner`/`ErrorView`/`EmptyState`/`Dialog`.
- Produces:
  - `useMechanics(opts?: { includeInactive?: boolean })` → `SubscriptionState<Mechanic[]>`
  - `useActiveMechanics()` → `SubscriptionState<Mechanic[]>`
  - `useCreateMechanic()` / `useUpdateMechanic()` mutations
  - `MechanicsPage` component; route `RoutePaths.mechanics = '/settings/mechanics'`

- [ ] **Step 1: Create the hooks**

Create `web_admin/src/presentation/hooks/useMechanics.ts`:

```ts
import { useMechanicRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Mechanic } from '@/domain/entities';

/** Live mechanic list. Pass includeInactive for the management screen. */
export function useMechanics(opts?: { includeInactive?: boolean }) {
  const repo = useMechanicRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<Mechanic[]>(
    (onData) => repo.watchAll(onData, { includeInactive }),
    [repo, includeInactive],
  );
}

/** Active, name-sorted mechanics — the POS picker source. */
export function useActiveMechanics() {
  return useMechanics({ includeInactive: false });
}
```

Create `web_admin/src/presentation/hooks/useMechanicMutations.ts`:

```ts
import { useMutation } from '@tanstack/react-query';
import { useMechanicRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Mechanic } from '@/domain/entities';

export function useCreateMechanic() {
  const repo = useMechanicRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Mechanic, Error, { name: string }>({
    mutationFn: async ({ name }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(name, actor.id);
    },
  });
}

export function useUpdateMechanic() {
  const repo = useMechanicRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; name?: string; isActive?: boolean }>({
    mutationFn: async ({ id, ...patch }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.update(id, patch, actor.id);
    },
  });
}
```

- [ ] **Step 2: Create the admin page**

Create `web_admin/src/presentation/features/settings/MechanicsPage.tsx` (modeled on `ManageListsPage`, single list, no kind tabs):

```tsx
import { useEffect, useState } from 'react';
import { EyeIcon, EyeSlashIcon, PencilIcon, PlusIcon } from '@heroicons/react/24/outline';
import { useMechanics } from '@/presentation/hooks/useMechanics';
import { useCreateMechanic, useUpdateMechanic } from '@/presentation/hooks/useMechanicMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import type { Mechanic } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

export function MechanicsPage() {
  useEffect(() => {
    document.title = 'Mechanics · MAKI POS Admin';
  }, []);

  const { data: mechanics, isLoading, error } = useMechanics({ includeInactive: true });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Mechanic | null>(null);
  const [name, setName] = useState('');
  const [active, setActive] = useState(true);

  const create = useCreateMechanic();
  const update = useUpdateMechanic();
  const busy = create.isPending || update.isPending;

  const openAdd = () => {
    setEditing(null);
    setName('');
    setActive(true);
    setDialogOpen(true);
  };
  const openEdit = (m: Mechanic) => {
    setEditing(m);
    setName(m.name);
    setActive(m.isActive);
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

  const toggleActive = async (m: Mechanic) => {
    await update.mutateAsync({ id: m.id, isActive: !m.isActive });
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Mechanics</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Mechanics available for the labor picker on service sales.
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

      {error ? (
        <ErrorView title="Could not load mechanics" message={error.message} />
      ) : isLoading || !mechanics ? (
        <LoadingView label="Loading…" />
      ) : mechanics.length === 0 ? (
        <EmptyState title="No mechanics yet" description="Add the first mechanic." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {mechanics.map((m) => (
              <li key={m.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                <span
                  className={cn(
                    'text-bodySmall',
                    m.isActive ? 'text-light-text' : 'text-light-text-hint line-through',
                  )}
                >
                  {m.name}
                  {m.isActive ? '' : ' (inactive)'}
                </span>
                <span className="flex items-center gap-tk-xs">
                  <button
                    type="button"
                    onClick={() => openEdit(m)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    <PencilIcon className="h-3.5 w-3.5" /> Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => toggleActive(m)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    {m.isActive ? <EyeSlashIcon className="h-3.5 w-3.5" /> : <EyeIcon className="h-3.5 w-3.5" />}
                    {m.isActive ? 'Deactivate' : 'Reactivate'}
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
        title={editing ? 'Edit mechanic' : 'Add mechanic'}
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

- [ ] **Step 3: Add the route path**

In `web_admin/src/presentation/router/routePaths.ts`, add after `manageLists: '/settings/lists',`:

```ts
  mechanics: '/settings/mechanics',
```

- [ ] **Step 4: Wire the route**

In `web_admin/src/presentation/router/routes.tsx`:
- Add the import after the `ManageListsPage` import: `import { MechanicsPage } from '@/presentation/features/settings/MechanicsPage';`
- Add the route after the `manageLists` route line:

```tsx
        { path: RoutePaths.mechanics, element: <MechanicsPage /> },
```

- [ ] **Step 5: Add the Settings nav entry**

In `web_admin/src/presentation/features/settings/SettingsPage.tsx`:
- Add `WrenchScrewdriverIcon` to the `@heroicons/react/24/outline` import.
- Add a `Row` inside the "Administration" `<Section>` after the "Manage lists" Row:

```tsx
        <Row
          to={RoutePaths.mechanics}
          icon={WrenchScrewdriverIcon}
          tone="orange"
          title="Mechanics"
          subtitle="Mechanics for labor on service sales"
        />
```

- [ ] **Step 6: Typecheck + build**

Run: `npm run typecheck && npm run build`
Expected: both clean (no unit test — the admin mirrors the untested Category admin; verified by browser smoke in Task 7).

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/presentation/hooks/useMechanics.ts web_admin/src/presentation/hooks/useMechanicMutations.ts \
  web_admin/src/presentation/features/settings/MechanicsPage.tsx \
  web_admin/src/presentation/router/routePaths.ts web_admin/src/presentation/router/routes.tsx \
  web_admin/src/presentation/features/settings/SettingsPage.tsx
git commit -m "feat(web): /settings/mechanics admin page + mechanic hooks"
```

---

## Slice 3b — POS labor + mechanic

### Task 3: Labor pure helpers + labor-inclusive cart total

**Files:**
- Create: `web_admin/src/domain/sales/labor.ts`
- Test: `web_admin/src/domain/sales/labor.test.ts`
- Modify: `web_admin/src/domain/sales/cart.ts`
- Modify: `web_admin/src/domain/sales/cart.test.ts`
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx` (keep the `cartGrandTotal` call compiling)

**Interfaces:**
- Consumes: `LaborLine` (`@/domain/entities/LaborLine`), the existing `cart.ts` helpers.
- Produces:
  - `describedLaborLines(lines: LaborLine[]): LaborLine[]`
  - `cartLaborSubtotal(lines: LaborLine[]): number`
  - `cartGrandTotal(lines: CartLine[], laborLines: LaborLine[], discountType: DiscountType): number` (new signature — parts revenue + labor subtotal)

- [ ] **Step 1: Write the failing labor test**

Create `web_admin/src/domain/sales/labor.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { cartLaborSubtotal, describedLaborLines } from './labor';
import type { LaborLine } from '@/domain/entities/LaborLine';

const line = (over: Partial<LaborLine> = {}): LaborLine => ({
  id: 'l1',
  description: 'Tune-up',
  fee: 500,
  ...over,
});

describe('describedLaborLines', () => {
  it('keeps only lines with a non-blank description (fee may be 0)', () => {
    const lines = [
      line({ id: 'a', description: 'Tune-up', fee: 500 }),
      line({ id: 'b', description: '   ', fee: 300 }), // blank → dropped
      line({ id: 'c', description: 'Courtesy check', fee: 0 }), // kept, fee 0 ok
      line({ id: 'd', description: '', fee: 0 }), // blank → dropped
    ];
    expect(describedLaborLines(lines).map((l) => l.id)).toEqual(['a', 'c']);
  });
});

describe('cartLaborSubtotal', () => {
  it('sums fees of described lines only', () => {
    const lines = [
      line({ id: 'a', description: 'Tune-up', fee: 500 }),
      line({ id: 'b', description: '   ', fee: 300 }), // blank desc → excluded
      line({ id: 'c', description: 'Brake bleed', fee: 250 }),
    ];
    expect(cartLaborSubtotal(lines)).toBe(750);
  });
  it('is 0 for an empty list', () => {
    expect(cartLaborSubtotal([])).toBe(0);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run test -- labor`
Expected: FAIL — cannot resolve `./labor`.

- [ ] **Step 3: Create `labor.ts`**

Create `web_admin/src/domain/sales/labor.ts`:

```ts
import type { LaborLine } from '@/domain/entities/LaborLine';

/** Labor lines that count: a charge requires a non-blank description. */
export function describedLaborLines(lines: LaborLine[]): LaborLine[] {
  return lines.filter((l) => l.description.trim() !== '');
}

/** Σ fee of the described labor lines (full price, never discounted). */
export function cartLaborSubtotal(lines: LaborLine[]): number {
  return describedLaborLines(lines).reduce((sum, l) => sum + (l.fee || 0), 0);
}
```

- [ ] **Step 4: Run the labor test (passes)**

Run: `npm run test -- labor`
Expected: PASS.

- [ ] **Step 5: Make `cartGrandTotal` labor-inclusive**

In `web_admin/src/domain/sales/cart.ts`:
- Add the imports at the top (alongside the existing imports):

```ts
import type { LaborLine } from '@/domain/entities/LaborLine';
import { cartLaborSubtotal } from './labor';
```

- Replace the existing `cartGrandTotal` function with:

```ts
export function cartGrandTotal(
  lines: CartLine[],
  laborLines: LaborLine[],
  discountType: DiscountType,
): number {
  // Parts revenue (labor-0 path) + labor subtotal (described lines only).
  return saleGrandTotal(asSale(lines, discountType)) + cartLaborSubtotal(laborLines);
}
```

(`cartSubtotal` / `cartDiscount` and the labor-0 `asSale` are unchanged.)

- [ ] **Step 6: Update `cart.test.ts`**

In `web_admin/src/domain/sales/cart.test.ts`, update the two `cartGrandTotal` calls to pass `[]` as the new labor arg, and add a labor-inclusive case. Replace the `describe('cartGrandTotal', …)` block with:

```ts
describe('cartGrandTotal', () => {
  it('sums net of per-line amount discounts (no labor)', () => {
    expect(
      cartGrandTotal(
        [line({ quantity: 2 }), line({ productId: 'p2', discountValue: 20 })],
        [],
        DiscountType.amount,
      ),
    ).toBe(200 + 80);
  });
  it('applies percentage discounts (no labor)', () => {
    expect(cartGrandTotal([line({ discountValue: 10 })], [], DiscountType.percentage)).toBe(90);
  });
  it('adds described labor on top of parts', () => {
    expect(
      cartGrandTotal(
        [line({ quantity: 2 })],
        [
          { id: 'l1', description: 'Tune-up', fee: 300 },
          { id: 'l2', description: '   ', fee: 999 }, // blank desc → excluded
        ],
        DiscountType.amount,
      ),
    ).toBe(200 + 300);
  });
});
```

- [ ] **Step 7: Keep PosPage compiling**

In `web_admin/src/presentation/features/pos/PosPage.tsx`, update the `grandTotal` line to pass an empty labor list for now (Task 5 swaps it for real labor):

```tsx
  const grandTotal = cartGrandTotal(lines, [], discountType);
```

- [ ] **Step 8: Test + typecheck**

Run: `npm run test -- labor cart && npm run typecheck`
Expected: `labor.test.ts` + `cart.test.ts` PASS; typecheck clean.

- [ ] **Step 9: Commit**

```bash
git add web_admin/src/domain/sales/labor.ts web_admin/src/domain/sales/labor.test.ts \
  web_admin/src/domain/sales/cart.ts web_admin/src/domain/sales/cart.test.ts \
  web_admin/src/presentation/features/pos/PosPage.tsx
git commit -m "feat(web): labor helpers + labor-inclusive cartGrandTotal"
```

---

### Task 4: Cart store — labor lines + mechanic

**Files:**
- Modify: `web_admin/src/presentation/stores/cartStore.ts`
- Modify: `web_admin/src/presentation/stores/cartStore.test.ts`

**Interfaces:**
- Consumes: `LaborLine` (`@/domain/entities/LaborLine`).
- Produces (new `CartState` members): `laborLines: LaborLine[]`, `mechanicId: string | null`, `mechanicName: string | null`, `addLaborLine()`, `setLaborLine(id, patch)`, `removeLaborLine(id)`, `setMechanic(id, name)`; `clear()` resets all of them.

- [ ] **Step 1: Write the failing store tests**

In `web_admin/src/presentation/stores/cartStore.test.ts`, add these cases inside the `describe('cartStore', …)` block:

```ts
  it('adds, edits, and removes labor lines (fee clamps at 0)', () => {
    const store = useCartStore.getState();
    store.addLaborLine();
    let lines = useCartStore.getState().laborLines;
    expect(lines).toHaveLength(1);
    expect(lines[0].description).toBe('');
    expect(lines[0].fee).toBe(0);

    const id = lines[0].id;
    store.setLaborLine(id, { description: 'Tune-up' });
    store.setLaborLine(id, { fee: -5 });
    lines = useCartStore.getState().laborLines;
    expect(lines[0].description).toBe('Tune-up');
    expect(lines[0].fee).toBe(0); // clamped

    store.setLaborLine(id, { fee: 300 });
    expect(useCartStore.getState().laborLines[0].fee).toBe(300);

    store.removeLaborLine(id);
    expect(useCartStore.getState().laborLines).toHaveLength(0);
  });

  it('sets and clears the mechanic, and clear() resets labor + mechanic', () => {
    const store = useCartStore.getState();
    store.setMechanic('m1', 'Juan');
    expect(useCartStore.getState().mechanicId).toBe('m1');
    expect(useCartStore.getState().mechanicName).toBe('Juan');

    store.addLaborLine();
    store.clear();
    expect(useCartStore.getState().laborLines).toHaveLength(0);
    expect(useCartStore.getState().mechanicId).toBeNull();
    expect(useCartStore.getState().mechanicName).toBeNull();
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `npm run test -- cartStore`
Expected: FAIL — `addLaborLine` / `setMechanic` are not functions.

- [ ] **Step 3: Extend the store**

In `web_admin/src/presentation/stores/cartStore.ts`:
- Add the import: `import type { LaborLine } from '@/domain/entities/LaborLine';`
- Add to the `CartState` interface (after `discountType: DiscountType;`):

```ts
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
```

- Add to the `CartState` interface (after `setDiscountType: …;`):

```ts
  addLaborLine: () => void;
  setLaborLine: (id: string, patch: Partial<Pick<LaborLine, 'description' | 'fee'>>) => void;
  removeLaborLine: (id: string) => void;
  setMechanic: (id: string | null, name: string | null) => void;
```

- Add the initial state (after `discountType: DiscountType.amount,`):

```ts
  laborLines: [],
  mechanicId: null,
  mechanicName: null,
```

- Add the actions (before `clear:`):

```ts
  addLaborLine: () =>
    set((s) => ({
      laborLines: [...s.laborLines, { id: crypto.randomUUID(), description: '', fee: 0 }],
    })),
  setLaborLine: (id, patch) =>
    set((s) => ({
      laborLines: s.laborLines.map((l) => {
        if (l.id !== id) return l;
        const next = { ...l, ...patch };
        if (patch.fee !== undefined) next.fee = Math.max(0, patch.fee || 0);
        return next;
      }),
    })),
  removeLaborLine: (id) =>
    set((s) => ({ laborLines: s.laborLines.filter((l) => l.id !== id) })),
  setMechanic: (id, name) => set({ mechanicId: id, mechanicName: name }),
```

- Replace `clear` with the labor/mechanic-resetting version:

```ts
  clear: () =>
    set({
      lines: [],
      discountType: DiscountType.amount,
      laborLines: [],
      mechanicId: null,
      mechanicName: null,
    }),
```

- [ ] **Step 4: Run the store tests (pass)**

Run: `npm run test -- cartStore && npm run typecheck`
Expected: all `cartStore.test.ts` PASS; typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/stores/cartStore.ts web_admin/src/presentation/stores/cartStore.test.ts
git commit -m "feat(web): cart store holds labor lines + mechanic"
```

---

### Task 5: Carry labor + mechanic through checkout

**Files:**
- Modify: `web_admin/src/presentation/hooks/buildSaleInput.ts`
- Modify: `web_admin/src/presentation/hooks/buildSaleInput.test.ts`
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx`

**Interfaces:**
- Consumes: `LaborLine`, `describedLaborLines` (Task 3), the cart store's `laborLines`/`mechanicId`/`mechanicName` (Task 4).
- Produces: `CheckoutInput` gains `laborLines: LaborLine[]`, `mechanicId: string | null`, `mechanicName: string | null`; `buildSaleInput` writes them.

- [ ] **Step 1: Update the buildSaleInput test**

In `web_admin/src/presentation/hooks/buildSaleInput.test.ts`:
- Add `import type { LaborLine } from '@/domain/entities/LaborLine';` (top, with the other imports).
- Add `laborLines: [], mechanicId: null, mechanicName: null,` to the `input(...)` factory defaults (so existing cases still type-check), i.e. replace the factory body defaults with:

```ts
const input = (over: Partial<CheckoutInput> = {}): CheckoutInput => ({
  lines: [],
  discountType: DiscountType.amount,
  paymentMethod: PaymentMethod.cash,
  tenders: { [PaymentMethod.cash]: 100 },
  amountReceived: 100,
  changeGiven: 0,
  laborLines: [],
  mechanicId: null,
  mechanicName: null,
  ...over,
});
```

- Add a new test inside `describe('buildSaleInput', …)`:

```ts
  it('carries labor lines + mechanic through verbatim', () => {
    const labor: LaborLine[] = [{ id: 'l1', description: 'Tune-up', fee: 500 }];
    const s = buildSaleInput(
      input({ laborLines: labor, mechanicId: 'm1', mechanicName: 'Juan' }),
      actor(),
    );
    expect(s.laborLines).toEqual(labor);
    expect(s.mechanicId).toBe('m1');
    expect(s.mechanicName).toBe('Juan');
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `npm run test -- buildSaleInput`
Expected: FAIL — `laborLines`/`mechanicId`/`mechanicName` not on `CheckoutInput` (type error) / assertion fails.

- [ ] **Step 3: Widen `CheckoutInput` + use the fields**

In `web_admin/src/presentation/hooks/buildSaleInput.ts`:
- Add the import: `import type { LaborLine } from '@/domain/entities/LaborLine';`
- Add to the `CheckoutInput` interface (after `changeGiven: number;`):

```ts
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
```

- In `buildSaleInput`'s returned object, replace the three hardcoded lines:

```ts
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
```

with:

```ts
    laborLines: input.laborLines,
    mechanicId: input.mechanicId,
    mechanicName: input.mechanicName,
```

- [ ] **Step 4: Wire PosPage onComplete + grandTotal**

In `web_admin/src/presentation/features/pos/PosPage.tsx`:
- Add the import: `import { describedLaborLines } from '@/domain/sales/labor';`
- Add cart-store selectors (next to the existing `useCartStore` selectors):

```tsx
  const laborLines = useCartStore((s) => s.laborLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
```

- Change the `grandTotal` line from `cartGrandTotal(lines, [], discountType)` to:

```tsx
  const grandTotal = cartGrandTotal(lines, laborLines, discountType);
```

- In `onComplete`, add the three fields to the `checkout.mutateAsync({...})` argument (after `changeGiven: pay.changeGiven,`):

```tsx
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
```

- [ ] **Step 5: Test + typecheck**

Run: `npm run test -- buildSaleInput && npm run typecheck`
Expected: `buildSaleInput.test.ts` PASS (incl. the new case); typecheck clean. (Behavior unchanged in the app — labor/mechanic are still empty until Task 6's UI.)

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/hooks/buildSaleInput.ts web_admin/src/presentation/hooks/buildSaleInput.test.ts \
  web_admin/src/presentation/features/pos/PosPage.tsx
git commit -m "feat(web): carry labor lines + mechanic through checkout"
```

---

### Task 6: POS labor editor + mechanic picker UI

**Files:**
- Create: `web_admin/src/presentation/features/pos/LaborSection.tsx`
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx`

**Interfaces:**
- Consumes: `useCartStore` (labor/mechanic state + setters from Task 4), `useActiveMechanics` (Task 2), `cartLaborSubtotal` (Task 3), `formatMoney`, `cn`.
- Produces: `LaborSection` component (self-contained: reads the cart store + active mechanics); a "Labor" summary row in PosPage.

- [ ] **Step 1: Create `LaborSection`**

Create `web_admin/src/presentation/features/pos/LaborSection.tsx`:

```tsx
import { useState } from 'react';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useActiveMechanics } from '@/presentation/hooks/useMechanics';
import type { LaborLine } from '@/domain/entities/LaborLine';

export function LaborSection() {
  const laborLines = useCartStore((s) => s.laborLines);
  const addLaborLine = useCartStore((s) => s.addLaborLine);
  const setLaborLine = useCartStore((s) => s.setLaborLine);
  const removeLaborLine = useCartStore((s) => s.removeLaborLine);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const setMechanic = useCartStore((s) => s.setMechanic);

  const { data: mechanics } = useActiveMechanics();
  const active = mechanics ?? [];

  const onMechanicChange = (id: string) => {
    if (!id) return setMechanic(null, null);
    const m = active.find((x) => x.id === id);
    setMechanic(id, m?.name ?? null);
  };

  return (
    <div className="space-y-tk-sm border-t border-light-hairline px-tk-md py-tk-sm">
      <div className="flex items-center justify-between">
        <span className="text-bodySmall font-medium text-light-text">Labor</span>
        <button
          type="button"
          onClick={addLaborLine}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] text-light-text-secondary hover:bg-light-subtle"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add labor
        </button>
      </div>

      {laborLines.map((l) => (
        <LaborRow key={l.id} line={l} onChange={setLaborLine} onRemove={removeLaborLine} />
      ))}

      <label className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
        Mechanic
        <select
          value={mechanicId ?? ''}
          onChange={(e) => onMechanicChange(e.target.value)}
          className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
        >
          <option value="">None</option>
          {active.map((m) => (
            <option key={m.id} value={m.id}>
              {m.name}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}

function LaborRow({
  line,
  onChange,
  onRemove,
}: {
  line: LaborLine;
  onChange: (id: string, patch: Partial<Pick<LaborLine, 'description' | 'fee'>>) => void;
  onRemove: (id: string) => void;
}) {
  // Fee is string-backed locally so decimals (e.g. 150.50) type cleanly; the
  // store keeps the parsed number for the totals.
  const [feeText, setFeeText] = useState(line.fee ? String(line.fee) : '');

  return (
    <div className="flex items-center gap-tk-sm">
      <input
        type="text"
        value={line.description}
        onChange={(e) => onChange(line.id, { description: e.target.value })}
        placeholder="Description"
        className="min-w-0 flex-1 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
      />
      <input
        type="number"
        min={0}
        step="0.01"
        inputMode="decimal"
        value={feeText}
        onChange={(e) => {
          setFeeText(e.target.value);
          onChange(line.id, { fee: Number(e.target.value) || 0 });
        }}
        placeholder="Fee"
        className="w-24 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
      />
      <button
        type="button"
        onClick={() => onRemove(line.id)}
        className="text-light-text-hint hover:text-error"
      >
        <TrashIcon className="h-4 w-4" />
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Render it + add the Labor summary row in PosPage**

In `web_admin/src/presentation/features/pos/PosPage.tsx`:
- Add the imports: `import { cartLaborSubtotal } from '@/domain/sales/labor';` and `import { LaborSection } from './LaborSection';`
- Compute the labor subtotal next to the other totals:

```tsx
  const labor = cartLaborSubtotal(laborLines);
```

- Inside the cart card, immediately **before** the summary `<dl …>`, render the section:

```tsx
          <LaborSection />
```

- In the summary `<dl>`, add a Labor row between the Discount row and the Total row:

```tsx
            <Row label="Labor" value={formatMoney(labor)} />
```

(The `Total` row already uses `grandTotal`, which is now labor-inclusive from Task 5.)

- [ ] **Step 3: Typecheck + build**

Run: `npm run typecheck && npm run build && npm run test`
Expected: typecheck clean; build succeeds; all tests PASS (no behavioral test for the UI — covered by Task 7 smoke).

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/features/pos/LaborSection.tsx \
  web_admin/src/presentation/features/pos/PosPage.tsx
git commit -m "feat(web): POS labor editor + mechanic picker + labor in cart total"
```

---

### Task 7: Verify end-to-end

**Files:** none (verification only).

- [ ] **Step 1: Full typecheck + tests + build**

Run: `npm run typecheck && npm run test && npm run build`
Expected: typecheck clean; all suites green (incl. `mechanicConverter`, `labor`, updated `cart` / `cartStore` / `buildSaleInput`); build succeeds.

- [ ] **Step 2: Browser smoke — mechanics admin**

`npm run dev`, sign in. Go to **Settings → Mechanics** (`/settings/mechanics`). Add a mechanic (e.g. "Juan"); rename it; deactivate then reactivate. ✅ The list updates live; inactive renders struck-through.

- [ ] **Step 3: Browser smoke — POS labor + mechanic sale**

Go to `/pos`. Add a product. Click **Add labor**, enter `Tune-up` / `500.50` (✅ the decimal types cleanly). Pick **Juan** in the Mechanic dropdown. ✅ The summary shows a **Labor ₱500.50** row and **Total** = parts + ₱500.50; the payment panel's tender must cover the labor-inclusive total. Complete the sale (cash). Open it in **Reports → Sale Detail**: ✅ the labor line + labor subtotal + "Mechanic: Juan" all render. Check **Reports → Profit**: ✅ the labor revenue/profit track moved.

- [ ] **Step 4: Browser smoke — edge rules**

✅ A labor row with a fee but **blank description** does not change the Total and is not written (Sale Detail omits it). ✅ A labor-only attempt (no parts) leaves **Complete** disabled. ✅ "None" mechanic completes fine (mechanic optional).

- [ ] **Step 5: Commit (only if smoke-fix tweaks were needed)**

```bash
git add -A
git commit -m "fix(web): POS labor/mechanic smoke-test fixes"
```

---

## Notes for the implementer

- **Spec:** `docs/superpowers/specs/2026-06-20-web-pos-phase3-labor-mechanics-design.md`.
- **Deviation from spec §4.3:** the spec described routing labor through `asSale`/`saleGrandTotal`; the plan instead composes `cartGrandTotal = parts (labor-0 path) + cartLaborSubtotal(describedLaborLines)`. This is intentional — it keeps the displayed total consistent with the **described-only** lines that actually get written (no fee-with-blank-description drift).
- **Green between tasks:** Task 3 changes `cartGrandTotal`'s signature and patches the PosPage call to `[]`; Task 5 swaps in the real labor list; Task 6 adds the UI. Each task leaves typecheck + tests green.
- **No deploy.** Deployment (push + `firebase deploy --only hosting`) is a separate, explicitly-authorized step.
