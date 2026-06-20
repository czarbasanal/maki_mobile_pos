# Web POS Phase 4 — Drafts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the web POS hold a cart as a named draft, list open drafts, resume one back into the cart, and convert it to a sale on checkout — preserving parts, discount, labor, and mechanic.

**Architecture:** Extend the stale `Draft` entity (+ labor/mechanic), add a `draftConverter` + `FirestoreDraftRepository` (mirroring the Supplier CRUD repo) on the shared `drafts` collection, track the active draft in `cartStore`, and wire Save / Drafts-list / Resume / convert into the existing POS. No `firestore.rules` or `routeGuards` change.

**Tech Stack:** React + Vite + TypeScript, Zustand, TanStack Query, Firestore, Vitest. Run all commands from `web_admin/`.

## Global Constraints

- All commands run from `web_admin/`. Verify with `npm run typecheck` (`tsc -b`) and `npm run test` (vitest); `npm run build` for UI tasks.
- Vitest resolves the `@/` alias.
- Drafts write to the **shared `drafts` collection** mobile reads — match mobile `draft_model` field names (`name`, inline `items` maps w/ id, inline `laborLines` `{id,description,fee}`, `mechanicId`, `mechanicName`, `discountType`, `createdBy`, `createdByName`, `isConverted`, `convertedToSaleId`, `convertedAt`, `notes`, audit).
- **No `firestore.rules` change** — `drafts` allows `read` for any active user, `create` when `createdBy == request.auth.uid` (so the create path MUST set `createdBy = actor.id`), and `update`/`delete` for owner or admin (web admins qualify).
- **No `routeGuards` change** — `/drafts` is a `commonRoute` and `/drafts/*` has a dynamic allow; only wire the route element.
- Product rules: convert = **mark-converted, keep** the draft (`isConverted:true` + `convertedToSaleId` + `convertedAt`); the cart tracks the **active draft** (`draftId`/`draftName`) so resume→edit→Save updates the same draft; **name required** on save; **empty cart** can't be saved; **resume confirms** before replacing a non-empty cart; labor written to a draft is filtered to **described** lines (same rule as checkout); `markConverted` is **best-effort after** the sale (never undoes a completed sale).
- Do NOT touch: `firestore.rules`, `routeGuards.ts`, `FirestoreSaleRepository`, `summarizeSales`.

---

## Slice 4a — Draft data layer

### Task 1: Extend Draft entity + draftConverter (shared labor helper)

**Files:**
- Modify: `web_admin/src/domain/entities/Draft.ts`
- Create: `web_admin/src/data/converters/laborLines.ts`
- Modify: `web_admin/src/data/converters/saleConverter.ts`
- Create: `web_admin/src/data/converters/draftConverter.ts`
- Test: `web_admin/src/data/converters/draftConverter.test.ts`

**Interfaces:**
- Consumes: `requireDate`/`toDate` (`./timestamps`), `discountTypeFromString` (`@/domain/enums`), `SaleItem`/`LaborLine`/`Draft` entities.
- Produces:
  - `Draft` gains `laborLines: LaborLine[]`, `mechanicId: string | null`, `mechanicName: string | null`.
  - `parseLaborLines(value: unknown): LaborLine[]` + `laborLinesToMaps(lines: LaborLine[]): object[]` (in `laborLines.ts`).
  - `parseDraftItems(value: unknown): SaleItem[]` + `draftItemsToMaps(items: SaleItem[]): object[]` + `draftConverter: FirestoreDataConverter<Draft>` (in `draftConverter.ts`).

- [ ] **Step 1: Write the failing converter test**

