# SKU-uniqueness guard Slice C (web admin) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the mobile SKU guard in the React/TS web admin — every SKU-write path (`create`, SKU `rename`, Bulk-Receiving variations) atomically reserves/moves its `product_skus/{normalizeSku(sku)}` claim via `runTransaction`, and `skuExists` reads that claim.

**Architecture:** Add `normalizeSku`/`isValidSku` to the SKU domain module (TDD'd, pure). Convert `FirestoreProductRepository.create` and `updateProductWithSku` from `addDoc`/`writeBatch` to `runTransaction` with a `tx.get(claimRef)` gate; switch `skuExists` to a claim-doc read; add bounded retry-on-collision to the Bulk-Receiving variation create. A shared `DuplicateSkuError` signals a taken claim.

**Tech Stack:** React/Vite/TS, Firebase JS v9 modular SDK (`runTransaction(db, fn)`, `doc`, `tx.get/set/update/delete`), vitest. Web admin is admin-only. Spec: `docs/superpowers/specs/2026-06-01-sku-guard-slice-c-web-design.md`.

**Testing approach (chosen):** the web admin has **no** Firestore-repository tests (data layer untested by design — no Firebase mock/emulator). So **only Task 1 (pure domain) is test-first**; the repository/receiving changes (Tasks 2–5) are verified by `npm run typecheck` + `npm run build` + `npm run test` (domain suite stays green) + an adversarial review + parity with the TDD-proven mobile Slice B. Run all commands from inside `web_admin/`.

---

## Context verified (exact current code)

- `web_admin/src/infrastructure/firebase/collections.ts` — `FirestoreCollections` object (no `product_skus`); `Subcollections.priceHistory`.
- `web_admin/src/domain/products/sku.ts` — exports `slugifyForSku`, `generateSku`; **no** `normalizeSku`/`isValidSku`. Tests in `sku.test.ts` (vitest, pure).
- `web_admin/src/data/repositories/FirestoreProductRepository.ts`:
  - imports from `firebase/firestore` include `addDoc, collection, doc, getDoc, getDocs, increment, limit, onSnapshot, orderBy, query, serverTimestamp, updateDoc, where, writeBatch` (lines 4–20). `writeBatch` is used **only** in `updateProductWithSku`; `addDoc` is used in `create` and `recordPriceChange`; `limit` in `skuExists` and `listPriceHistory`.
  - `skuExists` (96–99): `getDocs(query(this.col(), where('sku','==',sku), limit(2)))` → `.some(d => d.id !== excludeId)`.
  - `updateProductWithSku` (106–133): `writeBatch`; `batch.update(parent, updateData({...input, sku:newSku}))`; query children `where('baseSku','==',oldSku)`; `batch.update(child.ref, {...})`; `batch.commit()`.
  - `create` (140–148): `addDoc(collection(db, products), createData(input, actorId))` → `getById`.
  - `createData` (157–188) / `updateData` (190–213) private helpers.
- `web_admin/src/data/repositories/FirestoreReceivingRepository.ts` — `bulkReceive`; the `'mismatch'` branch (67–90) creates a variation: `nextVariationNumber(base, knownSkus)` → `variationSku` → `knownSkus.push(sku)` → `this.products.create(...)`. Imports `Receiving` from `@/domain/entities`; `nextVariationNumber, variationSku` from `@/domain/receiving/variations`.
- `web_admin/src/domain/entities` exports `Product`.
- Web is admin-only; `product_skus` rules (Slice A) already allow admin create/delete.

## File Structure

- **Create:** `web_admin/src/data/errors.ts` (`DuplicateSkuError`).
- **Modify:** `web_admin/src/domain/products/sku.ts` (+`normalizeSku`,`isValidSku`);
  `web_admin/src/infrastructure/firebase/collections.ts` (+`productSkus`);
  `web_admin/src/data/repositories/FirestoreProductRepository.ts` (`create`,`skuExists`,
  `updateProductWithSku`, imports); `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`
  (variation retry, imports).
- **Test:** `web_admin/src/domain/products/sku.test.ts` (+`normalizeSku`/`isValidSku`).

---

## Task 1: `normalizeSku` + `isValidSku` (domain, test-first)

**Files:**
- Modify: `web_admin/src/domain/products/sku.ts`
- Test: `web_admin/src/domain/products/sku.test.ts`

- [ ] **Step 1: Write the failing tests**

In `web_admin/src/domain/products/sku.test.ts`, change the import on line 2 to:

```ts
import { generateSku, slugifyForSku, normalizeSku, isValidSku } from './sku';
```

Append at the end of the file:

```ts
describe('normalizeSku', () => {
  it('trims and uppercases', () => {
    expect(normalizeSku('  abc-1 ')).toBe('ABC-1');
    expect(normalizeSku('ABC-1')).toBe('ABC-1');
    expect(normalizeSku('aBc-1')).toBe('ABC-1');
  });

  it('is idempotent', () => {
    const once = normalizeSku('  abc-1 ');
    expect(normalizeSku(once)).toBe(once);
  });
});

describe('isValidSku', () => {
  it('accepts letters, numbers, and hyphens up to 50 chars', () => {
    expect(isValidSku('ABC-1')).toBe(true);
    expect(isValidSku('A'.repeat(50))).toBe(true);
  });

  it('rejects empty, slash, whitespace, and over-50', () => {
    expect(isValidSku('')).toBe(false);
    expect(isValidSku('PRD/001')).toBe(false);
    expect(isValidSku('A B')).toBe(false);
    expect(isValidSku('A'.repeat(51))).toBe(false);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `web_admin/`): `npm run test -- sku`
Expected: FAIL — `normalizeSku`/`isValidSku` are not exported from `./sku`.

- [ ] **Step 3: Implement the helpers**

In `web_admin/src/domain/products/sku.ts`, append:

```ts
/**
 * Canonical key for product_skus claims. MUST stay byte-identical to
 * scripts/backfill-product-skus.mjs and mobile SkuGenerator.normalizeSku
 * (`trim().toUpperCase()`), or the guard and the backfilled claims key
 * differently and uniqueness silently breaks.
 */
export function normalizeSku(sku: string): string {
  return sku.trim().toUpperCase();
}

/**
 * Code128-safe SKU and a valid Firestore doc-id subset (non-empty, <= 50 chars,
 * letters/digits/hyphens only). Used to reject SKUs that can't key a claim doc.
 */
export function isValidSku(sku: string): boolean {
  return sku.length > 0 && sku.length <= 50 && /^[A-Za-z0-9-]+$/.test(sku);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run test -- sku`
Expected: PASS (all `sku.test.ts` cases green).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/sku.ts web_admin/src/domain/products/sku.test.ts
git commit -m "feat(web): normalizeSku + isValidSku (SKU claim key + doc-id guard)"
```

---

## Task 2: `product_skus` plumbing + `DuplicateSkuError` + `create()` transaction

**Files:**
- Modify: `web_admin/src/infrastructure/firebase/collections.ts`
- Create: `web_admin/src/data/errors.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Add the `productSkus` collection constant**

In `web_admin/src/infrastructure/firebase/collections.ts`, add to the `FirestoreCollections`
object (after `settings: 'settings',`):

```ts
  // SKU-uniqueness claim collection (Slice A). Keyed by normalizeSku(sku).
  productSkus: 'product_skus',
```

- [ ] **Step 2: Create the shared error**

Create `web_admin/src/data/errors.ts`:

```ts
/**
 * Thrown by the product repository when a SKU's product_skus claim is already
 * taken. Message matches the string InventoryFormPage maps to a field error;
 * the Bulk-Receiving retry catches this type to bump the variation number.
 */
export class DuplicateSkuError extends Error {
  constructor(message = 'A product with this SKU already exists') {
    super(message);
    this.name = 'DuplicateSkuError';
  }
}
```

- [ ] **Step 3: Update `FirestoreProductRepository` imports**

In `web_admin/src/data/repositories/FirestoreProductRepository.ts`, change the `firebase/firestore`
import block (lines 4–20) to **add `runTransaction`** (keep `writeBatch` for now — it's still used
by `updateProductWithSku` until Task 4 removes it):

```ts
import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
```

Add two imports below the existing `import ... from '@/domain/products/searchKeywords';` line (27):

```ts
import { normalizeSku, isValidSku } from '@/domain/products/sku';
import { DuplicateSkuError } from '@/data/errors';
```

- [ ] **Step 4: Replace `create()` with the claim transaction**

Replace the `create` method (lines 140–148) with:

```ts
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    // The SKU becomes a product_skus claim doc-id (normalizeSku(sku)); reject
    // SKUs that can't form a valid doc-id ('/', empty) before the transaction
    // so it fails with a clear message rather than an opaque Firestore error.
    if (!isValidSku(normalizeSku(input.sku))) {
      throw new Error(
        `Invalid SKU "${input.sku}" — use letters, numbers, and hyphens only.`,
      );
    }
    const ref = doc(collection(this.db, FirestoreCollections.products));
    const claimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(input.sku),
    );
    await runTransaction(this.db, async (tx) => {
      const claim = await tx.get(claimRef);
      if (claim.exists()) throw new DuplicateSkuError();
      tx.set(ref, this.createData(input, actorId));
      tx.set(claimRef, {
        sku: input.sku,
        productId: ref.id,
        claimedBy: actorId,
        claimedAt: serverTimestamp(),
      });
    });
    const created = await this.getById(ref.id);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }
```

- [ ] **Step 5: Typecheck**

Run (from `web_admin/`): `npm run typecheck`
Expected: no errors. (`writeBatch` is still imported and used by the unchanged
`updateProductWithSku`; `runTransaction` is now used by `create`. Task 4 removes `writeBatch`.)

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/infrastructure/firebase/collections.ts web_admin/src/data/errors.ts web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web): claim product_skus atomically in create() (close SKU TOCTOU)"
```

---

## Task 3: `skuExists()` → claim-doc read

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Replace `skuExists()`**

Replace the `skuExists` method (lines 96–99) with:

```ts
  async skuExists(sku: string, excludeId?: string): Promise<boolean> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku)),
    );
    if (!snap.exists()) return false;
    if (excludeId === undefined) return true;
    return (snap.data() as { productId?: string }).productId !== excludeId;
  }
```

- [ ] **Step 2: Typecheck**

Run: `npm run typecheck`
Expected: no errors. (`limit` is still used by `listPriceHistory`, so its import stays.)

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web): skuExists reads product_skus claim (case-insensitive)"
```

---

## Task 4: `updateProductWithSku()` rename → claim-move transaction

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`

- [ ] **Step 1: Replace `updateProductWithSku()` with a transaction**

Replace the `updateProductWithSku` method (lines 106–133) with:

```ts
  async updateProductWithSku(
    id: string,
    input: ProductUpdateInput,
    oldSku: string,
    newSku: string,
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    // Variation children must be read OUTSIDE the transaction (Firestore
    // transactions can't run queries) — same as the previous writeBatch.
    const children = await getDocs(
      query(
        collection(this.db, FirestoreCollections.products),
        where('baseSku', '==', oldSku),
      ),
    );
    const oldClaimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(oldSku),
    );
    const newClaimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(newSku),
    );
    // Move the parent's claim (delete old, set new), update the parent, and
    // re-point every child's baseSku — atomically.
    await runTransaction(this.db, async (tx) => {
      const newClaim = await tx.get(newClaimRef);
      if (
        newClaim.exists() &&
        (newClaim.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateSkuError();
      }
      tx.update(
        doc(this.db, FirestoreCollections.products, id),
        this.updateData({ ...input, sku: newSku }, actorId),
      );
      for (const child of children.docs) {
        tx.update(child.ref, {
          baseSku: newSku,
          updatedBy: actorId,
          updatedByName: actorName,
          updatedAt: serverTimestamp(),
        });
      }
      // delete-then-set is safe even when old == new (case-only rename): same
      // ref → the set wins, re-keying the claim's sku field.
      tx.delete(oldClaimRef);
      tx.set(newClaimRef, {
        sku: newSku,
        productId: id,
        claimedBy: actorId,
        claimedAt: serverTimestamp(),
      });
    });
  }
```

- [ ] **Step 2: Remove the now-unused `writeBatch` import**

In the `firebase/firestore` import block, remove the `writeBatch,` line (it was only used by the
old `updateProductWithSku`).

- [ ] **Step 3: Typecheck + build**

Run: `npm run typecheck && npm run build`
Expected: no errors, build succeeds. (Confirms no remaining `writeBatch` reference and the
transaction types check out.)

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web): move product_skus claim atomically on SKU rename"
```

---

## Task 5: Bulk-Receiving variation retry-on-collision

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`

- [ ] **Step 1: Import `Product` and `DuplicateSkuError`**

In `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`, change the entities import
(line 19) to add `Product`:

```ts
import type { Receiving, Product } from '@/domain/entities';
```

Add below the `variations` import (line 25):

```ts
import { DuplicateSkuError } from '@/data/errors';
```

- [ ] **Step 2: Wrap the variation create in a bounded retry**

