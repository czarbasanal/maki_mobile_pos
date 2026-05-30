# Admin-Editable SKU Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an admin change an existing product's SKU safely — history stays intact, variation links cascade, and the old SKU stays scannable.

**Architecture:** SKU editing is gated to admins at three layers (form field, `UpdateProductUseCase`, Firestore rules). On an admin SKU change the use-case validates format + uniqueness and appends the old SKU to `barcodes` (scan alias); the repository performs an atomic `WriteBatch` that updates the product doc and re-points every variation child (`baseSku == oldSku`) to the new SKU. Sales/receiving history is untouched because those records store a stable `productId` plus a frozen SKU snapshot.

**Tech Stack:** Flutter, Dart, Riverpod, Cloud Firestore. Tests: `flutter_test` + `mocktail` (use-cases), `fake_cloud_firestore` (repositories), `@firebase/rules-unit-testing` + Mocha on the Firestore emulator (rules).

**Spec:** `docs/superpowers/specs/2026-05-30-admin-editable-sku-design.md`

> **Note on the Flutter SDK:** if `flutter` is not on your `PATH`, use the absolute path `/Users/czar/flutter/bin/flutter` in every `flutter` command below.

> **Baseline caveat:** before this plan, `test/domain/usecases/product/update_product_usecase_test.dart` has **one pre-existing failing test** — `cashier denied (no edit permission at all)` — which is stale (the cashier now has a name-only edit branch). Task 1 replaces it. The rest of the file is green.

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `lib/domain/usecases/product/update_product_usecase.dart` | Permission tiers + SKU validation/uniqueness/alias/logging | Modify |
| `test/domain/usecases/product/update_product_usecase_test.dart` | Use-case unit tests | Modify (fix stale test + add SKU tests) |
| `lib/data/repositories/product_repository_impl.dart` | Atomic SKU-change cascade to variation children | Modify `updateProduct` |
| `test/data/repositories/product_repository_impl_test.dart` | Repository cascade tests (fake Firestore) | Create |
| `lib/presentation/providers/product_provider.dart` | Variation-children count provider | Modify (add provider) |
| `lib/presentation/mobile/screens/inventory/product_form_screen.dart` | Admin-editable SKU field + validator + confirm dialog | Modify |
| `firestore.rules` | Lock SKU writes to admin (staff denylist) | Modify |
| `tools/firestore-rules-test/test/rules.test.js` | Rules tests for SKU write gating | Modify |

---

## Task 1: Use-case — admin-only SKU editing

**Files:**
- Modify: `lib/domain/usecases/product/update_product_usecase.dart`
- Test: `test/domain/usecases/product/update_product_usecase_test.dart`

- [ ] **Step 1: Replace the stale cashier test and add SKU tests**

In `test/domain/usecases/product/update_product_usecase_test.dart`, find and **delete** this stale test:

```dart
    test('cashier denied (no edit permission at all)', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: original.copyWith(name: 'Hacked'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
```

Replace it with these tests (cashier can rename, but SKU/staff/admin SKU rules are enforced):

```dart
    test('cashier CAN change name (name-only tier)', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: original.copyWith(name: 'Renamed by cashier'),
      );

      expect(result.success, true);
    });

    test('cashier CANNOT change sku', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: original.copyWith(sku: 'CASH-NEW'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'restricted-fields');
      expect(result.errorMessage, contains('sku'));
      verifyNever(() => repo.updateProduct(
            product: any(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test('staff CANNOT change sku', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: original.copyWith(sku: 'STAFF-NEW'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'restricted-fields');
      expect(result.errorMessage, contains('sku'));
    });

    test('admin can change sku; old sku preserved as barcode alias', () async {
      final original = _product(); // sku: SKU-001
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);
      when(() => repo.skuExists(sku: 'SKU-NEW', excludeProductId: 'p-1'))
          .thenAnswer((_) async => false);
      when(() => repo.getSkuVariations('SKU-001'))
          .thenAnswer((_) async => <ProductEntity>[]);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: original.copyWith(sku: 'SKU-NEW'),
      );

      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: 'u-admin',
            updatedByName: 'admin user',
          )).captured;
      final saved = captured.single as ProductEntity;
      expect(saved.sku, 'SKU-NEW');
      expect(saved.barcodes, contains('SKU-001'));
    });

    test('admin SKU change rejected when new SKU already exists', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);
      when(() => repo.skuExists(sku: 'DUPE', excludeProductId: 'p-1'))
          .thenAnswer((_) async => true);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: original.copyWith(sku: 'DUPE'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'duplicate-sku');
      verifyNever(() => repo.updateProduct(
            product: any(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test('admin SKU change rejected when new SKU format is invalid', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: original.copyWith(sku: 'bad sku!'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-sku');
    });
```

