# Sale idempotency residuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the two documented residuals of fixed-ID sales: subtract stock inside the sale transaction (atomic), and tie the checkout id to the cart instead of the checkout screen.

**Architecture:** Part A folds the per-item stock decrement into `createSale`'s existing `runTransaction` (gated by a new `decrementStock` flag), removing the use case's separate best-effort inventory step. Part B moves the idempotency key onto `CartState` (minted once, cleared on cart reset) so it survives checkout-screen re-entry.

**Tech Stack:** Flutter, cloud_firestore transactions, uuid, mocktail + fake_cloud_firestore (tests).

## Global Constraints

- Mobile only (`lib/`, `test/`). No `web_admin/` changes.
- **No `firestore.rules`/schema/migration change** — verified: `products` update rule (lines 103–108) allows any active user to write exactly `['quantity','updatedAt','updatedBy','updatedByName']`; the transaction stock write hits exactly those keys.
- Overselling stays allowed (blind `FieldValue.increment`, no availability enforcement in the transaction). Behavior change (approved): a stock-write failure now aborts the whole sale.
- Each task ends green: `flutter analyze` clean + `flutter test` passing. Per-task commits on `fix/sale-idempotency-residuals`. Baseline: 842 tests.

---

### Task 1: Part A — subtract stock inside the sale transaction

**Files:**
- Modify: `lib/domain/repositories/sale_repository.dart` (`createSale` signature)
- Modify: `lib/data/repositories/sale_repository_impl.dart` (`createSale` + add `_productsRef`)
- Modify: `lib/domain/usecases/pos/process_sale_usecase.dart` (`execute` + delete `_updateInventory`)
- Test: `test/data/repositories/sale_repository_impl_test.dart`
- Test: `test/domain/usecases/process_sale_usecase_test.dart`, `test/domain/usecases/process_sale_tender_validation_test.dart` (migrate stubs)

**Interfaces:**
- Produces: `Future<SaleEntity> createSale(SaleEntity sale, {String? id, bool decrementStock = false})` — when `decrementStock`, each `sale.items` line's product quantity is decremented in the same transaction.

- [ ] **Step 1: Write the failing repo tests**

Add inside `group('SaleRepositoryImpl', ...)` in `sale_repository_impl_test.dart`:

```dart
    test('createSale with decrementStock subtracts stock atomically', () async {
      await fakeFirestore.collection('products').doc('prod-1').set({'quantity': 10});
      final sale = createTestSale(); // one line: prod-1 x2

      await repository.createSale(sale, id: 'k1', decrementStock: true);

      final prod = await fakeFirestore.collection('products').doc('prod-1').get();
      expect(prod.data()!['quantity'], 8);
    });

    test('a duplicate sale does not subtract stock twice', () async {
      await fakeFirestore.collection('products').doc('prod-1').set({'quantity': 10});
      final sale = createTestSale();
      await repository.createSale(sale, id: 'k2', decrementStock: true);

      expect(
        () => repository.createSale(sale, id: 'k2', decrementStock: true),
        throwsA(isA<DuplicateSaleException>()),
      );

      final prod = await fakeFirestore.collection('products').doc('prod-1').get();
      expect(prod.data()!['quantity'], 8); // decremented once, not twice
    });

    test('decrementStock:false leaves stock untouched', () async {
      await fakeFirestore.collection('products').doc('prod-1').set({'quantity': 10});
      final sale = createTestSale();

      await repository.createSale(sale, id: 'k3');

      final prod = await fakeFirestore.collection('products').doc('prod-1').get();
      expect(prod.data()!['quantity'], 10);
    });
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/data/repositories/sale_repository_impl_test.dart`
Expected: FAIL — `createSale` has no `decrementStock` param / stock not changed.

- [ ] **Step 3: Add `_productsRef` + the interface param**

In `sale_repository_impl.dart`, next to the `_settingsRef` getter (~line 26), add:

```dart
  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection(FirestoreCollections.products);
```

In `sale_repository.dart`, change the declaration to:

```dart
  Future<SaleEntity> createSale(SaleEntity sale, {String? id, bool decrementStock = false});
```

- [ ] **Step 4: Decrement stock inside `createSale`'s transaction**

In `sale_repository_impl.dart`, change the `createSale` signature to `{String? id, bool decrementStock = false}`, and insert the stock loop AFTER the items-writing loop and BEFORE the `return sale.copyWith(...)`:

```dart
        // Atomically subtract stock for each product line. Labor lines are not
        // in sale.items and never touch stock. Blind increment — overselling
        // stays allowed (stock may go negative), matching prior behavior.
        if (decrementStock) {
          for (final item in sale.items) {
            transaction.update(_productsRef.doc(item.productId), {
              'quantity': FieldValue.increment(-item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': sale.cashierId,
              'updatedByName': sale.cashierName,
            });
          }
        }
```

(All reads — `transaction.get(saleDocRef)` and the counter get inside `_generateSaleNumberInTransaction` — still precede every write, including these blind product updates.)

- [ ] **Step 5: Run the repo tests — expect PASS**

Run: `flutter test test/data/repositories/sale_repository_impl_test.dart` → PASS

- [ ] **Step 6: Route the use case through it; delete `_updateInventory`**

In `process_sale_usecase.dart` `execute`, change the `createSale` call to pass the flag:

```dart
        createdSale = await _saleRepository.createSale(
          sale.copyWith(saleNumber: ''),
          id: checkoutId,
          decrementStock: updateInventory,
        );
```

Delete the entire step-4 inventory block (it sits between the `createSale` try/catch and the `_reconcileDraft` call):

```dart
      // 4. Update inventory
      if (updateInventory) {
        final stockWarnings = await _updateInventory(
          sale.items,
          createdSale.cashierId,
          updatedByName: createdSale.cashierName,
        );
        warnings.addAll(stockWarnings);
      }

```

Delete the now-dead `_updateInventory` method (the `Future<List<String>> _updateInventory(List<SaleItemEntity> items, String updatedBy, {String? updatedByName})` that loops `_productRepository.updateStock`). Keep `_checkInventoryAvailability` (the pre-sale low-stock warning).

- [ ] **Step 7: Migrate the use-case test stubs + the two stock-verifying tests**

The `createSale` mock gained a `decrementStock` named param. In BOTH `process_sale_usecase_test.dart` and `process_sale_tender_validation_test.dart`, replace every `createSale(any(), id: any(named: 'id'))` with `createSale(any(), id: any(named: 'id'), decrementStock: any(named: 'decrementStock'))`.

Two tests in `process_sale_usecase_test.dart` verify `mockProductRepo.updateStock` — it is no longer called by the use case. Fix both:
- In `should return success when sale is valid`: delete the `verify(() => mockProductRepo.updateStock(... quantityChange: -2 ...)).called(1)` block and replace it with:
  ```dart
      verify(() => mockSaleRepo.createSale(any(),
          id: any(named: 'id'), decrementStock: true)).called(1);
  ```
- In `labor lines do not deduct inventory (only items are stocked)`: delete the trailing `verify(() => mockProductRepo.updateStock(...))` block. Keep the `laborSubtotal`/`grandTotal` assertions. (The "labor never touches stock" guarantee is now covered by the repo layer — Step 8.)

- [ ] **Step 8: Add the repo test proving labor never decrements stock**

Add to `sale_repository_impl_test.dart`:

```dart
    test('decrementStock ignores labor lines (only product items move stock)',
        () async {
      await fakeFirestore.collection('products').doc('prod-1').set({'quantity': 10});
      final sale = createTestSale().copyWith(
        laborLines: const [
          LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 450),
        ],
      );

      await repository.createSale(sale, id: 'k4', decrementStock: true);

      final prod = await fakeFirestore.collection('products').doc('prod-1').get();
      expect(prod.data()!['quantity'], 8); // only the product line moved
    });
```

- [ ] **Step 9: Full gate**

Run: `flutter analyze` → No issues
Run: `flutter test` → all green

- [ ] **Step 10: Commit**

```bash
git add lib/domain/repositories/sale_repository.dart lib/data/repositories/sale_repository_impl.dart lib/domain/usecases/pos/process_sale_usecase.dart test/data/repositories/sale_repository_impl_test.dart test/domain/usecases/process_sale_usecase_test.dart test/domain/usecases/process_sale_tender_validation_test.dart
git commit -m "feat(pos): subtract stock inside the sale transaction (atomic)"
```

---

### Task 2: Part B — tie the checkout id to the cart

