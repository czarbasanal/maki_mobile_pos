# Barcode Guard — Slice C (web) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the web admin enforce barcode uniqueness via `product_barcodes` claims in Firestore transactions, replacing the advisory `barcodeExists`-then-write check — mirroring the web SKU guard and mobile Slice B, for the web's singular `Product.barcode`.

**Architecture:** `FirestoreProductRepository.create` claims the (optional) barcode inside its existing SKU/product transaction; `updateProductWithSku` is generalized to `updateProductWithClaims` to move the SKU and/or barcode claim; `barcodeExists` reads the claim. `buildProductWrites` and the receiving engine are untouched (receiving products carry no barcode).

**Tech Stack:** TypeScript / React, `firebase/firestore` transactions, Vitest (pure helpers only), Vite.

## Global Constraints

- **`normalizeBarcode(code) = code.trim()`** — case-sensitive; MUST stay byte-identical to `scripts/backfill-product-barcodes.mjs` and the Dart `SkuGenerator.normalizeBarcode`.
- **Web `barcode` stays singular** (0-or-1 claim); `barcodes[]` migration deferred.
- **Claims kept on deactivate**; a barcode claim frees only when the barcode is cleared/changed via an edit.
- Import convention: tested modules (`src/domain/products/sku.ts`) and transitive imports use relative imports — but note `web_admin` has `@/` alias configured in vitest, so `@/` also resolves; follow the file's existing style (`sku.ts` is pure, no imports needed for the new helpers).
- The web has **no Firestore-mock test infra** — repo transaction code is verified by `npm run typecheck` + `npm run build` + manual smoke (same as the web SKU slice C). Only the pure `sku.ts` helpers get unit tests.
- **Rollout (after merge):** re-run `scripts/backfill-product-barcodes.mjs`, then `cd web_admin && npm run build && firebase deploy --only hosting`. No `firestore.rules` change (Slice A shipped it).

---

## Task 1: Foundation — helpers, error, constant, `barcodeExists`

**Files:**
- Modify: `web_admin/src/domain/products/sku.ts` (add `normalizeBarcode`, `isClaimableBarcode`)
- Modify: `web_admin/src/domain/products/sku.test.ts` (add tests for both)
- Modify: `web_admin/src/data/errors.ts` (add `DuplicateBarcodeError`)
- Modify: `web_admin/src/infrastructure/firebase/collections.ts` (add `productBarcodes`)
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts` (`barcodeExists` gains `excludeProductId?`)
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts` (`barcodeExists` reads the claim)

**Interfaces:**
- Produces: `normalizeBarcode(string): string`, `isClaimableBarcode(string): boolean`, `DuplicateBarcodeError`, `FirestoreCollections.productBarcodes`, `barcodeExists(barcode, excludeProductId?): Promise<boolean>`.

- [ ] **Step 1: Write the failing helper tests**

Append to `web_admin/src/domain/products/sku.test.ts`:
```ts
import { normalizeBarcode, isClaimableBarcode } from './sku';

describe('normalizeBarcode', () => {
  it('trims and preserves case (NOT uppercased)', () => {
    expect(normalizeBarcode(' Abc/12 ')).toBe('Abc/12');
    expect(normalizeBarcode('4800123')).toBe('4800123');
    expect(normalizeBarcode('abc')).toBe('abc');
  });
});

describe('isClaimableBarcode', () => {
  it('accepts a normal code', () => {
    expect(isClaimableBarcode('4800123456789')).toBe(true);
  });
  it('rejects empty, slash, dot/dotdot, and dunder keys', () => {
    expect(isClaimableBarcode('')).toBe(false);
    expect(isClaimableBarcode('a/b')).toBe(false);
    expect(isClaimableBarcode('.')).toBe(false);
    expect(isClaimableBarcode('..')).toBe(false);
    expect(isClaimableBarcode('__x__')).toBe(false);
  });
});
```
(Add `normalizeBarcode, isClaimableBarcode` to the existing `from './sku'` import at the top rather than a second import line.)

- [ ] **Step 2: Run them — verify they fail**

Run: `cd web_admin && npx vitest run src/domain/products/sku.test.ts`
Expected: FAIL — `normalizeBarcode`/`isClaimableBarcode` not exported.

- [ ] **Step 3: Add the helpers to `sku.ts`**

