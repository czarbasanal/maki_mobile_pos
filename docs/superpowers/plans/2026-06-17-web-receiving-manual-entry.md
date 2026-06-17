# Web Receiving — Manual Entry + Dashboard + Drafts — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the web admin's Receiving area to mirror mobile — a dashboard landing, a manual line-item entry form (existing match/mismatch + inline new-product), drafts (create/update/complete), and a history sub-view — keeping CSV import under Receiving.

**Architecture:** Phase 1 extracts `bulkReceive`'s product/stock logic into a Firestore-free engine (`applyReceivedItems`) that operates on a normalized `ReceivableItem`, then implements the stubbed `create`/`update`/`complete`/`watchDrafts` repo methods on top of it. Phase 2 builds the three pages (dashboard, entry form, relocated history) and their hooks against that data layer.

**Tech Stack:** React 18 + TypeScript + Vite, TanStack Query, Zustand, react-hook-form + zod, Firebase Firestore, Tailwind, Vitest.

## Global Constraints

- **Web admin only.** No Flutter/mobile changes. No `firestore.rules` change (`receivings` create/update already allowed for staff+admin; a draft is a `status:'draft'` doc).
- **Import convention:** any module imported by a Vitest test (all of `src/domain/**` and the new `src/data/receiving/applyReceivedItems.ts`) and its transitive imports MUST use **relative imports**, never the `@/` alias (Vitest does not resolve `@/`). Presentation-only code (hooks/pages) may use `@/`.
- **Verify with `npm run build`**, not just `tsc` — run from `web_admin/`. Gates per task: `npm run typecheck` + `npm run test` + (final) `npm run build`.
- **Shared `receivings` writes are production-affecting** — the `bulkReceive` refactor must be behavior-preserving; `complete` must be idempotent (never double-apply stock).
- **Item ids:** every persisted `ReceivingItem` gets a `crypto.randomUUID()` id (consistent with the existing converter fix).
- Currency formatting via `formatMoney` (`@/core/utils/money`). No toast library exists — success = navigate; errors = inline.

---

# Phase 1 — Data layer (Tasks 1–5)

Independently shippable: a fully tested receiving write/read layer with no UI changes.

## Task 1: `ReceivableItem` normalized type + mapper from classified rows

**Files:**
- Create: `web_admin/src/domain/receiving/receivableItem.ts`
- Test: `web_admin/src/domain/receiving/receivableItem.test.ts`

**Interfaces:**
- Consumes: `ClassifiedReceivingRow` (`./classifyReceivingRows`), `Product` (`../entities`).
- Produces:
  - `type ReceivableItem` (discriminated union, each carries `ref: string | number`).
  - `classifiedToReceivable(row: ClassifiedReceivingRow): ReceivableItem | null` (null for `error` rows).

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/domain/receiving/receivableItem.test.ts
import { describe, expect, it } from 'vitest';
import { classifiedToReceivable } from './receivableItem';
import type { ClassifiedReceivingRow } from './classifyReceivingRows';
import type { Product } from '../entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcode: null, supplierId: null, supplierName: null, baseSku: null,
    variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar',
  } as Product;
}

function row(
  status: ClassifiedReceivingRow['status'],
  over: Partial<ClassifiedReceivingRow['row']> = {},
  existing: Product | null = null,
): ClassifiedReceivingRow {
  return {
    status,
    existing,
    row: {
      rowNumber: 1, sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
      cost: 180, price: 220, quantity: 10, reorderLevel: 2, autoGenerateSku: false,
      errors: [], warnings: [], ...over,
    },
  };
}

describe('classifiedToReceivable', () => {
  it('maps a match to {kind:match, product, quantity}', () => {
    const p = product();
    expect(classifiedToReceivable(row('match', { quantity: 10 }, p))).toEqual({
      ref: 1, kind: 'match', product: p, quantity: 10,
    });
  });

  it('maps a mismatch to {kind:mismatch, product, quantity, cost}', () => {
    const p = product();
    expect(classifiedToReceivable(row('mismatch', { quantity: 4, cost: 200 }, p))).toEqual({
      ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200,
    });
  });

  it('maps a new row to {kind:new, ...row fields}', () => {
    expect(
      classifiedToReceivable(
        row('new', { sku: 'GENERATE', autoGenerateSku: true, name: 'Squid', category: 'Fish',
          unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1, rowNumber: 7 }),
      ),
    ).toEqual({
      ref: 7, kind: 'new', sku: 'GENERATE', autoGenerateSku: true, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
    });
  });

  it('returns null for error rows', () => {
    expect(classifiedToReceivable(row('error'))).toBeNull();
  });
});
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `cd web_admin && npx vitest run src/domain/receiving/receivableItem.test.ts`
Expected: FAIL — `classifiedToReceivable` is not exported / module not found.

- [ ] **Step 3: Write the implementation**

```ts
// web_admin/src/domain/receiving/receivableItem.ts
import type { Product } from '../entities';
import type { ClassifiedReceivingRow } from './classifyReceivingRows';

/** A line ready to be received, normalized so both the CSV path (classified
 *  rows) and a resumed draft (persisted items) map into the same shape that
 *  `applyReceivedItems` consumes. `ref` labels the source line for error
 *  reporting (the CSV row number, or a 1-based index for manual entry). */
export type ReceivableItem = { ref: string | number } & (
  | { kind: 'match'; product: Product; quantity: number }
  | { kind: 'mismatch'; product: Product; quantity: number; cost: number }
  | {
      kind: 'new';
      sku: string;
      autoGenerateSku: boolean;
      name: string;
      category: string | null;
      unit: string;
      cost: number;
      price: number;
      quantity: number;
      reorderLevel: number;
    }
);

export function classifiedToReceivable(row: ClassifiedReceivingRow): ReceivableItem | null {
  if (row.status === 'error') return null;
  const r = row.row;
  if (row.status === 'match' && row.existing) {
    return { ref: r.rowNumber, kind: 'match', product: row.existing, quantity: r.quantity };
  }
  if (row.status === 'mismatch' && row.existing) {
    return {
      ref: r.rowNumber, kind: 'mismatch', product: row.existing,
      quantity: r.quantity, cost: r.cost,
    };
  }
  return {
    ref: r.rowNumber, kind: 'new', sku: r.sku, autoGenerateSku: r.autoGenerateSku,
    name: r.name, category: r.category, unit: r.unit, cost: r.cost, price: r.price,
    quantity: r.quantity, reorderLevel: r.reorderLevel,
  };
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `cd web_admin && npx vitest run src/domain/receiving/receivableItem.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/receiving/receivableItem.ts web_admin/src/domain/receiving/receivableItem.test.ts
git commit -m "feat(web): ReceivableItem normalized type + classified-row mapper"
```

---

## Task 2: `applyReceivedItems` engine (Firestore-free), TDD with a fake repo

This is the extracted core of `bulkReceive`: it creates new/variation products via the injected `ProductRepository`, accumulates match increments, and returns finished `ReceivingItem[]`. It performs **no Firestore doc writes** — callers persist the receiving doc.

**Files:**
- Create: `web_admin/src/data/receiving/applyReceivedItems.ts`
- Test: `web_admin/src/data/receiving/applyReceivedItems.test.ts`

**Interfaces:**
- Consumes: `ReceivableItem` (`../../domain/receiving/receivableItem`), `ProductRepository` (`../../domain/repositories/ProductRepository`), `CostCode` + `encodeCostCode` (`../../domain/entities/CostCode`), `generateSku` (`../../domain/products/sku`), `generateSearchKeywords` (`../../domain/products/searchKeywords`), `nextVariationNumber`/`variationSku` (`../../domain/receiving/variations`), `DuplicateSkuError` (`../errors`), `Product`/`ReceivingItem`/`ProductCreateInput` types.
- Produces:
  - `interface ReceiveContext { cipher: CostCode; actor: { id: string; name: string | null }; supplier: { id: string; name: string } | null; knownSkus: string[] }`
  - `interface ReceiveOutcome { items: ReceivingItem[]; increments: Map<string, number>; newProducts: number; variations: number; received: number; failed: { ref: string | number; message: string }[] }`
  - `async function applyReceivedItems(receivables: ReceivableItem[], products: ProductRepository, ctx: ReceiveContext): Promise<ReceiveOutcome>`

- [ ] **Step 1: Write the failing test**

```ts
// web_admin/src/data/receiving/applyReceivedItems.test.ts
import { describe, expect, it, vi } from 'vitest';
import { applyReceivedItems, type ReceiveContext } from './applyReceivedItems';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';
import type { Product } from '../../domain/entities';
import type { ProductRepository } from '../../domain/repositories/ProductRepository';
import { DuplicateSkuError } from '../errors';
import { CostCode } from '../../domain/entities/CostCode';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcode: null, supplierId: null, supplierName: null, baseSku: null,
    variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar', ...over,
  } as Product;
}

