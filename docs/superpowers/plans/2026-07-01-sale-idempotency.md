# Fixed-ID (idempotent) sales Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the sale write idempotent on a client checkout ID so a retried checkout returns the existing sale instead of creating a duplicate (and doesn't re-subtract stock).

**Architecture:** A `checkoutId` (UUID) generated once per checkout screen becomes the sale document's ID. `ProcessSaleUseCase.execute` short-circuits if a sale with that ID already exists; `createSale` guards inside its transaction and throws `DuplicateSaleException` on a repeat, which the use case treats as "already recorded" (no re-applied side-effects).

**Tech Stack:** Flutter, cloud_firestore transactions, uuid (already a dep), mocktail + fake_cloud_firestore (tests).

## Global Constraints

- Mobile only (`lib/`, `test/`). No `web_admin/` changes.
- **No `firestore.rules` change** — verified: `sales` create is `isValidUser() && isActiveUser()` with wildcard `{saleId}`, no field constraints; a client UUID doc ID + `tx.get` are already allowed.
- No schema/migration: existing sales keep auto IDs; only new sales get a UUID ID.
- No draft idempotency (out of scope). Not doing full 4-step atomicity (out of scope).
- Each task ends green: `flutter analyze` clean + `flutter test` passing. Per-task commits on `fix/sale-idempotency`. Baseline: 838 tests.

---

### Task 1: Idempotent `createSale` + `DuplicateSaleException`

**Files:**
- Modify: `lib/core/errors/exceptions.dart` (add `DuplicateSaleException` near `DuplicateSkuException`, ~line 256)
- Modify: `lib/domain/repositories/sale_repository.dart` (`createSale` signature)
- Modify: `lib/data/repositories/sale_repository_impl.dart` (`createSale`, lines 31–83)
- Test: `test/data/repositories/sale_repository_impl_test.dart`

**Interfaces:**
- Produces: `Future<SaleEntity> createSale(SaleEntity sale, {String? id})` — when `id` is given, the sale doc uses it and a repeat throws `DuplicateSaleException`; when omitted, unchanged auto-ID behavior. `const DuplicateSaleException({String saleId, ...})`.

- [ ] **Step 1: Write the failing repo test**

Add inside the `group('SaleRepositoryImpl', ...)` in `sale_repository_impl_test.dart`:

```dart
    test('createSale with an id is idempotent (second call throws)', () async {
      final sale = createTestSale();

      final first = await repository.createSale(sale, id: 'checkout-1');
      expect(first.id, 'checkout-1');
      expect(first.saleNumber, startsWith('SALE-'));

      expect(
        () => repository.createSale(sale, id: 'checkout-1'),
        throwsA(isA<DuplicateSaleException>()),
      );

      final docs = await fakeFirestore.collection('sales').get();
      expect(docs.docs.length, 1);
    });
```

Add the import at the top of the test file: `import 'package:maki_mobile_pos/core/errors/exceptions.dart';`

- [ ] **Step 2: Run it — expect FAIL**

Run: `flutter test test/data/repositories/sale_repository_impl_test.dart`
Expected: FAIL — `createSale` has no `id` param / `DuplicateSaleException` undefined.

- [ ] **Step 3: Add `DuplicateSaleException`**

In `lib/core/errors/exceptions.dart`, directly after the `DuplicateSkuException` class:

```dart
class DuplicateSaleException extends DuplicateEntryException {
  const DuplicateSaleException({
    String saleId = '',
    super.message = 'This sale was already recorded',
    super.code = 'duplicate-sale',
  }) : super(field: 'saleId', value: saleId);
}
```

- [ ] **Step 4: Update the interface**

In `lib/domain/repositories/sale_repository.dart`, change the `createSale` declaration to:

```dart
  Future<SaleEntity> createSale(SaleEntity sale, {String? id});
```

- [ ] **Step 5: Make `createSale` idempotent**