- [ ] **Step 2: Run the tests to verify the new SKU tests fail**

Run: `flutter test test/domain/usecases/product/update_product_usecase_test.dart`
Expected: FAIL — `cashier CANNOT change sku`, `staff CANNOT change sku`, and the three admin-SKU tests fail (current code lets staff change SKU, doesn't validate/dedupe SKU, and doesn't append the alias). The two "can" tests pass.

- [ ] **Step 3: Add the SkuGenerator import**

At the top of `lib/domain/usecases/product/update_product_usecase.dart`, add this import alongside the existing ones:

```dart
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
```

- [ ] **Step 4: Implement SKU rules in `execute`**

Replace the entire `execute` method body (from `final original = await _repository.getProductById(product.id);` through the `return UseCaseResult.successData(updated);` line) with this version. It adds `skuChanged`, includes `sku` in the staff/cashier restricted lists, adds the admin SKU-handling block, saves `productToSave`, and makes the activity log SKU-aware:

```dart
      final original = await _repository.getProductById(product.id);
      if (original == null) {
        return const UseCaseResult.failure(
          message: 'Product not found',
          code: 'not-found',
        );
      }

      final skuChanged = product.sku != original.sku;

      // If only the limited permission is held, reject any change to the
      // restricted columns. SKU is admin-only, so it belongs here too.
      if (!hasFullEdit && hasLimitedEdit) {
        final changed = <String>[];
        if (skuChanged) changed.add('sku');
        if (product.price != original.price) changed.add('price');
        if (product.cost != original.cost) changed.add('cost');
        if (product.costCode != original.costCode) changed.add('costCode');
        if (changed.isNotEmpty) {
          return UseCaseResult.failure(
            message:
                'Staff cannot change ${changed.join(", ")}. Ask an admin to update those fields.',
            code: 'restricted-fields',
          );
        }
      }

      // Cashier (name-only tier) may change only name and imageUrl.
      if (!hasFullEdit && !hasLimitedEdit && hasNameOnlyEdit) {
        final changed = <String>[];
        if (skuChanged) changed.add('sku');
        if (product.costCode != original.costCode) changed.add('costCode');
        if (product.cost != original.cost) changed.add('cost');
        if (product.price != original.price) changed.add('price');
        if (product.quantity != original.quantity) changed.add('quantity');
        if (product.reorderLevel != original.reorderLevel) {
          changed.add('reorderLevel');
        }
        if (product.unit != original.unit) changed.add('unit');
        if (product.supplierId != original.supplierId) changed.add('supplier');
        if (!_listEquals(product.barcodes, original.barcodes)) {
          changed.add('barcodes');
        }
        if (product.category != original.category) changed.add('category');
        if (product.notes != original.notes) changed.add('notes');
        if (changed.isNotEmpty) {
          return UseCaseResult.failure(
            message:
                'Cashier can only change name and image. Ask staff or admin to update ${changed.join(", ")}.',
            code: 'restricted-fields',
          );
        }
      }

      // Admin SKU change: validate format + uniqueness, keep the old SKU
      // scannable (append to barcodes), and count the variation children the
      // repository will re-point to the new SKU (for the audit log).
      var productToSave = product;
      var relinkedVariations = 0;
      if (hasFullEdit && skuChanged) {
        if (!SkuGenerator.isValidSku(product.sku)) {
          return const UseCaseResult.failure(
            message:
                'SKU may contain only letters, numbers, and hyphens (max 50 characters).',
            code: 'invalid-sku',
          );
        }
        final duplicate = await _repository.skuExists(
          sku: product.sku,
          excludeProductId: product.id,
        );
        if (duplicate) {
          return UseCaseResult.failure(
            message: 'Another product already uses SKU "${product.sku}".',
            code: 'duplicate-sku',
          );
        }
        final barcodes = List<String>.of(product.barcodes);
        if (!barcodes.contains(original.sku)) barcodes.add(original.sku);
        productToSave = product.copyWith(barcodes: barcodes);

        final group = await _repository.getSkuVariations(original.sku);
        relinkedVariations =
            group.where((p) => p.baseSku == original.sku).length;
      }

      final updated = await _repository.updateProduct(
        product: productToSave,
        updatedBy: actor.id,
        updatedByName: actor.displayName,
      );

      await _logger.log(
        type: ActivityType.inventory,
        action: skuChanged
            ? 'Changed SKU: ${original.sku} → ${updated.sku}'
            : 'Updated product: ${updated.name}',
        details: skuChanged
            ? '${updated.name}${relinkedVariations > 0 ? ' · relinked $relinkedVariations variation(s)' : ''}'
            : 'SKU ${updated.sku}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: updated.id,
        entityType: 'product',
        metadata: skuChanged
            ? {
                'oldSku': original.sku,
                'newSku': updated.sku,
                'relinkedVariations': relinkedVariations,
              }
            : null,
      );

      return UseCaseResult.successData(updated);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/domain/usecases/product/update_product_usecase_test.dart`