// A 1:1 cost-code cipher is enough for the engine — it only needs encodeCostCode
// not to throw. Use the real default mapping.
const cipher = CostCode.defaultMapping();

const ctx = (over: Partial<ReceiveContext> = {}): ReceiveContext => ({
  cipher, actor: { id: 'u1', name: 'Czar' }, supplier: null, knownSkus: [], ...over,
});

/** Minimal in-memory ProductRepository — only the methods the engine calls. */
function fakeRepo(over: Partial<ProductRepository> = {}): ProductRepository {
  let seq = 0;
  return {
    create: vi.fn(async (input) => ({ ...input, id: `new-${++seq}`, createdAt: new Date(), updatedAt: null, searchKeywords: input.searchKeywords ?? [] } as Product)),
    recordPriceChange: vi.fn(async () => {}),
    ...over,
  } as unknown as ProductRepository;
}

describe('applyReceivedItems', () => {
  it('match → accumulates an increment and emits an item at the product cost', async () => {
    const p = product({ id: 'p1', cost: 180 });
    const items: ReceivableItem[] = [{ ref: 1, kind: 'match', product: p, quantity: 10 }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(out.increments.get('p1')).toBe(10);
    expect(out.items).toHaveLength(1);
    expect(out.items[0]).toMatchObject({ productId: 'p1', quantity: 10, unitCost: 180, isNewVariation: false });
    expect(out.items[0].id).toMatch(/.+/);
    expect(out.received).toBe(10);
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('new → creates a product and emits an item; auto-generates SKU when asked', async () => {
    const items: ReceivableItem[] = [{
      ref: 1, kind: 'new', sku: 'GENERATE', autoGenerateSku: true, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
    }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(repo.create).toHaveBeenCalledTimes(1);
    expect(out.newProducts).toBe(1);
    expect(out.items[0]).toMatchObject({ name: 'Squid', quantity: 3, unitCost: 90, isNewVariation: false, newProductId: null });
    expect(out.items[0].sku).not.toBe('GENERATE'); // auto-generated
  });

  it('mismatch → creates a <base>-N variation, records a price change, emits a variation item', async () => {
    const p = product({ id: 'p1', sku: 'SP', baseSku: null, cost: 180 });
    const items: ReceivableItem[] = [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200 }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx({ knownSkus: ['SP'] }));
    expect(repo.create).toHaveBeenCalledTimes(1);
    expect(repo.recordPriceChange).toHaveBeenCalledTimes(1);
    expect(out.variations).toBe(1);
    expect(out.items[0]).toMatchObject({ productId: 'p1', sku: 'SP-1', unitCost: 200, isNewVariation: true });
    expect(out.items[0].newProductId).toMatch(/.+/);
  });

  it('mismatch → retries the next variation number on DuplicateSkuError', async () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180 });
    let calls = 0;
    const repo = fakeRepo({
      create: vi.fn(async (input) => {
        calls += 1;
        if (input.sku === 'SP-1') throw new DuplicateSkuError('SP-1');
        return { ...input, id: 'v1', createdAt: new Date(), updatedAt: null, searchKeywords: [] } as Product;
      }),
      recordPriceChange: vi.fn(async () => {}),
    });
    const out = await applyReceivedItems(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200 }],
      repo, ctx({ knownSkus: ['SP'] }),
    );
    expect(calls).toBe(2);
    expect(out.items[0].sku).toBe('SP-2');
  });

  it('records a failure (does not throw) when a line cannot be processed', async () => {
    const repo = fakeRepo({ create: vi.fn(async () => { throw new Error('boom'); }), recordPriceChange: vi.fn() });
    const out = await applyReceivedItems(
      [{ ref: 9, kind: 'new', sku: 'X', autoGenerateSku: false, name: 'X', category: null, unit: 'pcs', cost: 1, price: 2, quantity: 1, reorderLevel: 0 }],
      repo, ctx(),
    );
    expect(out.items).toHaveLength(0);
    expect(out.failed).toEqual([{ ref: 9, message: 'boom' }]);
  });
});
```

> Note: if `CostCode.defaultMapping()` is not the exact API, the reader's
> report shows `encodeCostCode(cc: CostCode, cost)` lives in
> `src/domain/entities/CostCode.ts`; use whatever constructor/default the file
> exposes (e.g. an identity mapping object) — the engine only needs it to not
> throw. Confirm the exact export when writing the test.

- [ ] **Step 2: Run the test, verify it fails**

Run: `cd web_admin && npx vitest run src/data/receiving/applyReceivedItems.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the engine**