In `sale_repository_impl.dart`, replace the whole `createSale` method (lines 31–83) with:

```dart
  @override
  Future<SaleEntity> createSale(SaleEntity sale, {String? id}) async {
    try {
      return await _firestore.runTransaction<SaleEntity>((transaction) async {
        // Deterministic doc id (idempotency key) when provided, else auto-id.
        final saleDocRef = id != null ? _salesRef.doc(id) : _salesRef.doc();

        // Guard (reads-before-writes): refuse a second write under the same id.
        final existing = await transaction.get(saleDocRef);
        if (existing.exists) {
          throw const DuplicateSaleException();
        }

        // Generate the sale number inside the transaction, so the counter
        // increment is atomic with the sale write and covered by the guard.
        String saleNumber = sale.saleNumber;
        if (saleNumber.isEmpty) {
          saleNumber = await _generateSaleNumberInTransaction(
            transaction,
            sale.createdAt,
          );
        }

        final saleModel = SaleModel.fromEntity(sale.copyWith(
          id: saleDocRef.id,
          saleNumber: saleNumber,
        ));

        transaction.set(saleDocRef, saleModel.toCreateMap());

        final itemsRef = saleDocRef.collection(FirestoreCollections.saleItems);
        for (final item in saleModel.items) {
          final itemDocRef = itemsRef.doc();
          final itemWithId = item.copyWith(id: itemDocRef.id);
          transaction.set(itemDocRef, itemWithId.toMap());
        }

        return sale.copyWith(
          id: saleDocRef.id,
          saleNumber: saleNumber,
        );
      });
    } on DuplicateSaleException {
      rethrow; // don't let the generic catch convert this to DatabaseException
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create sale: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create sale: $e',
        originalError: e,
      );
    }
  }
```

Add the import if not present at the top of `sale_repository_impl.dart`: `import 'package:maki_mobile_pos/core/errors/exceptions.dart';` (it already imports it for `DatabaseException` — verify and skip if so).

- [ ] **Step 6: Run tests — expect PASS**

