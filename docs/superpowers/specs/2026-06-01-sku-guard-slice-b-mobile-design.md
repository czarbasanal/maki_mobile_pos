# SKU-uniqueness guard — Slice B (mobile) — Design

**Date:** 2026-06-01
**Status:** Approved (design); ready for writing-plans.
**Predecessor:** [Slice A](2026-06-01-sku-guard-rules-backfill-design.md) — `product_skus` claim
collection rules + backfill, **live in prod** (6/6 products claimed, 0 collisions).
**Successor:** Slice C (web admin guard) — mirrors this in `FirestoreProductRepository`.

## 1. Problem

Mobile product creation reserves a SKU with a read-then-write (TOCTOU) race:
`createProduct` calls `skuExists()` and then `_productsRef.add()`
(`lib/data/repositories/product_repository_impl.dart:22-77`). Two concurrent creates with the
same SKU both pass the check and both write. The same gap exists for the synthesized SKUs of
variations created during receiving, where `getNextVariationNumber` ("scan siblings, max+1") is
non-atomic and receiving has no retry.

Slice A added the fix's foundation: a `product_skus/{normalizeSku(sku)}` claim collection
(one doc per in-use SKU), enforced by Firestore rules and backfilled for every existing product.
**Slice B makes the mobile client actually use it** — atomically claiming/moving the SKU inside a
transaction on every SKU-write path.

## 2. Locked policy (from Slice A)

- **Normalization:** `normalizeSku(sku) = sku.trim().toUpperCase()` (case-insensitive uniqueness).
  Must be byte-identical to `scripts/backfill-product-skus.mjs`.
- **Claim doc:** `product_skus/{normalizeSku(sku)}` → `{ sku, productId, claimedBy, claimedAt }`.
  The stored product `sku` keeps the **user-entered case**; only the claim *key* is normalized
  (matches the backfill, which stored original case and keyed uppercase).
- **Lifecycle:** a claim is **kept on deactivate** (soft delete). It is freed only by an admin
  **rename** (claim moves old→new) or a **hard delete** (none exists on mobile — see §6).

## 3. Architecture

A transactional claim is the only construct that closes a TOCTOU (advisory-only checks and a
Cloud-Function arbiter were rejected in Slice A). Slice B routes all three mobile SKU-write
chokepoints through `runTransaction`, with `tx.get(claimRef)` as the atomic gate. No new
collections, no rules change (Slice A's rules already permit these reads/creates/deletes for
admin|staff), no UI change (the product form already catches `DuplicateSkuException`).

`fake_cloud_firestore` v4.0.1 supports `runTransaction` (already exercised by
`SaleRepositoryImpl` tests), so every path below is unit-testable.

## 4. Components

### 4.1 `SkuGenerator.normalizeSku` — new
**File:** `lib/core/utils/sku_generator.dart` (alongside existing `isValidSku`, `slugifyForSku`).

```dart
/// Canonical key for SKU-uniqueness claims. MUST match
/// scripts/backfill-product-skus.mjs (`s.trim().toUpperCase()`).
static String normalizeSku(String sku) => sku.trim().toUpperCase();
```

Single source of truth for every claim key in the app.

### 4.2 `createProduct` → transaction
**File:** `lib/data/repositories/product_repository_impl.dart` (`createProduct`, lines 22-77).

- Replace `_productsRef.add(...)` with a **pre-allocated** ref: `final docRef = _productsRef.doc();`
  (still an auto-generated id).
- Compute `final claimRef = _skusRef.doc(SkuGenerator.normalizeSku(product.sku));` where
  `_skusRef = _firestore.collection(FirestoreCollections.productSkus)` (new constant
  `'product_skus'` in `lib/core/constants/firestore_collections.dart`).
- Wrap the writes in `_firestore.runTransaction((tx) async { ... })`:
  - `final claim = await tx.get(claimRef);`
  - if `claim.exists` → `throw DuplicateSkuException(sku: product.sku);`
  - `tx.set(docRef, productModel.toCreateMap(createdBy, createdByDisplayName: createdByName));`
  - `tx.set(claimRef, { 'sku': product.sku, 'productId': docRef.id, 'claimedBy': createdBy,
    'claimedAt': FieldValue.serverTimestamp() });`