**Files:**
- Modify: `lib/presentation/providers/cart_provider.dart` (`CartState` field + `copyWith` + `props`; `CartNotifier.ensureCheckoutId`)
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart` (use cart id; remove `_checkoutId` + uuid import)
- Test: `test/presentation/providers/cart_provider_test.dart`
- Test: `test/presentation/providers/state_equality_test.dart` (checkoutId in equality)

**Interfaces:**
- Produces: `CartState.checkoutId` (String, default `''`); `CartNotifier.ensureCheckoutId() → String` (mints once, idempotent); cleared by `reset()`/`resetAfterCheckout()`.

- [ ] **Step 1: Write the failing cart tests**

Add to `cart_provider_test.dart` (inside `main`, after the existing tests):

```dart
  group('checkout id', () {
    test('ensureCheckoutId mints once and is stable', () {
      final first = cartNotifier.ensureCheckoutId();
      final second = cartNotifier.ensureCheckoutId();
      expect(first, isNotEmpty);
      expect(second, first);
    });

    test('reset clears the checkout id so the next one differs', () {
      final first = cartNotifier.ensureCheckoutId();
      cartNotifier.reset();
      final next = cartNotifier.ensureCheckoutId();
      expect(next, isNot(first));
    });
  });
```

Add to `state_equality_test.dart` in the `CartState value equality` group:

```dart
    test('differing checkoutId compares unequal', () {
      // ignore: prefer_const_constructors
      final a = CartState(checkoutId: 'a');
      // ignore: prefer_const_constructors
      final b = CartState(checkoutId: 'b');
      expect(a, isNot(equals(b)));
    });
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/presentation/providers/cart_provider_test.dart test/presentation/providers/state_equality_test.dart`
Expected: FAIL — `ensureCheckoutId`/`checkoutId` undefined.

- [ ] **Step 3: Add `checkoutId` to `CartState`**

In `cart_provider.dart` `CartState`:
- Add the field near the other fields: `final String checkoutId;`
- Add to the const constructor: `this.checkoutId = '',`
- Add to `copyWith`: parameter `String? checkoutId,` and in the returned `CartState(...)`: `checkoutId: checkoutId ?? this.checkoutId,`
- Add `checkoutId` to the Equatable `props` list.

- [ ] **Step 4: Add `ensureCheckoutId` to `CartNotifier`**

In `CartNotifier` (which already has `final Uuid _uuid = const Uuid();`), add:

```dart
  /// Returns this cart's checkout id, minting one on first call. Stable for the
  /// life of the cart (survives checkout-screen re-entry); cleared by reset() /
  /// resetAfterCheckout() so the next order gets a fresh id.
  String ensureCheckoutId() {
    if (state.checkoutId.isEmpty) {
      state = state.copyWith(checkoutId: _uuid.v4());
    }
    return state.checkoutId;
  }
```

(`reset()`/`resetAfterCheckout()` already do `state = const CartState()`, so `checkoutId` returns to `''` automatically; `loadFromDraft` builds a fresh `CartState` without `checkoutId`, also `''`. No change needed to those.)

- [ ] **Step 5: Use the cart id in the checkout screen**

In `checkout_screen.dart`:
- Delete the `import 'package:uuid/uuid.dart';` line.
- Delete the `late final String _checkoutId = const Uuid().v4();` field (and its comment).
- In `_processCheckout`, immediately after the `_isProcessing` guard + `setState`, get the id from the cart and use it in the `execute` call. Change:
  ```dart
      final result = await useCase.execute(sale: sale, checkoutId: _checkoutId);
  ```
  to:
  ```dart
      final checkoutId = ref.read(cartProvider.notifier).ensureCheckoutId();
      final result = await useCase.execute(sale: sale, checkoutId: checkoutId);
  ```

- [ ] **Step 6: Run the tests — expect PASS + full gate**

Run: `flutter test test/presentation/providers/cart_provider_test.dart test/presentation/providers/state_equality_test.dart` → PASS
Run: `flutter analyze` → No issues
Run: `flutter test` → all green

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/cart_provider.dart lib/presentation/mobile/screens/pos/checkout_screen.dart test/presentation/providers/cart_provider_test.dart test/presentation/providers/state_equality_test.dart
git commit -m "feat(pos): tie the checkout id to the cart so re-entry can't duplicate a sale"
```

---

## Self-Review

**Spec coverage:** Part A (atomic stock + decrementStock flag + no rules change + reads-before-writes + labor-untouched) → Task 1; Part B (checkoutId on CartState + ensureCheckoutId + reset-clears + screen wiring) → Task 2. Both fully covered.

**Placeholder scan:** No TBD/TODO. All code blocks concrete; the existing-test migrations (Task 1 Step 7) are precise mechanical edits with the exact before/after.

**Type consistency:** `createSale(SaleEntity, {String? id, bool decrementStock = false})` defined (Task 1 Step 3) and consumed with `decrementStock: updateInventory` (Step 6) and in stubs `decrementStock: any(named: 'decrementStock')` (Step 7). `CartState.checkoutId` + `ensureCheckoutId()` defined (Task 2 Steps 3–4) and consumed in the screen (Step 5). Names consistent throughout.