Create `web_admin/src/data/converters/draftConverter.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { draftConverter } from './draftConverter';
import { DiscountType } from '@/domain/enums/DiscountType';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, exists: () => true, data: () => data }) as never;

const createdTs = Timestamp.fromDate(new Date('2026-02-01T00:00:00Z'));

describe('draftConverter.fromFirestore', () => {
  it('parses items + labor + mechanic + discount + conversion fields', () => {
    const d = draftConverter.fromFirestore(
      snap('d1', {
        name: 'Mr Cruz bike',
        items: [
          { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 2, discountValue: 0, unit: 'pcs' },
        ],
        laborLines: [{ id: 'l1', description: 'Tune-up', fee: 500 }],
        mechanicId: 'm1',
        mechanicName: 'Juan',
        discountType: 'percentage',
        createdBy: 'u1',
        createdByName: 'Cashier',
        createdAt: createdTs,
        isConverted: false,
        convertedToSaleId: null,
        notes: null,
      }),
    );
    expect(d.id).toBe('d1');
    expect(d.name).toBe('Mr Cruz bike');
    expect(d.items).toHaveLength(1);
    expect(d.items[0]).toMatchObject({ id: 'i1', productId: 'p1', quantity: 2 });
    expect(d.laborLines).toEqual([{ id: 'l1', description: 'Tune-up', fee: 500 }]);
    expect(d.mechanicId).toBe('m1');
    expect(d.mechanicName).toBe('Juan');
    expect(d.discountType).toBe(DiscountType.percentage);
    expect(d.isConverted).toBe(false);
    expect(d.createdAt).toEqual(createdTs.toDate());
  });

  it('defaults a missing name and missing labor', () => {
    const d = draftConverter.fromFirestore(snap('d2', { createdAt: createdTs }));
    expect(d.name).toBe('Unnamed Draft');
    expect(d.laborLines).toEqual([]);
    expect(d.items).toEqual([]);
    expect(d.mechanicId).toBeNull();
    expect(d.isConverted).toBe(false);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run test -- draftConverter`
Expected: FAIL — cannot resolve `./draftConverter`.

- [ ] **Step 3: Extend the Draft entity**

Replace the body of `web_admin/src/domain/entities/Draft.ts` with:

```ts
// Mirror of lib/domain/entities/draft_entity.dart.
import type { DiscountType } from '../enums';
import type { SaleItem } from './SaleItem';
import type { LaborLine } from './LaborLine';

export interface Draft {
  id: string;
  name: string;
  items: SaleItem[];
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  discountType: DiscountType;
  createdBy: string;
  createdByName: string;
  createdAt: Date;
  updatedAt: Date | null;
  updatedBy: string | null;
  isConverted: boolean;
  convertedToSaleId: string | null;
  convertedAt: Date | null;
  notes: string | null;
}
```

- [ ] **Step 4: Create the shared labor-lines helper**

Create `web_admin/src/data/converters/laborLines.ts`:

```ts
import type { LaborLine } from '@/domain/entities';

/** Parse an inline `laborLines` array from Firestore into LaborLine[]. */
export function parseLaborLines(value: unknown): LaborLine[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `labor-${i}`,
      description: typeof m.description === 'string' ? m.description : '',
      fee: Number(m.fee ?? 0),
    };
  });
}

/** Serialize LaborLine[] to inline Firestore maps (id included). */
export function laborLinesToMaps(lines: LaborLine[]): object[] {
  return lines.map((l) => ({ id: l.id, description: l.description, fee: l.fee }));
}
```

- [ ] **Step 5: Point saleConverter at the shared helper**

In `web_admin/src/data/converters/saleConverter.ts`:
- Add the import near the other imports: `import { parseLaborLines } from './laborLines';`
- Delete the local `function parseLaborLines(value: unknown): LaborLine[] { … }` block (the one defined at the bottom of the file). `parseTenders` stays.
- The `LaborLine` type import on line 10 (`import type { LaborLine, Sale } …`) is still used by `parseTenders`? No — it was only used by the removed function. If `LaborLine` is now unused in the file, drop it from that import (leave `Sale`). Run typecheck to confirm.

- [ ] **Step 6: Create the draftConverter**

Create `web_admin/src/data/converters/draftConverter.ts`:

```ts
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Draft, SaleItem } from '@/domain/entities';
import { discountTypeFromString } from '@/domain/enums';
import { requireDate, toDate } from './timestamps';
import { laborLinesToMaps, parseLaborLines } from './laborLines';

/** Serialize cart/draft items to inline Firestore maps (id included). */
export function draftItemsToMaps(items: SaleItem[]): object[] {
  return items.map((it) => ({
    id: it.id,
    productId: it.productId,
    sku: it.sku,
    name: it.name,
    unitPrice: it.unitPrice,
    unitCost: it.unitCost,
    quantity: it.quantity,
    discountValue: it.discountValue,
    unit: it.unit,
  }));
}

/** Parse an inline `items` array from Firestore into SaleItem[]. */
export function parseDraftItems(value: unknown): SaleItem[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw, i) => {
    const m = (raw ?? {}) as Record<string, unknown>;
    return {
      id: typeof m.id === 'string' ? m.id : `item-${i}`,
      productId: typeof m.productId === 'string' ? m.productId : '',
      sku: typeof m.sku === 'string' ? m.sku : '',
      name: typeof m.name === 'string' ? m.name : '',
      unitPrice: Number(m.unitPrice ?? 0),
      unitCost: Number(m.unitCost ?? 0),
      quantity: Number(m.quantity ?? 0),
      discountValue: Number(m.discountValue ?? 0),
      unit: typeof m.unit === 'string' ? m.unit : 'pcs',
    };
  });
}

// Reads use this converter; writes go through the repository inline (so they can
// use serverTimestamp). toFirestore is required by the type but unused on write.
export const draftConverter: FirestoreDataConverter<Draft> = {
  toFirestore(d) {
    return {
      name: d.name,
      items: draftItemsToMaps(d.items),
      laborLines: laborLinesToMaps(d.laborLines),
      mechanicId: d.mechanicId,
      mechanicName: d.mechanicName,
      discountType: d.discountType,
      createdBy: d.createdBy,
      createdByName: d.createdByName,
      updatedBy: d.updatedBy,
      isConverted: d.isConverted,
      convertedToSaleId: d.convertedToSaleId,
      notes: d.notes,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Draft {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: typeof d.name === 'string' && d.name ? d.name : 'Unnamed Draft',
      items: parseDraftItems(d.items),
      laborLines: parseLaborLines(d.laborLines),
      mechanicId: d.mechanicId ?? null,
      mechanicName: d.mechanicName ?? null,
      discountType: discountTypeFromString(d.discountType),
      createdBy: d.createdBy ?? '',
      createdByName: d.createdByName ?? '',
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      updatedBy: d.updatedBy ?? null,
      isConverted: d.isConverted ?? false,
      convertedToSaleId: d.convertedToSaleId ?? null,
      convertedAt: toDate(d.convertedAt),
      notes: d.notes ?? null,
    };
  },
};
```

- [ ] **Step 7: Run the tests + typecheck**

Run: `npm run test -- draftConverter saleConverter && npm run typecheck`
Expected: `draftConverter.test.ts` PASS (2 tests); `saleConverter.test.ts` still PASS; typecheck clean.

- [ ] **Step 8: Commit**

```bash
git add web_admin/src/domain/entities/Draft.ts web_admin/src/data/converters/laborLines.ts \
  web_admin/src/data/converters/saleConverter.ts web_admin/src/data/converters/draftConverter.ts \
  web_admin/src/data/converters/draftConverter.test.ts
git commit -m "feat(web): extend Draft entity (labor/mechanic) + draftConverter + shared labor helper"
```

---

### Task 2: FirestoreDraftRepository + DI + useDrafts hook

**Files:**
- Create: `web_admin/src/data/repositories/FirestoreDraftRepository.ts`
- Modify: `web_admin/src/infrastructure/di/container.tsx`
- Create: `web_admin/src/presentation/hooks/useDrafts.ts`

**Interfaces:**
- Consumes: `DraftRepository` (`@/domain/repositories/DraftRepository`), `draftItemsToMaps`/`draftConverter` (Task 1), `laborLinesToMaps` (Task 1), `useFirestoreSubscription`.
- Produces: `FirestoreDraftRepository`, `useDraftRepo(): DraftRepository`, `useDrafts(): SubscriptionState<Draft[]>`.

- [ ] **Step 1: Create the repository**

Create `web_admin/src/data/repositories/FirestoreDraftRepository.ts`:

```ts
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type { DraftRepository } from '@/domain/repositories/DraftRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Draft } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { draftConverter, draftItemsToMaps } from '@/data/converters/draftConverter';
import { laborLinesToMaps } from '@/data/converters/laborLines';

export class FirestoreDraftRepository implements DraftRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.drafts).withConverter(draftConverter);
  }

  async getById(id: string): Promise<Draft | null> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.drafts, id).withConverter(draftConverter),
    );
    return snap.exists() ? snap.data() : null;
  }

  watchAll(callback: (drafts: Draft[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), orderBy('createdAt', 'desc')), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  async create(draft: Omit<Draft, 'id' | 'createdAt' | 'updatedAt'>): Promise<Draft> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.drafts), {
      name: draft.name,
      items: draftItemsToMaps(draft.items),
      laborLines: laborLinesToMaps(draft.laborLines),
      mechanicId: draft.mechanicId,
      mechanicName: draft.mechanicName,
      discountType: draft.discountType,
      createdBy: draft.createdBy,
      createdByName: draft.createdByName,
      updatedBy: draft.updatedBy,
      isConverted: draft.isConverted,
      convertedToSaleId: draft.convertedToSaleId,
      convertedAt: draft.convertedAt,
      notes: draft.notes,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created draft');
    return created;
  }

  async update(
    id: string,
    patch: Partial<Omit<Draft, 'id' | 'createdAt'>>,
    actorId: string,
  ): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (patch.name !== undefined) data.name = patch.name;
    if (patch.items !== undefined) data.items = draftItemsToMaps(patch.items);
    if (patch.laborLines !== undefined) data.laborLines = laborLinesToMaps(patch.laborLines);
    if (patch.mechanicId !== undefined) data.mechanicId = patch.mechanicId;
    if (patch.mechanicName !== undefined) data.mechanicName = patch.mechanicName;
    if (patch.discountType !== undefined) data.discountType = patch.discountType;
    if (patch.notes !== undefined) data.notes = patch.notes;
    await updateDoc(doc(this.db, FirestoreCollections.drafts, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.drafts, id));
  }

  async markConverted(id: string, saleId: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.drafts, id), {
      isConverted: true,
      convertedToSaleId: saleId,
      convertedAt: serverTimestamp(),
    });
  }
}
```

- [ ] **Step 2: Register in the DI container**

In `web_admin/src/infrastructure/di/container.tsx`:
- Add import: `import { FirestoreDraftRepository } from '@/data/repositories/FirestoreDraftRepository';`
- Add type import: `import type { DraftRepository } from '@/domain/repositories/DraftRepository';`
- Add to the `Container` interface (after `mechanicRepo: MechanicRepository;`): `draftRepo: DraftRepository;`
- Add to `buildDefaultContainer()` (after `mechanicRepo: new FirestoreMechanicRepository(db),`): `draftRepo: new FirestoreDraftRepository(db),`
- Add the accessor at the end:

```ts
export function useDraftRepo(): DraftRepository {
  return useContainer().draftRepo;
}
```

- [ ] **Step 3: Create the useDrafts hook**

Create `web_admin/src/presentation/hooks/useDrafts.ts`:

```ts
import { useDraftRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Draft } from '@/domain/entities';

/** Live list of all drafts (newest first). The list page filters to open ones. */
export function useDrafts() {
  const repo = useDraftRepo();
  return useFirestoreSubscription<Draft[]>((onData) => repo.watchAll(onData), [repo]);
}
```

- [ ] **Step 4: Typecheck**

Run: `npm run typecheck`
Expected: clean (repo implements the interface, DI wired, hook resolves).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreDraftRepository.ts \
  web_admin/src/infrastructure/di/container.tsx web_admin/src/presentation/hooks/useDrafts.ts
