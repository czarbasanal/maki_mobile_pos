# Product Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Custom color-coded tags attachable to products (all three roles), managed under Settings → Lists on both surfaces, shown as chips on inventory rows with a tag filter (including Untagged) and a quick-attach action.

**Architecture:** New `product_tags` Firestore collection (bespoke Mechanics-pattern entity: name + color token + description + isActive + audit) and a `tagIds: string[]` array on product docs. Chips resolve name/color live from the streamed tag list — nothing denormalized. Quick attach writes only `tagIds` + audit fields through a dedicated `updateTags`/`updateProductTags` repo method.

**Tech Stack:** Flutter + Riverpod (root), React + Vite + TypeScript + Vitest (`web_admin/`), Firestore rules tests via `@firebase/rules-unit-testing` (`tools/firestore-rules-test/`).

**Spec:** `docs/superpowers/specs/2026-09-03-product-tags-design.md`

## Global Constraints

- Branch: `feat/product-tags` (already exists, spec committed). Commit per task; never push unless asked.
- Firestore field/collection names must be byte-identical across surfaces: collection `product_tags`, product field `tagIds`.
- Color tokens (exact list, both surfaces): `gray`, `red`, `amber`, `green`, `teal`, `blue`, `purple`, `pink`. Unknown/missing token renders as `gray`.
- The Untagged filter sentinel is the string `__untagged__` on both surfaces (never a possible Firestore doc id).
- Role policy: tag list CRUD = `editLists` (all roles) for add/rename, `manageCategories` (staff/admin) for deactivate/reactivate/delete; attaching tags to products = all three roles.
- Never deploy firestore.rules or hosting inside a task — deployment is the user-confirmed rollout in Task 17.
- Web checks run from `web_admin/`: `npm run typecheck`, `npm run test`, `npm run build`. Mobile: `flutter test`, `flutter analyze` from repo root. Rules: `npm test` from `tools/firestore-rules-test/`.
- Match surrounding idiom: heroicons on web (NOT lucide), Lucide + `AppTextStyles`/`AppColors` on mobile.

---

### Task 1: Firestore rules — `product_tags` collection + product `tagIds` proofs

**Files:**
- Modify: `firestore.rules` (add block after the MECHANICS collection block, ~line 440)
- Test: `tools/firestore-rules-test/test/rules.test.js`

**Interfaces:**
- Produces: rules allowing any active user to read/create/edit `product_tags/{tagId}` (staff/admin only for `isActive` flips and deletes), and the proven fact that a cashier `tagIds`-only product update passes while `tagIds`+`price` fails. No product-rule text changes expected.

- [ ] **Step 1: Write the failing tests**

In `tools/firestore-rules-test/test/rules.test.js`, add `"product_tags"` to the `LISTS` array in the `shared list collections` describe (line ~1055):

```js
  const LISTS = [
    "expense_categories",
    "units",
    "void_reasons",
    "mechanics",
    "shop_fees",
    "product_tags",
  ];
```

Then inside the `describe("/products", ...)` block (after the existing staff/cashier update tests), add:

```js
  it("cashier CAN update tagIds alone (sweep quick-attach)", async () => {
    await assertSucceeds(
      as("cashier").collection("products").doc("p-1").update({
        tagIds: ["t1", "t2"],
      })
    );
  });

  it("cashier CAN update tagIds with audit fields (updateProductTags shape)", async () => {
    await assertSucceeds(
      as("cashier").collection("products").doc("p-1").update({
        tagIds: ["t1"],
        updatedAt: new Date(),
        updatedBy: "cashier-1",
        updatedByName: "Cashier One",
      })
    );
  });

  it("cashier CANNOT smuggle price alongside tagIds", async () => {
    await assertFails(
      as("cashier").collection("products").doc("p-1").update({
        tagIds: ["t1"],
        price: 9999,
      })
    );
  });

  it("staff CAN update tagIds", async () => {
    await assertSucceeds(
      as("staff").collection("products").doc("p-1").update({ tagIds: ["t1"] })
    );
  });
```

- [ ] **Step 2: Run tests to verify the product_tags list tests fail**