```ts
// web_admin/src/data/receiving/applyReceivedItems.ts
import type { Product, ReceivingItem } from '../../domain/entities';
import type { ProductCreateInput, ProductRepository } from '../../domain/repositories/ProductRepository';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';
import { CostCode, encodeCostCode } from '../../domain/entities/CostCode';
import { generateSku } from '../../domain/products/sku';
import { generateSearchKeywords } from '../../domain/products/searchKeywords';
import { nextVariationNumber, variationSku } from '../../domain/receiving/variations';
import { DuplicateSkuError } from '../errors';

export interface ReceiveContext {
  cipher: CostCode;
  actor: { id: string; name: string | null };
  supplier: { id: string; name: string } | null;
  knownSkus: string[];
}

export interface ReceiveOutcome {
  items: ReceivingItem[];
  increments: Map<string, number>;
  newProducts: number;
  variations: number;
  received: number;
  failed: { ref: string | number; message: string }[];
}

const MAX_VARIATION_ATTEMPTS = 5;

interface NewProductFields {
  sku: string; name: string; cost: number; costCode: string; price: number;
  quantity: number; reorderLevel: number; unit: string; category: string | null;
  supplierId: string | null; supplierName: string | null;
  baseSku: string | null; variationNumber: number | null;
}

function buildProductInput(p: NewProductFields, actor: ReceiveContext['actor']): ProductCreateInput {
  const actorName = actor.name?.trim() || null;
  return {
    sku: p.sku, name: p.name, costCode: p.costCode, cost: p.cost, price: p.price,
    quantity: p.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
    supplierId: p.supplierId, supplierName: p.supplierName, isActive: true,
    createdBy: actor.id, updatedBy: actor.id, createdByName: actorName, updatedByName: actorName,
    searchKeywords: generateSearchKeywords([p.sku, p.name, p.category]),
    baseSku: p.baseSku, variationNumber: p.variationNumber, barcode: null,
    category: p.category, imageUrl: null, notes: null,
  } as ProductCreateInput;
}

function item(over: Omit<ReceivingItem, 'id' | 'notes'>): ReceivingItem {
  return { ...over, id: crypto.randomUUID(), notes: null };
}

export async function applyReceivedItems(
  receivables: ReceivableItem[],
  products: ProductRepository,
  ctx: ReceiveContext,
): Promise<ReceiveOutcome> {
  const items: ReceivingItem[] = [];
  const increments = new Map<string, number>();
  const knownSkus = [...ctx.knownSkus];
  const failed: ReceiveOutcome['failed'] = [];
  let newProducts = 0;
  let variations = 0;

  for (const rec of receivables) {
    try {
      if (rec.kind === 'match') {
        const p = rec.product;
        increments.set(p.id, (increments.get(p.id) ?? 0) + rec.quantity);
        items.push(item({
          productId: p.id, sku: p.sku, name: p.name, quantity: rec.quantity,
          unit: p.unit, unitCost: p.cost, costCode: p.costCode,
          isNewVariation: false, newProductId: null,
        }));
      } else if (rec.kind === 'mismatch') {
        const p = rec.product;
        const base = p.baseSku ?? p.sku;
        const costCode = encodeCostCode(ctx.cipher, rec.cost);
        let n = nextVariationNumber(base, knownSkus);
        let created: Product | undefined;
        let sku = '';
        for (let attempt = 0; attempt < MAX_VARIATION_ATTEMPTS; attempt += 1) {
          sku = variationSku(base, n);
          try {
            created = await products.create(
              buildProductInput({
                sku, name: p.name, cost: rec.cost, costCode, price: p.price,
                quantity: rec.quantity, reorderLevel: p.reorderLevel, unit: p.unit,
                category: p.category, supplierId: p.supplierId, supplierName: p.supplierName,
                baseSku: base, variationNumber: n,
              }, ctx.actor),
              ctx.actor.id,
            );
            break;
          } catch (e) {
            if (e instanceof DuplicateSkuError) { n += 1; continue; }
            throw e;
          }
        }
        if (!created) throw new Error(`Could not allocate a unique variation SKU for "${base}"`);
        knownSkus.push(sku);
        await products.recordPriceChange(created.id, {
          price: p.price, cost: rec.cost, changedBy: ctx.actor.id, reason: 'receiving',
        });
        variations += 1;
        items.push(item({
          productId: p.id, sku, name: p.name, quantity: rec.quantity, unit: p.unit,
          unitCost: rec.cost, costCode, isNewVariation: true, newProductId: created.id,
        }));
      } else {
        // new
        const sku = rec.autoGenerateSku ? generateSku(rec.name) : rec.sku;
        const costCode = encodeCostCode(ctx.cipher, rec.cost);
        const created = await products.create(
          buildProductInput({
            sku, name: rec.name, cost: rec.cost, costCode, price: rec.price,
            quantity: rec.quantity, reorderLevel: rec.reorderLevel, unit: rec.unit,
            category: rec.category, supplierId: ctx.supplier?.id ?? null,
            supplierName: ctx.supplier?.name ?? null, baseSku: null, variationNumber: null,
          }, ctx.actor),
          ctx.actor.id,
        );
        knownSkus.push(created.sku);
        await products.recordPriceChange(created.id, {
          price: rec.price, cost: rec.cost, changedBy: ctx.actor.id, reason: 'Initial price',
        });
        newProducts += 1;
        items.push(item({
          productId: created.id, sku: created.sku, name: rec.name, quantity: rec.quantity,
          unit: rec.unit, unitCost: rec.cost, costCode, isNewVariation: false, newProductId: null,
        }));
      }
    } catch (e) {
      failed.push({ ref: rec.ref, message: (e as Error).message });
    }
  }

  const received = items.reduce((n, it) => n + it.quantity, 0);
  return { items, increments, newProducts, variations, received, failed };
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `cd web_admin && npx vitest run src/data/receiving/applyReceivedItems.test.ts`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/data/receiving/applyReceivedItems.ts web_admin/src/data/receiving/applyReceivedItems.test.ts
git commit -m "feat(web): applyReceivedItems engine (Firestore-free, fake-repo tested)"
```

---

## Task 3: Refactor `bulkReceive` onto the engine (behavior-preserving)

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreReceivingRepository.ts` (the `bulkReceive` method body, the `BuiltItem` interface, and the private `productInput`).

**Interfaces:**
- Consumes: `applyReceivedItems`/`ReceiveContext` (`@/data/receiving/applyReceivedItems`), `classifiedToReceivable` (`@/domain/receiving/receivableItem`).
- Produces: unchanged public `bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult>`.

- [ ] **Step 1: Add imports**

At the top of `FirestoreReceivingRepository.ts`, add:

```ts
import { applyReceivedItems } from '@/data/receiving/applyReceivedItems';
import { classifiedToReceivable } from '@/domain/receiving/receivableItem';
```

- [ ] **Step 2: Replace the item-building loop in `bulkReceive`**

Replace the whole `for (const c of rows) { … }` loop **and** the trailing item-id `.map` (`items: items.map((it) => ({ ...it, id: crypto.randomUUID(), notes: null }))`) so the doc is written from the engine outcome. The new `bulkReceive` body:

```ts
  async bulkReceive(input: BulkReceiveInput): Promise<ReceivingResult> {
    const { rows, supplier, cipher, actor } = input;
    const referenceNumber = await this.generateReferenceNumber();

    const receivables = rows.map(classifiedToReceivable).filter((r): r is NonNullable<typeof r> => r !== null);
    const outcome = await applyReceivedItems(receivables, this.products, {
      cipher, actor, supplier, knownSkus: input.products.map((p) => p.sku),
    });

    const batch = writeBatch(this.db);
    for (const [productId, delta] of outcome.increments) {
      batch.update(doc(this.db, FirestoreCollections.products, productId), {
        quantity: increment(delta),
        updatedBy: actor.id,
        updatedByName: actor.name,
        updatedAt: serverTimestamp(),
      });
    }
    const totalQuantity = outcome.items.reduce((n, it) => n + it.quantity, 0);
    const totalCost = outcome.items.reduce((n, it) => n + it.unitCost * it.quantity, 0);
    batch.set(doc(collection(this.db, FirestoreCollections.receivings)), {
      referenceNumber,
      supplierId: supplier?.id ?? null,
      supplierName: supplier?.name ?? null,
      items: outcome.items,
      totalCost,
      totalQuantity,
      status: 'completed',
      notes: null,
      createdBy: actor.id,
      createdByName: actor.name,
      completedBy: actor.id,
      createdAt: serverTimestamp(),
      completedAt: serverTimestamp(),
    });
    await batch.commit();

    return {
      referenceNumber,
      received: outcome.received,
      newProducts: outcome.newProducts,
      variations: outcome.variations,
      failed: outcome.failed.map((f) => ({ row: Number(f.ref), message: f.message })),
    };
  }
