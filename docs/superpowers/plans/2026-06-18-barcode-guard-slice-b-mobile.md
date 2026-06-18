# Barcode Guard — Slice B (mobile) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Flutter app enforce barcode uniqueness via `product_barcodes` claims in Firestore transactions, replacing the advisory `barcodeExists`-then-write check — mirroring the SKU guard, for optional/multi-valued barcodes.

**Architecture:** In `ProductRepositoryImpl`, `createProduct` claims each barcode atomically inside the existing SKU/product transaction; `updateProduct` diffs the barcode set (release removed, claim added); `createVariation` clears barcodes; `barcodeExists` reads the claim. A `normalizeBarcode = trim()` helper is the cross-surface key contract.

**Tech Stack:** Dart / Flutter, `cloud_firestore` transactions, `fake_cloud_firestore` tests, `flutter test`.

## Global Constraints

- **`SkuGenerator.normalizeBarcode(code) = code.trim()`** — case-sensitive; MUST stay byte-identical to `scripts/backfill-product-barcodes.mjs` and (later) the web TS, or claims key differently and uniqueness silently breaks.
- **Optional + 1:N:** a product claims one `product_barcodes/{key}` doc per non-empty, deduped, valid barcode; no barcodes → no claim.
- **Claims kept on deactivate**; a barcode claim frees only when the barcode is removed via an edit. No hard-delete path exists.
- **Variations carry no barcodes.**
- Run `flutter test` for verification (the repo uses `fake_cloud_firestore`).
- **Rollout:** re-run `scripts/backfill-product-barcodes.mjs` right before building/installing this app (products created since Slice A lack claims).

---

## Task 1: Foundation — constant, ref, helpers, exception, `barcodeExists`

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart` (add `productBarcodes`)
- Modify: `lib/core/utils/sku_generator.dart` (add `normalizeBarcode`, `isClaimableBarcode`)
- Modify: `lib/core/errors/exceptions.dart` (add `DuplicateBarcodeException`)
- Modify: `lib/data/repositories/product_repository_impl.dart` (add `_barcodesRef`, a private `_barcodeKeys` helper, and rewrite `barcodeExists`)
- Test: `test/data/repositories/product_repository_impl_test.dart` (add a `barcodeExists` group)

**Interfaces:**
- Produces:
  - `FirestoreCollections.productBarcodes = 'product_barcodes'`
  - `SkuGenerator.normalizeBarcode(String) -> String` (trim), `SkuGenerator.isClaimableBarcode(String key) -> bool`
  - `DuplicateBarcodeException({required String barcode})`
  - private `CollectionReference _barcodesRef`, private `Set<String> _barcodeKeys(List<String> codes, {bool validate})`

- [ ] **Step 1: Add the collection constant**

In `firestore_collections.dart`, after `static const String productSkus = 'product_skus';`:
```dart
  static const String productBarcodes = 'product_barcodes';
```

- [ ] **Step 2: Add the helpers to `SkuGenerator`**

In `sku_generator.dart`, after the `normalizeSku` getter:
```dart
  /// Canonical key for barcode-uniqueness claims
  /// (`product_barcodes/{normalizeBarcode(code)}`). MUST stay byte-identical to
  /// scripts/backfill-product-barcodes.mjs (`String(s).trim()`) and the web TS —
  /// case-sensitive (barcodes are exact scanned tokens, NOT uppercased).
  static String normalizeBarcode(String code) => code.trim();

  /// Whether a (already-normalized, non-empty) barcode key can be a Firestore
  /// doc-id, so it can be claimed. Empty keys mean "no barcode" (skip, not error).
  static bool isClaimableBarcode(String key) {
    if (key.isEmpty || key.length > 1500) return false;
    if (key == '.' || key == '..') return false;
    if (key.contains('/')) return false;
    return !RegExp(r'^__.*__$').hasMatch(key);
  }