Expected: PASS — all tests green (including the corrected cashier tests and the five SKU tests).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/usecases/product/update_product_usecase.dart test/domain/usecases/product/update_product_usecase_test.dart
git commit -m "$(cat <<'EOF'
feat(inventory): enforce admin-only SKU edits in update use-case

Validate format + uniqueness on SKU change, append the old SKU to
barcodes as a scan alias, and log old->new with the relinked-variation
count. Staff/cashier SKU changes are rejected. Also corrects a stale
cashier test that predated the name-only edit branch.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Repository — atomic SKU-change cascade

**Files:**
- Modify: `lib/data/repositories/product_repository_impl.dart` (`updateProduct`, ~lines 370-426)
- Test: `test/data/repositories/product_repository_impl_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/data/repositories/product_repository_impl_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ProductRepositoryImpl(firestore: firestore);
  });

  // Seeds a product doc with sensible defaults, overridden by [data].
  // Returns the generated document id.
  Future<String> seedProduct(Map<String, dynamic> data) async {
    final ref = await firestore.collection('products').add({
      'sku': 'X',
      'name': 'X',
      'costCode': '',
      'cost': 1.0,
      'price': 2.0,
      'quantity': 0,
      'reorderLevel': 10,
      'unit': 'pcs',
      'isActive': true,
      'searchKeywords': <String>[],
      'barcodes': <String>[],
      'createdAt': Timestamp.now(),
      ...data,
    });
    return ref.id;
  }

  group('ProductRepositoryImpl.updateProduct SKU cascade', () {
    test('re-points variation children when parent SKU changes', () async {
      final parentId = await seedProduct({'sku': 'OLD', 'name': 'Parent'});
      final child1Id = await seedProduct({
        'sku': 'OLD-1',
        'name': 'Child 1',
        'baseSku': 'OLD',
        'variationNumber': 1,
      });
      final child2Id = await seedProduct({
        'sku': 'OLD-2',
        'name': 'Child 2',
        'baseSku': 'OLD',
        'variationNumber': 2,
      });
      final otherId = await seedProduct({
        'sku': 'ZZZ-1',
        'name': 'Unrelated',
        'baseSku': 'ZZZ',
        'variationNumber': 1,
      });

      final parent = await repository.getProductById(parentId);
      await repository.updateProduct(
        product: parent!.copyWith(sku: 'NEW'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect((await repository.getProductById(parentId))!.sku, 'NEW');
      expect((await repository.getProductById(child1Id))!.baseSku, 'NEW');
      expect((await repository.getProductById(child2Id))!.baseSku, 'NEW');
      expect((await repository.getProductById(otherId))!.baseSku, 'ZZZ');
    });

    test('does not touch children when SKU is unchanged', () async {
      final parentId = await seedProduct({'sku': 'OLD', 'name': 'Parent'});
      final childId = await seedProduct({
        'sku': 'OLD-1',
        'name': 'Child',
        'baseSku': 'OLD',
        'variationNumber': 1,
      });

      final parent = await repository.getProductById(parentId);
      await repository.updateProduct(
        product: parent!.copyWith(name: 'Parent Renamed'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect(
        (await repository.getProductById(parentId))!.name,
        'Parent Renamed',
      );
      expect((await repository.getProductById(childId))!.baseSku, 'OLD');
    });

    test('childless product SKU change succeeds', () async {
      final id = await seedProduct({'sku': 'SOLO', 'name': 'Solo'});
      final product = await repository.getProductById(id);

      final updated = await repository.updateProduct(
        product: product!.copyWith(sku: 'SOLO-2'),
        updatedBy: 'admin-1',
        updatedByName: 'Admin',
      );

      expect(updated.sku, 'SOLO-2');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: FAIL — `re-points variation children when parent SKU changes` fails (children keep `baseSku == 'OLD'` because no cascade exists yet).

- [ ] **Step 3: Implement the cascade**

In `lib/data/repositories/product_repository_impl.dart`, replace the body of `updateProduct` from the line:

```dart
      final productModel = ProductModel.fromEntity(product);
      await _productsRef.doc(product.id).update(
            productModel.toUpdateMap(
              updatedBy,
              updatedByDisplayName: updatedByName,
            ),
          );
