# SKU-uniqueness guard Slice B (mobile) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every mobile path that writes or changes a product SKU atomically reserve/move its `product_skus/{normalizeSku(sku)}` claim inside a Firestore transaction, replacing the read-then-write (TOCTOU) `skuExists` check.

**Architecture:** Route the three SKU-write chokepoints in `ProductRepositoryImpl` through `runTransaction` with `tx.get(claimRef)` as the atomic gate: `createProduct` (claim on create), `updateProduct` rename (move claim old→new alongside the existing variation-relink), and `createVariation` (retry-on-collision). Switch the advisory `skuExists` to a case-insensitive claim-doc read. No rules change (Slice A covers them), no UI change.

**Tech Stack:** Flutter/Dart, `cloud_firestore`, `fake_cloud_firestore` v4.0.1 (supports `runTransaction`). Spec: `docs/superpowers/specs/2026-06-01-sku-guard-slice-b-mobile-design.md`.

---

## Context verified (exact current code)

- `lib/data/repositories/product_repository_impl.dart`:
  - `createProduct` (lines 21-77): plain `_productsRef.add()`; pre-checks `skuExists` (line 29) then `barcodeExists` (loop 35-44); best-effort `recordPriceChange` after (57-67); wrapped in `try { } on FirebaseException`.
  - `updateProduct` (370-446): SKU-change branch (388-404) uses a `_firestore.batch()` to update the parent + relink variation children (`baseSku == prior.sku`); else plain `update` (406).
  - `createVariation` (586-624): `getNextVariationNumber` → `generateVariation` → `createProduct`; wrapped in `try { } on FirebaseException`.
  - `getNextVariationNumber` (626-640): query siblings (`baseSku ==`), return max `variationNumber` + 1.
  - `skuExists` (712-733): `where('sku', isEqualTo: sku).limit(2)` then `excludeProductId` filter.
  - Collection ref: `_productsRef` getter (16-17). Field `_firestore` (11).
- `lib/core/constants/firestore_collections.dart`: has `products`, `priceHistory`, etc. (no `product_skus`).
- `lib/core/utils/sku_generator.dart`: has `isValidSku`, `slugifyForSku`, `generateVariation`; **no** `normalizeSku`.
- `lib/core/errors/exceptions.dart`: `DuplicateSkuException({required String sku, ...})` (256-262, extends `DuplicateEntryException`); `DatabaseException({required String message, String? code, dynamic originalError, ...})` (130-137).
- `lib/domain/entities/product_entity.dart`: ctor required `id, sku, name, costCode, cost, price, quantity, reorderLevel, unit, isActive, createdAt`; optional `baseSku, variationNumber, barcodes, ...` (97-123). `copyWith` exists (used by current `createVariation`).
- Tests: `test/data/repositories/product_repository_impl_test.dart` uses `FakeFirebaseFirestore` + a local `seedProduct(Map)` helper; tests live under `group('ProductRepositoryImpl.updateProduct SKU cascade')`. `SkuGenerator` tests live in `test/core/utils/utils_test.dart` under `group('SkuGenerator', ...)` (line 50).
- **Fallout check:** every other test that references `skuExists`/`createProduct` (`create_product_usecase_test.dart`, `update_product_usecase_test.dart`, `product_form_screen_test.dart`, receiving tests, `integration_test/sku_edit_flow_test.dart`) **mocks the repository interface** (mocktail `when(() => repo.skuExists(...))`). The interface signatures are unchanged, so impl changes do not affect them. Only `product_repository_impl_test.dart` exercises the real impl.

## File Structure

- **Modify** `lib/core/utils/sku_generator.dart` — add `normalizeSku`.
- **Modify** `lib/core/constants/firestore_collections.dart` — add `productSkus = 'product_skus'`.
- **Modify** `lib/data/repositories/product_repository_impl.dart` — add `_skusRef`; rewrite `createProduct`, `updateProduct` (rename branch), `createVariation`, `skuExists`.
- **Test** `test/core/utils/utils_test.dart` — `normalizeSku` cases.
- **Test** `test/data/repositories/product_repository_impl_test.dart` — claim/transaction tests (add imports for `ProductEntity` + exceptions).