```

- [ ] **Step 3: Add the exception**

In `exceptions.dart`, after `DuplicateSkuException`:
```dart
/// Exception thrown when a barcode already claimed by another product.
class DuplicateBarcodeException extends DuplicateEntryException {
  const DuplicateBarcodeException({
    required String barcode,
    super.message = 'A product with this barcode already exists',
    super.code = 'duplicate-barcode',
  }) : super(field: 'barcodes', value: barcode);
}
```

- [ ] **Step 4: Add `_barcodesRef` + `_barcodeKeys` to the repository**

In `product_repository_impl.dart`, after the `_skusRef` getter (~line 19):
```dart
  CollectionReference<Map<String, dynamic>> get _barcodesRef =>
      _firestore.collection(FirestoreCollections.productBarcodes);

  /// The set of claimable barcode keys for a product: trim → drop empty → dedupe.
  /// When [validate], rejects a non-empty code that can't form a claim doc-id.
  Set<String> _barcodeKeys(List<String> codes, {bool validate = false}) {
    final keys = <String>{};
    for (final code in codes) {
      final key = SkuGenerator.normalizeBarcode(code);
      if (key.isEmpty) continue;
      if (validate && !SkuGenerator.isClaimableBarcode(key)) {
        throw ValidationException(
          message: 'Invalid barcode "$code" — cannot contain "/".',
          code: 'invalid-barcode',
        );
      }
      keys.add(key);
    }
    return keys;
  }
```
(`FirestoreCollections` is already imported by this file.)

- [ ] **Step 5: Write the failing `barcodeExists` test**

Add to `test/data/repositories/product_repository_impl_test.dart`:
```dart
  group('ProductRepositoryImpl.barcodeExists (claim-backed)', () {
    test('true when a claim exists, false otherwise', () async {
      await firestore.collection('product_barcodes').doc('ABC123').set({
        'barcode': 'ABC123', 'productId': 'p1',
      });
      expect(await repository.barcodeExists(barcode: ' ABC123 '), isTrue); // trimmed
      expect(await repository.barcodeExists(barcode: 'NOPE'), isFalse);
    });

    test('excludeProductId lets the owning product reuse its own barcode', () async {
      await firestore.collection('product_barcodes').doc('ABC123').set({
        'barcode': 'ABC123', 'productId': 'p1',
      });
      expect(await repository.barcodeExists(barcode: 'ABC123', excludeProductId: 'p1'), isFalse);
      expect(await repository.barcodeExists(barcode: 'ABC123', excludeProductId: 'p2'), isTrue);
    });
  });