```

> Match the existing field set of the `batch.set` exactly (compare against the
> current method before replacing — copy any field this snippet omits, e.g. if
> the current code writes additional audit fields). The only intended changes
> are: items now come from `outcome.items`, and stats come from `outcome`.

- [ ] **Step 3: Delete the now-dead `BuiltItem` interface and `productInput` method**

Remove `interface BuiltItem { … }` and the private `productInput(p) { … }` method — both moved into `applyReceivedItems`. Leave `generateReferenceNumber` in place.

- [ ] **Step 4: Typecheck + the engine tests**

Run: `cd web_admin && npm run typecheck && npx vitest run src/data/receiving`
Expected: typecheck exit 0; engine tests PASS. (No repo-level test exists; behavior is covered by Task 2's engine tests + the dev-server smoke at the end.)

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreReceivingRepository.ts
git commit -m "refactor(web): bulkReceive routes through applyReceivedItems (no behavior change)"
```

---

## Task 4: Implement `create` / `update` / `complete` + draft new-product shape

**Files:**
- Modify: `web_admin/src/domain/entities/Receiving.ts` (extend `ReceivingItem` with an optional draft-only `pendingNewProduct`).
- Modify: `web_admin/src/data/converters/receivingConverter.ts` (read/write `pendingNewProduct`).
- Modify: `web_admin/src/domain/repositories/ReceivingRepository.ts` (interface: `update`, `watchDrafts`, `complete` signature).
- Modify: `web_admin/src/data/repositories/FirestoreReceivingRepository.ts` (implement `create`, `update`, `complete`, `watchDrafts`; add a private `resolveDraftItems`).
- Create: `web_admin/src/data/receiving/resolveDraftItems.ts` (pure mapper) + `.test.ts`.

**Interfaces:**
- Produces:
  - `ReceivingItem.pendingNewProduct?: { category: string | null; price: number; reorderLevel: number; autoGenerateSku: boolean } | null`
  - `resolveDraftItems(items: ReceivingItem[], products: Product[]): ReceivableItem[]`
  - `ReceivingRepository.update(id: string, input: ReceivingInput, actorId: string): Promise<void>`
  - `ReceivingRepository.complete(id: string, actor: { id: string; name: string | null }, cipher: CostCode): Promise<void>`
  - `ReceivingRepository.watchDrafts(onData, onError?): Unsubscribe`
  - where `ReceivingInput = Omit<Receiving, 'id' | 'createdAt' | 'completedAt' | 'completedBy'>`.

- [ ] **Step 1: Extend the entity (no test — type change)**

In `web_admin/src/domain/entities/Receiving.ts`, add to `ReceivingItem`:

```ts
  /** Draft-only: a not-yet-created product's spec, created at complete time.
   *  Absent/null on completed-doc items. */
  pendingNewProduct?: {
    category: string | null;
    price: number;
    reorderLevel: number;
    autoGenerateSku: boolean;
  } | null;
```

- [ ] **Step 2: Write the failing test for `resolveDraftItems`**

```ts
// web_admin/src/data/receiving/resolveDraftItems.test.ts
import { describe, expect, it } from 'vitest';
import { resolveDraftItems } from './resolveDraftItems';
import type { Product, ReceivingItem } from '../../domain/entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcode: null, supplierId: null, supplierName: null, baseSku: null, variationNumber: null,
    isActive: true, imageUrl: null, notes: null, searchKeywords: [], createdAt: new Date(),
    updatedAt: null, createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar', ...over,
  } as Product;
}

function draftItem(over: Partial<ReceivingItem> = {}): ReceivingItem {
  return {
    id: 'i1', productId: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', quantity: 10,
    unit: 'kg', unitCost: 180, costCode: 'AB-CD', isNewVariation: false, newProductId: null,
    notes: null, ...over,
  };
}

describe('resolveDraftItems', () => {
  it('existing product, same cost → match', () => {
    const out = resolveDraftItems([draftItem({ unitCost: 180 })], [product({ cost: 180 })]);
    expect(out).toEqual([{ ref: 0, kind: 'match', product: expect.objectContaining({ id: 'p1' }), quantity: 10 }]);
  });

  it('existing product, different cost (> tolerance) → mismatch', () => {
    const out = resolveDraftItems([draftItem({ unitCost: 200 })], [product({ cost: 180 })]);
    expect(out[0]).toMatchObject({ kind: 'mismatch', quantity: 10, cost: 200 });
  });

  it('pendingNewProduct → new', () => {
    const out = resolveDraftItems(
      [draftItem({ productId: '', sku: 'GENERATE', name: 'Squid', unitCost: 90,
        pendingNewProduct: { category: 'Fish', price: 130, reorderLevel: 1, autoGenerateSku: true } })],
      [],
    );
    expect(out[0]).toMatchObject({ kind: 'new', name: 'Squid', cost: 90, price: 130, reorderLevel: 1, autoGenerateSku: true });
  });

  it('existing product missing from inventory → skipped', () => {
    const out = resolveDraftItems([draftItem({ productId: 'gone' })], []);
    expect(out).toEqual([]);
  });
});
```

- [ ] **Step 3: Run it, verify it fails**

Run: `cd web_admin && npx vitest run src/data/receiving/resolveDraftItems.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 4: Write `resolveDraftItems`**

```ts
// web_admin/src/data/receiving/resolveDraftItems.ts
import type { Product, ReceivingItem } from '../../domain/entities';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';

const COST_TOLERANCE = 0.01;

/** Re-derives ReceivableItems from a draft's persisted items against the
 *  CURRENT inventory (so match/mismatch reflects today's product cost). New
 *  items (pendingNewProduct) are resolved straight from the persisted spec.
 *  Existing items whose product no longer exists are dropped. */