---

## Task 1: `SkuGenerator.normalizeSku`

**Files:**
- Modify: `lib/core/utils/sku_generator.dart`
- Test: `test/core/utils/utils_test.dart` (inside `group('SkuGenerator', ...)`)

- [ ] **Step 1: Write the failing test**

In `test/core/utils/utils_test.dart`, inside `group('SkuGenerator', () {`, after the
`getNextVariationNumber returns correct number` test (line 69), add:

```dart
    test('normalizeSku trims and uppercases', () {
      expect(SkuGenerator.normalizeSku('  abc-1 '), 'ABC-1');
      expect(SkuGenerator.normalizeSku('ABC-1'), 'ABC-1');
      expect(SkuGenerator.normalizeSku('aBc-1'), 'ABC-1');
    });

    test('normalizeSku is idempotent', () {
      final once = SkuGenerator.normalizeSku('  abc-1 ');
      expect(SkuGenerator.normalizeSku(once), once);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/utils_test.dart`
Expected: FAIL — `The method 'normalizeSku' isn't defined for the type 'SkuGenerator'`.

- [ ] **Step 3: Implement `normalizeSku`**

In `lib/core/utils/sku_generator.dart`, after `slugifyForSku` (ends line 76), add:

```dart
  /// Canonical key for SKU-uniqueness claims (`product_skus/{normalizeSku(sku)}`).
  /// MUST stay byte-identical to scripts/backfill-product-skus.mjs
  /// (`String(s).trim().toUpperCase()`), or the mobile guard and the backfilled
  /// claims will key differently and uniqueness will silently break.
  static String normalizeSku(String sku) => sku.trim().toUpperCase();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/utils_test.dart`