```

- [ ] **Step 6: Run it — verify it fails**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: the new group FAILs (old `barcodeExists` queries `products`, not the claim — `' ABC123 '` won't match and `excludeProductId` differs).

- [ ] **Step 7: Rewrite `barcodeExists` to read the claim**

Replace the body of `barcodeExists` (the array-contains + legacy queries) with a claim read mirroring `skuExists`:
```dart
  @override
  Future<bool> barcodeExists({
    required String barcode,
    String? excludeProductId,
  }) async {
    try {
      final snap =
          await _barcodesRef.doc(SkuGenerator.normalizeBarcode(barcode)).get();
      if (!snap.exists) return false;
      if (excludeProductId == null) return true;
      return snap.data()?['productId'] != excludeProductId;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check barcode existence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```
(Leave `getProductByBarcode` unchanged — it's a *lookup* that must still find products by their `barcodes`/legacy field.)

- [ ] **Step 8: Run it — verify it passes**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: the `barcodeExists` group PASSES; the rest of the file still green.

- [ ] **Step 9: Commit**

```bash
git add lib/core/constants/firestore_collections.dart lib/core/utils/sku_generator.dart lib/core/errors/exceptions.dart lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): barcode-guard foundation — normalizeBarcode, claim ref, barcodeExists reads claim"
```

---

## Task 2: `createProduct` claims all barcodes atomically

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart` (`createProduct`)
- Test: `test/data/repositories/product_repository_impl_test.dart` (extend `buildProduct`, add a create-barcode group)

**Interfaces:**
- Consumes: `_barcodeKeys`, `_barcodesRef`, `DuplicateBarcodeException` (Task 1).

- [ ] **Step 1: Extend the `buildProduct` test helper with barcodes**

In the test file, add a `barcodes` param to `buildProduct`:
```dart
  ProductEntity buildProduct({
    String id = '',
    required String sku,
    String name = 'Test',
    String? baseSku,
    int? variationNumber,
    List<String> barcodes = const [],
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
      barcodes: barcodes,
    );
  }
```

- [ ] **Step 2: Write the failing create-barcode tests**

```dart
  group('ProductRepositoryImpl.createProduct barcode claims', () {
    test('claims every barcode and dedupes/trims', () async {
      final created = await repository.createProduct(
        product: buildProduct(sku: 'P1', barcodes: [' A1 ', 'A1', 'B2']),
        createdBy: 'u1',
      );
      final a = await firestore.collection('product_barcodes').doc('A1').get();
      final b = await firestore.collection('product_barcodes').doc('B2').get();
      expect(a.exists, isTrue);
      expect(a.data()?['productId'], created.id);
      expect(b.exists, isTrue);
    });

    test('rejects a barcode already claimed by another product (atomic)', () async {
      await firestore.collection('product_barcodes').doc('A1').set({
        'barcode': 'A1', 'productId': 'other',
      });
      await expectLater(
        () => repository.createProduct(
          product: buildProduct(sku: 'P2', barcodes: ['A1']),
          createdBy: 'u1',
        ),
        throwsA(isA<DuplicateBarcodeException>()),
      );
      // Nothing committed — no product with sku P2.
      final p2 = await firestore.collection('products').where('sku', isEqualTo: 'P2').get();
      expect(p2.docs, isEmpty);
    });

    test('rejects a barcode that cannot form a claim doc-id', () async {
      await expectLater(
        () => repository.createProduct(
          product: buildProduct(sku: 'P3', barcodes: ['a/b']),
          createdBy: 'u1',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
```

- [ ] **Step 3: Run them — verify they fail**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: the create-barcode group FAILs (current `createProduct` only does an advisory `barcodeExists` and never writes claims).

- [ ] **Step 4: Rewrite `createProduct`'s barcode handling**

Replace the advisory barcode loop (the `for (final code in product.barcodes) { … barcodeExists … }` block) with key-set building, and extend the transaction to claim each barcode. The full method:
```dart
  Future<ProductEntity> createProduct({
    required ProductEntity product,
    required String createdBy,
    String? createdByName,
  }) async {
    try {
      if (!SkuGenerator.isValidSku(SkuGenerator.normalizeSku(product.sku))) {
        throw ValidationException(
          message:
              'Invalid SKU "${product.sku}" — use letters, numbers, and hyphens only.',
          code: 'invalid-sku',
        );
      }

      // Claimable barcode keys (optional, trimmed, deduped, validated).
      final barcodeKeys = _barcodeKeys(product.barcodes, validate: true);

      final productModel = ProductModel.fromEntity(product);
      final docRef = _productsRef.doc(); // pre-allocate id for the transaction
      final claimRef = _skusRef.doc(SkuGenerator.normalizeSku(product.sku));
      final barcodeRefs = barcodeKeys.map(_barcodesRef.doc).toList();

      // Atomically reserve the SKU + barcode claims and write the product
      // together. Reads precede writes (Firestore transaction rule).
      await _firestore.runTransaction((tx) async {
        final claim = await tx.get(claimRef);
        final barcodeClaims = [for (final ref in barcodeRefs) await tx.get(ref)];
        if (claim.exists) {
          throw DuplicateSkuException(sku: product.sku);
        }
        for (var i = 0; i < barcodeClaims.length; i++) {
          if (barcodeClaims[i].exists) {
            throw DuplicateBarcodeException(barcode: barcodeRefs[i].id);
          }
        }
        tx.set(
          docRef,
          productModel.toCreateMap(createdBy,
              createdByDisplayName: createdByName),
        );
        tx.set(claimRef, {
          'sku': product.sku,
          'productId': docRef.id,
          'claimedBy': createdBy,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        for (final ref in barcodeRefs) {
          tx.set(ref, {
            'barcode': ref.id,
            'productId': docRef.id,
            'claimedBy': createdBy,
            'claimedAt': FieldValue.serverTimestamp(),
          });
        }
      });

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
  }
```

- [ ] **Step 5: Run them — verify pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: the create-barcode group PASSES; the existing SKU-claim tests still pass.

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): createProduct claims all barcodes atomically"
```

---

## Task 3: `updateProduct` diffs the barcode set

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart` (`updateProduct`)
- Test: `test/data/repositories/product_repository_impl_test.dart` (add an update-barcode group)