export function resolveDraftItems(items: ReceivingItem[], products: Product[]): ReceivableItem[] {
  const byId = new Map(products.map((p) => [p.id, p]));
  const out: ReceivableItem[] = [];
  items.forEach((it, index) => {
    if (it.pendingNewProduct) {
      const np = it.pendingNewProduct;
      out.push({
        ref: index, kind: 'new', sku: it.sku, autoGenerateSku: np.autoGenerateSku,
        name: it.name, category: np.category, unit: it.unit, cost: it.unitCost,
        price: np.price, quantity: it.quantity, reorderLevel: np.reorderLevel,
      });
      return;
    }
    const product = byId.get(it.productId);
    if (!product) return; // product gone — skip
    if (Math.abs(product.cost - it.unitCost) <= COST_TOLERANCE) {
      out.push({ ref: index, kind: 'match', product, quantity: it.quantity });
    } else {
      out.push({ ref: index, kind: 'mismatch', product, quantity: it.quantity, cost: it.unitCost });
    }
  });
  return out;
}
```

- [ ] **Step 5: Run it, verify it passes**

Run: `cd web_admin && npx vitest run src/data/receiving/resolveDraftItems.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 6: Update the converter for `pendingNewProduct`**

In `receivingConverter.ts` `parseItems`, add to the returned item:

```ts
      pendingNewProduct:
        it.pendingNewProduct != null
          ? {
              category: ((it.pendingNewProduct as Record<string, unknown>).category as string | null) ?? null,
              price: Number((it.pendingNewProduct as Record<string, unknown>).price ?? 0),
              reorderLevel: Number((it.pendingNewProduct as Record<string, unknown>).reorderLevel ?? 0),
              autoGenerateSku: Boolean((it.pendingNewProduct as Record<string, unknown>).autoGenerateSku ?? false),
            }
          : null,
```

(The `toFirestore` path already spreads `r.items`, so persisted drafts keep the field — no change needed there. Completed-doc items simply have it `null`.)

- [ ] **Step 7: Update the repository interface**

In `web_admin/src/domain/repositories/ReceivingRepository.ts`:
- Add a type alias `export type ReceivingInput = Omit<Receiving, 'id' | 'createdAt' | 'completedAt' | 'completedBy'>;`
- Replace `create(...)` to `create(input: ReceivingInput, actorId: string): Promise<Receiving>` (if not already this shape).
- Add `update(id: string, input: ReceivingInput, actorId: string): Promise<void>;`
- Replace the `complete` stub signature with `complete(id: string, actor: { id: string; name: string | null }, cipher: CostCode): Promise<void>;`
- Add `watchDrafts(onData: (records: Receiving[]) => void, onError?: (err: Error) => void): Unsubscribe;`
- Import `CostCode` from `../entities`.

- [ ] **Step 8: Implement the four methods in `FirestoreReceivingRepository`**

Add imports: `import { applyReceivedItems } from '@/data/receiving/applyReceivedItems';` (already added in Task 3), `import { resolveDraftItems } from '@/data/receiving/resolveDraftItems';`, `import type { CostCode } from '@/domain/entities';`, and ensure `setDoc`, `updateDoc`, `where`, `getDocs` are imported from `firebase/firestore`.

Replace the `create`/`update`/`complete` stubs with:

```ts
  async create(input: ReceivingInput, actorId: string): Promise<Receiving> {
    const ref = doc(collection(this.db, FirestoreCollections.receivings));
    const items = input.items.map((it) => ({ ...it, id: it.id || crypto.randomUUID() }));
    await setDoc(ref, {
      referenceNumber: input.referenceNumber,
      supplierId: input.supplierId,
      supplierName: input.supplierName,
      items,
      totalCost: input.totalCost,
      totalQuantity: input.totalQuantity,
      status: input.status,
      notes: input.notes,
      createdBy: actorId,
      createdByName: input.createdByName,
      completedBy: input.status === 'completed' ? actorId : null,
      createdAt: serverTimestamp(),
      completedAt: input.status === 'completed' ? serverTimestamp() : null,
    });
    const snap = await getDoc(ref.withConverter(receivingConverter));
    return snap.data()!;
  }

  async update(id: string, input: ReceivingInput, actorId: string): Promise<void> {
    const ref = doc(this.db, FirestoreCollections.receivings, id);
    const snap = await getDoc(ref);
    if (snap.exists() && snap.data().status === 'completed') {
      throw new Error('Cannot edit a completed receiving');
    }
    const items = input.items.map((it) => ({ ...it, id: it.id || crypto.randomUUID() }));
    await updateDoc(ref, {
      supplierId: input.supplierId,
      supplierName: input.supplierName,
      items,
      totalCost: input.totalCost,
      totalQuantity: input.totalQuantity,
      notes: input.notes,
      updatedBy: actorId,
    });
  }

  async complete(
    id: string,
    actor: { id: string; name: string | null },
    cipher: CostCode,
  ): Promise<void> {
    const ref = doc(this.db, FirestoreCollections.receivings, id);
    const snap = await getDoc(ref.withConverter(receivingConverter));
    const receiving = snap.exists() ? snap.data() : null;
    if (!receiving) throw new Error('Receiving not found');
    if (receiving.status === 'completed') return; // idempotent — never double-apply stock

    const products = await this.products.list();
    const receivables = resolveDraftItems(receiving.items, products);
    const outcome = await applyReceivedItems(receivables, this.products, {
      cipher, actor, supplier: receiving.supplierId
        ? { id: receiving.supplierId, name: receiving.supplierName ?? '' } : null,
      knownSkus: products.map((p) => p.sku),
    });

    const batch = writeBatch(this.db);
    for (const [productId, delta] of outcome.increments) {
      batch.update(doc(this.db, FirestoreCollections.products, productId), {
        quantity: increment(delta), updatedBy: actor.id, updatedByName: actor.name,
        updatedAt: serverTimestamp(),
      });
    }
    batch.update(ref, {
      items: outcome.items,
      totalQuantity: outcome.items.reduce((n, it) => n + it.quantity, 0),
      totalCost: outcome.items.reduce((n, it) => n + it.unitCost * it.quantity, 0),
      status: 'completed',
      completedBy: actor.id,
      completedAt: serverTimestamp(),
    });
    await batch.commit();
  }

  watchDrafts(
    onData: (records: Receiving[]) => void,
    onError?: (err: Error) => void,
  ): Unsubscribe {
    return onSnapshot(
      query(this.receivingsCol(), where('status', '==', 'draft'), orderBy('createdAt', 'desc')),
      (snap) => onData(snap.docs.map((d) => d.data())),
      onError,
    );
  }
```

> `ProductRepository.list()` returns all products (used by `useBulkReceiving`);
> confirm the method name (`list`) — the reader showed `productRepo.list()` in
> use. `receivingsCol()` is the existing private helper with the converter.

- [ ] **Step 9: Typecheck + tests**

