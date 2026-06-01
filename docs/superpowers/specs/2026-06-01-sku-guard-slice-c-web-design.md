# SKU-uniqueness guard — Slice C (web admin) — Design

**Date:** 2026-06-01
**Status:** Approved (design); ready for writing-plans.
**Predecessors:** [Slice A](2026-06-01-sku-guard-rules-backfill-design.md) — `product_skus` claim
collection + backfill, **live in prod**. [Slice B](2026-06-01-sku-guard-slice-b-mobile-design.md)
— mobile guard, **merged to origin/main**, fully TDD-tested.
**This slice:** mirror the mobile guard in the React/TS web admin (`web_admin/`).

## 1. Problem

The web admin reserves a SKU with a read-then-write (TOCTOU) race, identical to the
pre-Slice-B mobile bug. `FirestoreProductRepository.create()` calls `addDoc()` after the
`useCreateProduct` hook checks `skuExists()`; `updateProductWithSku()` (admin SKU rename) uses a
`writeBatch` after a `skuExists()` pre-check; Bulk Receiving creates variation SKUs through the
same `create()` with **no** retry on collision. None of these is atomic, so concurrent writers can
create duplicate SKUs.

Slice A's `product_skus` claim collection and backfill are already live. Slice C makes the **web**
client reserve/move the claim inside a Firestore transaction on every SKU-write path.

## 2. Locked policy (from Slices A/B)

- `normalizeSku(sku) = sku.trim().toUpperCase()` — byte-identical to
  `scripts/backfill-product-skus.mjs` and mobile `SkuGenerator.normalizeSku`.
- Claim doc `product_skus/{normalizeSku(sku)}` → `{ sku, productId, claimedBy, claimedAt }`. Stored
  product `sku` keeps user case; only the claim *key* normalizes.
- Claim kept on deactivate; freed only by an admin rename (claim moves) or hard delete (none on
  web — see §7).

## 3. Architecture

A transactional claim is the only construct that closes a TOCTOU. Slice C routes the three web
SKU-write chokepoints through the **Firebase JS v9 modular** `runTransaction(db, fn)` with
`tx.get(claimRef)` as the gate, exactly mirroring mobile Slice B. The web admin is **admin-only**
(`ProtectedRoute`), and the Slice-A claim rules already permit admin create/delete — **no rules
change**. Web uses a singular `barcode` field (not the mobile `barcodes` array); barcodes stay
out of scope.

## 4. Components

### 4.1 Domain helpers — `web_admin/src/domain/products/sku.ts` (TDD'd, pure)
```ts
/** Canonical key for product_skus claims. MUST equal scripts/backfill-product-skus.mjs
 *  and mobile SkuGenerator.normalizeSku: trim + uppercase. */
export function normalizeSku(sku: string): string {
  return sku.trim().toUpperCase();
}

/** Code128-safe + valid Firestore doc-id subset (non-empty, <=50, [A-Za-z0-9-]). */
export function isValidSku(sku: string): boolean {
  return sku.length > 0 && sku.length <= 50 && /^[A-Za-z0-9-]+$/.test(sku);
}
```
Both get real vitest tests in `sku.test.ts` (the codebase's established domain-test pattern).

### 4.2 `DuplicateSkuError` — shared data-layer error
A small `class DuplicateSkuError extends Error` (e.g. `web_admin/src/data/errors.ts`) with
`message = 'A product with this SKU already exists'` (so the existing `InventoryFormPage`
`msg.includes('sku already exists')` match still sets the field error). Thrown by `create()` and
the rename on a taken claim; caught by the bulk-receive retry.

### 4.3 `create()` → transaction (`FirestoreProductRepository`)
- Guard `if (!isValidSku(normalizeSku(input.sku))) throw new Error('Invalid SKU …')` before the tx
  — rejects `/`/empty SKUs that would otherwise crash the claim doc-id (the bug Slice B's review
  caught; `addDoc` previously tolerated such SKUs as plain fields).
- `const ref = doc(collection(this.db, FirestoreCollections.products));` (pre-allocated id).
- `const claimRef = doc(this.db, FirestoreCollections.productSkus, normalizeSku(input.sku));`
- `await runTransaction(this.db, async (tx) => { const claim = await tx.get(claimRef); if
  (claim.exists()) throw new DuplicateSkuError(); tx.set(ref, this.createData(input, actorId));
  tx.set(claimRef, { sku: input.sku, productId: ref.id, claimedBy: actorId, claimedAt:
  serverTimestamp() }); });`
- `return this.getById(ref.id)` (read-back, unchanged).
- Both `useCreateProduct` and `FirestoreReceivingRepository.bulkReceive` call `create()`, so both
  are guarded.

### 4.4 `skuExists()` → claim-doc read
```ts
async skuExists(sku: string, excludeId?: string): Promise<boolean> {
  const snap = await getDoc(doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku)));
  if (!snap.exists()) return false;
  if (excludeId === undefined) return true;
  return snap.data().productId !== excludeId;
}
```
Case-insensitive, consistent with the guard. The `useCreateProduct`/`useUpdateProduct` hooks keep
calling it as an advisory pre-check (fast inline field error); the transaction is the authority.

### 4.5 `updateProductWithSku()` rename → transaction (was `writeBatch`)
- Read children (`where('baseSku', '==', oldSku)`) **before** the tx (as the batch does).
- `oldClaimRef = doc(db, productSkus, normalizeSku(oldSku))`,
  `newClaimRef = doc(db, productSkus, normalizeSku(newSku))`.
- `runTransaction`: `const nc = await tx.get(newClaimRef); if (nc.exists() && nc.data().productId
  !== id) throw new DuplicateSkuError(); tx.update(parentRef, updateData({...input, sku: newSku}));
  for (child) tx.update(child.ref, { baseSku: newSku, updatedBy, updatedByName, updatedAt });
  tx.delete(oldClaimRef); tx.set(newClaimRef, { sku: newSku, productId: id, claimedBy, claimedAt });`
- Only the parent's claim moves; children keep their own SKUs/claims. delete-then-set is safe when
  `normalizeSku(old) === normalizeSku(new)` (case-only rename → same ref, set wins).

### 4.6 Bulk-receive variation retry (`FirestoreReceivingRepository.bulkReceive`)
Wrap the per-variation `this.products.create(...)` in a bounded loop (≤5):
```ts
let n = nextVariationNumber(base, knownSkus);
let created: Product | undefined;
for (let attempt = 0; attempt < 5; attempt++) {
  const sku = variationSku(base, n);
  try {
    created = await this.products.create(this.productInput({ ...fields, sku, baseSku: base,
      variationNumber: n, actor }), actor.id);
    knownSkus.push(sku);
    break;
  } catch (e) {
    if (e instanceof DuplicateSkuError) { n += 1; continue; } // bump & retry
    throw e;
  }
}
if (!created) throw new Error(`Could not allocate a unique variation SKU for "${base}"`);
```
On a claim collision the number is bumped locally (`knownSkus` is in-memory), so concurrent
receiving self-heals instead of hard-failing mid-batch.

### 4.7 Plumbing — web `FirestoreCollections`
Add `productSkus = 'product_skus'` to `web_admin/src/.../FirestoreCollections` (the constants
object `create()` already uses for `products`).

## 5. Data flow (create)

UI/BulkReceiving → `repo.create(input, actorId)`: validate SKU → `runTransaction` `tx.get(claim)`
absent → `tx.set(product)` + `tx.set(claim)` commit atomically. Concurrent same-SKU create: the
loser's `tx.get` (on Firestore's auto-retry) sees the claim → `DuplicateSkuError` → hook surfaces
the existing "SKU already exists" field error, or the bulk-receive retry bumps the number.