**Interfaces:**
- Consumes: `_barcodeKeys`, `_barcodesRef`, `DuplicateBarcodeException`.

- [ ] **Step 1: Write the failing update-barcode tests**

```dart
  group('ProductRepositoryImpl.updateProduct barcode diff', () {
    test('claims a newly added barcode', () async {
      final p = await repository.createProduct(
        product: buildProduct(sku: 'U1'), createdBy: 'u1');
      await repository.updateProduct(
        product: buildProduct(id: p.id, sku: 'U1', barcodes: ['NEW1']),
        updatedBy: 'u1');
      final claim = await firestore.collection('product_barcodes').doc('NEW1').get();
      expect(claim.exists, isTrue);
      expect(claim.data()?['productId'], p.id);
    });

    test('frees a removed barcode (reusable by another product)', () async {
      final p = await repository.createProduct(
        product: buildProduct(sku: 'U2', barcodes: ['OLD1']), createdBy: 'u1');
      await repository.updateProduct(
        product: buildProduct(id: p.id, sku: 'U2', barcodes: const []),
        updatedBy: 'u1');
      expect((await firestore.collection('product_barcodes').doc('OLD1').get()).exists, isFalse);
    });

    test('rejects adding a barcode owned by another product; nothing changes', () async {
      final a = await repository.createProduct(
        product: buildProduct(sku: 'UA', barcodes: ['SHARED']), createdBy: 'u1');
      final b = await repository.createProduct(
        product: buildProduct(sku: 'UB'), createdBy: 'u1');
      await expectLater(
        () => repository.updateProduct(
          product: buildProduct(id: b.id, sku: 'UB', barcodes: ['SHARED']),
          updatedBy: 'u1'),
        throwsA(isA<DuplicateBarcodeException>()),
      );
      // SHARED still owned by A.
      final claim = await firestore.collection('product_barcodes').doc('SHARED').get();
      expect(claim.data()?['productId'], a.id);
    });
  });
```

- [ ] **Step 2: Run them — verify they fail**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: the update-barcode group FAILs (current `updateProduct` ignores barcode changes when the SKU is unchanged).

- [ ] **Step 3: Add barcode diffing to `updateProduct`**

Replace the `skuChanged`/transaction block. After `final skuChanged = prior != null && prior.sku != product.sku;` add:
```dart
      final priorKeys = _barcodeKeys(prior?.barcodes ?? const []);
      final newKeys = _barcodeKeys(product.barcodes, validate: true);
      final addedKeys = newKeys.difference(priorKeys);
      final removedKeys = priorKeys.difference(newKeys);
      final barcodesChanged = addedKeys.isNotEmpty || removedKeys.isNotEmpty;

      if (skuChanged || barcodesChanged) {
        // Variation children (baseSku == old) must be read OUTSIDE the
        // transaction — Firestore transactions cannot run queries.
        final children = skuChanged
            ? await _productsRef.where('baseSku', isEqualTo: prior!.sku).get()
            : null;
        final newSkuClaimRef = _skusRef.doc(SkuGenerator.normalizeSku(product.sku));
        final addedRefs = addedKeys.map(_barcodesRef.doc).toList();

        await _firestore.runTransaction((tx) async {
          // Reads first.
          final newSkuClaim = skuChanged ? await tx.get(newSkuClaimRef) : null;
          final addedClaims = [for (final ref in addedRefs) await tx.get(ref)];
          // Conflict checks.
          if (skuChanged &&
              newSkuClaim!.exists &&
              newSkuClaim.data()?['productId'] != product.id) {
            throw DuplicateSkuException(sku: product.sku);
          }
          for (var i = 0; i < addedClaims.length; i++) {
            final c = addedClaims[i];
            if (c.exists && c.data()?['productId'] != product.id) {
              throw DuplicateBarcodeException(barcode: addedRefs[i].id);
            }
          }
          // Writes.
          tx.update(_productsRef.doc(product.id), updateMap);
          if (skuChanged) {
            for (final child in children!.docs) {
              tx.update(child.reference, {
                'baseSku': product.sku,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': updatedBy,
                if (updatedByName != null) 'updatedByName': updatedByName,
              });
            }
            tx.delete(_skusRef.doc(SkuGenerator.normalizeSku(prior!.sku)));
            tx.set(newSkuClaimRef, {
              'sku': product.sku,
              'productId': product.id,
              'claimedBy': updatedBy,
              'claimedAt': FieldValue.serverTimestamp(),
            });
          }
          for (final key in removedKeys) {
            tx.delete(_barcodesRef.doc(key));
          }
          for (final ref in addedRefs) {
            tx.set(ref, {
              'barcode': ref.id,
              'productId': product.id,
              'claimedBy': updatedBy,
              'claimedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      } else {
        await _productsRef.doc(product.id).update(updateMap);
      }
```
Delete the **old** `if (skuChanged) { … } else { … }` block this replaces (the previous SKU-only transaction). `updateMap` is already computed above; the price-history tail below is unchanged.