- The **barcode** advisory check (`barcodeExists`) stays **before** the transaction — barcodes are
  out of scope (no Slice-A claim collection for them; see §7).
- `recordPriceChange(...)` stays **after** the transaction, best-effort (unchanged) — it writes a
  `price_history` subcollection doc and must not abort the create.
- `return product.copyWith(id: docRef.id);` (unchanged shape).

> Note: `tx.get` must precede `tx.set` (Firestore: all reads before writes). The barcode loop and
> price-history write stay outside so the transaction body is reads-then-writes only.
>
> **Contention correctness:** when two creates race on a *new* SKU, both `tx.get(claimRef)` see it
> absent. The first to commit wins; the second's commit fails its read precondition, so Firestore
> **automatically re-runs the transaction body**, where `tx.get` now sees the claim and the body
> throws `DuplicateSkuException` (an app-thrown error aborts without retry and propagates). This
> auto-retry is what makes the absent-then-created window safe — it is not a TOCTOU.

### 4.3 `updateProduct` rename → transaction
**File:** `lib/data/repositories/product_repository_impl.dart` (`updateProduct`, SKU-change branch
~lines 388-404, currently a `writeBatch`).

The current batch updates the parent and re-points every variation child (`baseSku == old`) to
the new SKU. Convert it to a transaction that **also** moves the parent's claim:

- Before the transaction (cannot query inside one): `final children = await _productsRef
  .where('baseSku', isEqualTo: prior.sku).get();` (same read the batch does today).
- `final oldClaimRef = _skusRef.doc(normalizeSku(prior.sku));`
  `final newClaimRef = _skusRef.doc(normalizeSku(product.sku));`
- `_firestore.runTransaction((tx) async {`
  - `final newClaim = await tx.get(newClaimRef);`
  - if `newClaim.exists && newClaim.data()?['productId'] != product.id` →
    `throw DuplicateSkuException(sku: product.sku);`
  - `tx.update(_productsRef.doc(product.id), updateMap);`
  - for each `child` in `children.docs`: `tx.update(child.reference, { 'baseSku': product.sku,
    'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': updatedBy,
    if (updatedByName != null) 'updatedByName': updatedByName });`
  - `tx.delete(oldClaimRef);`
  - `tx.set(newClaimRef, { 'sku': product.sku, 'productId': product.id, 'claimedBy': updatedBy,
    'claimedAt': FieldValue.serverTimestamp() });`
  - `});`
- Children keep their own `sku` (`old-1`, `old-2`) and their own claims (`OLD-1`, …) untouched —
  only their `baseSku` pointer moves, so **only the parent's claim relocates**.
- The old SKU stays scannable (already appended to the parent's `barcodes` by
  `UpdateProductUseCase`); its claim is correctly freed because no product has `sku == old`
  anymore. Barcodes are not claim-guarded, so a future product may reuse the old SKU.
- Non-SKU updates keep the plain `_productsRef.doc(id).update(updateMap)` path (no transaction).

> **Reads-before-writes:** `tx.get(newClaimRef)` is the only in-transaction read; the children
> were read before the transaction (as the batch does). `tx.get(oldClaimRef)` is **not** needed —
> `tx.delete` of a possibly-absent doc is a no-op-safe write (defensive: if the old claim is
> missing, the rename still completes and creates the new claim, self-healing the backfill gap).

### 4.4 `createVariation` retry-on-collision
**File:** `lib/data/repositories/product_repository_impl.dart` (`createVariation`, ~lines 587-624).

Wrap `getNextVariationNumber` + `createProduct` in a bounded retry:

```
for (attempt in 1..maxAttempts /* 5 */):
  number = await getNextVariationNumber(baseSku)
  sku    = SkuGenerator.generateVariation(baseSku, number)
  try   { return await createProduct(product: variation(number, sku), ...) }
  catch (DuplicateSkuException) { continue }   // a concurrent writer took this number
throw DatabaseException('Could not allocate a unique variation SKU for $baseSku after N tries')
```

The guard makes the colliding create throw `DuplicateSkuException` atomically; the retry recomputes
the next free number. This lets concurrent receiving completions self-heal instead of failing the
whole receiving (`receiving_repository_impl.dart` calls `createVariation` with no retry today).

### 4.5 Advisory `skuExists` → claim-doc read
**File:** `lib/data/repositories/product_repository_impl.dart` (`skuExists`, ~lines 713-728).