After `isValidSku` in `web_admin/src/domain/products/sku.ts`:
```ts
/**
 * Canonical key for barcode-uniqueness claims
 * (`product_barcodes/{normalizeBarcode(code)}`). MUST stay byte-identical to
 * scripts/backfill-product-barcodes.mjs (`String(s).trim()`) and the Dart
 * SkuGenerator.normalizeBarcode — case-sensitive (barcodes are exact tokens).
 */
export function normalizeBarcode(code: string): string {
  return code.trim();
}

/**
 * Whether a (already-normalized, non-empty) barcode key can be a Firestore
 * doc-id, so it can be claimed. Empty keys mean "no barcode" (skip, not error).
 */
export function isClaimableBarcode(key: string): boolean {
  if (key.length === 0 || key.length > 1500) return false;
  if (key === '.' || key === '..') return false;
  if (key.includes('/')) return false;
  return !/^__.*__$/.test(key);
}
```

- [ ] **Step 4: Run them — verify they pass**

Run: `cd web_admin && npx vitest run src/domain/products/sku.test.ts`
Expected: PASS.

- [ ] **Step 5: Add `DuplicateBarcodeError`**

In `web_admin/src/data/errors.ts`, after `DuplicateSkuError`:
```ts
/**
 * Thrown by the product repository when a barcode's product_barcodes claim is
 * already taken. Message matches the string InventoryFormPage maps to a field
 * error.
 */
export class DuplicateBarcodeError extends Error {
  constructor(message = 'A product with this barcode already exists') {
    super(message);
    this.name = 'DuplicateBarcodeError';
  }
}
```

- [ ] **Step 6: Add the collection constant**

In `web_admin/src/infrastructure/firebase/collections.ts`, after `productSkus: 'product_skus',`:
```ts
  productBarcodes: 'product_barcodes',
```

- [ ] **Step 7: Widen `barcodeExists` in the interface**

In `web_admin/src/domain/repositories/ProductRepository.ts`, change the `barcodeExists` signature to:
```ts
  barcodeExists(barcode: string, excludeProductId?: string): Promise<boolean>;
```

- [ ] **Step 8: Rewrite `barcodeExists` to read the claim**

In `FirestoreProductRepository.ts`, replace `barcodeExists` (keep `getByBarcode` as-is) and add the imports `normalizeBarcode` (from `@/domain/products/sku`) and `FirestoreCollections.productBarcodes` is already covered by the existing `FirestoreCollections` import:
```ts
  async barcodeExists(barcode: string, excludeProductId?: string): Promise<boolean> {
    const snap = await getDoc(
      doc(this.db, FirestoreCollections.productBarcodes, normalizeBarcode(barcode)),
    );
    if (!snap.exists()) return false;
    if (excludeProductId === undefined) return true;
    return (snap.data() as { productId?: string }).productId !== excludeProductId;
  }
```
Add to the `sku` import at the top of the file: `import { normalizeBarcode } from '@/domain/products/sku';` (or extend an existing import from that module).

- [ ] **Step 9: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass.

- [ ] **Step 10: Commit**

```bash
git add web_admin/src/domain/products/sku.ts web_admin/src/domain/products/sku.test.ts web_admin/src/data/errors.ts web_admin/src/infrastructure/firebase/collections.ts web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web): barcode-guard foundation — normalizeBarcode, claim const, barcodeExists reads claim"
```

---