```

with this (keep everything before `final prior = ...` and everything from `final updated = await getProductById(product.id);` onward unchanged):

```dart
      final productModel = ProductModel.fromEntity(product);
      final updateMap = productModel.toUpdateMap(
        updatedBy,
        updatedByDisplayName: updatedByName,
      );

      final skuChanged = prior != null && prior.sku != product.sku;
      if (skuChanged) {
        // Re-point variation children (baseSku == old SKU) to the new SKU in
        // the same atomic batch as the product update, so the variation group
        // never observes a dangling parent link.
        final batch = _firestore.batch();
        batch.update(_productsRef.doc(product.id), updateMap);
        final children =
            await _productsRef.where('baseSku', isEqualTo: prior!.sku).get();
        for (final child in children.docs) {
          batch.update(child.reference, {
            'baseSku': product.sku,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': updatedBy,
            if (updatedByName != null) 'updatedByName': updatedByName,
          });
        }
        await batch.commit();
      } else {
        await _productsRef.doc(product.id).update(updateMap);
      }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/data/repositories/product_repository_impl_test.dart`
Expected: PASS — all three cascade tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/product_repository_impl.dart test/data/repositories/product_repository_impl_test.dart
git commit -m "$(cat <<'EOF'
feat(inventory): cascade SKU change to variation children

When a product's SKU changes, re-point every child (baseSku == old SKU)
to the new SKU in the same WriteBatch as the product update, keeping the
variation group intact. No-op when the SKU is unchanged.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Provider — variation children count

**Files:**
- Modify: `lib/presentation/providers/product_provider.dart`

- [ ] **Step 1: Add the provider**

In `lib/presentation/providers/product_provider.dart`, add this provider after `productByBarcodeProvider` (i.e., within the `PRODUCT QUERIES` section):

```dart
/// Number of variation children linked to [parentSku] (docs whose `baseSku`
/// equals [parentSku]). Used to warn an admin before a SKU change re-points
/// them to the new SKU.
final productVariationChildrenCountProvider =
    FutureProvider.family<int, String>((ref, parentSku) async {
  final repository = ref.watch(productRepositoryProvider);
  final group = await repository.getSkuVariations(parentSku);
  return group.where((p) => p.baseSku == parentSku).length;
});
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/providers/product_provider.dart`
Expected: No issues (0 errors). Warnings unrelated to this file's new code are acceptable.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/product_provider.dart
git commit -m "$(cat <<'EOF'
feat(inventory): add variation-children count provider

Exposes the number of variation children for a parent SKU so the edit
form can warn the admin how many links a SKU change will re-point.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Form — admin-editable SKU field + confirm dialog

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

- [ ] **Step 1: Widen `canEditSku` and add a field-enabled flag**

In the `build` method, replace this line (~line 171):

```dart
    final bool canEditSku =
        !widget.isEditing; // SKU never editable after creation
```

with:

```dart
    // Admin may edit the SKU of an existing product; anyone who can create may
    // set it at create time. Staff/cashier keep the SKU locked once a product
    // exists.
    final bool canEditSku = isCreating || userRole == UserRole.admin;
    // The Auto/Manual generator is a create-time convenience only; on edit the
    // admin types the SKU directly.
    final bool skuFieldEnabled = isCreating
        ? (canEditSku && !_autoGenerateSku)
        : (userRole == UserRole.admin);