- [ ] **Step 4: Run them — verify pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: update-barcode group PASSES; the existing SKU-cascade tests (re-point children, rename moves claim, rename-onto-existing throws) still PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): updateProduct diffs barcode set (release removed / claim added)"
```

---

## Task 4: `createVariation` carries no barcodes

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart` (`createVariation`)
- Test: `test/data/repositories/product_repository_impl_test.dart` (add a variation-barcode test)

- [ ] **Step 1: Write the failing test**

```dart
  group('ProductRepositoryImpl.createVariation barcodes', () {
    test('variation carries no barcodes and claims none', () async {
      final original = buildProduct(sku: 'BASE', barcodes: ['BC1']);
      final variation = await repository.createVariation(
        originalProduct: original,
        newCost: 9.0,
        newCostCode: 'ZZ',
        createdBy: 'u1',
      );
      final stored = await firestore.collection('products').doc(variation.id).get();
      expect((stored.data()?['barcodes'] as List).isEmpty, isTrue);
      // The variation never claimed the base's barcode.
      expect((await firestore.collection('product_barcodes').doc('BC1').get()).exists, isFalse);
    });
  });
```

- [ ] **Step 2: Run it — verify it fails**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: FAIL — the variation copies `original.barcodes` (`['BC1']`) and claims it, so the doc-id `BC1` claim exists / the stored barcodes aren't empty.

- [ ] **Step 3: Clear barcodes in `createVariation`**

In `createVariation`, add `barcodes: const [],` to the `originalProduct.copyWith(...)` call (alongside `id: ''`, `sku: newSku`, …):
```dart
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
          barcodes: const [],
        );
```

- [ ] **Step 4: Run it — verify pass**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: the variation-barcode test PASSES; existing variation tests still PASS.

- [ ] **Step 5: Full suite + commit**

Run: `flutter test`
Expected: the full mobile suite passes.
```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "feat(mobile): createVariation carries no barcodes (claims none)"
```

---

## Self-review notes (author)

- **Spec coverage:** §2 helpers/exception/ref → Task 1; §3 createProduct claim → Task 2; §4 updateProduct diff → Task 3; §5 createVariation → Task 4; §6 barcodeExists → Task 1; §7 tests/rollout → each task's tests + the rollout note in Global Constraints. Covered.
- **Type/contract consistency:** `normalizeBarcode = code.trim()` matches the script's `String(s).trim()`; claim doc shape `{barcode, productId, claimedBy, claimedAt}` matches `product_barcodes` (Slice A) and `product_skus`. `_barcodeKeys` used identically in create + update. `DuplicateBarcodeException(barcode:)` consistent across tasks.
- **Reads-before-writes:** both transactions read (SKU claim + each added/all barcode claim) before any write; removed-barcode `tx.delete` after reads is valid (blind delete, like the SKU old-claim delete).
- **`copyWith(barcodes:)`:** assumes `ProductEntity.copyWith` accepts `barcodes` — it does (the entity has a `barcodes` field with a copyWith param; confirm at implementation).
- **No web / no rules change** — Slice A shipped the rules; this is mobile-only.