Replace the `where('sku', isEqualTo: sku).limit(2)` query with a claim-doc read:

```dart
final snap = await _skusRef.doc(SkuGenerator.normalizeSku(sku)).get();
if (!snap.exists) return false;
if (excludeProductId == null) return true;
return snap.data()?['productId'] != excludeProductId;
```

Case-insensitive, consistent with the guard, preserves `excludeProductId` semantics. Callers:
`UpdateProductUseCase` (admin rename pre-validation) gets a friendly pre-save error; the
transaction stays the atomic authority. `createProduct`'s own pre-check is now redundant with the
in-transaction `tx.get` and is **removed** (the transaction throws `DuplicateSkuException` directly).

## 5. Data flow (create, happy + race)

1. UI → `ProductOperationsNotifier.createProduct` → `CreateProductUseCase.execute`
   (asserts `Permission.addProduct`) → `repository.createProduct`.
2. Repo: barcode advisory check → `runTransaction`: `tx.get(claim)` absent → `tx.set(product)` +
   `tx.set(claim)` commit atomically.
3. Concurrent same-SKU create: the second transaction's `tx.get(claim)` now sees the doc (or the
   commit fails the create-contention check) → `DuplicateSkuException` → use case returns
   `failure`, UI shows the existing "SKU already exists" message.

## 6. Hard delete

There is **no** hard-delete path on mobile — `ProductRepository` exposes only
`deactivateProduct` (soft, `isActive=false`); no `products` doc is ever `.delete()`d. Therefore
Slice B adds **no** claim-freeing code. Claims are freed only by the rename-move in §4.3. This is
consistent with the locked "keep claim on deactivate" policy.

## 7. Out of scope

- **Barcode TOCTOU** (`barcodeExists` → write) — identical race, but needs its own claim collection
  + rules + backfill (a future "Slice A-bis"). Not touched here.
- **Web admin** (`FirestoreProductRepository`) — Slice C.
- **Retroactively uppercasing stored SKUs** — the stored `sku` keeps user case; only the claim key
  normalizes (matches the backfill). No data migration.
- **Switching `updateProduct`'s non-SKU path to a transaction** — unchanged plain update.

## 8. Risks & bounds

- **Transaction write count:** rename writes `parent + N children + 2 claim ops` in one
  transaction (Firestore cap 500). Far under for this shop (6 products); noted as a known bound.
- **Pre-existing case-collisions:** the Slice-A backfill reported `collisions = 0`, so no two live
  SKUs normalize equal today; the guard is safe to switch on.
- **Backfill gap self-heal:** a rename whose old claim is unexpectedly missing still completes
  (delete-missing is safe) and writes the new claim.

## 9. Acceptance criteria

- `flutter analyze` clean; `flutter test` green (new + existing).
- New/updated unit tests (all via `FakeFirebaseFirestore`):
  - `normalizeSku`: trim, uppercase, idempotent.
  - `createProduct`: writes product **and** claim atomically; duplicate SKU (mixed case) →
    `DuplicateSkuException`; claim's `productId` matches the new doc id.
  - `updateProduct` rename: claim moves `OLD→NEW` (`OLD` absent, `NEW` present, same `productId`),
    children relinked; rename onto an existing SKU → throws and changes nothing.
  - `createVariation`: pre-seeded next-number claim → retries to the next free number; exhausted →
    `DatabaseException`.
  - `skuExists`: claim-doc semantics including `excludeProductId`.
- No change to `firestore.rules` (Slice A already covers it) and no UI changes.

## 10. Affected files

- **Modify:** `lib/core/utils/sku_generator.dart` (add `normalizeSku`);
  `lib/core/constants/firestore_collections.dart` (add `productSkus = 'product_skus'`);
  `lib/data/repositories/product_repository_impl.dart` (`createProduct`, `updateProduct`,
  `createVariation`, `skuExists`; add `_skusRef`).
- **Test:** `test/core/utils/sku_generator_test.dart` (or new `normalizeSku` group);
  `test/data/repositories/product_repository_impl_test.dart` (claim/transaction tests).
- **Unchanged but verified:** `update_product_usecase.dart`, `create_product_usecase.dart`,
  `receiving_repository_impl.dart`, `product_form_screen.dart` (no behavior change;
  `createVariation` now self-heals under contention).