```

(`isCreating` is already declared just above as `final bool isCreating = !widget.isEditing;`.)

- [ ] **Step 2: Update the SKU section (toggle gating, helper text, validator, enabled)**

Replace the entire SKU block — the `if (canEditSku) SwitchListTile(...)` widget and the SKU `TextFormField` that follows it (~lines 312-354) — with:

```dart
                    // SKU — Auto/Manual generator is create-only. On edit the
                    // field is editable for admins (history-safe; old code is
                    // kept scannable) and read-only for everyone else.
                    if (isCreating)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Auto-generate SKU'),
                        subtitle: Text(
                          _autoGenerateSku
                              ? 'Built from category + random suffix'
                              : 'Type the SKU manually',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        value: _autoGenerateSku,
                        onChanged: (v) {
                          setState(() {
                            _autoGenerateSku = v;
                            if (v) {
                              _skuController.text =
                                  SkuGenerator.generateForName(
                                _nameController.text,
                              );
                            }
                          });
                        },
                      ),
                    TextFormField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        labelText: 'SKU *',
                        prefixIcon: const Icon(CupertinoIcons.qrcode),
                        helperText: (!isCreating && userRole == UserRole.admin)
                            ? 'Changing the SKU keeps past sales & receiving '
                                'history intact and keeps the old code scannable.'
                            : null,
                        suffixIcon: (isCreating && _autoGenerateSku)
                            ? IconButton(
                                tooltip: 'Regenerate',
                                icon: const Icon(
                                    CupertinoIcons.arrow_2_circlepath),
                                onPressed: _regenerateSku,
                              )
                            : null,
                      ),
                      enabled: skuFieldEnabled,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'SKU is required';
                        if (!SkuGenerator.isValidSku(v)) {
                          return 'Use only letters, numbers, and hyphens (max 50)';
                        }
                        return null;
                      },
                    ),
```

- [ ] **Step 3: Add the SKU-change confirmation dialog helper**

Add this method to `_ProductFormScreenState`, just before `_confirmDelete` (~line 714):

```dart
  /// Confirms a consequential SKU change before saving. Returns true when the
  /// admin chooses to proceed.
  Future<bool?> _confirmSkuChange({
    required String oldSku,
    required String newSku,
    required int variationCount,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change SKU?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$oldSku  →  $newSku',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '• Past sales and receiving records keep their original SKU.',
            ),
            const Text('• The old SKU stays scannable (added to barcodes).'),
            if (variationCount > 0)
              Text(
                '• $variationCount linked variation(s) will be re-pointed to '
                'the new SKU.',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change SKU'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Wire the confirm dialog + pass the new SKU in the admin update branch**

In `_handleSubmit`, inside the `if (userRole == UserRole.admin) {` branch (the admin UPDATE branch, ~line 782), add this as the **first** statements of that branch — before `final costValue = ...`:

```dart
          // A SKU change is consequential — confirm it (and surface how many
          // variation links will be re-pointed) before saving.
          final newSku = _skuController.text.trim();
          final skuChanged = newSku != _existingProduct!.sku;
          if (skuChanged) {
            final childCount = await ref
                .read(productVariationChildrenCountProvider(
                        _existingProduct!.sku)
                    .future)
                .catchError((_) => 0);
            if (!mounted) return;
            final confirmed = await _confirmSkuChange(
              oldSku: _existingProduct!.sku,
              newSku: newSku,
              variationCount: childCount,
            );
            // Returning here triggers the `finally` block, which resets the
            // saving spinner.
            if (confirmed != true) return;
          }
```

Then, in the admin `_existingProduct!.copyWith(` call within that same branch (~line 826), add `sku: newSku,` as the first named argument:

```dart
          final product = _existingProduct!.copyWith(
            sku: newSku,
            name: _nameController.text.trim(),
            costCode: costCode,
            // ... rest unchanged ...
```

- [ ] **Step 5: Static analysis**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/product_form_screen.dart`
Expected: No errors. (Pre-existing warnings in the file, if any, are acceptable — but the changed lines must be clean.)

- [ ] **Step 6: Manual smoke test**

Run the app (`flutter run`, or your usual launch) and verify:
1. As **admin**, open an existing product → the SKU field is editable, with the helper text. Change it and save → confirmation dialog appears showing `old → new`. Confirm → success snackbar.
2. In Firestore (or by reopening the product): the product's `sku` is the new value, and the old SKU now appears in the `barcodes` chips. Scanning/searching the old code still finds the product.
3. If the product had variations, their `baseSku` now equals the new SKU (group stays intact in receiving flows).
4. As **staff** and **cashier**, open an existing product → the SKU field is disabled (read-only).
5. On the **Add Product** screen, the Auto-generate toggle still works as before.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "$(cat <<'EOF'
feat(inventory): let admins edit product SKU with a confirm dialog

Admins can edit the SKU on the product form; the field stays locked for
staff/cashier. A SKU change is validated (format) and confirmed via a
dialog that summarizes the impact, including how many variations will be
re-pointed.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Firestore rules — lock SKU writes to admin

**Files:**
- Modify: `firestore.rules` (staff update rule, ~lines 84-85)
- Test: `tools/firestore-rules-test/test/rules.test.js`

> **Prerequisite:** the rules suite runs against the Firestore emulator and needs Java + the Firebase CLI. From `tools/firestore-rules-test/`, dependencies install with `npm install` and the suite runs with `npm test` (which wraps `firebase emulators:exec`). If the emulator/Java is unavailable in your environment, implement the change and run this suite wherever the emulator is available before merging.

- [ ] **Step 1: Add the failing rules tests**

In `tools/firestore-rules-test/test/rules.test.js`, inside the `describe("/products", ...)` block, add these two tests next to the existing `staff CANNOT change ...` tests:

```javascript
  it("staff CANNOT change sku", async () => {
    await assertFails(
      as("staff").collection("products").doc("p-1").update({ sku: "NEW-SKU" })
    );
  });

  it("admin CAN change sku", async () => {
    await assertSucceeds(
      as("admin").collection("products").doc("p-1").update({ sku: "NEW-SKU" })
    );
  });
```

- [ ] **Step 2: Run the suite to verify the staff test fails**

Run: `cd tools/firestore-rules-test && npm test`
Expected: FAIL — `staff CANNOT change sku` fails (the current staff rule allows SKU writes). `admin CAN change sku` passes.

- [ ] **Step 3: Add `sku` to the staff denylist**

In `firestore.rules`, update the staff product-update rule (~lines 84-85) from:

```
      // Staff can update product fields EXCEPT price, cost, and costCode
      allow update: if hasRole('staff') && isActiveUser() &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['price', 'cost', 'costCode']);
```

to:

```
      // Staff can update product fields EXCEPT sku, price, cost, and costCode
      // (SKU edits are admin-only). Unchanged values never appear in
      // affectedKeys(), so a staff edit that leaves sku alone still passes.
      allow update: if hasRole('staff') && isActiveUser() &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['sku', 'price', 'cost', 'costCode']);
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `cd tools/firestore-rules-test && npm test`
Expected: PASS — entire `/products` suite green, including `staff CANNOT change sku`, `admin CAN change sku`, and the existing `staff CAN update name + reorder level + supplier`.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "$(cat <<'EOF'
feat(rules): restrict product SKU writes to admin