Replace the `'mismatch'` branch (lines 67–90, from `} else if (c.status === 'mismatch' && c.existing) {`
through the `items.push({ ... });` that closes it) with:

```ts
        } else if (c.status === 'mismatch' && c.existing) {
          const base = c.existing.baseSku ?? c.existing.sku;
          const costCode = encodeCostCode(cipher, r.cost);
          // The claim guard makes a colliding variation create throw
          // DuplicateSkuError. Bump the number and retry so concurrent
          // receiving self-heals instead of failing the whole batch.
          let n = nextVariationNumber(base, knownSkus);
          let created: Product | undefined;
          let sku = '';
          for (let attempt = 0; attempt < 5; attempt += 1) {
            sku = variationSku(base, n);
            try {
              created = await this.products.create(
                this.productInput({
                  sku, name: c.existing.name, cost: r.cost, costCode, price: c.existing.price,
                  quantity: r.quantity, reorderLevel: c.existing.reorderLevel, unit: c.existing.unit,
                  category: c.existing.category, supplierId: c.existing.supplierId,
                  supplierName: c.existing.supplierName, baseSku: base, variationNumber: n, actor,
                }),
                actor.id,
              );
              break;
            } catch (e) {
              if (e instanceof DuplicateSkuError) {
                n += 1;
                continue;
              }
              throw e;
            }
          }
          if (!created) {
            throw new Error(`Could not allocate a unique variation SKU for "${base}"`);
          }
          knownSkus.push(sku);
          await this.products.recordPriceChange(created.id, {
            price: c.existing.price, cost: r.cost, changedBy: actor.id, reason: 'receiving',
          });
          variations += 1;
          items.push({
            productId: c.existing.id, sku, name: c.existing.name, quantity: r.quantity,
            unit: c.existing.unit, unitCost: r.cost, costCode, isNewVariation: true,
            newProductId: created.id,
          });
        } else {
```

(The new-product `else` branch below is unchanged; a `DuplicateSkuError` there is a genuine
duplicate and is correctly caught by the surrounding `try` → `failed.push`.)

- [ ] **Step 3: Typecheck + build**

Run: `npm run typecheck && npm run build`
Expected: no errors, build succeeds.

- [ ] **Step 4: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreReceivingRepository.ts
git commit -m "feat(web): retry-on-collision for Bulk-Receiving variations (self-heals)"
```

---

## Task 6: Full verification + finish branch

**Files:** none (verification only).

- [ ] **Step 1: Typecheck, test, build**

Run (from `web_admin/`): `npm run typecheck && npm run test && npm run build`
Expected: typecheck clean, all vitest suites green (incl. the new `normalizeSku`/`isValidSku`
tests), build succeeds.

- [ ] **Step 2: Finish the branch**

Announce: "I'm using the finishing-a-development-branch skill to complete this work." Then follow
superpowers:finishing-a-development-branch (verify tests, present merge/PR options).

---

## Self-Review notes (author)

- **Spec coverage:** §4.1 helpers → Task 1; §4.2 `DuplicateSkuError` + §4.7 constant + §4.3 create →
  Task 2; §4.4 skuExists → Task 3; §4.5 rename → Task 4; §4.6 bulk-receive retry → Task 5; §8/§9
  verification → Task 6. §7 hard-delete (none) → no task, by design.
- **Placeholder scan:** every step has full code + exact commands. The only nuance is the
  `writeBatch` import ordering (keep in Task 2, remove in Task 4) — called out explicitly.
- **Type/name consistency:** `normalizeSku`/`isValidSku` (Task 1) reused in Tasks 2–4;
  `productSkus`/`DuplicateSkuError` defined in Task 2, reused in Tasks 3–5; claim fields
  `{sku, productId, claimedBy, claimedAt}` identical across create (Task 2) + rename (Task 4) and
  match the Slice-A backfill + mobile Slice B; `DuplicateSkuError` thrown by create/rename and
  caught by the bulk-receive retry (Task 5).
- **Testing limitation (accepted):** Tasks 2–5 have no repo unit test (no Firebase mock/emulator in
  the web admin); verified by typecheck + build + domain suite + adversarial review + mobile parity.
- **Out of scope:** barcode TOCTOU, stored-SKU casing, web rename not appending old SKU to barcode,
  adding a Firestore test harness.
- **Rollout:** re-run `scripts/backfill-product-skus.mjs` immediately before deploying (carried from
  Slice B — handled at deploy time, not in this plan).