Run: `cd web_admin && npm run typecheck && npx vitest run src/data`
Expected: typecheck exit 0; all data tests PASS.

- [ ] **Step 10: Commit**

```bash
git add web_admin/src/domain/entities/Receiving.ts web_admin/src/data/converters/receivingConverter.ts web_admin/src/domain/repositories/ReceivingRepository.ts web_admin/src/data/repositories/FirestoreReceivingRepository.ts web_admin/src/data/receiving/resolveDraftItems.ts web_admin/src/data/receiving/resolveDraftItems.test.ts
git commit -m "feat(web): implement receiving create/update/complete + drafts (idempotent)"
```

---

## Task 5: Mutation + query hooks

**Files:**
- Create: `web_admin/src/presentation/hooks/useReceivingMutations.ts` (`useCreateReceiving`, `useUpdateReceiving`, `useCompleteReceiving`).
- Create: `web_admin/src/presentation/hooks/useDraftReceivings.ts`.
- Create: `web_admin/src/presentation/hooks/useReceivingSummary.ts`.

**Interfaces:**
- Consumes: `useReceivingRepo`/`useCostCode`/`useAuthStore`, `useReceivings` (existing), repo methods from Task 4.
- Produces the hooks above (used by Phase 2 pages).

- [ ] **Step 1: Write the mutation hooks**

```ts
// web_admin/src/presentation/hooks/useReceivingMutations.ts
import { useMutation } from '@tanstack/react-query';
import { useReceivingRepo } from '@/infrastructure/di/container';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useAuthStore } from '@/presentation/stores/authStore';
import type { Receiving } from '@/domain/entities';
import type { ReceivingInput } from '@/domain/repositories/ReceivingRepository';

export function useCreateReceiving() {
  const repo = useReceivingRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<Receiving, Error, ReceivingInput>({
    mutationFn: (input) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(input, actor.id);
    },
  });
}

export function useUpdateReceiving() {
  const repo = useReceivingRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, { id: string; input: ReceivingInput }>({
    mutationFn: ({ id, input }) => {
      if (!actor) throw new Error('Not signed in');
      return repo.update(id, input, actor.id);
    },
  });
}

export function useCompleteReceiving() {
  const repo = useReceivingRepo();
  const actor = useAuthStore((s) => s.user);
  const { data: cipher } = useCostCode();
  return useMutation<void, Error, string>({
    mutationFn: (id) => {
      if (!actor) throw new Error('Not signed in');
      if (!cipher) throw new Error('Cost-code settings still loading');
      return repo.complete(id, { id: actor.id, name: actor.displayName }, cipher);
    },
  });
}
```

- [ ] **Step 2: Write the drafts + summary hooks**

```ts
// web_admin/src/presentation/hooks/useDraftReceivings.ts
import { useReceivingRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Receiving } from '@/domain/entities';

/** Realtime list of all open (draft) receivings, any age. */
export function useDraftReceivings() {
  const repo = useReceivingRepo();
  return useFirestoreSubscription<Receiving[]>(
    (onData, onError) => repo.watchDrafts(onData, onError),
    [repo],
  );
}
```

```ts
// web_admin/src/presentation/hooks/useReceivingSummary.ts
import { useMemo } from 'react';
import { startOfMonth, endOfDay } from 'date-fns';
import { useReceivings } from './useReceivings';
import { useDraftReceivings } from './useDraftReceivings';

/** Dashboard cards: this-month completed count + ₱ total, open drafts count. */
export function useReceivingSummary(now: Date) {
  const monthRange = useMemo(() => ({ start: startOfMonth(now), end: endOfDay(now) }), [now]);
  const { data: month, isLoading: lm } = useReceivings(monthRange);
  const { data: drafts, isLoading: ld } = useDraftReceivings();

  const completed = (month ?? []).filter((r) => r.status === 'completed');
  return {
    isLoading: lm || ld,
    completedCount: completed.length,
    receivedTotal: completed.reduce((n, r) => n + r.totalCost, 0),
    draftCount: (drafts ?? []).length,
    recent: (month ?? []).slice(0, 8),
  };
}
```

> `now` is passed in from the page (which creates it once via `useState(() => new Date())`)
> so the hook stays pure/stable.

- [ ] **Step 3: Typecheck**

Run: `cd web_admin && npm run typecheck`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/presentation/hooks/useReceivingMutations.ts web_admin/src/presentation/hooks/useDraftReceivings.ts web_admin/src/presentation/hooks/useReceivingSummary.ts
git commit -m "feat(web): receiving mutation + drafts + summary hooks"
```

---

# Phase 2 — UI (Tasks 6–9)

Consumes Phase 1. Each task ends with `npm run build` green.

## Task 6: Manual entry form (`ReceivingEntryPage`)

**Files:**
- Create: `web_admin/src/presentation/features/receiving/ReceivingEntryPage.tsx`
- Create: `web_admin/src/presentation/features/receiving/useReceivingEntry.ts`
- Modify: `web_admin/src/presentation/router/routePaths.ts` (add `receivingNew: '/receiving/new'`, `receivingNewDraft: '/receiving/new/:id'`).
- Modify: `web_admin/src/presentation/router/routes.tsx` (register the two routes).
- Modify: `web_admin/src/presentation/router/routeGuards.ts` (guard `/receiving/new` and `/receiving/new/:id` with `Permission.receiveStock`).

**Interfaces:**
- Consumes: `useProducts` (`@/presentation/hooks/useProducts`), `useSuppliers`, `useActiveCategories`, `useCostCode`, `filterProducts` (`@/domain/products/filterProducts`), `generateSku` (`@/domain/products/sku`), `useCreateReceiving`/`useUpdateReceiving`/`useCompleteReceiving` (Task 5), `useReceiving` (existing, for resuming a draft by id), `formatMoney`.

The hook owns all logic; the page renders it. The hook builds a draft `ReceivingItem[]` (with `pendingNewProduct` for new lines), computes totals, and exposes `saveDraft()`/`receive()`.

- [ ] **Step 1: Write the entry hook**

```ts
// web_admin/src/presentation/features/receiving/useReceivingEntry.ts
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useProducts } from '@/presentation/hooks/useProducts';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useReceiving } from '@/presentation/hooks/useReceiving';
import { useCreateReceiving, useUpdateReceiving, useCompleteReceiving } from '@/presentation/hooks/useReceivingMutations';
import { useAuthStore } from '@/presentation/stores/authStore';
import { filterProducts } from '@/domain/products/filterProducts';
import type { Product, ReceivingItem } from '@/domain/entities';
import type { ReceivingInput } from '@/domain/repositories/ReceivingRepository';

export interface DraftLine extends ReceivingItem {} // identical shape; new lines carry pendingNewProduct