Add 'sku' to the staff update denylist so only admins can change a
product SKU, mirroring the use-case enforcement. Unchanged SKU values
are not in affectedKeys(), so normal staff edits are unaffected.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Integration — full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full Dart test suite**

Run: `flutter test`
Expected: PASS — entire suite green (no regressions; the previously-stale cashier test is now fixed).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: No new errors introduced by these changes.

- [ ] **Step 3: Confirm clean status**

Run: `git status`
Expected: Working tree clean for the files this plan touched (the unrelated untracked `ios/`, `linux/`, `macos/`, `windows/` dirs and the pre-existing `receiving_repository_impl.dart` import edit are not part of this work and should be left alone).

---

## Self-Review Notes

- **Spec coverage:** admin-only gating (Tasks 1, 4, 5) · format + uniqueness validation (Task 1) · old-SKU scan alias (Task 1) · variation cascade (Task 2) · confirm dialog with variation count (Tasks 3, 4) · history-unaffected (no code change needed; verified by design — `productId` + snapshot) · audit log old→new + relinked count (Task 1) · tests at use-case/repo/rules layers (Tasks 1, 2, 5). All spec requirements map to a task.
- **Type consistency:** `productVariationChildrenCountProvider` (Task 3) is consumed in Task 4. `_confirmSkuChange({oldSku, newSku, variationCount})` defined and called with the same names in Task 4. Use-case codes `invalid-sku` / `duplicate-sku` / `restricted-fields` are asserted in the Task 1 tests exactly as produced. Repo `updateProduct` signature is unchanged across Tasks 1–2.
- **Known limits (from spec):** check-then-write uniqueness race (not transaction-guarded); old-SKU/barcode collision is low-risk and deduped within the product.