Run: `flutter test test/data/repositories/sale_repository_impl_test.dart`
Expected: PASS. Then `flutter analyze` → No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/core/errors/exceptions.dart lib/domain/repositories/sale_repository.dart lib/data/repositories/sale_repository_impl.dart test/data/repositories/sale_repository_impl_test.dart
git commit -m "feat(data): idempotent createSale on optional id (DuplicateSaleException)"
```

---

### Task 2: `ProcessSaleUseCase.execute` — checkoutId short-circuit

**Files:**
- Modify: `lib/domain/usecases/pos/process_sale_usecase.dart` (`execute`, lines 33–103)
- Test: `test/domain/usecases/process_sale_usecase_test.dart` (new tests + migrate existing)
- Test: `test/domain/usecases/process_sale_tender_validation_test.dart` (migrate `execute` calls)

**Interfaces:**
- Consumes: `createSale(sale, {String? id})`, `DuplicateSaleException` (Task 1).
- Produces: `Future<ProcessSaleResult> execute({required SaleEntity sale, required String checkoutId, bool updateInventory = true})`.

- [ ] **Step 1: Write the failing idempotency tests**

Add these tests inside `group('ProcessSaleUseCase', ...)` in `process_sale_usecase_test.dart`, and add the import `import 'package:maki_mobile_pos/core/errors/exceptions.dart';`:

```dart
    test('short-circuits when a sale already exists for the checkout id', () async {
      final sale = createTestSale();
      final existing = sale.copyWith(id: 'chk-1', saleNumber: 'SALE-001');
      when(() => mockSaleRepo.getSaleById('chk-1'))
          .thenAnswer((_) async => existing);

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-1');

      expect(result.success, isTrue);
      expect(result.sale!.id, 'chk-1');
      verifyNever(() => mockSaleRepo.createSale(any(), id: any(named: 'id')));
      verifyNever(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test('DuplicateSaleException from createSale returns the existing sale', () async {
      final sale = createTestSale();
      final existing = sale.copyWith(id: 'chk-2', saleNumber: 'SALE-002');
      var getCalls = 0;
      when(() => mockSaleRepo.getSaleById('chk-2')).thenAnswer((_) async {
        getCalls++;
        return getCalls == 1 ? null : existing; // pre-check null, catch returns existing
      });
      when(() => mockSaleRepo.createSale(any(), id: any(named: 'id')))
          .thenThrow(const DuplicateSaleException());
      when(() => mockProductRepo.getProductById(any()))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(sale: sale, checkoutId: 'chk-2');

      expect(result.success, isTrue);
      expect(result.sale!.id, 'chk-2');
      verifyNever(() => mockProductRepo.updateStock(
            productId: any(named: 'productId'),
            quantityChange: any(named: 'quantityChange'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/domain/usecases/process_sale_usecase_test.dart`
Expected: FAIL — `execute` has no `checkoutId` param; `createSale(any(), id:)` stub signature mismatch.

- [ ] **Step 3: Rewrite `execute`**

Replace `execute` (lines 33–103) in `process_sale_usecase.dart` with (also add `import 'package:maki_mobile_pos/core/errors/exceptions.dart';` if the file lacks it — it imports it already for `AppException`, verify):

```dart
  Future<ProcessSaleResult> execute({
    required SaleEntity sale,
    required String checkoutId,
    bool updateInventory = true,
  }) async {
    final warnings = <String>[];

    try {
      // 1. Validate
      _validateSale(sale);

      // 2. Idempotency pre-check. If a sale already exists under this checkout
      //    id it was already recorded — return it, apply no side-effects. A
      //    read failure must not block a real sale; fall through to the
      //    transaction guard in createSale.
      try {
        final existing = await _saleRepository.getSaleById(checkoutId);
        if (existing != null) {
          return ProcessSaleResult(
            success: true,
            sale: existing,
            warnings: const ['This sale was already recorded.'],
          );
        }
      } catch (_) {
        // ignore — createSale's transaction guard is authoritative
      }

      // 3. Inventory availability (warnings only)
      if (updateInventory) {
        final stockIssues = await _checkInventoryAvailability(sale.items);
        if (stockIssues.isNotEmpty) {
          warnings.addAll(stockIssues);
        }
      }

      // 4. Create the sale under the checkout id. The sale number is generated
      //    inside createSale's transaction. A concurrent write under the same
      //    id throws DuplicateSaleException — treat it as "already recorded".
      final SaleEntity createdSale;
      try {
        createdSale = await _saleRepository.createSale(
          sale.copyWith(saleNumber: ''),
          id: checkoutId,
        );
      } on DuplicateSaleException {
        final existing = await _saleRepository.getSaleById(checkoutId);
        return ProcessSaleResult(
          success: true,
          sale: existing ?? sale,
          warnings: const ['This sale was already recorded.'],
        );
      }

      // 5. Update inventory
      if (updateInventory) {
        final stockWarnings = await _updateInventory(
          sale.items,
          createdSale.cashierId,
          updatedByName: createdSale.cashierName,
        );
        warnings.addAll(stockWarnings);
      }

      // 6. Mark draft converted if applicable
      if (sale.draftId != null && sale.draftId!.isNotEmpty) {
        try {
          await _draftRepository.markDraftAsConverted(
            draftId: sale.draftId!,
            saleId: createdSale.id,
          );
        } catch (e) {
          warnings.add('Draft conversion failed: $e');
        }
      }

      return ProcessSaleResult(
        success: true,
        sale: createdSale,
        warnings: warnings,
      );
    } on AppException catch (e) {
      return ProcessSaleResult(
        success: false,
        errorMessage: e.message,
        errors: [e.message],
      );
    } catch (e) {
      return ProcessSaleResult(
        success: false,
        errorMessage: 'Failed to process sale: $e',
        errors: ['Unexpected error: $e'],
      );
    }
  }
```

(Note: this removes the old step-3 `generateSaleNumber` pre-call — the number is now generated inside `createSale`. If the analyzer flags `createdSale` as possibly-unassigned, change `final SaleEntity createdSale;` to `late final SaleEntity createdSale;`.)

- [ ] **Step 4: Migrate the existing use-case tests**

Both test files call `useCase.execute(...)` without `checkoutId` and stub `createSale(any())`. Update them:
- In BOTH `process_sale_usecase_test.dart` and `process_sale_tender_validation_test.dart`: add `checkoutId: 'chk-test'` to every `useCase.execute(sale: ...)` call.
- Replace every `when(() => mockSaleRepo.createSale(any()))` with `when(() => mockSaleRepo.createSale(any(), id: any(named: 'id')))`.
- For any test that expects a sale to be created (not the two new short-circuit tests), add `when(() => mockSaleRepo.getSaleById(any())).thenAnswer((_) async => null);` so the pre-check returns "not found". (The old `generateSaleNumber` stubs can stay; they're now unused and harmless.)

- [ ] **Step 5: Run — expect PASS**

Run: `flutter test test/domain/usecases/process_sale_usecase_test.dart test/domain/usecases/process_sale_tender_validation_test.dart`
Expected: PASS. Then `flutter analyze` → No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/usecases/pos/process_sale_usecase.dart test/domain/usecases/process_sale_usecase_test.dart test/domain/usecases/process_sale_tender_validation_test.dart
git commit -m "feat(pos): idempotent sale via checkoutId short-circuit + duplicate guard"
```

---

### Task 3: Wire the checkout screen to a fixed checkout ID

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart` (imports; `_CheckoutScreenState` field; `_processCheckout` call, ~line 446)

**Interfaces:**
- Consumes: `execute({required sale, required checkoutId, ...})` (Task 2).

- [ ] **Step 1: Add the uuid import + checkout-id field**

At the top of `checkout_screen.dart` add: `import 'package:uuid/uuid.dart';`

In `_CheckoutScreenState` (where `bool _isProcessing = false;` is declared, line 31), add below it:

```dart
  // One stable id per checkout attempt. Reused across retries on this screen
  // (so a retry returns the existing sale instead of writing a duplicate); a
  // new checkout is a new screen instance and gets a fresh id.
  late final String _checkoutId = const Uuid().v4();
```

- [ ] **Step 2: Pass it into `execute`**

In `_processCheckout`, change the `useCase.execute(...)` call (line 446 area) from:

```dart
      final result = await useCase.execute(sale: sale);
```
to:
```dart
      final result = await useCase.execute(sale: sale, checkoutId: _checkoutId);
```

- [ ] **Step 3: Verify + full gate**

Run: `flutter analyze` → No issues
Run: `flutter test` → all green (838 baseline + 2 new idempotency tests + the migrated tests)

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/mobile/screens/pos/checkout_screen.dart
git commit -m "feat(pos): use a fixed checkout id so retries can't duplicate a sale"
```

---

## Self-Review

**Spec coverage:** §1 checkout id → Task 3; §2 use-case pre-check + duplicate-catch → Task 2; §3 createSale deterministic id + tx.get guard → Task 1; §"no rules change" verified in Global Constraints; testing → Task 1 (repo) + Task 2 (use case). All covered.

**Placeholder scan:** No TBD/TODO. All code blocks are concrete. The one conditional note (`late final` fallback if the analyzer flags definite-assignment) is a concrete either/or, not a placeholder.

**Type consistency:** `createSale(SaleEntity, {String? id})` and `DuplicateSaleException` defined in Task 1 and consumed verbatim in Task 2; `execute({required sale, required checkoutId})` defined in Task 2 and consumed verbatim in Task 3. `_checkoutId` field name consistent. Mock stubs updated to the new `createSale(any(), id: any(named: 'id'))` shape everywhere it's referenced.