export function useReceivingEntry() {
  const { id } = useParams();
  const navigate = useNavigate();
  const actor = useAuthStore((s) => s.user);
  const { data: products } = useProducts();
  const { data: suppliers } = useSuppliers();
  const existing = useReceiving(id ?? '');           // resume draft (enabled when id present)
  const create = useCreateReceiving();
  const update = useUpdateReceiving();
  const complete = useCompleteReceiving();

  const [supplierId, setSupplierId] = useState('');
  const [lines, setLines] = useState<DraftLine[]>([]);
  const [search, setSearch] = useState('');
  const [savedId, setSavedId] = useState<string | null>(id ?? null);
  const [error, setError] = useState<string | null>(null);

  // Hydrate from a resumed draft once it loads.
  // (guard with a ref/effect in the page; omitted here for brevity — see Step 2)

  const matches = useMemo(
    () => (search.trim() && products ? filterProducts(products, { search, stock: 'all', category: 'all' }).slice(0, 8) : []),
    [search, products],
  );

  const totals = useMemo(() => ({
    quantity: lines.reduce((n, l) => n + l.quantity, 0),
    cost: lines.reduce((n, l) => n + l.unitCost * l.quantity, 0),
  }), [lines]);

  function addExisting(p: Product, quantity: number, unitCost: number) {
    setLines((ls) => [...ls, {
      id: crypto.randomUUID(), productId: p.id, sku: p.sku, name: p.name, quantity,
      unit: p.unit, unitCost, costCode: p.costCode, isNewVariation: false, newProductId: null,
      notes: null, pendingNewProduct: null,
    }]);
    setSearch('');
  }

  function addNew(spec: {
    name: string; sku: string; autoGenerateSku: boolean; category: string | null;
    unit: string; cost: number; price: number; quantity: number; reorderLevel: number;
  }) {
    setLines((ls) => [...ls, {
      id: crypto.randomUUID(), productId: '', sku: spec.sku, name: spec.name,
      quantity: spec.quantity, unit: spec.unit, unitCost: spec.cost, costCode: '',
      isNewVariation: false, newProductId: null, notes: null,
      pendingNewProduct: { category: spec.category, price: spec.price, reorderLevel: spec.reorderLevel, autoGenerateSku: spec.autoGenerateSku },
    }]);
    setSearch('');
  }

  function removeLine(lineId: string) {
    setLines((ls) => ls.filter((l) => l.id !== lineId));
  }

  function buildInput(status: 'draft' | 'completed'): ReceivingInput {
    const supplier = suppliers?.find((s) => s.id === supplierId) ?? null;
    return {
      referenceNumber: existing.data?.referenceNumber ?? '',  // create() fills a real ref for new docs
      supplierId: supplier?.id ?? null,
      supplierName: supplier?.name ?? null,
      items: lines,
      totalCost: totals.cost,
      totalQuantity: totals.quantity,
      status,
      notes: null,
      createdBy: actor?.id ?? '',
      createdByName: actor?.displayName ?? '',
    } as ReceivingInput;
  }

  async function saveDraft() {
    setError(null);
    try {
      if (savedId) {
        await update.mutateAsync({ id: savedId, input: buildInput('draft') });
      } else {
        const r = await create.mutateAsync(buildInput('draft'));
        setSavedId(r.id);
      }
      navigate('/receiving');
    } catch (e) { setError((e as Error).message); }
  }

  async function receive() {
    setError(null);
    if (lines.length === 0) { setError('Add at least one item.'); return; }
    try {
      let targetId = savedId;
      if (!targetId) {
        const r = await create.mutateAsync(buildInput('draft'));
        targetId = r.id;
      } else {
        await update.mutateAsync({ id: targetId, input: buildInput('draft') });
      }
      await complete.mutateAsync(targetId);
      navigate(`/receiving/${targetId}`);
    } catch (e) { setError((e as Error).message); }
  }

  return {
    suppliers: suppliers ?? [], supplierId, setSupplierId,
    search, setSearch, matches, products: products ?? [],
    lines, addExisting, addNew, removeLine, totals,
    error, existing, savedId,
    isBusy: create.isPending || update.isPending || complete.isPending,
    saveDraft, receive,
  };
}
```

> The create() call writes a real `RCV-…` reference number itself; the form
> passes `referenceNumber: ''` and the repo generates one. Confirm `create`
> calls `generateReferenceNumber()` when `input.referenceNumber` is blank — if
> not, add that to the Task 4 `create` (generate when empty).

- [ ] **Step 2: Write the page (mirrors `BulkReceivingPage`/`InventoryFormPage` styling)**

Create `ReceivingEntryPage.tsx`: a header (`New receiving` + Back link), a supplier `<select>` (options from `suppliers`), a product search box that renders `matches` as a dropdown (each → `addExisting(p, qty, cost)` with qty/cost inputs) plus a `"+ New product '<search>'"` row that reveals the inline new-product fields (name prefilled from `search`, category/unit dropdowns from `useActiveCategories`, price, reorder, cost, qty, auto-SKU toggle via `generateSku`), an items table (line.name · sku · qty · unitCost · line total · remove; show a "new" / "variation?" badge), a totals row, and a footer with **Save draft** and **Receive** buttons (disabled while `isBusy`); render `error` inline. Use the exact Tailwind class patterns from `BulkReceivingPage.tsx` and the field markup from `InventoryFormPage.tsx`. On mount, when `existing.data` is a draft, hydrate `supplierId`/`lines` once (guard with a `useRef` flag).

- [ ] **Step 3: Wire routes + paths + guard**

In `routePaths.ts` add:
```ts
  receivingNew: '/receiving/new',
  receivingNewDraft: '/receiving/new/:id',
```
In `routes.tsx` (above the `bulkReceiving` entry) add:
```tsx
{ path: RoutePaths.receivingNew, element: <ReceivingEntryPage /> },
{ path: RoutePaths.receivingNewDraft, element: <ReceivingEntryPage /> },
```
In `routeGuards.ts` `checkDynamicRoute`, add before the `/receiving/bulk/` check:
```ts
if (path === '/receiving/new' || path.startsWith('/receiving/new/')) {
  return hasPermission(user.role, Permission.receiveStock);
}
```
And add `[RoutePaths.receivingNew, Permission.receiveStock]` to the `protectedRoutes` map.

- [ ] **Step 4: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both succeed.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/receiving/ReceivingEntryPage.tsx web_admin/src/presentation/features/receiving/useReceivingEntry.ts web_admin/src/presentation/router/routePaths.ts web_admin/src/presentation/router/routes.tsx web_admin/src/presentation/router/routeGuards.ts
git commit -m "feat(web): manual receiving entry form (existing + inline new product, drafts)"
```

---

## Task 7: Dashboard (`ReceivingDashboardPage`)

**Files:**
- Create: `web_admin/src/presentation/features/receiving/ReceivingDashboardPage.tsx`
- Modify: `web_admin/src/presentation/router/routes.tsx` (point `RoutePaths.receiving` at the dashboard — see Task 8 for the swap).

**Interfaces:**
- Consumes: `useReceivingSummary` (Task 5), `useDraftReceivings`, `formatMoney`, `ReceivingStatusBadge` (existing), `RoutePaths`.