## Task 2: `create` claims the barcode in its transaction

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts` (`create`)

**Interfaces:**
- Consumes: `normalizeBarcode`/`isClaimableBarcode` (Task 1), `DuplicateBarcodeError`, `FirestoreCollections.productBarcodes`, `buildProductWrites`/`newProductId` (existing).

- [ ] **Step 1: Rewrite `create` to also claim the barcode**

Replace the `create` method body:
```ts
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    const productId = newProductId(this.db);
    const { productRef, productData, claimRef, claimData } = buildProductWrites(
      this.db,
      input,
      actorId,
      productId,
    );
    const barcodeKey = input.barcode ? normalizeBarcode(input.barcode) : '';
    if (barcodeKey && !isClaimableBarcode(barcodeKey)) {
      throw new Error(`Invalid barcode "${input.barcode}" — it can't contain "/".`);
    }
    const barcodeClaimRef = barcodeKey
      ? doc(this.db, FirestoreCollections.productBarcodes, barcodeKey)
      : null;

    await runTransaction(this.db, async (tx) => {
      const claim = await tx.get(claimRef);
      const barcodeClaim = barcodeClaimRef ? await tx.get(barcodeClaimRef) : null;
      if (claim.exists()) throw new DuplicateSkuError();
      if (barcodeClaim?.exists()) throw new DuplicateBarcodeError();
      tx.set(productRef, productData);
      tx.set(claimRef, claimData);
      if (barcodeClaimRef) {
        tx.set(barcodeClaimRef, {
          barcode: barcodeKey,
          productId,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      }
    });

    const created = await this.getById(productId);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }
```
Ensure these are imported in the file: `isClaimableBarcode` (add to the `@/domain/products/sku` import next to `normalizeBarcode`), `DuplicateBarcodeError` (from `@/data/errors`, next to `DuplicateSkuError`), and `serverTimestamp` (already used by `updateProductWithSku`, so already imported).

- [ ] **Step 2: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass.

- [ ] **Step 3: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreProductRepository.ts
git commit -m "feat(web): createProduct claims the barcode in its transaction"
```

---

## Task 3: Generalize update to `updateProductWithClaims` (move SKU and/or barcode claim)

**Files:**
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts` (rename + signature)
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts` (`updateProductWithSku` → `updateProductWithClaims`)
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts` (`UpdateProductInput`, `useUpdateProduct`)
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx` (pass `oldBarcode`)

**Interfaces:**
- Consumes: Task 1/2 helpers, `DuplicateBarcodeError`, `barcodeExists(_, excludeId)`.
- Produces: `updateProductWithClaims(id, input, sku, barcode, actorId, actorName)`.

- [ ] **Step 1: Rename + widen the interface method**

In `web_admin/src/domain/repositories/ProductRepository.ts`, replace the `updateProductWithSku(...)` declaration with:
```ts
  updateProductWithClaims(
    id: string,
    input: ProductUpdateInput,
    sku: { old: string; next: string; changed: boolean },
    barcode: { old: string | null; next: string | null; changed: boolean },
    actorId: string,
    actorName: string | null,
  ): Promise<void>;
```

- [ ] **Step 2: Reimplement in the repository**

In `FirestoreProductRepository.ts`, replace `updateProductWithSku` with:
```ts
  async updateProductWithClaims(
    id: string,
    input: ProductUpdateInput,
    sku: { old: string; next: string; changed: boolean },
    barcode: { old: string | null; next: string | null; changed: boolean },
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    // Variation children (baseSku == old) must be read OUTSIDE the transaction
    // (Firestore transactions can't run queries) — only needed on a SKU rename.
    const children = sku.changed
      ? await getDocs(
          query(
            collection(this.db, FirestoreCollections.products),
            where('baseSku', '==', sku.old),
          ),
        )
      : null;

    const newBarcodeKey = barcode.next ? normalizeBarcode(barcode.next) : '';
    if (barcode.changed && newBarcodeKey && !isClaimableBarcode(newBarcodeKey)) {
      throw new Error(`Invalid barcode "${barcode.next}" — it can't contain "/".`);
    }
    const oldBarcodeKey = barcode.old ? normalizeBarcode(barcode.old) : '';

    const newSkuClaimRef = doc(
      this.db,
      FirestoreCollections.productSkus,
      normalizeSku(sku.next),
    );
    const newBarcodeClaimRef =
      barcode.changed && newBarcodeKey
        ? doc(this.db, FirestoreCollections.productBarcodes, newBarcodeKey)
        : null;

    await runTransaction(this.db, async (tx) => {
      // Reads first.
      const newSkuClaim = sku.changed ? await tx.get(newSkuClaimRef) : null;
      const newBarcodeClaim = newBarcodeClaimRef ? await tx.get(newBarcodeClaimRef) : null;
      if (
        sku.changed &&
        newSkuClaim!.exists() &&
        (newSkuClaim!.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateSkuError();
      }
      if (
        newBarcodeClaim?.exists() &&
        (newBarcodeClaim.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateBarcodeError();
      }
      // Writes. updateData writes both the new sku and new barcode from input.
      tx.update(
        doc(this.db, FirestoreCollections.products, id),
        this.updateData(input, actorId),
      );
      if (sku.changed) {
        for (const child of children!.docs) {
          tx.update(child.ref, {
            baseSku: sku.next,
            updatedBy: actorId,
            updatedByName: actorName,
            updatedAt: serverTimestamp(),
          });
        }
        tx.delete(doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.old)));
        tx.set(newSkuClaimRef, {
          sku: sku.next,
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      }
      if (barcode.changed) {
        if (oldBarcodeKey) {
          tx.delete(doc(this.db, FirestoreCollections.productBarcodes, oldBarcodeKey));
        }
        if (newBarcodeClaimRef) {
          tx.set(newBarcodeClaimRef, {
            barcode: newBarcodeKey,
            productId: id,
            claimedBy: actorId,
            claimedAt: serverTimestamp(),
          });
        }
      }
    });
  }
```
(`input` already carries the new `sku` and `barcode` from the form patch, so `this.updateData(input, actorId)` writes them — no need for the old `{ ...input, sku: newSku }` override.)

- [ ] **Step 3: Update the mutation hook**

In `web_admin/src/presentation/hooks/useProductMutations.ts`:
- Add `oldBarcode: string | null;` to the `UpdateProductInput` interface.
- Replace the `useUpdateProduct` `mutationFn` body:
```ts
    mutationFn: async ({ id, oldSku, oldBarcode, patch, priceChange }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || null;
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: actorName };
      const newSku = (fullPatch.sku ?? oldSku) as string;
      const skuChanged = fullPatch.sku !== undefined && fullPatch.sku !== oldSku;
      const newBarcode = (fullPatch.barcode ?? null) as string | null;
      const barcodeChanged = newBarcode !== oldBarcode;

      if (skuChanged || barcodeChanged) {
        if (skuChanged && (await repo.skuExists(newSku, id))) {
          throw new Error('A product with this SKU already exists');
        }
        if (barcodeChanged && newBarcode && (await repo.barcodeExists(newBarcode, id))) {
          throw new Error('A product with this barcode already exists');
        }
        await repo.updateProductWithClaims(
          id,
          fullPatch,
          { old: oldSku, next: newSku, changed: skuChanged },
          { old: oldBarcode, next: newBarcode, changed: barcodeChanged },
          actor.id,
          actorName,
        );
      } else {
        await repo.update(id, fullPatch, actor.id);
      }

      if (priceChange) {
        try {
          await repo.recordPriceChange(id, {
            price: priceChange.price,
            cost: priceChange.cost,
            changedBy: actor.id,
            reason: priceChange.reason,
          });
        } catch {
          // best-effort, mirroring mobile — never fail the save on a history write
        }
      }
      qc.invalidateQueries({ queryKey: ['product', id] });
    },