## 6. Error handling

`DuplicateSkuError` (message matches the UI string) propagates from `create()`/rename. The invalid-
SKU guard throws a plain `Error('Invalid SKU …')`. No new UI code: `InventoryFormPage` already maps
"sku already exists" to a field error; the bulk-receive result already aggregates failures.

## 7. Hard delete

No hard-delete path on web — only soft `deactivate`/`reactivate`. Slice C adds **no** claim-freeing
code; claims free only via the rename-move (§4.5). Matches keep-on-deactivate.

## 8. Testing & verification

Per the chosen approach (consistent with the web admin's deliberate choice not to unit-test
Firestore repositories — the data layer currently has **zero** repo tests):
- **Real vitest unit tests** for `normalizeSku` and `isValidSku` in `sku.test.ts` (trim, uppercase,
  idempotent; valid/invalid incl. `/`, empty, >50, lowercase).
- **The repository/receiving transaction code has NO repo-level unit test** (no Firebase mock or
  emulator exists, and adding one is out of scope). It is verified by: `npm run typecheck`, `npm run
  build`, `npm run test` (domain suite stays green), an **adversarial review of the diff**, and
  **parity with the TDD-proven mobile Slice B**. This limitation is stated explicitly and accepted.

## 9. Acceptance criteria

- `npm run typecheck`, `npm run build`, `npm run test` all clean/green.
- New `normalizeSku`/`isValidSku` unit tests pass (incl. edge cases).
- `create()`, `skuExists()`, `updateProductWithSku()` use the claim transaction; `bulkReceive`
  retries on `DuplicateSkuError`; `DuplicateSkuError` + `productSkus` constant added.
- No `firestore.rules` change; no UI change.
- Adversarial review of the diff surfaces no unrefuted high-severity finding.

## 10. Out of scope

- Barcode TOCTOU (`barcodeExists` → write) — needs its own claim collection + rules + backfill.
- Retroactively normalizing stored SKUs.
- Web rename not appending old SKU to `barcode` — pre-existing behavior, unchanged.
- Adding a Firestore mock/emulator test harness.

## 11. Rollout note (carried from Slice B)

The guard assumes every existing product has a claim. The Slice-A backfill is point-in-time; any
product created via the old app / pre-C web after the backfill lacks a claim. **Re-run
`scripts/backfill-product-skus.mjs` immediately before deploying Slice C** (and the Slice B app
build), so no live product is left unclaimed when the strict guard goes live.

## 12. Affected files

- **Modify:** `web_admin/src/domain/products/sku.ts` (+`normalizeSku`,`isValidSku`);
  `web_admin/src/.../FirestoreCollections` (+`productSkus`);
  `web_admin/src/data/repositories/FirestoreProductRepository.ts` (`create`,`skuExists`,
  `updateProductWithSku`); `web_admin/src/data/repositories/FirestoreReceivingRepository.ts`
  (`bulkReceive` retry).
- **Create:** `web_admin/src/data/errors.ts` (`DuplicateSkuError`).
- **Test:** `web_admin/src/domain/products/sku.test.ts` (`normalizeSku`/`isValidSku`).
- **Unchanged but verified:** `useProductMutations.ts`, `InventoryFormPage.tsx` (advisory pre-check
  + error mapping still work; no behavior change).