- [ ] **Step 1: Write the dashboard page**

Header `Receiving` + actions `[+ New Receiving]` (→ `RoutePaths.receivingNew`) and `[Import CSV]` (→ `RoutePaths.bulkReceiving`). Three summary cards from `useReceivingSummary(now)` where `now = useState(() => new Date())[0]`: **This month** (`completedCount` receivings), **Drafts** (`draftCount`, links to a drafts view — for now the history page filtered, or list drafts inline), **Received** (`formatMoney(receivedTotal)`). Below: a **Recent receivings** table from `summary.recent` (reference · date · supplier · items · total · status badge; row → `/receiving/:id`) with a `[View all →]` link to `/receiving/history`. Mirror the card styling from the mobile summary intent and the table markup from the existing list page. Use `LoadingView` while `summary.isLoading`.

- [ ] **Step 2: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both succeed.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/presentation/features/receiving/ReceivingDashboardPage.tsx
git commit -m "feat(web): receiving dashboard (summary cards + recent + actions)"
```

---

## Task 8: Relocate history + move the detail route

**Files:**
- Rename: `web_admin/src/presentation/features/receiving/ReceivingListPage.tsx` → `ReceivingHistoryPage.tsx` (rename the component to `ReceivingHistoryPage`; keep the realtime date-filtered list). Update its row link to `/receiving/${r.id}` and its header (drop the now-duplicated `[Import CSV]`/`[+ New Receiving]` buttons that live on the dashboard, or keep a single "Import CSV" — your call; default: remove them, this is the pure history list).
- Modify: `web_admin/src/presentation/features/receiving/ReceivingDetailPage.tsx` (Back link → `/receiving/history`; its `RoutePaths.receiving` references stay valid).
- Modify: `web_admin/src/presentation/router/routePaths.ts` (add `receivingHistory: '/receiving/history'`, `receivingDetail: '/receiving/:id'`; keep `bulkReceiving`; the old `bulkReceivingDetail` is removed).
- Modify: `web_admin/src/presentation/router/routes.tsx`:
  - `{ path: RoutePaths.receiving, element: <ReceivingDashboardPage /> }` (was `ReceivingListPage`)
  - `{ path: RoutePaths.receivingHistory, element: <ReceivingHistoryPage /> }`
  - `{ path: RoutePaths.bulkReceiving, element: <BulkReceivingPage /> }` (unchanged)
  - `{ path: RoutePaths.receivingDetail, element: <ReceivingDetailPage /> }` (replaces `bulkReceivingDetail`)
  - Order: place `receivingNew`, `receivingNewDraft`, `receivingHistory`, `bulkReceiving` BEFORE `receivingDetail` so the static segments win over `:id`.
- Modify: `web_admin/src/presentation/router/routeGuards.ts`:
  - `protectedRoutes`: add `[RoutePaths.receivingHistory, Permission.viewReceivingHistory]`.
  - `checkDynamicRoute`: replace the `/receiving/bulk/` block. Add `if (path.startsWith('/receiving/') && !path.startsWith('/receiving/new') && !path.startsWith('/receiving/bulk')) return hasPermission(user.role, Permission.viewReceivingHistory);` for `/receiving/:id`.

- [ ] **Step 1: Rename + retarget the list page**

`git mv` the file, rename the export to `ReceivingHistoryPage`, change the row `onClick`/link from `/receiving/bulk/${r.id}` to `/receiving/${r.id}`, and set its "← Back"/title to the History context.

- [ ] **Step 2: Update routePaths, routes, guards** per the file list above.

- [ ] **Step 3: Grep for stale references**

Run: `cd web_admin && grep -rn "bulkReceivingDetail\|ReceivingListPage\|/receiving/bulk/\${" src`
Expected: no matches (all updated). Fix any that remain.

- [ ] **Step 4: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both succeed.

- [ ] **Step 5: Commit**

```bash
git add -A web_admin/src/presentation
git commit -m "feat(web): receiving dashboard landing; relocate history; move detail to /receiving/:id"
```

---

## Task 9: Finalize — sidebar, CSV entry point, full verification, smoke

**Files:**
- Verify: `web_admin/src/presentation/components/common/Sidebar.tsx` (single "Receiving" → `/receiving`; already done — confirm no stale Bulk Receiving entry).
- Verify: the dashboard's `[Import CSV]` is the only nav into `/receiving/bulk`.

- [ ] **Step 1: Reconcile the earlier nav edits**

The working tree already has the `Bulk Receiving` sidebar removal and a `ReceivingListPage` button rename. Confirm the sidebar is correct and, since the import entry now lives on the dashboard, drop the leftover `[Import CSV]`/`[+ New Receiving]` from the history page if not removed in Task 8.

- [ ] **Step 2: Full verification suite**

Run: `cd web_admin && npm run typecheck && npm run test && npm run build`
Expected: typecheck exit 0; all vitest pass; build succeeds.

- [ ] **Step 3: Manual smoke (dev server)**

Run `npm run dev`, sign in, then verify: `/receiving` shows the dashboard (cards + recent + actions); `[+ New Receiving]` → form; add an existing product (match), an existing product at a different cost (mismatch badge), and a brand-new product; **Save draft** → returns to dashboard, Drafts count = 1; reopen the draft from the dashboard, **Receive** → lands on `/receiving/:id` detail; confirm in `/inventory` that the matched product's stock rose, a `<sku>-N` variation exists, and the new product was created. Confirm `[Import CSV]` still opens the CSV flow.

- [ ] **Step 4: Commit**

```bash
git add -A web_admin/src/presentation
git commit -m "chore(web): finalize receiving nav + CSV entry point"
```

---

## Self-review notes (author)

- **Spec coverage:** §2 routes → Tasks 6/8; §3 classification + draft new-product → Tasks 1/4; §4 repo (engine extract + create/update/complete/list/drafts) → Tasks 2/3/4; §5 form → Task 6; §6 dashboard → Task 7; §7 history → Task 8; §8 hooks → Task 5; §9 testing → Tasks 1/2/4 + Task 9 gates. Covered.
- **Type consistency:** `ReceivableItem` (Task 1) is consumed by `applyReceivedItems` (Task 2), `resolveDraftItems` (Task 4), and `classifiedToReceivable`/bulkReceive (Tasks 1/3). `ReceiveContext`/`ReceiveOutcome` defined in Task 2 used in Tasks 3/4. `ReceivingInput` defined in Task 4 used in Tasks 5/6. `complete(id, actor, cipher)` signature consistent across Tasks 4/5.
- **Known confirmations for the implementer** (flagged inline): exact `CostCode` default/constructor for the engine test; that the current `bulkReceive` `batch.set` field set matches the Task 3 snippet; that `create` generates a reference number when `input.referenceNumber` is blank; the exact `ProductRepository.list()` name.
- **Risk:** Task 3 refactors a repo method with no repo-level test — mitigated by Task 2's engine tests and the Task 9 dev-server smoke. Keep the `batch.set` field set identical.