```

- [ ] **Step 4: Pass `oldBarcode` from the form**

In `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`, in the edit-path `update.mutateAsync({...})` call, add `oldBarcode: target.barcode,` alongside `oldSku: target.sku,`:
```ts
      await update.mutateAsync({
        id: target.id,
        oldSku: target.sku,
        oldBarcode: target.barcode,
        patch,
        priceChange: reason ? { price: priceNum, cost: costNum, reason } : null,
      });
```
(The existing `barcode already exists` → `setError('barcode', …)` mapping already handles the new error message.)

- [ ] **Step 5: Typecheck + build + helper tests**

Run: `cd web_admin && npm run typecheck && npm run test && npm run build`
Expected: typecheck clean; all vitest pass (incl. the new `sku.test.ts` cases); build succeeds.

- [ ] **Step 6: Manual verify (dev server)**

`npm run dev`, sign in. (a) Create two products with the same barcode → 2nd blocked ("barcode already exists" on the field). (b) Edit a product's barcode to one already taken → blocked. (c) Clear a product's barcode (save), then set that same barcode on another product → succeeds (freed). (d) SKU rename still works (claim moves + variation children relink).

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/domain/repositories/ProductRepository.ts web_admin/src/data/repositories/FirestoreProductRepository.ts web_admin/src/presentation/hooks/useProductMutations.ts web_admin/src/presentation/features/inventory/InventoryFormPage.tsx
git commit -m "feat(web): updateProductWithClaims moves SKU and/or barcode claim"
```

---

## Self-review notes (author)

- **Spec coverage:** §2 helpers/error/const → Task 1; §3 create claim → Task 2; §4 update generalization → Task 3; §5 barcodeExists + create pre-check → Task 1 (read) + existing `useCreateProduct` pre-check (unchanged); §6 testing/rollout → Task 1 helper tests + build gates + the rollout note in Global Constraints. Covered.
- **Type/contract consistency:** `normalizeBarcode = code.trim()` matches the script + Dart; claim shape `{barcode, productId, claimedBy, claimedAt}` matches `product_barcodes` (Slice A). `updateProductWithClaims` signature is identical in the interface (Task 3 Step 1) and impl (Step 2) and call site (Step 3). `barcodeExists(_, excludeProductId?)` widened in interface (Task 1 Step 7) + impl (Step 8) + used in the hook (Task 3 Step 3); the existing `useCreateProduct` call `barcodeExists(input.barcode)` still type-checks (optional param).
- **Reads-before-writes:** both transactions read all claims (SKU + barcode) before any write; old-claim deletes are blind (valid after the reads).
- **No web Firestore test infra** — repo tx verified by typecheck/build + manual (Task 3 Step 6), matching the web SKU slice C precedent. Pure helpers are unit-tested.
- **Receiving engine / `buildProductWrites` untouched** — receiving products have no barcode, so nothing to claim there.