Expected: PASS (all SkuGenerator tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/sku_generator.dart test/core/utils/utils_test.dart
git commit -m "feat(mobile): SkuGenerator.normalizeSku (trim+uppercase claim key)"
```

---

## Task 2: `createProduct` → transactional SKU claim

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart`
- Modify: `lib/data/repositories/product_repository_impl.dart`
- Test: `test/data/repositories/product_repository_impl_test.dart`

- [ ] **Step 1: Add test imports + a product builder**

At the top of `test/data/repositories/product_repository_impl_test.dart`, add two imports
after the existing `product_repository_impl.dart` import (line 4):

```dart
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
```

Inside `main()`, after the `seedProduct` helper (after line 34), add a builder:

```dart
  ProductEntity buildProduct({
    String id = '',
    required String sku,
    String name = 'Test',
    String? baseSku,
    int? variationNumber,
  }) {
    return ProductEntity(
      id: id,
      sku: sku,
      name: name,
      costCode: '',
      cost: 1.0,
      price: 2.0,
      quantity: 0,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
      baseSku: baseSku,
      variationNumber: variationNumber,
    );
  }
```

- [ ] **Step 2: Write the failing tests**

At the end of `main()` (after the existing `group('ProductRepositoryImpl.updateProduct SKU cascade', ...)` closes, before the final `}`), add:

```dart
  group('ProductRepositoryImpl.createProduct SKU claim', () {
    test('writes the product and a normalized SKU claim', () async {
      final created = await repository.createProduct(
        product: buildProduct(sku: 'abc-1'),
        createdBy: 'admin-1',
        createdByName: 'Admin',
      );

      expect((await repository.getProductById(created.id))!.sku, 'abc-1');

      final claim =
          await firestore.collection('product_skus').doc('ABC-1').get();
      expect(claim.exists, true);
      expect(claim.data()!['productId'], created.id);
      expect(claim.data()!['sku'], 'abc-1');
    });

    test('rejects a duplicate SKU case-insensitively', () async {
      await repository.createProduct(
        product: buildProduct(sku: 'ABC-1'),
        createdBy: 'admin-1',
      );

      expect(
        () => repository.createProduct(
          product: buildProduct(sku: 'abc-1'),
          createdBy: 'admin-1',
        ),
        throwsA(isA<DuplicateSkuException>()),
      );
    });
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: FAIL — the claim doc `product_skus/ABC-1` does not exist (createProduct still uses `.add()` and writes no claim), so `claim.exists` is `false` and the duplicate is not rejected.

- [ ] **Step 4: Add the `product_skus` collection constant**

In `lib/core/constants/firestore_collections.dart`, after the `voidRequests` constant (line 56), add:

```dart
  /// Product SKU-uniqueness claim collection. One doc per in-use SKU, keyed by
  /// SkuGenerator.normalizeSku(sku); reserved atomically on product create /
  /// SKU rename. See docs/superpowers/specs/2026-06-01-sku-guard-*.
  static const String productSkus = 'product_skus';
```

- [ ] **Step 5: Add the `_skusRef` getter**

In `lib/data/repositories/product_repository_impl.dart`, after the `_productsRef` getter
(line 17), add:

```dart
  CollectionReference<Map<String, dynamic>> get _skusRef =>
      _firestore.collection(FirestoreCollections.productSkus);
```

- [ ] **Step 6: Rewrite `createProduct` to claim in a transaction**

Replace the body of `createProduct` (lines 27-76, the whole `try { ... } on FirebaseException catch (e) { ... }`) with:

```dart
    try {
      // Barcode advisory check (barcodes are not claim-guarded — out of scope).
      for (final code in product.barcodes) {
        if (code.isEmpty) continue;
        if (await barcodeExists(barcode: code)) {
          throw DuplicateEntryException(
            field: 'barcodes',
            value: code,
            message: 'A product with barcode "$code" already exists',
          );
        }
      }

      final productModel = ProductModel.fromEntity(product);
      final docRef = _productsRef.doc(); // pre-allocate id for the transaction
      final claimRef = _skusRef.doc(SkuGenerator.normalizeSku(product.sku));

      // Atomically reserve the SKU claim and write the product together. The
      // tx.get gate + Firestore's auto-retry on contention closes the TOCTOU
      // the old skuExists()-then-add() left open.
      await _firestore.runTransaction((tx) async {
        final claim = await tx.get(claimRef);
        if (claim.exists) {
          throw DuplicateSkuException(sku: product.sku);
        }
        tx.set(
          docRef,
          productModel.toCreateMap(createdBy, createdByDisplayName: createdByName),
        );
        tx.set(claimRef, {
          'sku': product.sku,
          'productId': docRef.id,
          'claimedBy': createdBy,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      });

      // Initial price history — best-effort (unchanged). A failure here must not
      // abort or roll back the already-committed product+claim.
      try {
        await recordPriceChange(
          productId: docRef.id,
          price: product.price,
          cost: product.cost,
          changedBy: createdBy,
          reason: 'Initial price',
        );
      } catch (_) {
        // Swallowed by design.
      }

      return product.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create product: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
```

(Note: the old `skuExists()` pre-check is removed — the in-transaction `tx.get` replaces it. `DuplicateSkuException` is not a `FirebaseException`, so it propagates past the outer catch unchanged.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: PASS (createProduct group green; the existing updateProduct cascade group still green).

- [ ] **Step 8: Commit**

```bash
git add lib/core/constants/firestore_collections.dart lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): claim product_skus atomically in createProduct (close SKU TOCTOU)"
```

---

## Task 3: `skuExists` → claim-doc read

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart`
- Test: `test/data/repositories/product_repository_impl_test.dart`

- [ ] **Step 1: Write the failing tests**

At the end of `main()` in `product_repository_impl_test.dart`, add:

```dart
  group('ProductRepositoryImpl.skuExists (claim-backed)', () {
    test('true when a claim exists (case-insensitive), false otherwise', () async {
      await firestore.collection('product_skus').doc('ABC-1').set({
        'sku': 'abc-1',
        'productId': 'p1',
        'claimedBy': 'x',
      });

      expect(await repository.skuExists(sku: 'abc-1'), true);
      expect(await repository.skuExists(sku: '  ABC-1 '), true);
      expect(await repository.skuExists(sku: 'ZZZ'), false);
    });

    test('excludeProductId lets the owning product reuse its own SKU', () async {
      await firestore.collection('product_skus').doc('ABC-1').set({
        'sku': 'abc-1',
        'productId': 'p1',
        'claimedBy': 'x',
      });

      expect(
        await repository.skuExists(sku: 'abc-1', excludeProductId: 'p1'),
        false,
      );
      expect(
        await repository.skuExists(sku: 'abc-1', excludeProductId: 'p2'),
        true,
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: FAIL — current `skuExists` queries the `products` collection (`where('sku' == ...)`), so a seeded `product_skus` claim with no matching product doc returns `false`; the first test's `expect(... 'abc-1'), true)` fails.

- [ ] **Step 3: Rewrite `skuExists` as a claim-doc read**

Replace the body of `skuExists` (lines 717-732, the `try { ... } on FirebaseException`) with:

```dart
    try {
      final snap = await _skusRef.doc(SkuGenerator.normalizeSku(sku)).get();
      if (!snap.exists) return false;
      if (excludeProductId == null) return true;
      return snap.data()?['productId'] != excludeProductId;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check SKU existence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: PASS (skuExists group green; all prior groups still green).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): skuExists reads product_skus claim (case-insensitive, consistent with guard)"
```

---

## Task 4: `updateProduct` rename → transactional claim move

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart`
- Test: `test/data/repositories/product_repository_impl_test.dart`

- [ ] **Step 1: Write the failing tests**

At the end of `main()` in `product_repository_impl_test.dart`, add:

```dart
  group('ProductRepositoryImpl.updateProduct SKU claim move', () {
    test('moves the claim from old to new on rename', () async {
      final id = await seedProduct({'sku': 'OLD', 'name': 'P'});
      await firestore.collection('product_skus').doc('OLD').set({
        'sku': 'OLD',
        'productId': id,
        'claimedBy': 'x',
      });

      final p = await repository.getProductById(id);
      await repository.updateProduct(
        product: p!.copyWith(sku: 'NEW'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect(
        (await firestore.collection('product_skus').doc('OLD').get()).exists,
        false,
      );
      final newClaim =
          await firestore.collection('product_skus').doc('NEW').get();
      expect(newClaim.exists, true);
      expect(newClaim.data()!['productId'], id);
    });

    test('rename onto an existing SKU throws and changes nothing', () async {
      final id = await seedProduct({'sku': 'OLD', 'name': 'P'});
      await firestore.collection('product_skus').doc('OLD').set({
        'sku': 'OLD',
        'productId': id,
        'claimedBy': 'x',
      });
      final takenId = await seedProduct({'sku': 'TAKEN', 'name': 'Other'});
      await firestore.collection('product_skus').doc('TAKEN').set({
        'sku': 'TAKEN',
        'productId': takenId,
        'claimedBy': 'x',
      });

      final p = await repository.getProductById(id);
      expect(
        () => repository.updateProduct(
          product: p!.copyWith(sku: 'TAKEN'),
          updatedBy: 'admin-1',
        ),
        throwsA(isA<DuplicateSkuException>()),
      );

      expect((await repository.getProductById(id))!.sku, 'OLD');
      expect(
        (await firestore.collection('product_skus').doc('OLD').get()).exists,
        true,
      );
      expect(
        (await firestore.collection('product_skus').doc('TAKEN').get())
            .data()!['productId'],
        takenId,
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: FAIL — current `updateProduct` rename uses a batch that never touches `product_skus`, so `OLD` still exists, `NEW` is absent, and renaming onto `TAKEN` does not throw.

- [ ] **Step 3: Rewrite the rename branch as a transaction**

In `updateProduct`, replace the `if (skuChanged) { ... } else { ... }` block (lines 388-407) with:

```dart
      final skuChanged = prior != null && prior.sku != product.sku;
      if (skuChanged) {
        // Variation children (baseSku == old) must be read OUTSIDE the
        // transaction — Firestore transactions cannot run queries.
        final children =
            await _productsRef.where('baseSku', isEqualTo: prior.sku).get();
        final oldClaimRef = _skusRef.doc(SkuGenerator.normalizeSku(prior.sku));
        final newClaimRef = _skusRef.doc(SkuGenerator.normalizeSku(product.sku));

        // Move the parent's SKU claim (delete old, create new), update the
        // parent, and re-point every child's baseSku — all atomically.
        await _firestore.runTransaction((tx) async {
          final newClaim = await tx.get(newClaimRef);
          if (newClaim.exists &&
              newClaim.data()?['productId'] != product.id) {
            throw DuplicateSkuException(sku: product.sku);
          }
          tx.update(_productsRef.doc(product.id), updateMap);
          for (final child in children.docs) {
            tx.update(child.reference, {
              'baseSku': product.sku,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': updatedBy,
              if (updatedByName != null) 'updatedByName': updatedByName,
            });
          }
          // delete-then-set is safe even if old == new (case-only rename):
          // same ref → the set wins, re-keying the claim's sku field.
          tx.delete(oldClaimRef);
          tx.set(newClaimRef, {
            'sku': product.sku,
            'productId': product.id,
            'claimedBy': updatedBy,
            'claimedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        await _productsRef.doc(product.id).update(updateMap);
      }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: PASS — the new claim-move group is green, **and** the three pre-existing
`ProductRepositoryImpl.updateProduct SKU cascade` tests stay green (they seed no claims;
`tx.get` of an absent new-claim proceeds, `tx.delete` of an absent old-claim is a safe no-op).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): move product_skus claim atomically on SKU rename"
```

---

## Task 5: `createVariation` retry-on-collision

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart`
- Test: `test/data/repositories/product_repository_impl_test.dart`

- [ ] **Step 1: Write the failing tests**

At the end of `main()` in `product_repository_impl_test.dart`, add:

```dart
  group('ProductRepositoryImpl.createVariation retry-on-collision', () {
    test('allocates the next free number past existing variations', () async {
      final parentId = await seedProduct({'sku': 'BASE', 'name': 'Parent'});
      // Existing variation #1 (product + claim) → next free number is 2.
      await seedProduct({
        'sku': 'BASE-1',
        'name': 'V1',
        'baseSku': 'BASE',
        'variationNumber': 1,
      });
      await firestore.collection('product_skus').doc('BASE-1').set({
        'sku': 'BASE-1',
        'productId': 'v1',
        'claimedBy': 'x',
      });

      final parent = await repository.getProductById(parentId);
      final v = await repository.createVariation(
        originalProduct: parent!,
        newCost: 5,
        newCostCode: 'X',
        createdBy: 'admin-1',
      );

      expect(v.sku, 'BASE-2');
      expect(v.variationNumber, 2);
      expect(
        (await firestore.collection('product_skus').doc('BASE-2').get()).exists,
        true,
      );
    });

    test('throws DatabaseException after exhausting retries', () async {
      final parentId = await seedProduct({'sku': 'BASE', 'name': 'Parent'});
      // Orphan claim on BASE-1 with NO product → getNextVariationNumber keeps
      // returning 1, so every attempt collides and retries are exhausted.
      await firestore.collection('product_skus').doc('BASE-1').set({
        'sku': 'BASE-1',
        'productId': 'ghost',
        'claimedBy': 'x',
      });

      final parent = await repository.getProductById(parentId);
      expect(
        () => repository.createVariation(
          originalProduct: parent!,
          newCost: 5,
          newCostCode: 'X',
          createdBy: 'admin-1',
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: FAIL — current `createVariation` makes one attempt; with the orphan `BASE-1`
claim it calls `createProduct`, which now throws `DuplicateSkuException` (Task 2). Without a
retry loop the second test gets `DuplicateSkuException`, not `DatabaseException`.

- [ ] **Step 3: Add the bounded retry loop**

Replace the body of `createVariation` (lines 594-623, the `try { ... } on FirebaseException`) with:

```dart
    try {
      final baseSku = originalProduct.baseSku ?? originalProduct.sku;
      const maxAttempts = 5;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final variationNum = await getNextVariationNumber(baseSku);
        final newSku = SkuGenerator.generateVariation(baseSku, variationNum);

        final variation = originalProduct.copyWith(
          id: '',
          sku: newSku,
          cost: newCost,
          costCode: newCostCode,
          quantity: 0,
          baseSku: baseSku,
          variationNumber: variationNum,
          createdBy: createdBy,
          updatedBy: null,
          updatedAt: null,
        );

        try {
          return await createProduct(
            product: variation,
            createdBy: createdBy,
            createdByName: createdByName,
          );
        } on DuplicateSkuException {
          // A concurrent writer claimed this variation number; once their
          // product commits, getNextVariationNumber advances. Recompute & retry.
        }
      }
      throw DatabaseException(
        message:
            'Could not allocate a unique variation SKU for "$baseSku" after $maxAttempts attempts',
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create variation: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: PASS (createVariation group green; all prior groups still green).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): retry-on-collision in createVariation (concurrent receiving self-heals)"
```

---

## Task 6: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Analyze**

Run: `flutter analyze lib/data/repositories/product_repository_impl.dart lib/core/utils/sku_generator.dart lib/core/constants/firestore_collections.dart`
Expected: no new errors. Pre-existing `withOpacity` deprecation *info* notes elsewhere are
unrelated; the touched files should be clean.

- [ ] **Step 2: Run the full mobile test suite**

Run: `flutter test`
Expected: PASS — all suites green. Confirms the repo-impl changes didn't regress the
use-case/widget tests (which mock the repository) or the receiving flow.

- [ ] **Step 3: If anything fails, fix and re-run**

If `flutter test` surfaces a failure in a test that exercises the real `ProductRepositoryImpl`
and depends on a SKU claim existing (e.g. a receiving integration that creates a product then
expects to find it by SKU), seed the corresponding `product_skus/{normalizeSku(sku)}` claim in
that test's setup, or call through `repository.createProduct` so the claim is written. Re-run
`flutter test` until green. (Per the fallout check, the mocked use-case/widget tests should not
require changes.)

- [ ] **Step 4: Finish the branch**

Announce: "I'm using the finishing-a-development-branch skill to complete this work." Then follow
superpowers:finishing-a-development-branch (verify tests, present merge/PR options).

---

## Self-Review notes (author)

- **Spec coverage:** §4.1 normalize → Task 1; §4.2 create claim → Task 2; §4.5 skuExists → Task 3;
  §4.3 rename claim move → Task 4; §4.4 variation retry → Task 5; §9 acceptance (analyze + full
  suite) → Task 6. §6 hard-delete (none) → no task needed, by design.
- **Placeholder scan:** every code step shows full code; commands have expected output. No TBDs.
- **Type/name consistency:** `normalizeSku` (Task 1) used identically in Tasks 2-5;
  `_skusRef`/`productSkus` defined in Task 2 and reused; claim fields `{sku, productId, claimedBy,
  claimedAt}` identical across create (Task 2) and rename (Task 4) and match the Slice-A backfill;
  `DuplicateSkuException(sku:)` / `DatabaseException(message:)` match `exceptions.dart`.
- **Ordering:** Task 2 adds the constant + `_skusRef` that Tasks 3-5 depend on; `createProduct`
  (Task 2) is claim-aware before `createVariation` (Task 5) relies on it throwing
  `DuplicateSkuException`. Each task leaves `flutter test` green.
- **Out of scope (Slice C / later):** web `FirestoreProductRepository`, barcode TOCTOU, stored-SKU
  case migration, switching the non-SKU update path to a transaction.