git commit -m "feat(web): FirestoreDraftRepository + DI + useDrafts hook"
```

---

## Slice 4b — Save + list + delete

### Task 3: Cart store — active draft (draftId/draftName/loadDraft)

**Files:**
- Modify: `web_admin/src/presentation/stores/cartStore.ts`
- Modify: `web_admin/src/presentation/stores/cartStore.test.ts`

**Interfaces:**
- Consumes: `Draft` (`@/domain/entities`).
- Produces: `cartStore` gains `draftId: string | null`, `draftName: string | null`, `loadDraft(draft: Draft): void`; `clear()` resets both.

- [ ] **Step 1: Write the failing store tests**

In `web_admin/src/presentation/stores/cartStore.test.ts`, add (inside the `describe('cartStore', …)` block) — and add `import type { Draft } from '@/domain/entities';` at the top:

```ts
  it('loadDraft hydrates the cart and marks the draft active; clear resets it', () => {
    const store = useCartStore.getState();
    const draft: Draft = {
      id: 'd1',
      name: 'Mr Cruz bike',
      items: [
        { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 2, discountValue: 0, unit: 'pcs' },
      ],
      laborLines: [{ id: 'l1', description: 'Tune-up', fee: 500 }],
      mechanicId: 'm1',
      mechanicName: 'Juan',
      discountType: DiscountType.percentage,
      createdBy: 'u1',
      createdByName: 'Cashier',
      createdAt: new Date('2026-02-01'),
      updatedAt: null,
      updatedBy: null,
      isConverted: false,
      convertedToSaleId: null,
      convertedAt: null,
      notes: null,
    };

    store.loadDraft(draft);
    let s = useCartStore.getState();
    expect(s.lines).toHaveLength(1);
    expect(s.discountType).toBe(DiscountType.percentage);
    expect(s.laborLines).toEqual(draft.laborLines);
    expect(s.mechanicId).toBe('m1');
    expect(s.mechanicName).toBe('Juan');
    expect(s.draftId).toBe('d1');
    expect(s.draftName).toBe('Mr Cruz bike');

    store.clear();
    s = useCartStore.getState();
    expect(s.draftId).toBeNull();
    expect(s.draftName).toBeNull();
    expect(s.lines).toHaveLength(0);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `npm run test -- cartStore`
Expected: FAIL — `loadDraft` is not a function.

- [ ] **Step 3: Extend the store**

In `web_admin/src/presentation/stores/cartStore.ts`:
- Add import: `import type { Draft } from '@/domain/entities';`
- Add to the `CartState` interface (after `mechanicName: string | null;`):

```ts
  draftId: string | null;
  draftName: string | null;
```

- Add to the `CartState` interface (after `setMechanic: …;`):

```ts
  loadDraft: (draft: Draft) => void;
```

- Add initial state (after `mechanicName: null,`):

```ts
  draftId: null,
  draftName: null,
```

- Add the action (before `clear:`):

```ts
  loadDraft: (draft) =>
    set({
      lines: draft.items,
      discountType: draft.discountType,
      laborLines: draft.laborLines,
      mechanicId: draft.mechanicId,
      mechanicName: draft.mechanicName,
      draftId: draft.id,
      draftName: draft.name,
    }),
```

- Replace `clear` with the draft-resetting version:

```ts
  clear: () =>
    set({
      lines: [],
      discountType: DiscountType.amount,
      laborLines: [],
      mechanicId: null,
      mechanicName: null,
      draftId: null,
      draftName: null,
    }),
```

- [ ] **Step 4: Run the store tests + typecheck**

Run: `npm run test -- cartStore && npm run typecheck`
Expected: all `cartStore.test.ts` PASS; typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/stores/cartStore.ts web_admin/src/presentation/stores/cartStore.test.ts
git commit -m "feat(web): cart store tracks the active draft (loadDraft + draftId/draftName)"
```

---

### Task 4: Draft mutations + Save-draft button on POS

**Files:**
- Create: `web_admin/src/presentation/hooks/useDraftMutations.ts`
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx`

**Interfaces:**
- Consumes: `useDraftRepo` (Task 2), `useAuthStore`, `describedLaborLines` (labor.ts), the cart store, the common `Dialog`.
- Produces:
  - `SaveDraftInput` `{ draftId: string | null; name: string; items: SaleItem[]; discountType: DiscountType; laborLines: LaborLine[]; mechanicId: string | null; mechanicName: string | null }`
  - `useSaveDraft()`, `useDeleteDraft()`, `useMarkConverted()` mutations.

- [ ] **Step 1: Create the mutations hook**

Create `web_admin/src/presentation/hooks/useDraftMutations.ts`:

```ts
import { useMutation } from '@tanstack/react-query';
import { useDraftRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Draft, LaborLine, SaleItem } from '@/domain/entities';
import type { DiscountType } from '@/domain/enums/DiscountType';

export interface SaveDraftInput {
  draftId: string | null;
  name: string;
  items: SaleItem[];
  discountType: DiscountType;
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
}

/** Create a new draft or update the active one (resume → edit → save). */
export function useSaveDraft() {
  const repo = useDraftRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Draft | void, Error, SaveDraftInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      if (input.draftId) {
        await repo.update(
          input.draftId,
          {
            name: input.name,
            items: input.items,
            discountType: input.discountType,
            laborLines: input.laborLines,
            mechanicId: input.mechanicId,
            mechanicName: input.mechanicName,
          },
          actor.id,
        );
        return;
      }
      const cashierName = actor.displayName.trim() || actor.email;
      return repo.create({
        name: input.name,
        items: input.items,
        discountType: input.discountType,
        laborLines: input.laborLines,
        mechanicId: input.mechanicId,
        mechanicName: input.mechanicName,
        createdBy: actor.id,
        createdByName: cashierName,
        updatedBy: null,
        isConverted: false,
        convertedToSaleId: null,
        convertedAt: null,
        notes: null,
      });
    },
  });
}

export function useDeleteDraft() {
  const repo = useDraftRepo();
  return useMutation<void, Error, string>({ mutationFn: (id) => repo.delete(id) });
}

export function useMarkConverted() {
  const repo = useDraftRepo();
  return useMutation<void, Error, { id: string; saleId: string }>({
    mutationFn: ({ id, saleId }) => repo.markConverted(id, saleId),
  });
}
```

- [ ] **Step 2: Add the Save-draft button + dialog to PosPage**

In `web_admin/src/presentation/features/pos/PosPage.tsx`:
- Add imports:

```tsx
import { useSaveDraft } from '@/presentation/hooks/useDraftMutations';
import { Dialog } from '@/presentation/components/common/Dialog';
```

(`describedLaborLines` is already imported in PosPage from Phase 3 — reuse it; do not re-import. `cn` and `useState` are also already imported.)

- Add the `draftName` selector next to the other cart-store selectors:

```tsx
  const draftId = useCartStore((s) => s.draftId);
  const draftName = useCartStore((s) => s.draftName);
```

(`mechanicId`/`mechanicName`/`laborLines` selectors already exist from Phase 3.)

- Add local state + the save hook (near the other `useState`s):

```tsx
  const saveDraft = useSaveDraft();
  const [saveOpen, setSaveOpen] = useState(false);
  const [draftNameInput, setDraftNameInput] = useState('');
```

- Add the save handlers (near `onComplete`):

```tsx
  const openSave = () => {
    setDraftNameInput(draftName ?? '');
    setSaveOpen(true);
  };
  const onSaveDraft = async () => {
    const name = draftNameInput.trim();
    if (!name) return;
    try {
      await saveDraft.mutateAsync({
        draftId,
        name,
        items: lines,
        discountType,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
      });
      setSaveOpen(false);
      clear();
    } catch {
      // surfaced via saveDraft.error
    }
  };
```

(The dedicated `saveDraft.isSuccess` banner added below is the confirmation — the
sale-only `done` banner is left untouched, so no change to it is needed.)

- Add a **Save draft** button beside the Complete button (in the payment card, before or after Complete):

```tsx
          <button
            type="button"
            disabled={lines.length === 0 || saveDraft.isPending}
            onClick={openSave}
            className={cn(
              'w-full rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle',
              (lines.length === 0 || saveDraft.isPending) && 'cursor-not-allowed opacity-60',
            )}
          >
            {saveDraft.isPending ? 'Saving…' : draftId ? 'Update draft' : 'Save as draft'}
          </button>
```

- Add the name dialog (anywhere in the returned JSX, e.g. before the closing `</div>` of the page root):

```tsx
      <Dialog
        open={saveOpen}
        onClose={() => {
          if (!saveDraft.isPending) setSaveOpen(false);
        }}
        title={draftId ? 'Update draft' : 'Save as draft'}
        dismissable={!saveDraft.isPending}
      >
        <div className="space-y-tk-md">
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall text-light-text-secondary">Draft name</span>
            <input
              type="text"
              value={draftNameInput}
              onChange={(e) => setDraftNameInput(e.target.value)}
              autoFocus
              placeholder="e.g. Mr Cruz — blue Mio"
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </label>
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setSaveOpen(false)}
              disabled={saveDraft.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSaveDraft}
              disabled={saveDraft.isPending || !draftNameInput.trim()}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              Save
            </button>
          </div>
        </div>
      </Dialog>
```

- Add the "Saved to drafts" confirmation near the existing `checkout.error` banner:

```tsx
        {saveDraft.isSuccess ? (
          <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
            Saved to drafts.
          </p>
        ) : null}
```

- [ ] **Step 3: Typecheck + build + test**

Run: `npm run typecheck && npm run build && npm run test`
Expected: typecheck clean; build succeeds; all tests still green (no behavior change to existing tests).

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/hooks/useDraftMutations.ts web_admin/src/presentation/features/pos/PosPage.tsx
git commit -m "feat(web): save cart as a draft (create/update) from POS"
```

---

### Task 5: Drafts list page (`/drafts`) — resume + delete

**Files:**
- Create: `web_admin/src/presentation/features/drafts/DraftsPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx`

**Interfaces:**
- Consumes: `useDrafts` (Task 2), `useDeleteDraft` (Task 4), `useCartStore` `loadDraft`/`lines` (Task 3), `cartGrandTotal` (`@/domain/sales/cart`), `formatMoney`, `RoutePaths`, common components.
- Produces: `DraftsPage` wired at `RoutePaths.drafts`.

- [ ] **Step 1: Create the drafts list page**

Create `web_admin/src/presentation/features/drafts/DraftsPage.tsx`:

```tsx
import { useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useDrafts } from '@/presentation/hooks/useDrafts';
import { useDeleteDraft } from '@/presentation/hooks/useDraftMutations';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import type { Draft } from '@/domain/entities';

export function DraftsPage() {
  useEffect(() => {
    document.title = 'Drafts · MAKI POS Admin';
  }, []);

  const { data: drafts, isLoading, error } = useDrafts();
  const lines = useCartStore((s) => s.lines);
  const loadDraft = useCartStore((s) => s.loadDraft);
  const deleteDraft = useDeleteDraft();
  const navigate = useNavigate();

  const open = useMemo(() => (drafts ?? []).filter((d) => !d.isConverted), [drafts]);

  const onResume = (draft: Draft) => {
    if (lines.length > 0 && !window.confirm('Replace the current cart with this draft?')) return;
    loadDraft(draft);
    navigate(RoutePaths.pos);
  };
  const onDelete = (draft: Draft) => {
    if (!window.confirm(`Delete draft "${draft.name}"?`)) return;
    deleteDraft.mutate(draft.id);
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Drafts</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Held orders — resume one into the POS or delete it.
        </p>
      </header>

      {error ? (
        <ErrorView title="Could not load drafts" message={error.message} />
      ) : isLoading || !drafts ? (
        <LoadingView label="Loading…" />
      ) : open.length === 0 ? (
        <EmptyState title="No drafts" description="Hold a cart from the POS with “Save as draft”." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {open.map((d) => {
              const count = d.items.reduce((s, i) => s + i.quantity, 0);
              const total = cartGrandTotal(d.items, d.laborLines, d.discountType);
              return (
                <li key={d.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                  <div className="min-w-0">
                    <div className="text-bodySmall font-medium text-light-text">{d.name}</div>
                    <div className="text-[12px] text-light-text-hint">
                      {count} item{count === 1 ? '' : 's'} · {formatMoney(total)}
                      {d.mechanicName ? ` · ${d.mechanicName}` : ''} ·{' '}
                      {d.createdAt.toLocaleDateString()}
                    </div>
                  </div>
                  <div className="flex items-center gap-tk-sm">
                    <button
                      type="button"
                      onClick={() => onResume(d)}
                      className="rounded-md bg-light-text px-tk-md py-[6px] text-[12px] font-semibold text-light-background hover:bg-primary-dark"
                    >
                      Resume
                    </button>
                    <button
                      type="button"
                      onClick={() => onDelete(d)}
                      disabled={deleteDraft.isPending}
                      className="text-light-text-hint hover:text-error"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Wire the route**

In `web_admin/src/presentation/router/routes.tsx`:
- Add import: `import { DraftsPage } from '@/presentation/features/drafts/DraftsPage';`
- Replace `{ path: RoutePaths.drafts, element: placeholder('Drafts', 'phase 10') },` with:

```tsx
        { path: RoutePaths.drafts, element: <DraftsPage /> },
```

(Leave `RoutePaths.draftEdit` as the placeholder — the POS cart is the editor.)

- [ ] **Step 3: Typecheck + build**

Run: `npm run typecheck && npm run build`
Expected: both clean (the page is verified by browser smoke in Task 7).

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/features/drafts/DraftsPage.tsx web_admin/src/presentation/router/routes.tsx
git commit -m "feat(web): /drafts list page — resume + delete"
```

---

## Slice 4c — Convert on checkout

### Task 6: Carry draftId onto the sale + mark converted

**Files:**
- Modify: `web_admin/src/presentation/hooks/buildSaleInput.ts`
- Modify: `web_admin/src/presentation/hooks/buildSaleInput.test.ts`
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx`

**Interfaces:**
- Consumes: `useMarkConverted` (Task 4), the cart store `draftId` (Task 3).
- Produces: `CheckoutInput` gains `draftId: string | null`; `buildSaleInput` writes it; `PosPage.onComplete` passes it and marks the draft converted.

- [ ] **Step 1: Update the buildSaleInput test**

In `web_admin/src/presentation/hooks/buildSaleInput.test.ts`:
- Add `draftId: null,` to the `input(...)` factory defaults (so existing cases still type-check):

```ts
  laborLines: [],
  mechanicId: null,
  mechanicName: null,
  draftId: null,
  ...over,
```

- Add a new test inside `describe('buildSaleInput', …)`:

```ts
  it('carries draftId onto the sale (sale originated from a draft)', () => {
    const s = buildSaleInput(input({ draftId: 'd1' }), actor());
    expect(s.draftId).toBe('d1');
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `npm run test -- buildSaleInput`
Expected: FAIL — `draftId` not on `CheckoutInput` / assertion fails (currently hardcoded `null`).

- [ ] **Step 3: Widen CheckoutInput + write draftId**

In `web_admin/src/presentation/hooks/buildSaleInput.ts`:
- Add to the `CheckoutInput` interface (after `mechanicName: string | null;`):

```ts
  draftId: string | null;
```

- In the returned object, replace `draftId: null,` with:

```ts
    draftId: input.draftId,
```

- [ ] **Step 4: Pass draftId + mark converted in PosPage.onComplete**

In `web_admin/src/presentation/features/pos/PosPage.tsx`:
- Add import: `import { useMarkConverted } from '@/presentation/hooks/useDraftMutations';` (or extend the existing `useDraftMutations` import to include it).
- Add the hook near the others: `const markConverted = useMarkConverted();`
- In `onComplete`, add `draftId` to the `checkout.mutateAsync({...})` argument (after `mechanicName,`):

```tsx
        draftId,
```

- After `setDone(sale.saleNumber);` (on success), before `clear()`, mark the source draft converted (best-effort):

```tsx
      if (draftId) {
        markConverted.mutate({ id: draftId, saleId: sale.id });
      }
```

(The completed sale is never undone if `markConverted` fails — it's a fire-and-forget mutation. `clear()` then resets `draftId`.)

- [ ] **Step 5: Test + typecheck + build**

Run: `npm run test -- buildSaleInput && npm run typecheck && npm run build`
Expected: `buildSaleInput.test.ts` PASS (incl. the new case); typecheck clean; build succeeds.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/hooks/buildSaleInput.ts web_admin/src/presentation/hooks/buildSaleInput.test.ts \
  web_admin/src/presentation/features/pos/PosPage.tsx
git commit -m "feat(web): convert resumed draft on checkout (draftId on sale + markConverted)"
```

---

### Task 7: Verify end-to-end

**Files:** none (verification only).

- [ ] **Step 1: Full typecheck + tests + build**

Run: `npm run typecheck && npm run test && npm run build`
Expected: typecheck clean; all suites green (incl. `draftConverter`, updated `cartStore` / `buildSaleInput`); build succeeds.

- [ ] **Step 2: Browser smoke — save a draft**

`npm run dev`, sign in, `/pos`. Add a product + a labor line + pick a mechanic. Click **Save as draft**, name it → ✅ the cart clears and a "Saved to drafts" confirmation shows.

- [ ] **Step 3: Browser smoke — list + resume + convert**

Go to **/drafts** → ✅ the draft appears with its name, item count, total (incl. labor), mechanic, and date. Click **Resume** → ✅ lands on `/pos` with the cart rehydrated (parts + labor + mechanic intact); the Save button now reads **Update draft**. Add a tender and **Complete** → ✅ the sale completes; return to **/drafts** → ✅ the draft is gone from the open list (marked converted). Open the sale in **Reports → Sale Detail** and confirm it persisted (the `draftId` is on the sale doc).

- [ ] **Step 4: Browser smoke — edge rules**

✅ **Save as draft** is disabled with an empty cart. ✅ Saving with a blank name is blocked (Save button disabled). ✅ **Resume** with a non-empty cart prompts to replace. ✅ **Delete** removes a draft after confirmation.

- [ ] **Step 5: Commit (only if smoke-fix tweaks were needed)**

```bash
git add -A
git commit -m "fix(web): drafts smoke-test fixes"
```

---

## Notes for the implementer

- **Spec:** `docs/superpowers/specs/2026-06-20-web-pos-phase4-drafts-design.md`.
- **Green between tasks:** the data layer (1–2) is additive; the cart store (3) is additive; Save (4) and the list (5) are additive UI; only Task 6 widens `CheckoutInput` and immediately updates its sole caller (PosPage). Each task leaves typecheck + tests green.
- **createdBy rule:** the `drafts` create rule requires `createdBy == auth.uid` — `useSaveDraft` sets `createdBy: actor.id`. Do not change this.
- **No deploy.** Deployment (push + `firebase deploy --only hosting`) is a separate, explicitly-authorized step.
```