Run: `cd tools/firestore-rules-test && npm test`
Expected: the six-ish `product_tags: ...` cases FAIL (no match block yet → all denied, so `cashier can create` etc. fail). The four `/products` tagIds tests should PASS already (the cashier denylist doesn't contain `tagIds`) — that is the spec's "proven, not assumed" claim. If any `/products` tagIds test fails, STOP and re-read the products rules; do not widen them without flagging it.

- [ ] **Step 3: Add the rules block**

In `firestore.rules`, after the MECHANICS collection block (immediately before whatever follows it), insert:

```
    // ==================== PRODUCT TAGS COLLECTION ====================

    match /product_tags/{tagId} {
      // All valid users can read tags (inventory chips, tag filter, pickers)
      allow read: if isValidUser() && isActiveUser();

      // Shared-list grants: any active user may add or edit entries (name,
      // color, description); only staff/admin may flip isActive
      // (deactivate/reactivate); delete is staff/admin. Same template as
      // units / void_reasons / mechanics.
      allow create: if isValidUser() && isActiveUser();
      allow update: if isValidUser() && isActiveUser() &&
        (isStaffOrAdmin() ||
          !request.resource.data.diff(resource.data).affectedKeys()
            .hasAny(['isActive']));
      allow delete: if isStaffOrAdmin() && isActiveUser();
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tools/firestore-rules-test && npm test`
Expected: PASS (entire suite — the shared-list loop now covers `product_tags` too).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(rules): product_tags shared-list collection; prove cashier tagIds-only product writes"
```

Do NOT deploy the rules — that happens in Task 17 with user confirmation.

---

### Task 2: Web — Tag entity, color tokens, converter

**Files:**
- Create: `web_admin/src/domain/entities/Tag.ts`
- Create: `web_admin/src/domain/tags/tagColors.ts`
- Create: `web_admin/src/data/converters/tagConverter.ts`
- Modify: `web_admin/src/domain/entities/index.ts` (add `export * from './Tag';`)
- Test: `web_admin/src/domain/tags/tagColors.test.ts`, `web_admin/src/data/converters/tagConverter.test.ts`

**Interfaces:**
- Produces: `Tag` (id, name, color: TagColor, description: string|null, isActive, createdAt: Date, updatedAt: Date|null, createdBy/updatedBy: string|null); `TAG_COLORS`, `type TagColor`, `normalizeTagColor(v: unknown): TagColor`, `tagChipStyle(color: TagColor): { bg: string; fg: string }`; `tagConverter: FirestoreDataConverter<Tag>`.

- [ ] **Step 1: Write the failing tests**

`web_admin/src/domain/tags/tagColors.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { TAG_COLORS, normalizeTagColor, tagChipStyle } from './tagColors';

describe('tagColors', () => {
  it('exposes the eight canonical tokens', () => {
    expect(TAG_COLORS).toEqual([
      'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
    ]);
  });
  it('normalizes unknown / missing values to gray', () => {
    expect(normalizeTagColor('green')).toBe('green');
    expect(normalizeTagColor('chartreuse')).toBe('gray');
    expect(normalizeTagColor(undefined)).toBe('gray');
    expect(normalizeTagColor(null)).toBe('gray');
    expect(normalizeTagColor(42)).toBe('gray');
  });
  it('every token has a chip style', () => {
    for (const c of TAG_COLORS) {
      const s = tagChipStyle(c);
      expect(s.bg).toMatch(/^#/);
      expect(s.fg).toMatch(/^#/);
    }
  });
});
```

`web_admin/src/data/converters/tagConverter.test.ts` (mirror `mechanicConverter.test.ts`):

```ts
import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { tagConverter } from './tagConverter';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

describe('tagConverter.fromFirestore', () => {
  it('reads name / color / description / isActive / audit', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const updated = Timestamp.fromDate(new Date('2026-09-02T03:04:05Z'));
    const t = tagConverter.fromFirestore(
      snap('t1', {
        name: 'Intact',
        color: 'green',
        description: 'Physical count verified',
        isActive: true,
        createdAt: created,
        updatedAt: updated,
        createdBy: 'u1',
        updatedBy: 'u2',
      }),
    );
    expect(t).toEqual({
      id: 't1',
      name: 'Intact',
      color: 'green',
      description: 'Physical count verified',
      isActive: true,
      createdAt: created.toDate(),
      updatedAt: updated.toDate(),
      createdBy: 'u1',
      updatedBy: 'u2',
    });
  });

  it('defaults name/isActive, normalizes a bad color to gray, nulls description', () => {
    const created = Timestamp.fromDate(new Date('2026-09-01T03:04:05Z'));
    const t = tagConverter.fromFirestore(snap('t2', { createdAt: created, color: 'neon' }));
    expect(t.name).toBe('');
    expect(t.color).toBe('gray');
    expect(t.description).toBeNull();
    expect(t.isActive).toBe(true);
    expect(t.updatedAt).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd web_admin && npx vitest run src/domain/tags/tagColors.test.ts src/data/converters/tagConverter.test.ts`
Expected: FAIL — modules not found.

- [ ] **Step 3: Implement**

`web_admin/src/domain/entities/Tag.ts`:

```ts
import type { TagColor } from '@/domain/tags/tagColors';

// Mirror of lib/domain/entities/tag_entity.dart. Custom product tags in the
// shared `product_tags` collection; attached to products via Product.tagIds.
// Built for the physical-count sweep (spec 2026-09-03) but general-purpose.
export interface Tag {
  id: string;
  name: string;          // display + match key
  color: TagColor;       // named token; each surface maps it to its own tint
  description: string | null; // shown only in the tag editor, never on rows
  isActive: boolean;     // soft-delete; inactive chips disappear, ids stay on products
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
```

`web_admin/src/domain/tags/tagColors.ts` (RELATIVE imports not needed — no imports):

```ts
// The eight tag color tokens, stored verbatim in product_tags.color. Keep in
// lockstep with lib/core/constants/tag_colors.dart — the same token must
// render as the same hue on both surfaces.
export const TAG_COLORS = [
  'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
] as const;

export type TagColor = (typeof TAG_COLORS)[number];

export function normalizeTagColor(v: unknown): TagColor {
  return TAG_COLORS.includes(v as TagColor) ? (v as TagColor) : 'gray';
}

// Muted tint + readable text per token — soft chips, not saturated badges.
const STYLES: Record<TagColor, { bg: string; fg: string }> = {
  gray:   { bg: '#ECEFF1', fg: '#455A64' },
  red:    { bg: '#FDE8E8', fg: '#B03A34' },
  amber:  { bg: '#FBF0DC', fg: '#8A6116' },
  green:  { bg: '#E5F2E5', fg: '#2E7D32' },
  teal:   { bg: '#E0F0EF', fg: '#1F6E66' },
  blue:   { bg: '#E3EDF8', fg: '#2A5D8F' },
  purple: { bg: '#EEE8F7', fg: '#6A4FA3' },
  pink:   { bg: '#F9E7F0', fg: '#A34D77' },
};

export function tagChipStyle(color: TagColor): { bg: string; fg: string } {
  return STYLES[color];
}
```

`web_admin/src/data/converters/tagConverter.ts`:

```ts
import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { Tag } from '@/domain/entities';
import { normalizeTagColor } from '@/domain/tags/tagColors';
import { requireDate, toDate } from './timestamps';

// Reads use this converter; writes go through the repository inline (so they
// can use serverTimestamp). toFirestore is required by the type but unused.
export const tagConverter: FirestoreDataConverter<Tag> = {
  toFirestore(t) {
    return {
      name: t.name,
      color: t.color,
      description: t.description,
      isActive: t.isActive,
      createdBy: t.createdBy,
      updatedBy: t.updatedBy,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): Tag {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      name: d.name ?? '',
      color: normalizeTagColor(d.color),
      description: d.description ?? null,
      isActive: d.isActive ?? true,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
    };
  },
};
```

Add `export * from './Tag';` to `web_admin/src/domain/entities/index.ts`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd web_admin && npx vitest run src/domain/tags/tagColors.test.ts src/data/converters/tagConverter.test.ts && npm run typecheck`
Expected: PASS, typecheck clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/entities/Tag.ts web_admin/src/domain/entities/index.ts web_admin/src/domain/tags/ web_admin/src/data/converters/tagConverter.ts web_admin/src/data/converters/tagConverter.test.ts
git commit -m "feat(web): Tag entity, color tokens, Firestore converter"
```

---

### Task 3: Web — TagRepository + Firestore impl + DI wiring

**Files:**
- Create: `web_admin/src/domain/repositories/TagRepository.ts`
- Create: `web_admin/src/data/repositories/FirestoreTagRepository.ts`
- Modify: `web_admin/src/infrastructure/firebase/collections.ts` (add `productTags: 'product_tags',`)
- Modify: `web_admin/src/infrastructure/di/container.tsx` (import, `tagRepo` on the Container interface, instantiation, `useTagRepo()` hook — mirror every `mechanicRepo` site)
- Test: `web_admin/src/data/repositories/FirestoreTagRepository.test.ts`

**Interfaces:**
- Consumes: `Tag`, `tagConverter` (Task 2).
- Produces: `TagCreateInput { name; color; description?: string | null }`, `TagUpdateInput { name?; color?; description?: string | null; isActive? }`, `TagRepository { watchAll(cb, opts?): Unsubscribe; nameExists(name): Promise<boolean>; create(input, actorId): Promise<Tag>; update(id, input, actorId): Promise<void>; delete(id): Promise<void> }`, `useTagRepo(): TagRepository`.

- [ ] **Step 1: Write the failing test**

`web_admin/src/data/repositories/FirestoreTagRepository.test.ts` (same fake-SDK template as `FirestoreMechanicRepository.test.ts`):

```ts
// No Firestore emulator in the vitest suite — fake the 'firebase/firestore'
// surface (same template as FirestoreMechanicRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

const state = vi.hoisted(() => ({
  deletes: [] as string[],
  adds: [] as Array<{ path: string; data: Record<string, unknown> }>,
}));

function makeRef(path: string): FakeRef {
  const segs = path.split('/');
  const ref: FakeRef = { path, id: segs[segs.length - 1], withConverter: () => ref };
  return ref;
}

vi.mock('firebase/firestore', () => ({
  collection: vi.fn((_db: unknown, ...segs: string[]) => {
    const path = segs.join('/');
    const col = { __col: true, path, withConverter: () => col };
    return col;
  }),
  doc: vi.fn((parent: unknown, ...segs: string[]) => {
    if (segs.length === 0) {
      const col = parent as { path: string };
      return makeRef(`${col.path}/auto1`);
    }
    return makeRef(segs.join('/'));
  }),
  addDoc: vi.fn(async (col: { path: string }, data: Record<string, unknown>) => {
    state.adds.push({ path: col.path, data });
    return makeRef(`${col.path}/new1`);
  }),
  getDoc: vi.fn(async () => ({ data: () => ({ id: 'new1', name: 'Intact' }) })),
  getDocs: vi.fn(),
  limit: vi.fn(),
  query: vi.fn(),
  where: vi.fn(),
  onSnapshot: vi.fn(),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  updateDoc: vi.fn(),
  deleteDoc: vi.fn(async (ref: FakeRef) => {
    state.deletes.push(ref.path);
  }),
}));

const { FirestoreTagRepository } = await import('./FirestoreTagRepository');

describe('FirestoreTagRepository', () => {
  beforeEach(() => {
    state.deletes = [];
    state.adds = [];
  });

  it('create writes into product_tags with color, null description, active + audit', async () => {
    const repo = new FirestoreTagRepository({} as unknown as Firestore);
    await repo.create({ name: 'Intact', color: 'green' }, 'u1');
    expect(state.adds).toHaveLength(1);
    expect(state.adds[0].path).toBe('product_tags');
    expect(state.adds[0].data).toMatchObject({
      name: 'Intact',
      color: 'green',
      description: null,
      isActive: true,
      createdBy: 'u1',
      updatedBy: 'u1',
    });
  });

  it('delete removes the tag doc by id', async () => {
    const repo = new FirestoreTagRepository({} as unknown as Firestore);
    await repo.delete('t1');
    expect(state.deletes).toContain('product_tags/t1');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run src/data/repositories/FirestoreTagRepository.test.ts`
Expected: FAIL — `FirestoreTagRepository` module not found.

- [ ] **Step 3: Implement**

`web_admin/src/domain/repositories/TagRepository.ts`:

```ts
import type { Tag } from '../entities';
import type { TagColor } from '@/domain/tags/tagColors';
import type { Unsubscribe } from './AuthRepository';

export interface TagCreateInput {
  name: string;
  color: TagColor;
  description?: string | null;
}

export interface TagUpdateInput {
  name?: string;
  color?: TagColor;
  // null clears the stored value; undefined leaves it untouched.
  description?: string | null;
  isActive?: boolean;
}

export interface TagRepository {
  watchAll(cb: (tags: Tag[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  /** Exact-name existence check (any active state). */
  nameExists(name: string): Promise<boolean>;
  create(input: TagCreateInput, actorId: string): Promise<Tag>;
  update(id: string, input: TagUpdateInput, actorId: string): Promise<void>;
  /** Hard-deletes the tag doc. Orphaned Product.tagIds entries are tolerated
   *  by every reader (unresolvable ids simply don't render). */
  delete(id: string): Promise<void>;
}
```

`web_admin/src/data/repositories/FirestoreTagRepository.ts` (mirror `FirestoreMechanicRepository.ts` exactly, with these substitutions — the full file):

```ts
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  query,
  where,
  serverTimestamp,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import type {
  TagCreateInput,
  TagRepository,
  TagUpdateInput,
} from '@/domain/repositories/TagRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { Tag } from '@/domain/entities';
import { tagConverter } from '@/data/converters/tagConverter';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';

// `product_tags` is a small collection — read the whole list and filter/sort
// client-side (no composite index), mirroring FirestoreMechanicRepository.
export class FirestoreTagRepository implements TagRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.productTags).withConverter(tagConverter);
  }

  private shape(items: Tag[], includeInactive: boolean): Tag[] {
    const out = includeInactive ? items : items.filter((t) => t.isActive);
    return out.sort((a, b) => a.name.localeCompare(b.name));
  }

  watchAll(cb: (tags: Tag[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe {
    return onSnapshot(this.col(), (snap) => {
      cb(this.shape(snap.docs.map((d) => d.data()), opts?.includeInactive ?? false));
    });
  }

  async nameExists(name: string): Promise<boolean> {
    const snap = await getDocs(
      query(collection(this.db, FirestoreCollections.productTags), where('name', '==', name), limit(1)),
    );
    return !snap.empty;
  }

  async create(input: TagCreateInput, actorId: string): Promise<Tag> {
    const ref = await addDoc(collection(this.db, FirestoreCollections.productTags), {
      name: input.name,
      color: input.color,
      description: input.description ?? null,
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    const snap = await getDoc(ref.withConverter(tagConverter));
    const created = snap.data();
    if (!created) throw new Error('Failed to load the created tag');
    return created;
  }

  async update(id: string, input: TagUpdateInput, actorId: string): Promise<void> {
    const data: Record<string, unknown> = {
      updatedBy: actorId,
      updatedAt: serverTimestamp(),
    };
    if (input.name !== undefined) data.name = input.name;
    if (input.color !== undefined) data.color = input.color;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    if (input.description !== undefined) data.description = input.description;
    await updateDoc(doc(this.db, FirestoreCollections.productTags, id), data);
  }

  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.productTags, id));
  }
}
```

In `collections.ts`, after `motorcycleModels`:

```ts
  // Custom product tags (spec 2026-09-03) — attached via products.tagIds.
  productTags: 'product_tags',
```

In `container.tsx`, mirror every `mechanicRepo` touchpoint (import class + type, `tagRepo: TagRepository;` on the Container interface, `tagRepo: new FirestoreTagRepository(db),` in the build, and:

```tsx
export function useTagRepo(): TagRepository {
  return useContainer().tagRepo;
}
```

using whatever accessor the neighboring `useMechanicRepo` uses).

- [ ] **Step 4: Run tests + typecheck**

Run: `cd web_admin && npx vitest run src/data/repositories/FirestoreTagRepository.test.ts && npm run typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/TagRepository.ts web_admin/src/data/repositories/FirestoreTagRepository.ts web_admin/src/data/repositories/FirestoreTagRepository.test.ts web_admin/src/infrastructure/firebase/collections.ts web_admin/src/infrastructure/di/container.tsx
git commit -m "feat(web): product_tags repository + DI wiring"
```

---

### Task 4: Web — tag hooks + ProductTagsPage + routes + Settings entry

**Files:**
- Create: `web_admin/src/presentation/hooks/useTags.ts`
- Create: `web_admin/src/presentation/hooks/useTagMutations.ts`
- Create: `web_admin/src/presentation/features/settings/ProductTagsPage.tsx`
- Modify: `web_admin/src/presentation/router/routePaths.ts` (add `productTags: '/settings/tags',` next to `mechanics`)
- Modify: `web_admin/src/presentation/router/routeGuards.ts` (add `[RoutePaths.productTags, Permission.editLists],` next to the mechanics entry)
- Modify: `web_admin/src/presentation/router/routes.tsx` (import + route with handle title/subtitle, next to the mechanics route)
- Modify: `web_admin/src/presentation/features/settings/SettingsPage.tsx` (new Row under the Mechanics row, gated `can(Permission.editLists)`)
- Test: `web_admin/src/presentation/features/settings/ProductTagsPage.test.tsx`

**Interfaces:**
- Consumes: `useTagRepo`, `TagRepository` (Task 3), `Tag`, `TAG_COLORS`, `tagChipStyle` (Task 2).
- Produces: `useTags(opts?)` / `useActiveTags()` (live lists), `useCreateTag()` / `useUpdateTag()` / `useDeleteTag()` mutations. Route `/settings/tags`.

- [ ] **Step 1: Write the failing page test**

`ProductTagsPage.test.tsx` (harness in the `InventoryListPage.test.tsx` style — DiProvider override + QueryClientProvider + MemoryRouter):

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductTagsPage } from './ProductTagsPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Tag } from '@/domain/entities';

const tag = (o: Partial<Tag> = {}): Tag => ({
  id: 't1', name: 'Intact', color: 'green', description: 'Count verified',
  isActive: true, createdAt: new Date('2026-09-01'), updatedAt: null,
  createdBy: null, updatedBy: null, ...o,
});

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
  });
}

function harness(tags: Tag[] = [tag()], repoOver: Partial<Container['tagRepo']> = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const tagRepo: Partial<Container['tagRepo']> = {
    watchAll: (cb: (tags: Tag[]) => void) => { cb(tags); return () => {}; },
    create: vi.fn().mockResolvedValue(tag({ id: 'new1' })),
    update: vi.fn().mockResolvedValue(undefined),
    delete: vi.fn().mockResolvedValue(undefined),
    ...repoOver,
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider override={{ tagRepo: tagRepo as Container['tagRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/settings/tags']}>
          <ProductTagsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return tagRepo;
}

describe('ProductTagsPage', () => {
  it('lists tags with their description', () => {
    signIn(UserRole.admin);
    harness();
    expect(screen.getByText('Intact')).toBeInTheDocument();
    expect(screen.getByText('Count verified')).toBeInTheDocument();
  });

  it('creates a tag with the selected color', async () => {
    signIn(UserRole.cashier); // editLists holders can add
    const repo = harness([]);
    await userEvent.click(screen.getByRole('button', { name: /add/i }));
    await userEvent.type(screen.getByLabelText('Name'), 'Intact');
    await userEvent.click(screen.getByRole('radio', { name: 'green' }));
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(repo.create).toHaveBeenCalledWith(
      { name: 'Intact', color: 'green', description: null },
      'u1',
    );
  });

  it('cashier sees no Deactivate or Delete controls', () => {
    signIn(UserRole.cashier);
    harness([tag(), tag({ id: 't2', name: 'Old', isActive: false })]);
    expect(screen.queryByRole('button', { name: /deactivate/i })).toBeNull();
    expect(screen.queryByRole('button', { name: /delete/i })).toBeNull();
  });

  it('staff can deactivate and can delete an inactive tag', () => {
    signIn(UserRole.staff);
    harness([tag(), tag({ id: 't2', name: 'Old', isActive: false })]);
    expect(screen.getByRole('button', { name: /deactivate/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run src/presentation/features/settings/ProductTagsPage.test.tsx`
Expected: FAIL — page module not found.

- [ ] **Step 3: Implement hooks**

`useTags.ts` (mirror `useMechanics.ts`):

```ts
import { useTagRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Tag } from '@/domain/entities';

/** Live tag list. Pass includeInactive for the management screen. */
export function useTags(opts?: { includeInactive?: boolean }) {
  const repo = useTagRepo();
  const includeInactive = opts?.includeInactive ?? false;
  return useFirestoreSubscription<Tag[]>(
    (onData) => repo.watchAll(onData, { includeInactive }),
    [repo, includeInactive],
    `product_tags:${includeInactive ? 'all' : 'active'}`,
  );
}

/** Active, name-sorted tags — the chip/filter/picker source. */
export function useActiveTags() {
  return useTags({ includeInactive: false });
}
```

`useTagMutations.ts` (mirror `useMechanicMutations.ts` with `entityType: 'tag'`, actions `Added tag: X` / `Updated tag…` (details `Reactivated`/`Deactivated` on isActive change) / `Deleted tag: X`, inputs `{ name; color; description?: string | null }` for create and `{ id; name?; color?; description?; isActive? }` for update, `{ id; name? }` for delete — same structure, `useTagRepo()` instead of `useMechanicRepo()`).

- [ ] **Step 4: Implement the page**

`ProductTagsPage.tsx` — copy `MechanicsPage.tsx` wholesale and adapt (keep every class string and Dialog/list scaffold identical). The deltas:

- State: `name`, `color: TagColor` (default `'gray'`), `description`, `active`; document title `'Product tags · MAKI POS Admin'`.
- List row: a color swatch dot before the name (`<span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: tagChipStyle(t.color).fg }} />` inside a flex row), name styled exactly like the mechanic name (strike-through + `(inactive)` when inactive), and the description as the secondary line where mechanics show contact/address.
- Dialog fields: Name input (same as mechanics), then a color picker rendered as a radiogroup so the test can target it:

```tsx
<div>
  <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">Color</label>
  <div role="radiogroup" className="flex flex-wrap gap-tk-sm">
    {TAG_COLORS.map((c) => (
      <button
        key={c}
        type="button"
        role="radio"
        aria-checked={color === c}
        aria-label={c}
        onClick={() => setColor(c)}
        className={cn(
          'h-7 w-7 rounded-full border-2',
          color === c ? 'border-light-text' : 'border-transparent',
        )}
        style={{ background: tagChipStyle(c).bg }}
      >
        <span className="mx-auto block h-3 w-3 rounded-full" style={{ background: tagChipStyle(c).fg }} />
      </button>
    ))}
  </div>
</div>
```

- then a Description textarea (rows=2, optional — blank collapses to null like the mechanic address), and the Active checkbox for `canManage` in edit mode.
- `onSave`: `create.mutateAsync({ name: trimmed, color, description: desc })` / `update.mutateAsync({ id, name: trimmed, color, description: desc, isActive: active })` where `const desc = description.trim() || null`.
- Delete confirm dialog copy: `"NAME" will be permanently deleted. Products keep the tag id but the chip disappears everywhere. Use Deactivate instead to just hide it.`
- Permissions identical to MechanicsPage: `canManage = hasPermission(user.role, Permission.manageCategories)`; Delete only offered on an inactive row.

- [ ] **Step 5: Wire routes + settings row**

- `routePaths.ts`: `productTags: '/settings/tags',` after `mechanics`.
- `routeGuards.ts`: `[RoutePaths.productTags, Permission.editLists],` after the mechanics line (keep the neighboring comment style).
- `routes.tsx`: import `ProductTagsPage`, add after the mechanics route:

```tsx
{
  path: RoutePaths.productTags,
  element: <ProductTagsPage />,
  handle: {
    title: 'Product tags',
    subtitle: 'Color-coded markers shown on inventory rows.',
  },
},
```

(match the exact `handle` shape the mechanics route uses at routes.tsx:368-372).
- `SettingsPage.tsx`: after the Mechanics row, inside the same `can(Permission.editLists)` pattern:

```tsx
{can(Permission.editLists) ? (
  <Row
    to={RoutePaths.productTags}
    icon={TagIcon}
    title="Product tags"
    subtitle="Color-coded markers shown on inventory"
  />
) : null}
```

with `TagIcon` imported from `@heroicons/react/24/outline` and any `tone` prop copied from the Mechanics row.

- [ ] **Step 6: Run tests + typecheck**

Run: `cd web_admin && npx vitest run src/presentation/features/settings/ProductTagsPage.test.tsx && npm run typecheck`
Expected: PASS. If the create-flow test can't find `Save`, match the button label used in MechanicsPage (`Save`).

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/presentation/hooks/useTags.ts web_admin/src/presentation/hooks/useTagMutations.ts web_admin/src/presentation/features/settings/ProductTagsPage.tsx web_admin/src/presentation/features/settings/ProductTagsPage.test.tsx web_admin/src/presentation/router/ web_admin/src/presentation/features/settings/SettingsPage.tsx
git commit -m "feat(web): Product Tags settings page at /settings/tags"
```

---

### Task 5: Web — `Product.tagIds` through entity/converter/writes + `updateTags` + hook

**Files:**
- Modify: `web_admin/src/domain/entities/Product.ts` (add `tagIds: string[];` after `notes`)
- Modify: `web_admin/src/data/converters/productConverter.ts` (read + write `tagIds`)
- Modify: `web_admin/src/data/products/productWrites.ts` (`buildProductWrites`: `tagIds: input.tagIds ?? [],`; `buildProductUpdate`: add `'tagIds'` to `valueFields`)
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts` (add `updateTags`)
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts` (implement `updateTags`)
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts` (add `useUpdateProductTags`)
- Test: `web_admin/src/data/converters/productConverter.test.ts`, `web_admin/src/data/products/productWrites.test.ts`, `web_admin/src/data/repositories/FirestoreProductRepository.test.ts` (extend each), plus fixture updates across existing tests

**Interfaces:**
- Produces: `Product.tagIds: string[]` (missing doc field → `[]`); `ProductRepository.updateTags(id: string, tagIds: string[], actorId: string, actorName: string | null): Promise<void>` writing ONLY `tagIds` + `updatedAt` + `updatedBy` (+ `updatedByName` when non-null); `useUpdateProductTags()` mutation taking `{ id: string; name: string; tagIds: string[] }`.

- [ ] **Step 1: Write the failing tests**

In `productConverter.test.ts` add (matching that file's existing snapshot-fake style):

```ts
it('reads tagIds and defaults a missing field to []', () => {
  // build a doc WITHOUT tagIds → expect []
  // build a doc with tagIds: ['t1', 't2'] → expect ['t1', 't2']
  // build a doc with tagIds: ['t1', 7, null] → expect ['t1'] (non-strings dropped)
});
```

Write these as three real cases using the same `snap()`/fixture helper the file already uses; assert `toFirestore` output includes `tagIds` verbatim.

In `productWrites.test.ts` add:

```ts
it('buildProductWrites defaults tagIds to []', () => {
  // existing minimal ProductCreateInput fixture in this file, without tagIds
  // → productData.tagIds toEqual([])
});
it('buildProductUpdate passes tagIds through when supplied', () => {
  // buildProductUpdate({ tagIds: ['t1'] }, 'u1') → data.tagIds toEqual(['t1'])
  // buildProductUpdate({}, 'u1') → 'tagIds' not a key of data
});
```

(again: real assertions against the helpers already in that file).

In `FirestoreProductRepository.test.ts` add a case that calls `repo.updateTags('p1', ['t1'], 'u1', 'Tester')` and asserts the `updateDoc` payload keys are exactly `['tagIds', 'updatedAt', 'updatedBy', 'updatedByName']` — reuse that file's existing `updateDoc` capture state.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd web_admin && npx vitest run src/data/converters/productConverter.test.ts src/data/products/productWrites.test.ts src/data/repositories/FirestoreProductRepository.test.ts`
Expected: new cases FAIL (field/method missing).

- [ ] **Step 3: Implement**

- `Product.ts`: after `notes: string | null;` add:

```ts
  /** Custom tag ids (product_tags docs). Missing on old docs → []. Orphaned
   *  ids (deleted tags) are tolerated — unresolvable ids never render. */
  tagIds: string[];
```

- `productConverter.ts`: in `toFirestore` add `tagIds: product.tagIds,`; in `fromFirestore` add:

```ts
tagIds: Array.isArray(d.tagIds)
  ? d.tagIds.filter((t: unknown): t is string => typeof t === 'string')
  : [],
```

- `productWrites.ts`: in `buildProductWrites` productData add `tagIds: input.tagIds ?? [],` (near `barcodes`); in `buildProductUpdate` add `'tagIds'` to the `valueFields` array.
- `ProductRepository.ts`: after `update(...)`:

```ts
  /** Writes ONLY tagIds + audit fields — the narrow write every role's rules
   *  branch permits (cashier included). Used by quick-attach on both list
   *  surfaces so a tag toggle can never clobber a concurrent field edit. */
  updateTags(id: string, tagIds: string[], actorId: string, actorName: string | null): Promise<void>;
```

- `FirestoreProductRepository.ts`:

```ts
  async updateTags(
    id: string,
    tagIds: string[],
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.products, id), {
      tagIds,
      updatedAt: serverTimestamp(),
      updatedBy: actorId,
      ...(actorName !== null ? { updatedByName: actorName } : {}),
    });
  }
```

- `useProductMutations.ts`:

```ts
export function useUpdateProductTags() {
  const repo = useProductRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; name: string; tagIds: string[] }>({
    mutationFn: async ({ id, name, tagIds }) => {
      if (!actor) throw new Error('Not signed in');
      await repo.updateTags(id, tagIds, actor.id, actor.displayName.trim() || null);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.inventory,
        action: `Updated tags: ${name}`,
        entityId: id,
        entityType: 'product',
      }));
    },
  });
}
```

- [ ] **Step 4: Fix fixture fallout, run the whole web suite**

Run: `cd web_admin && npm run typecheck`
Expected: errors in test fixtures that build full `Product` literals (`ProductModal.modes.test.tsx` `product()`, `filterProducts.test.ts` `p()`, `productConverter.test.ts`, `posSearch`/`stockTotals`-style fixtures, etc.). Add `tagIds: []` to each. Then:

Run: `cd web_admin && npm run test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A web_admin/src
git commit -m "feat(web): products carry tagIds; narrow updateTags write + mutation hook"
```

---

### Task 6: Web — `filterProducts` tag axis

**Files:**
- Modify: `web_admin/src/domain/products/filterProducts.ts`
- Test: `web_admin/src/domain/products/filterProducts.test.ts`

**Interfaces:**
- Produces: `export const UNTAGGED = '__untagged__';`; `ProductFilter` gains optional `tag?: string | 'all'` (a tag id or `UNTAGGED`; `undefined`/`'all'` disables the axis) and `activeTagIds?: readonly string[]` (needed only for `UNTAGGED`).

- [ ] **Step 1: Write the failing tests**

Append to `filterProducts.test.ts` (extend the `p()` helper's fixture products with `tagIds` overrides):

```ts
import { UNTAGGED } from './filterProducts';

describe('tag axis', () => {
  const tagged = p({ id: 'a', name: 'Tagged', tagIds: ['t1'] });
  const other = p({ id: 'b', name: 'Other', tagIds: ['t2'] });
  const bare = p({ id: 'c', name: 'Bare', tagIds: [] });
  const orphan = p({ id: 'd', name: 'Orphan', tagIds: ['deleted-tag'] });
  const list = [tagged, other, bare, orphan];
  const ACTIVE = ['t1', 't2'];

  it('is disabled by default (undefined) and by "all"', () => {
    expect(filterProducts(list, ALL).map((x) => x.id)).toEqual(['a', 'b', 'c', 'd']);
    expect(filterProducts(list, { ...ALL, tag: 'all' }).map((x) => x.id)).toEqual(['a', 'b', 'c', 'd']);
  });
  it('matches a specific tag id', () => {
    expect(filterProducts(list, { ...ALL, tag: 't1' }).map((x) => x.id)).toEqual(['a']);
  });
  it('UNTAGGED means no ACTIVE tag — orphaned ids count as untagged', () => {
    expect(
      filterProducts(list, { ...ALL, tag: UNTAGGED, activeTagIds: ACTIVE }).map((x) => x.id),
    ).toEqual(['c', 'd']);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd web_admin && npx vitest run src/domain/products/filterProducts.test.ts`
Expected: new describe FAILs (`UNTAGGED` not exported).

- [ ] **Step 3: Implement**

In `filterProducts.ts`:

```ts
/** Tag-filter sentinel: products with no ACTIVE tag (spec: orphaned ids from
 *  deleted tags count as untagged — they never render as chips either). */
export const UNTAGGED = '__untagged__';
```

Extend `ProductFilter`:

```ts
  /** A product_tags id, UNTAGGED, or 'all'. Optional so existing callers are
   *  untouched — undefined disables the axis. */
  tag?: string | 'all';
  /** Active tag ids; consulted only for UNTAGGED. */
  activeTagIds?: readonly string[];
```

Add to the predicate (after the category check):

```ts
    const tag = f.tag ?? 'all';
    if (tag !== 'all') {
      if (tag === UNTAGGED) {
        const active = new Set(f.activeTagIds ?? []);
        if (p.tagIds.some((id) => active.has(id))) return false;
      } else if (!p.tagIds.includes(tag)) {
        return false;
      }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd web_admin && npx vitest run src/domain/products/filterProducts.test.ts && npm run typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/filterProducts.ts web_admin/src/domain/products/filterProducts.test.ts
git commit -m "feat(web): tag filter axis with an Untagged sentinel"
```

---

### Task 7: Web — inventory Tags column, quick attach, tag filter, CSV

**Files:**
- Create: `web_admin/src/presentation/features/inventory/TagChips.tsx`
- Create: `web_admin/src/presentation/features/inventory/TagQuickAttach.tsx`
- Modify: `web_admin/src/presentation/features/inventory/InventoryListPage.tsx`
- Test: `web_admin/src/presentation/features/inventory/InventoryListPage.test.tsx` (extend), `web_admin/src/presentation/features/inventory/TagQuickAttach.test.tsx`

**Interfaces:**
- Consumes: `useActiveTags` (Task 4), `useUpdateProductTags` (Task 5), `UNTAGGED` (Task 6), `tagChipStyle` (Task 2).
- Produces: `TagChips({ tagIds, tags, max? })` (renders resolved chips, first `max` (default 2) + `+n` overflow, nothing when none resolve); `TagQuickAttachButton({ product, tags })` (tag-icon button opening a toggle Dialog; each toggle immediately calls `useUpdateProductTags`).

- [ ] **Step 1: Write the failing tests**

`TagQuickAttach.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { TagQuickAttachButton } from './TagQuickAttach';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Product, Tag } from '@/domain/entities';

const tags: Tag[] = [
  { id: 't1', name: 'Intact', color: 'green', description: null, isActive: true,
    createdAt: new Date('2026-09-01'), updatedAt: null, createdBy: null, updatedBy: null },
  { id: 't2', name: 'Recheck', color: 'amber', description: null, isActive: true,
    createdAt: new Date('2026-09-01'), updatedAt: null, createdBy: null, updatedBy: null },
];

const product = { id: 'p1', name: 'Brake shoe', tagIds: ['t2'] } as Product;

function harness() {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.cashier, isActive: true } as never,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    updateTags: vi.fn().mockResolvedValue(undefined),
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider override={{ productRepo: productRepo as Container['productRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <TagQuickAttachButton product={product} tags={tags} />
      </QueryClientProvider>
    </DiProvider>,
  );
  return productRepo;
}

describe('TagQuickAttachButton', () => {
  it('toggling tags writes the composed array each tap (add, then remove)', async () => {
    const repo = harness();
    await userEvent.click(screen.getByRole('button', { name: /edit tags/i }));
    // Add t1: component composes from its LOCAL state (seeded from
    // product.tagIds, updated per toggle) so successive toggles stack.
    await userEvent.click(screen.getByRole('checkbox', { name: 'Intact' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t2', 't1'], 'u1', 'Tester');
    // Remove t2: the earlier t1 addition must survive.
    await userEvent.click(screen.getByRole('checkbox', { name: 'Recheck' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t1'], 'u1', 'Tester');
  });
});
```

In `InventoryListPage.test.tsx`: add a `tagRepo` override to the harness (`watchAll: (cb) => { cb(TAGS); return () => {}; }` with one green `Intact` tag) and two cases:

```tsx
it('shows tag chips on rows and a Tag filter with Untagged', ...)
  // widget() fixture gains tagIds: ['t1'] → expect screen.getByText('Intact');
  // open the Tag SelectFilter → choose 'Untagged' → only the untagged row remains.
```

(follow the file's existing SelectFilter-interaction idiom from the Category filter tests; if none exists, assert via the rendered row names after firing the select's onChange.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd web_admin && npx vitest run src/presentation/features/inventory/TagQuickAttach.test.tsx src/presentation/features/inventory/InventoryListPage.test.tsx`
Expected: FAIL — components/column don't exist.

- [ ] **Step 3: Implement TagChips**

```tsx
import type { Tag } from '@/domain/entities';
import { tagChipStyle } from '@/domain/tags/tagColors';

/** Resolved tag chips for one product row: first `max` + a "+n" overflow.
 *  Unresolvable ids (deleted tags) and inactive tags simply don't render —
 *  callers pass the ACTIVE tag list. */
export function TagChips({ tagIds, tags, max = 2 }: { tagIds: string[]; tags: Tag[]; max?: number }) {
  const byId = new Map(tags.map((t) => [t.id, t]));
  const resolved = tagIds.map((id) => byId.get(id)).filter((t): t is Tag => !!t);
  if (resolved.length === 0) return null;
  const shown = resolved.slice(0, max);
  const extra = resolved.length - shown.length;
  return (
    <span className="flex flex-wrap items-center gap-1">
      {shown.map((t) => {
        const s = tagChipStyle(t.color);
        return (
          <span
            key={t.id}
            className="whitespace-nowrap rounded-[6px] px-2 py-[3px] text-[11px] font-medium"
            style={{ background: s.bg, color: s.fg }}
          >
            {t.name}
          </span>
        );
      })}
      {extra > 0 ? (
        <span className="whitespace-nowrap rounded-[6px] bg-surface-3 px-1.5 py-[3px] text-[11px] font-medium text-ink-2">
          +{extra}
        </span>
      ) : null}
    </span>
  );
}
```

- [ ] **Step 4: Implement TagQuickAttachButton**

`TagQuickAttach.tsx`: a `TagIcon` (heroicons outline) icon button labeled `aria-label="Edit tags"`, `onClick={(e) => { e.stopPropagation(); setOpen(true); }}`. Renders the shared `Dialog` (`title={product.name}`, small) containing one labeled checkbox row per active tag (color dot via `tagChipStyle(t.color).fg`, name as the label). Local state `const [ids, setIds] = useState(product.tagIds)`; each toggle computes `next` (append id, or filter it out), calls `setIds(next)` and `mutate({ id: product.id, name: product.name, tagIds: next })` via `useUpdateProductTags()`. Show a "No tags yet — create tags in Settings → Product tags." empty line when `tags` is empty. Keep the styling vocabulary of the inventory page (`text-ink-2`, `rounded-[6px]`, etc.).

- [ ] **Step 5: Wire the page**

In `InventoryListPage.tsx`:

1. `const { data: activeTags } = useActiveTags();` and `const tagList = activeTags ?? [];`
2. New state `const [tag, setTag] = useState<string | 'all'>('all');` — include `tag` + `activeTagIds: tagList.map((t) => t.id)` in the `scoped` filter call, add `tag` to `isFiltered`, `clearFilters`, and the page-reset `useEffect` deps.
3. Columns: insert after `category`:

```tsx
{
  key: 'tags', header: 'Tags',
  render: (p) => (
    <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
      <TagChips tagIds={p.tagIds} tags={tagList} />
      <TagQuickAttachButton product={p} tags={tagList} />
    </div>
  ),
},
```

4. Filter band, after the Category `SelectFilter`:

```tsx
<SelectFilter
  label="Tag"
  value={tag === 'all' ? '' : tag}
  options={[
    { value: UNTAGGED, label: 'Untagged' },
    ...tagList.map((t) => ({ value: t.id, label: t.name })),
  ]}
  onChange={(v) => {
    setTag(v || 'all');
    setPage(1);
  }}
  allLabel="All tags"
  allTriggerLabel="All"
/>
```

5. CSV: header `'Tags'` after `'Category'`; row value `p.tagIds.map((id) => tagNameById.get(id)).filter(Boolean).join('; ')` with `tagNameById` a memoized `Map` from `tagList`.
6. If the selected tag disappears from `tagList` (deleted/deactivated), reset to `'all'` — same pattern as the existing category-option reset effect.

- [ ] **Step 6: Run tests + typecheck**

Run: `cd web_admin && npx vitest run src/presentation/features/inventory/ && npm run typecheck`
Expected: PASS (including all pre-existing inventory tests — the new column must not break the money-card or filter tests).

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/presentation/features/inventory/
git commit -m "feat(web): inventory tag chips, quick attach, tag filter with Untagged, CSV column"
```

---

### Task 8: Web — ProductModal Tags field + web suite green

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/ProductModal.tsx`
- Test: `web_admin/src/presentation/features/inventory/ProductModal.tags.test.tsx` (new), plus `tagRepo` harness overrides in the five existing `ProductModal.*.test.tsx` files

**Interfaces:**
- Consumes: `useActiveTags`, `tagChipStyle`, `Product.tagIds`.
- Produces: a Tags chip-toggle field under Notes; `tagIds` included in the create payload and update patch; read-only for the cashier name-only tier.

- [ ] **Step 1: Write the failing test**

`ProductModal.tags.test.tsx` — copy the harness function verbatim from `ProductModal.modes.test.tsx` (signIn/product/harness), add a `tagRepo` override to it:

```tsx
const tagRepo: Partial<Container['tagRepo']> = {
  watchAll: (cb) => {
    cb([
      { id: 't1', name: 'Intact', color: 'green', description: null, isActive: true,
        createdAt: new Date('2026-09-01'), updatedAt: null, createdBy: null, updatedBy: null },
    ]);
    return () => {};
  },
};
```

and pass it in the `DiProvider` override. Tests:

```tsx
describe('ProductModal — tags field', () => {
  it('edit mode: toggling a tag chip puts tagIds in the update patch', async () => {
    signIn(UserRole.admin);
    const repo = harness('/inventory/p9/edit', product({ tagIds: [] }), {
      update: vi.fn().mockResolvedValue(undefined),
    });
    await screen.findByDisplayValue('Brake shoe (Yamaha)');
    await userEvent.click(screen.getByRole('button', { name: 'Intact' }));
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));
    await waitFor(() => expect(repo.update).toHaveBeenCalled());
    const patch = (repo.update as ReturnType<typeof vi.fn>).mock.calls[0][1];
    expect(patch.tagIds).toEqual(['t1']);
  });

  it('cashier name-only mode: tags are shown but not toggleable', async () => {
    signIn(UserRole.cashier);
    harness('/inventory/p9/edit', product({ tagIds: ['t1'] }));
    await screen.findByDisplayValue('Brake shoe (Yamaha)');
    expect(screen.getByText('Intact')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Intact' })).toBeNull();
  });
});
```

(If the Save button label differs, copy the exact label the modes test uses.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd web_admin && npx vitest run src/presentation/features/inventory/ProductModal.tags.test.tsx`
Expected: FAIL — no tags field.

- [ ] **Step 3: Implement**

In `ProductModal.tsx`:

1. Schema: add `tagIds: z.array(z.string()).optional(),` to the zod `schema`.
2. Defaults: `tagIds: [],` in `defaultValues`; in the edit-mode `reset(...)` seed add `tagIds: target.tagIds,`.
3. Data: `const { data: activeTags } = useActiveTags();`
4. JSX — directly under the Notes `<Field>`:

```tsx
{(activeTags ?? []).length > 0 || (watch('tagIds') ?? []).length > 0 ? (
  <Field group={!nameOnly} label="Tags">
    <div className="flex flex-wrap gap-1.5">
      {(activeTags ?? []).map((t) => {
        const selected = (watch('tagIds') ?? []).includes(t.id);
        const s = tagChipStyle(t.color);
        if (nameOnly) {
          return selected ? (
            <span key={t.id} className="rounded-[6px] px-2 py-[3px] text-[11px] font-medium"
              style={{ background: s.bg, color: s.fg }}>{t.name}</span>
          ) : null;
        }
        return (
          <button
            key={t.id}
            type="button"
            onClick={() => {
              const cur = watch('tagIds') ?? [];
              const next = selected ? cur.filter((id) => id !== t.id) : [...cur, t.id];
              setValue('tagIds', next, { shouldDirty: true });
            }}
            className={cn(
              'rounded-[6px] border px-2 py-[3px] text-[11px] font-medium',
              selected ? 'border-transparent' : 'border-line bg-surface text-ink-3',
            )}
            style={selected ? { background: s.bg, color: s.fg } : undefined}
          >
            {t.name}
          </button>
        );
      })}
    </div>
  </Field>
) : null}
```

5. Payloads: add `tagIds: values.tagIds ?? [],` to BOTH the create input object (near `notes: blank(values.notes)`) and the update patch object. The cashier rebase in `useUpdateProduct` builds an explicit field list that does NOT include `tagIds`, so a cashier form save leaves tags untouched — do not add it there.

- [ ] **Step 4: Update existing ProductModal test harnesses**

Each of `ProductModal.test.tsx`, `.modes`, `.adjustStock`, `.variation`, `.staffCost`, `.cashierNameOnly` now mounts a component that subscribes to `tagRepo.watchAll`. Add to each harness's DiProvider override:

```tsx
tagRepo: { watchAll: (cb: (t: never[]) => void) => { cb([]); return () => {}; } } as unknown as Container['tagRepo'],
```

- [ ] **Step 5: Run the full web suite**

Run: `cd web_admin && npm run typecheck && npm run test && npm run build`
Expected: all PASS, build clean. Fix any straggler fixture/harness fallout before committing.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/features/inventory/
git commit -m "feat(web): tags chip field in the product modal"
```

---

### Task 9: Mobile — TagEntity + TagModel + TagColors

**Files:**
- Create: `lib/domain/entities/tag_entity.dart`
- Create: `lib/data/models/tag_model.dart`
- Create: `lib/core/constants/tag_colors.dart`
- Modify: `lib/domain/entities/entities.dart` (add `export 'tag_entity.dart';`)
- Modify: `lib/data/models/models.dart` (add `export 'tag_model.dart';`)
- Test: `test/data/models/tag_model_test.dart`, `test/core/constants/tag_colors_test.dart`

**Interfaces:**
- Produces: `TagEntity { id, name, color (String token), description (String?), isActive, createdAt, updatedAt?, createdBy?, updatedBy? }` with `copyWith(..., bool clearDescription = false)` and `TagEntity.empty()`; `TagModel` with `fromFirestore/fromMap/toMap/toCreateMap/toUpdateMap/toEntity/fromEntity/copyWith`; `TagColors.tokens` (the 8 tokens), `TagColors.normalize(String?)`, `TagColors.styleFor(String token, bool isDark)` returning `TagChipStyle { Color bg; Color fg; }`.

- [ ] **Step 1: Write the failing tests**

`test/data/models/tag_model_test.dart` (mirror `mechanic_model_test.dart`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';

void main() {
  group('TagModel', () {
    test('fromMap reads fields and defaults', () {
      final model = TagModel.fromMap(
        {
          'name': 'Intact',
          'color': 'green',
          'description': 'Physical count verified',
          'isActive': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
          'createdBy': 'admin-1',
        },
        'tag-1',
      );
      expect(model.id, 'tag-1');
      expect(model.name, 'Intact');
      expect(model.color, 'green');
      expect(model.description, 'Physical count verified');
      expect(model.isActive, false);
      expect(model.createdAt, DateTime(2026, 9, 1));
      expect(model.updatedAt, isNull);
    });

    test('fromMap defaults missing name/color/isActive for legacy docs', () {
      final model = TagModel.fromMap(<String, dynamic>{}, 'tag-x');
      expect(model.name, '');
      expect(model.color, 'gray');
      expect(model.description, isNull);
      expect(model.isActive, true);
    });

    test('toMap emits name + color + description + isActive', () {
      final model = TagModel(
        id: 'tag-1',
        name: 'Intact',
        color: 'green',
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'admin-1',
      );
      final map = model.toMap();
      expect(map['name'], 'Intact');
      expect(map['color'], 'green');
      expect(map.containsKey('description'), isTrue);
      expect(map['description'], isNull);
      expect(map['isActive'], true);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('toCreateMap stamps server timestamps + createdBy', () {
      final model = TagModel(
        id: '',
        name: 'Intact',
        color: 'blue',
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
      );
      final map = model.toCreateMap('admin-9');
      expect(map['createdBy'], 'admin-9');
      expect(map['updatedBy'], 'admin-9');
      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });
}
```

`test/core/constants/tag_colors_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/tag_colors.dart';

void main() {
  test('eight canonical tokens, in lockstep with the web list', () {
    expect(TagColors.tokens, [
      'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
    ]);
  });

  test('normalize falls back to gray', () {
    expect(TagColors.normalize('green'), 'green');
    expect(TagColors.normalize('neon'), 'gray');
    expect(TagColors.normalize(null), 'gray');
  });

  test('styleFor resolves every token in both brightnesses', () {
    for (final token in TagColors.tokens) {
      expect(TagColors.styleFor(token, false).bg, isNotNull);
      expect(TagColors.styleFor(token, true).fg, isNotNull);
    }
    // Unknown token renders as gray, never throws.
    expect(TagColors.styleFor('neon', false).bg, TagColors.styleFor('gray', false).bg);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/models/tag_model_test.dart test/core/constants/tag_colors_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Implement**

`lib/domain/entities/tag_entity.dart` — copy `mechanic_entity.dart` structurally:

```dart
import 'package:equatable/equatable.dart';

/// Domain entity for a custom product tag (spec 2026-09-03).
///
/// Tags are attached to products via [ProductEntity.tagIds] and rendered as
/// colored chips on inventory rows. Built for the physical-count sweep
/// ("Intact" markers) but general-purpose. Inactive tags stop rendering but
/// their ids stay on products, so reactivation restores the chips.
class TagEntity extends Equatable {
  final String id;

  /// Tag name (display + match key).
  final String name;

  /// Named color token — one of [TagColors.tokens]; unknown renders as gray.
  final String color;

  /// Optional description, shown only in the tag editor.
  final String? description;

  /// Soft-delete flag.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const TagEntity({
    required this.id,
    required this.name,
    required this.color,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  TagEntity copyWith({
    String? id,
    String? name,
    String? color,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool clearDescription = false,
  }) {
    return TagEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: clearDescription ? null : (description ?? this.description),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory TagEntity.empty() {
    return TagEntity(
      id: '',
      name: '',
      color: 'gray',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, color, description, isActive, createdAt, updatedAt, createdBy, updatedBy];
}
```

`lib/data/models/tag_model.dart` — copy `mechanic_model.dart` structurally, replacing address/contactNumber with color/description. Key serialization lines:

```dart
  factory TagModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TagModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      color: TagColors.normalize(map['color'] as String?),
      description: map['description'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }
```

with the base `toMap` writing `{'name': name, 'color': color, 'description': description, 'isActive': isActive}` plus the same forCreate/forUpdate timestamp handling, and `toCreateMap` / `toUpdateMap` / `toEntity` / `fromEntity` / `copyWith` / `_parseTimestamp` all mirroring the mechanic model verbatim.

`lib/core/constants/tag_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Chip colors for one tag token: soft tint background + readable foreground.
class TagChipStyle {
  final Color bg;
  final Color fg;
  const TagChipStyle(this.bg, this.fg);
}

/// The eight tag color tokens, stored verbatim in `product_tags.color`.
/// Keep in lockstep with web_admin/src/domain/tags/tagColors.ts — the same
/// token must render as the same hue on both surfaces.
abstract class TagColors {
  static const List<String> tokens = [
    'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
  ];

  static String normalize(String? value) =>
      tokens.contains(value) ? value! : 'gray';

  static const Map<String, TagChipStyle> _light = {
    'gray':   TagChipStyle(Color(0xFFECEFF1), Color(0xFF455A64)),
    'red':    TagChipStyle(Color(0xFFFDE8E8), Color(0xFFB03A34)),
    'amber':  TagChipStyle(Color(0xFFFBF0DC), Color(0xFF8A6116)),
    'green':  TagChipStyle(Color(0xFFE5F2E5), Color(0xFF2E7D32)),
    'teal':   TagChipStyle(Color(0xFFE0F0EF), Color(0xFF1F6E66)),
    'blue':   TagChipStyle(Color(0xFFE3EDF8), Color(0xFF2A5D8F)),
    'purple': TagChipStyle(Color(0xFFEEE8F7), Color(0xFF6A4FA3)),
    'pink':   TagChipStyle(Color(0xFFF9E7F0), Color(0xFFA34D77)),
  };

  // Dark theme: dim tint (low-alpha fg over surface), brighter foreground.
  static const Map<String, TagChipStyle> _dark = {
    'gray':   TagChipStyle(Color(0x2690A4AE), Color(0xFFB0BEC5)),
    'red':    TagChipStyle(Color(0x26E57373), Color(0xFFEF9A9A)),
    'amber':  TagChipStyle(Color(0x26D9A54A), Color(0xFFE6C07B)),
    'green':  TagChipStyle(Color(0x2681C784), Color(0xFF8FE39A)),
    'teal':   TagChipStyle(Color(0x264DB6AC), Color(0xFF80CBC4)),
    'blue':   TagChipStyle(Color(0x2664B5F6), Color(0xFF90CAF9)),
    'purple': TagChipStyle(Color(0x26B39DDB), Color(0xFFC5AEE8)),
    'pink':   TagChipStyle(Color(0x26F06292), Color(0xFFF48FB1)),
  };

  static TagChipStyle styleFor(String token, bool isDark) {
    final map = isDark ? _dark : _light;
    return map[normalize(token)]!;
  }
}
```

(`TagModel` imports `tag_colors.dart` for `normalize`.) Add the two barrel exports.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/models/tag_model_test.dart test/core/constants/tag_colors_test.dart && flutter analyze lib/domain/entities/tag_entity.dart lib/data/models/tag_model.dart lib/core/constants/tag_colors.dart`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/ lib/data/models/ lib/core/constants/tag_colors.dart test/data/models/tag_model_test.dart test/core/constants/tag_colors_test.dart
git commit -m "feat(mobile): TagEntity, TagModel, shared tag color tokens"
```

---

### Task 10: Mobile — TagRepository + impl + providers

**Files:**
- Create: `lib/domain/repositories/tag_repository.dart`
- Create: `lib/data/repositories/tag_repository_impl.dart`
- Create: `lib/presentation/providers/tag_provider.dart`
- Modify: `lib/core/constants/firestore_collections.dart` (add `productTags`)
- Modify: the repository/provider barrels if they exist (`grep -l "mechanic_repository" lib/domain/repositories/*.dart lib/presentation/providers/providers.dart` and mirror whatever export lines mechanics has)
- Test: `test/presentation/providers/tag_provider_test.dart`

**Interfaces:**
- Consumes: `TagEntity`, `TagModel` (Task 9).
- Produces: `TagRepository { watchActive(); watchAll(); getTagById(id); createTag({tag, createdBy}); updateTag({tag, updatedBy}); setActive({tagId, active, updatedBy}); deleteTag(tagId); nameExists({name, excludeTagId}) }` — exact mirror of `MechanicRepository`'s shapes with `Tag` substituted; `tagRepositoryProvider`, `activeTagsProvider` / `allTagsProvider` (auth-gated streams), `TagOperationsNotifier` (`create/update/deactivate/reactivate/delete`) + `tagOperationsProvider`.

- [ ] **Step 1: Write the failing test**

`test/presentation/providers/tag_provider_test.dart` — test the notifier against a recording fake repository (Dart allows unimplemented members when the class declares `noSuchMethod`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/tag_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

class _RecordingTagRepo implements TagRepository {
  final created = <TagEntity>[];
  final setActiveCalls = <(String, bool)>[];

  @override
  Future<TagEntity> createTag({
    required TagEntity tag,
    required String createdBy,
  }) async {
    created.add(tag);
    return tag.copyWith(id: 'new-1', createdBy: createdBy);
  }

  @override
  Future<void> setActive({
    required String tagId,
    required bool active,
    required String updatedBy,
  }) async {
    setActiveCalls.add((tagId, active));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

UserEntity _staff() => UserEntity(
      id: 'u-staff',
      email: 'staff@x.com',
      displayName: 'Staff',
      role: UserRole.staff,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('create routes through the repository with the actor id', () async {
    final repo = _RecordingTagRepo();
    final container = ProviderContainer(overrides: [
      tagRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
    ]);
    addTearDown(container.dispose);
    // Let currentUserProvider emit before the notifier reads it.
    await container.read(currentUserProvider.future);

    final tag = TagEntity.empty().copyWith(name: 'Intact', color: 'green');
    final created =
        await container.read(tagOperationsProvider.notifier).create(tag: tag);

    expect(created, isNotNull);
    expect(repo.created.single.name, 'Intact');
    expect(repo.created.single.color, 'green');
  });

  test('deactivate flips isActive false via setActive', () async {
    final repo = _RecordingTagRepo();
    final container = ProviderContainer(overrides: [
      tagRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ok =
        await container.read(tagOperationsProvider.notifier).deactivate('t1');

    expect(ok, isTrue);
    expect(repo.setActiveCalls.single, ('t1', false));
  });
}
```

(If Dart records `(String, bool)` aren't used elsewhere in the test suite and analyze objects, store two parallel lists instead.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/tag_provider_test.dart`
Expected: FAIL — modules missing.

- [ ] **Step 3: Implement**

- `firestore_collections.dart`, after `motorcycleModels`:

```dart
  /// Custom product tags (spec 2026-09-03) — colored markers attached to
  /// products via `products.tagIds`. Managed in Settings > Product Tags.
  static const String productTags = 'product_tags';
```

- `tag_repository.dart`: copy `mechanic_repository.dart`, substituting `Tag` for `Mechanic` throughout (`watchActive`, `watchAll`, `getTagById`, `createTag`, `updateTag`, `setActive`, `deleteTag`, `nameExists({required String name, String? excludeTagId})`) and updating doc comments ("Backed by the single `product_tags` collection", delete note mentioning orphaned ids are tolerated).
- `tag_repository_impl.dart`: copy `mechanic_repository_impl.dart` with `TagModel`, `FirestoreCollections.productTags`, `DuplicateEntryException` message `'A tag with this name already exists'`, same client-side A→Z sort helper.
- `tag_provider.dart`: copy `mechanic_provider.dart` with names swapped (`tagRepositoryProvider`, `activeTagsProvider`, `allTagsProvider`, `TagOperationsNotifier`, `tagOperationsProvider`) — same `authGatedStream` wrapping, same `_requireUserId()` pattern, `create({required TagEntity tag})`, `update({required TagEntity tag})`, `deactivate/reactivate/delete`.

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/presentation/providers/tag_provider_test.dart && flutter analyze`
Expected: PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/tag_repository.dart lib/data/repositories/tag_repository_impl.dart lib/presentation/providers/tag_provider.dart lib/core/constants/firestore_collections.dart test/presentation/providers/tag_provider_test.dart
git commit -m "feat(mobile): product_tags repository + Riverpod providers"
```

---

### Task 11: Mobile — TagEditorScreen + settings tile + routing

**Files:**
- Create: `lib/presentation/mobile/screens/settings/tag_editor_screen.dart`
- Modify: `lib/presentation/mobile/widgets/settings/settings_crud_row.dart` (two opt-in params: `Widget? leading`, `String? subtitle`)
- Modify: `lib/config/router/route_names.dart` (`RouteNames.productTags = 'productTags'`; `RoutePaths.productTags = '/settings/tags'`)
- Modify: `lib/config/router/app_routes.dart` (GoRoute under `/settings`, import)
- Modify: `lib/config/router/route_guards.dart` (`'/settings/tags': Permission.editLists,`)
- Modify: `lib/presentation/mobile/screens/settings/settings_screen.dart` (tile in the Lists section)
- Test: `test/presentation/mobile/screens/settings/tag_editor_screen_test.dart`

**Interfaces:**
- Consumes: `allTagsProvider`, `tagOperationsProvider` (Task 10), `TagColors` (Task 9), `SettingsCrudRow`/`SettingsAddFab`.
- Produces: `/settings/tags` CRUD screen; `SettingsCrudRow` gains `leading` (replaces the icon tile when set) and `subtitle` (secondary line under the name, shown alongside/instead of the Inactive line).

- [ ] **Step 1: Write the failing widget test**

`tag_editor_screen_test.dart` (harness style of `category_editor_delete_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/tag_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

class _FakeTagOps extends TagOperationsNotifier {
  _FakeTagOps(super.ref);
  final created = <TagEntity>[];

  @override
  Future<TagEntity?> create({required TagEntity tag}) async {
    created.add(tag);
    return tag.copyWith(id: 'new-1');
  }
}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

TagEntity _tag(String id, String name, {bool isActive = true}) => TagEntity(
      id: id,
      name: name,
      color: 'green',
      description: 'Count verified',
      isActive: isActive,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  Widget harness(UserRole role, {List<Override> extraOverrides = const []}) =>
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
          allTagsProvider.overrideWith((ref) => Stream.value([_tag('t1', 'Intact')])),
          ...extraOverrides,
        ],
        child: const MaterialApp(home: TagEditorScreen()),
      );

  testWidgets('lists tags with description subtitle', (tester) async {
    await tester.pumpWidget(harness(UserRole.staff));
    await tester.pumpAndSettle();
    expect(find.text('Intact'), findsOneWidget);
    expect(find.text('Count verified'), findsOneWidget);
  });

  testWidgets('cashier: no archive or delete buttons', (tester) async {
    await tester.pumpWidget(harness(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.archive), findsNothing);
    expect(find.byIcon(LucideIcons.trash2), findsNothing);
  });

  testWidgets('staff: archive + delete buttons present', (tester) async {
    await tester.pumpWidget(harness(UserRole.staff));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.archive), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
  });

  testWidgets('add dialog creates a tag with the picked color', (tester) async {
    _FakeTagOps? ops;
    await tester.pumpWidget(harness(UserRole.cashier, extraOverrides: [
      tagOperationsProvider.overrideWith((ref) {
        ops = _FakeTagOps(ref);
        return ops!;
      }),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Recheck');
    await tester.tap(find.byKey(const ValueKey('tag-color-amber')));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(ops!.created.single.name, 'Recheck');
    expect(ops!.created.single.color, 'amber');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/settings/tag_editor_screen_test.dart`
Expected: FAIL — screen missing.

- [ ] **Step 3: Extend SettingsCrudRow**

Add to `SettingsCrudRow`: `final Widget? leading;` and `final String? subtitle;` (both optional, constructor-named). In `build`: when `leading != null` render it (with the same 10px trailing gap) instead of the `leadingIcon` tile; render `subtitle` under the name in the same style as the existing `'Inactive'` line (12px, muted) whenever non-null — when the row is also inactive, show `'Inactive · $subtitle'`. Keep all existing behavior byte-compatible when the new params are null.

- [ ] **Step 4: Implement the screen**

`tag_editor_screen.dart` — copy `mechanic_editor_screen.dart` wholesale and adapt:

- Title `'Product Tags'`, empty state icon `LucideIcons.tag`, title `'No tags yet'`, subtitle `'Tap Add to create one.'`.
- Row:

```dart
final style = TagColors.styleFor(tag.color, Theme.of(context).brightness == Brightness.dark);
return SettingsCrudRow(
  name: tag.name,
  isActive: tag.isActive,
  subtitle: tag.description,
  leading: Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: style.bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(LucideIcons.tag, size: 18, color: style.fg),
  ),
  onEdit: () => _showTagDialog(context, existing: tag),
  onToggleActive: canManage ? () => _toggleActive(tag) : null,
  onDelete: canManage ? () => _confirmDelete(tag) : null,
);
```

- `_TagFormDialog` (replacing `_MechanicFormDialog`): Name field (same validator), a color swatch row, an optional Description field (`minLines: 1, maxLines: 3`, blank collapses to null via `clearDescription`), and the same Active switch for `_isEdit && canManage`. Swatch row:

```dart
Wrap(
  spacing: 10,
  runSpacing: 10,
  children: TagColors.tokens.map((token) {
    final style = TagColors.styleFor(token, isDark);
    final selected = _color == token;
    return InkWell(
      key: ValueKey('tag-color-$token'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _color = token),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: style.bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? style.fg : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: style.fg, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }).toList(),
)
```

with `String _color` state seeded `existing?.color ?? 'gray'`. Save mirrors the mechanic `_save` exactly (`ops.create(tag: TagEntity(id: '', name: name, color: _color, description: desc.isEmpty ? null : desc, isActive: true, createdAt: DateTime.now()))` / `ops.update(tag: existing.copyWith(name: name, color: _color, isActive: _isActive, description: desc.isEmpty ? null : desc, clearDescription: desc.isEmpty))`). Delete confirm message: `'"${tag.name}" will be permanently deleted. Products keep the tag but the chip disappears everywhere. Use Deactivate instead to just hide it.'`. Dialog action labels: `'Create'` / `'Save'` (matching the mechanic dialog's `appDialogPrimary` labels).

- [ ] **Step 5: Wire tile + routes + guard**

- `route_names.dart`: `static const String productTags = 'productTags';` in the names class (next to `mechanics`), `static const String productTags = '/settings/tags';` in `RoutePaths` (next to `mechanics`).
- `app_routes.dart`: import the screen; after the `motorcycle-models` GoRoute:

```dart
GoRoute(
  path: 'tags',
  name: RouteNames.productTags,
  builder: (context, state) => const TagEditorScreen(),
),
```

- `route_guards.dart`: `'/settings/tags': Permission.editLists,` in `protectedRoutes` next to the other list routes.
- `settings_screen.dart`, Lists `_SectionCard` after the Shop Fees tile:

```dart
SettingsTile(
  icon: LucideIcons.tags,
  title: 'Product Tags',
  subtitle: 'Color-coded markers shown on inventory',
  onTap: () => context.push(RoutePaths.productTags),
),
```

(NOTE: the Manage Lists tile already uses `LucideIcons.tag`; use `LucideIcons.tags` here — if the analyzer says it doesn't exist in this lucide package version, use `LucideIcons.bookmark`.)

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/presentation/mobile/screens/settings/ && flutter analyze`
Expected: PASS (including the pre-existing category settings tests), analyze clean.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/screens/settings/tag_editor_screen.dart lib/presentation/mobile/widgets/settings/settings_crud_row.dart lib/config/router/ lib/presentation/mobile/screens/settings/settings_screen.dart test/presentation/mobile/screens/settings/tag_editor_screen_test.dart
git commit -m "feat(mobile): Product Tags editor at /settings/tags"
```

---

### Task 12: Mobile — `ProductEntity.tagIds` + `updateProductTags` + ops provider

**Files:**
- Modify: `lib/domain/entities/product_entity.dart` (field + constructor + `copyWith` + `props`)
- Modify: `lib/data/models/product_model.dart` (field, `fromMap`, `toMap`, `fromEntity`/`toEntity`/`copyWith` — every site the model mirrors entity fields)
- Modify: `lib/domain/repositories/product_repository.dart` (add `updateProductTags`)
- Modify: `lib/data/repositories/product_repository_impl.dart` (implement it, mirroring `updateStock`)
- Modify: `lib/presentation/providers/tag_provider.dart` (add `ProductTagOperationsNotifier` + `productTagOperationsProvider`)
- Test: `test/data/models/product_model_test.dart` (extend), `test/presentation/providers/tag_provider_test.dart` (extend)

**Interfaces:**
- Produces: `ProductEntity.tagIds: List<String>` (default `const []`; `fromMap` tolerates a missing field); `ProductRepository.updateProductTags({required String productId, required List<String> tagIds, required String updatedBy, String? updatedByName}): Future<void>` writing ONLY `tagIds` + audit fields; `productTagOperationsProvider` with `Future<bool> setTags({required String productId, required List<String> tagIds})` (reads the current user for updatedBy/updatedByName).

- [ ] **Step 1: Write the failing tests**

Extend `test/data/models/product_model_test.dart`:

```dart
test('fromMap defaults missing tagIds to empty and reads a stored list', () {
  final legacy = ProductModel.fromMap(<String, dynamic>{'name': 'X'}, 'p-1');
  expect(legacy.tagIds, isEmpty);

  final tagged = ProductModel.fromMap({
    'name': 'X',
    'tagIds': ['t1', 't2'],
  }, 'p-2');
  expect(tagged.tagIds, ['t1', 't2']);
});

test('toMap writes tagIds', () {
  // Copy this file's existing minimal ProductModel fixture, add
  // tagIds: const ['t1'], and assert toMap()['tagIds'] == ['t1'].
});
```

(Write the second test against the fixture constructor this file already uses — repeat its required args verbatim.)

Extend `tag_provider_test.dart` with the product-tag ops case — grow `_RecordingTagRepo`'s sibling: a `_RecordingProductRepo implements ProductRepository` using the same `noSuchMethod` trick, overriding only:

```dart
  final tagWrites = <(String, List<String>)>[];

  @override
  Future<void> updateProductTags({
    required String productId,
    required List<String> tagIds,
    required String updatedBy,
    String? updatedByName,
  }) async {
    tagWrites.add((productId, tagIds));
  }
```

then:

```dart
test('setTags writes through updateProductTags with the actor', () async {
  final repo = _RecordingProductRepo();
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
    currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
  ]);
  addTearDown(container.dispose);
  await container.read(currentUserProvider.future);

  final ok = await container
      .read(productTagOperationsProvider.notifier)
      .setTags(productId: 'p1', tagIds: ['t1', 't2']);

  expect(ok, isTrue);
  expect(repo.tagWrites.single.$1, 'p1');
  expect(repo.tagWrites.single.$2, ['t1', 't2']);
});
```

(import `product_provider.dart` for `productRepositoryProvider`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/models/product_model_test.dart test/presentation/providers/tag_provider_test.dart`
Expected: new cases FAIL.

- [ ] **Step 3: Implement**

- `product_entity.dart`: after `notes`:

```dart
  /// Custom tag ids (`product_tags` docs). Chips resolve live from the tag
  /// list; orphaned ids (deleted tags) are tolerated and never rendered.
  final List<String> tagIds;
```

constructor `this.tagIds = const [],`; `copyWith` param `List<String>? tagIds` → `tagIds: tagIds ?? this.tagIds,`; add `tagIds` to `props`.
- `product_model.dart`: same field; `fromMap`: `tagIds: _parseStringList(map['tagIds']),` (helper already exists for `searchKeywords`); base `toMap`: `'tagIds': tagIds,` next to `'barcodes'`; thread through `fromEntity`/`toEntity`/`copyWith` exactly as `barcodes` is.
- `product_repository.dart`, after `updateStock`:

```dart
  /// Replaces the product's tag list. Writes ONLY tagIds + audit fields —
  /// the narrow write every role's rules branch permits (cashier included),
  /// so a quick tag toggle can never clobber a concurrent field edit.
  Future<void> updateProductTags({
    required String productId,
    required List<String> tagIds,
    required String updatedBy,
    String? updatedByName,
  });
```

- `product_repository_impl.dart` (mirror `updateStock`'s try/catch + `DatabaseException` wrapping, but no re-read):

```dart
  @override
  Future<void> updateProductTags({
    required String productId,
    required List<String> tagIds,
    required String updatedBy,
    String? updatedByName,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'tagIds': tagIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        if (updatedByName != null) 'updatedByName': updatedByName,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update tags: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- `tag_provider.dart` — append:

```dart
/// Mutations for a PRODUCT's tag list (quick attach). Kept separate from the
/// form save path so a toggle writes only tagIds + audit fields.
class ProductTagOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProductTagOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> setTags({
    required String productId,
    required List<String> tagIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        throw const UnauthenticatedException();
      }
      await _ref.read(productRepositoryProvider).updateProductTags(
            productId: productId,
            tagIds: tagIds,
            updatedBy: user.id,
            updatedByName: user.displayName,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final productTagOperationsProvider =
    StateNotifierProvider<ProductTagOperationsNotifier, AsyncValue<void>>(
        (ref) {
  return ProductTagOperationsNotifier(ref);
});
```

(import `product_provider.dart`).

- [ ] **Step 4: Run the mobile suite**

Run: `flutter test && flutter analyze`
Expected: PASS — existing product model/usecase tests must stay green (entity default `const []` keeps every existing constructor call compiling). The cashier name-only rebase in `UpdateProductUseCase` (`original.copyWith(name:, imageUrl:)`) automatically preserves the fresh doc's `tagIds` — no use-case change; do not add one.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/product_entity.dart lib/data/models/product_model.dart lib/domain/repositories/product_repository.dart lib/data/repositories/product_repository_impl.dart lib/presentation/providers/tag_provider.dart test/
git commit -m "feat(mobile): products carry tagIds; narrow updateProductTags write"
```

---

### Task 13: Mobile — inventory tile tag chips

**Files:**
- Modify: `lib/presentation/mobile/widgets/inventory/product_list_tile.dart`
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart` (resolve + pass tags)
- Test: `test/presentation/mobile/widgets/inventory/product_list_tile_tags_test.dart`

**Interfaces:**
- Consumes: `TagEntity`, `TagColors` (Task 9), `ProductEntity.tagIds` (Task 12), `activeTagsProvider` (Task 10).
- Produces: `ProductListTile` gains `final List<TagEntity> tags;` (`this.tags = const []`) — the parent resolves ids → entities; the tile renders first 2 + `+n`.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_list_tile.dart';

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Brake shoe',
      costCode: 'NBF',
      cost: 100,
      price: 150,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

TagEntity _tag(String id, String name) => TagEntity(
      id: id,
      name: name,
      color: 'green',
      isActive: true,
      createdAt: DateTime(2026, 9, 1),
    );

Widget _harness(List<TagEntity> tags) => MaterialApp(
      home: Scaffold(
        body: ProductListTile(
          product: _product(),
          showCost: false,
          onTap: () {},
          tags: tags,
        ),
      ),
    );

void main() {
  testWidgets('renders no chips when the product has no tags', (tester) async {
    await tester.pumpWidget(_harness(const []));
    expect(find.text('Intact'), findsNothing);
  });

  testWidgets('renders up to two chips plus a +n overflow', (tester) async {
    await tester.pumpWidget(_harness([
      _tag('t1', 'Intact'),
      _tag('t2', 'Recheck'),
      _tag('t3', 'Promo'),
    ]));
    expect(find.text('Intact'), findsOneWidget);
    expect(find.text('Recheck'), findsOneWidget);
    expect(find.text('Promo'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });
}
```

(If `ProductEntity`'s constructor requires more named args than shown, satisfy exactly what `flutter analyze` demands using the entity's own defaults as a guide — do not change the entity.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/inventory/product_list_tile_tags_test.dart`
Expected: FAIL — `tags` param doesn't exist.

- [ ] **Step 3: Implement the tile**

- Add `final List<TagEntity> tags;` + `this.tags = const [],` to `ProductListTile`.
- In the tile's column, insert between the SKU/category row and the price row (replacing the single `SizedBox(height: AppSpacing.sm)`):

```dart
if (tags.isNotEmpty) ...[
  const SizedBox(height: 4),
  Wrap(
    spacing: 4,
    runSpacing: 3,
    children: [
      ...tags.take(2).map((t) => _TagChip(tag: t, isDark: isDark)),
      if (tags.length > 2) _OverflowChip(count: tags.length - 2),
    ],
  ),
],
const SizedBox(height: AppSpacing.sm),
```

- New private widgets in the same file (styled like `_CategoryChip` but filled with the tag tint):

```dart
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.isDark});
  final TagEntity tag;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final style = TagColors.styleFor(tag.color, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        tag.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: style.fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '+$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
```

(import `tag_colors.dart`).

- [ ] **Step 4: Pass resolved tags from the inventory screen**

In `inventory_screen.dart` `_buildProductList`, before the `ListView.builder`:

```dart
final tagById = {
  for (final t in ref.watch(activeTagsProvider).valueOrNull ?? <TagEntity>[])
    t.id: t,
};
```

and in the item builder:

```dart
tags: [
  for (final id in product.tagIds)
    if (tagById[id] != null) tagById[id]!,
],
```

(import `tag_provider.dart`). Run `grep -rn "ProductListTile(" lib/` — any other call site compiles unchanged thanks to the default, leave them without tags.

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/presentation/mobile/widgets/inventory/ && flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/inventory/product_list_tile.dart lib/presentation/mobile/screens/inventory/inventory_screen.dart test/presentation/mobile/widgets/inventory/product_list_tile_tags_test.dart
git commit -m "feat(mobile): tag chips on inventory tiles"
```

---

### Task 14: Mobile — long-press actions sheet + tag toggle sheet

**Files:**
- Create: `lib/presentation/mobile/widgets/inventory/product_tag_sheet.dart`
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart` (long-press → actions sheet for everyone)
- Test: `test/presentation/mobile/widgets/inventory/product_tag_sheet_test.dart`

**Interfaces:**
- Consumes: `activeTagsProvider`, `productTagOperationsProvider` (Tasks 10/12), `TagColors`.
- Produces: `Future<void> showProductTagSheet(BuildContext context, {required ProductEntity product})` — bottom sheet of active tags with checkmarks; each tap toggles + writes immediately via `setTags`.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_tag_sheet.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

class _FakeProductTagOps extends ProductTagOperationsNotifier {
  _FakeProductTagOps(super.ref);
  final writes = <List<String>>[];

  @override
  Future<bool> setTags({
    required String productId,
    required List<String> tagIds,
  }) async {
    writes.add(List.of(tagIds));
    return true;
  }
}

TagEntity _tag(String id, String name) => TagEntity(
      id: id,
      name: name,
      color: 'green',
      isActive: true,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  testWidgets('toggling tags writes the composed list each tap', (tester) async {
    _FakeProductTagOps? ops;
    final product = ProductEntity(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Brake shoe',
      costCode: 'NBF',
      cost: 100,
      price: 150,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      tagIds: const ['t2'],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeTagsProvider.overrideWith(
          (ref) => Stream.value([_tag('t1', 'Intact'), _tag('t2', 'Recheck')]),
        ),
        productTagOperationsProvider.overrideWith((ref) {
          ops = _FakeProductTagOps(ref);
          return ops!;
        }),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProductTagSheet(context, product: product),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Intact'));
    await tester.pump();
    expect(ops!.writes.last, ['t2', 't1']);

    await tester.tap(find.text('Recheck'));
    await tester.pump();
    expect(ops!.writes.last, ['t1']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/inventory/product_tag_sheet_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement the sheet**

`product_tag_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/tag_colors.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

/// Bottom sheet for quick tag attach/detach on one product (the sweep
/// gesture: long-press a tile → tap a tag → done). Every tap writes the
/// composed tagIds list immediately via [ProductTagOperationsNotifier.setTags]
/// — only tagIds + audit fields, so it can never clobber a concurrent edit.
Future<void> showProductTagSheet(
  BuildContext context, {
  required ProductEntity product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ProductTagSheet(product: product),
  );
}

class _ProductTagSheet extends ConsumerStatefulWidget {
  const _ProductTagSheet({required this.product});
  final ProductEntity product;

  @override
  ConsumerState<_ProductTagSheet> createState() => _ProductTagSheetState();
}

class _ProductTagSheetState extends ConsumerState<_ProductTagSheet> {
  late final Set<String> _selected = Set.of(widget.product.tagIds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tagsAsync = ref.watch(activeTagsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No tags yet — create tags in Settings → Product Tags.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: tags.map((tag) {
                      final style = TagColors.styleFor(tag.color, isDark);
                      final selected = _selected.contains(tag.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: style.bg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child:
                              Icon(LucideIcons.tag, size: 15, color: style.fg),
                        ),
                        title: Text(tag.name),
                        trailing: selected
                            ? Icon(LucideIcons.check, color: style.fg)
                            : null,
                        onTap: () => _toggle(tag.id),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load tags: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(String tagId) async {
    setState(() {
      if (!_selected.remove(tagId)) _selected.add(tagId);
    });
    // Preserve the original attach order for ids that stay selected.
    final ordered = <String>[
      ...widget.product.tagIds.where(_selected.contains),
      ..._selected.where((id) => !widget.product.tagIds.contains(id)),
    ];
    final ok = await ref
        .read(productTagOperationsProvider.notifier)
        .setTags(productId: widget.product.id, tagIds: ordered);
    if (!ok && mounted) {
      setState(() {
        if (!_selected.remove(tagId)) _selected.add(tagId); // roll back
      });
    }
  }
}
```

- [ ] **Step 4: Repurpose long-press in the inventory screen**

In `inventory_screen.dart` `_buildProductList`, replace

```dart
onLongPress:
    isAdmin ? () => _confirmAndDelete(context, product) : null,
```

with `onLongPress: () => _showProductActions(context, product, isAdmin),` and add:

```dart
void _showProductActions(
  BuildContext context,
  ProductEntity product,
  bool isAdmin,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.tag),
            title: const Text('Tags…'),
            onTap: () {
              Navigator.pop(sheetContext);
              showProductTagSheet(context, product: product);
            },
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.error),
              title: const Text('Delete product',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmAndDelete(context, product);
              },
            ),
        ],
      ),
    ),
  );
}
```

(match the existing imports/theme usage of the file; `_confirmAndDelete` and its admin gate stay untouched underneath).

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/presentation/mobile/widgets/inventory/ && flutter analyze`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/inventory/product_tag_sheet.dart lib/presentation/mobile/screens/inventory/inventory_screen.dart test/presentation/mobile/widgets/inventory/product_tag_sheet_test.dart
git commit -m "feat(mobile): long-press actions sheet with quick tag attach"
```

---

### Task 15: Mobile — inventory tag filter

**Files:**
- Modify: `lib/presentation/providers/inventory_provider.dart` (`tagFilter` state + filtering)
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart` (tag filter chip + active-filter integration)
- Test: `test/presentation/providers/inventory_tag_filter_test.dart`

**Interfaces:**
- Produces: `const String kUntaggedFilter = '__untagged__';` (exported from `inventory_provider.dart`); `InventoryState.tagFilter: String?` (a tag id or `kUntaggedFilter`; null = off) with `copyWith(clearTagFilter:)`, `props`, `InventoryNotifier.setTagFilter(String?)`; `filteredProductsProvider` applies the axis (untagged = no id present in the ACTIVE tag id set).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/inventory_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

ProductEntity _product(String id, {List<String> tagIds = const []}) =>
    ProductEntity(
      id: id,
      sku: 'SKU-$id',
      name: 'Product $id',
      costCode: 'NBF',
      cost: 100,
      price: 150,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      tagIds: tagIds,
    );

TagEntity _tag(String id) => TagEntity(
      id: id,
      name: 'Tag $id',
      color: 'green',
      isActive: true,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  final products = [
    _product('a', tagIds: ['t1']),
    _product('b', tagIds: ['t2']),
    _product('c'),
    _product('d', tagIds: ['deleted-tag']),
  ];

  ProviderContainer _container() {
    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value(products)),
      activeTagsProvider.overrideWith(
        (ref) => Stream.value([_tag('t1'), _tag('t2')]),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<List<String>> _idsAfter(
    ProviderContainer container,
    String? tagFilter,
  ) async {
    await container.read(productsProvider.future);
    await container.read(activeTagsProvider.future);
    container.read(inventoryStateProvider.notifier).setTagFilter(tagFilter);
    final result = container.read(filteredProductsProvider);
    return result.value!.map((p) => p.id).toList();
  }

  test('no tag filter returns everything', () async {
    expect(await _idsAfter(_container(), null), ['a', 'b', 'c', 'd']);
  });

  test('a specific tag id matches only its products', () async {
    expect(await _idsAfter(_container(), 't1'), ['a']);
  });

  test('untagged = no ACTIVE tag; orphaned ids count as untagged', () async {
    expect(await _idsAfter(_container(), kUntaggedFilter), ['c', 'd']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/inventory_tag_filter_test.dart`
Expected: FAIL — `kUntaggedFilter`/`setTagFilter` missing.

- [ ] **Step 3: Implement the provider changes**

In `inventory_provider.dart`:

```dart
/// Tag-filter sentinel: products with no ACTIVE tag. Orphaned ids from
/// deleted tags count as untagged — they never render as chips either.
const String kUntaggedFilter = '__untagged__';
```

`InventoryState`: add `final String? tagFilter;` (constructor `this.tagFilter,`), `copyWith` gains `String? tagFilter` + `bool clearTagFilter = false` (mirror `categoryFilter`), add to `props`. `InventoryNotifier`:

```dart
  void setTagFilter(String? tagIdOrUntagged) {
    state = state.copyWith(
      tagFilter: tagIdOrUntagged,
      clearTagFilter: tagIdOrUntagged == null,
    );
  }
```

`filteredProductsProvider`: at the top, `final activeTagIds = ref.watch(activeTagsProvider).valueOrNull?.map((t) => t.id).toSet() ?? const <String>{};` then after the category filter:

```dart
      // Apply tag filter
      final tagFilter = inventoryState.tagFilter;
      if (tagFilter != null) {
        if (tagFilter == kUntaggedFilter) {
          filtered = filtered
              .where((p) => !p.tagIds.any(activeTagIds.contains))
              .toList();
        } else {
          filtered =
              filtered.where((p) => p.tagIds.contains(tagFilter)).toList();
        }
      }
```

(import `tag_provider.dart`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/providers/inventory_tag_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the filter chip UI**

In `inventory_screen.dart`, next to `_buildCategoryFilterChip` in the filter row, add `_buildTagFilterChip(inventoryState),` and implement it as a sibling of `_buildCategoryFilterChip` (same `PopupMenuButton<String?>` + `Chip` pattern):

```dart
  Widget _buildTagFilterChip(InventoryState inventoryState) {
    final tagsAsync = ref.watch(activeTagsProvider);

    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        String label = 'Tag';
        final current = inventoryState.tagFilter;
        if (current == kUntaggedFilter) {
          label = 'Untagged';
        } else if (current != null) {
          for (final t in tags) {
            if (t.id == current) {
              label = t.name;
              break;
            }
          }
        }

        return PopupMenuButton<String?>(
          child: Chip(
            avatar: const Icon(LucideIcons.tag, size: 16),
            label: Text(label),
            deleteIcon: current != null ? const Icon(LucideIcons.x, size: 16) : null,
            onDeleted: current != null
                ? () => ref
                    .read(inventoryStateProvider.notifier)
                    .setTagFilter(null)
                : null,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('All Tags')),
            const PopupMenuItem(
              value: kUntaggedFilter,
              child: Text('Untagged'),
            ),
            ...tags.map(
              (t) => PopupMenuItem(value: t.id, child: Text(t.name)),
            ),
          ],
          onSelected: (value) {
            ref.read(inventoryStateProvider.notifier).setTagFilter(value);
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
```

Also fold `tagFilter` into `_hasActiveFilters` (add `|| state.tagFilter != null`) and, if `_buildActiveFilters` enumerates each axis, add the tag axis there following the category pattern (`resetFilters()` already clears it since it resets to `const InventoryState()`).

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test && flutter analyze`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/inventory_provider.dart lib/presentation/mobile/screens/inventory/inventory_screen.dart test/presentation/providers/inventory_tag_filter_test.dart
git commit -m "feat(mobile): inventory tag filter with Untagged"
```

---

### Task 16: Mobile — product form Tags field + mobile suite green

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

**Interfaces:**
- Consumes: `activeTagsProvider`, `TagColors`, `ProductEntity.tagIds`.
- Produces: a chip-toggle Tags field in the CLASSIFICATION card (after Notes); `tagIds` included in the built entity for create + update; participates in dirty tracking; read-only for the cashier name-only tier (their save path rebases and never writes tags anyway).

- [ ] **Step 1: Add the state + seeding**

- Field: `List<String> _selectedTagIds = [];` near the other field state.
- Seed in the product-load block (next to `_notesController.text = product.notes ?? '';` at ~line 592): `_selectedTagIds = List.of(product.tagIds);`
- Dirty tracking: add `_selectedTagIds.join(',')` to the `_sig()` tuple/string (~line 124, next to the notes component).

- [ ] **Step 2: Add the field UI**

In the CLASSIFICATION `_sectionCard`, after the Notes `TextFormField`:

```dart
const SizedBox(height: 14),
_tagField(isNameOnly),
```

and the builder method:

```dart
  Widget _tagField(bool isNameOnly) {
    final tagsAsync = ref.watch(activeTagsProvider);
    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty && _selectedTagIds.isEmpty) {
          return const SizedBox.shrink();
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) {
                final style = TagColors.styleFor(tag.color, isDark);
                final selected = _selectedTagIds.contains(tag.id);
                if (isNameOnly && !selected) return const SizedBox.shrink();
                return FilterChip(
                  label: Text(tag.name),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: style.bg,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? style.fg
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onSelected: isNameOnly
                      ? null
                      : (_) {
                          setState(() {
                            selected
                                ? _selectedTagIds.remove(tag.id)
                                : _selectedTagIds.add(tag.id);
                          });
                        },
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
```

(import `tag_provider.dart` + `tag_colors.dart`; match the surrounding label style if the file has a shared field-label helper.)

- [ ] **Step 3: Thread tagIds into the built entity**

Where the submit path constructs the `ProductEntity` (the block around line ~1353 with `supplierId: _selectedSupplierId,`), add `tagIds: _selectedTagIds,` for BOTH the create and update construction sites (grep the file for `supplierId: _selectedSupplierId` — every such entity build gets the line). The cashier name-only save is rebased inside `UpdateProductUseCase`, which preserves the fresh doc's tags — nothing to add there.

- [ ] **Step 4: Full mobile verification**

Run: `flutter analyze && flutter test`
Expected: both clean/PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "feat(mobile): tags chip field in the product form"
```

---

### Task 17: Final verification, review, and rollout handoff

**Files:** none new — verification + user-gated deployment.

- [ ] **Step 1: Run every suite end-to-end**

```bash
cd tools/firestore-rules-test && npm test && cd ../..
flutter analyze && flutter test
cd web_admin && npm run typecheck && npm run test && npm run build && cd ..
```

Expected: all PASS. Paste actual outputs in the report; if anything fails, fix before proceeding (verification-before-completion).

- [ ] **Step 2: Code review + app-level verify**

Per the repo's development loop: run `/code-review` on the branch diff and apply/triage findings, then `/verify` (web dev server walk-through of: create a tag, see the chip + filter + quick attach on inventory, product modal field).

- [ ] **Step 3: Rollout — STOP for user confirmation at each deploy**

1. **Rules** (production-affecting — confirm with the user first, per CLAUDE.md): show the `firestore.rules` diff, then `firebase deploy --only firestore:rules`. If firebase claims "credentials no longer valid", it may be the IPv6 lie — force IPv4 via `NODE_OPTIONS="--dns-result-order=ipv4first"` before re-authing.
2. **Web hosting** (needs the user's firebase reauth): `cd web_admin && npm run build`, then `firebase deploy --only hosting` — confirm with the user first.
3. **Mobile**: no build now — the tags feature rides the next APK (+33, already holding the receiving changes). Note it in the release log memory when +33 ships.

- [ ] **Step 4: Finish the branch**

Use the finishing-a-development-branch skill: the branch stacks on `feat/web-reskin-product-modal` — merge/PR per the user's choice once that parent has landed (or rebase onto main if it already has).
