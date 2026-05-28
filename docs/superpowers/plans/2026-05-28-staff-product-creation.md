# Staff Product Creation + Cashier Add-Product Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the inventory "Add Product" button from cashiers, and let staff create products by entering a cost *code* (decoded to the real cost in the use case, never shown in the staff UI).

**Architecture:** Reuse the existing `Permission.addProduct`. Grant it to staff; gate the inventory button on it; relax the Firestore products `create` rule to staff; and have `CreateProductUseCase` decode the staff-entered cost code into the numeric cost so the number never enters the UI layer. The product form gains a staff-only "Cost Code" field on the create path.

**Tech Stack:** Flutter + Riverpod, `mocktail` for Dart unit tests, `@firebase/rules-unit-testing` + Firestore emulator (Java 19) for rules tests.

**Spec:** `docs/superpowers/specs/2026-05-28-staff-product-creation-design.md`

**Conventions:**
- Dart tests: `flutter test <path>`
- Rules tests: from `tools/firestore-rules-test/`, `JAVA_HOME="$(/usr/libexec/java_home -v 19)" npm test`
- Commit per task. Do NOT deploy Firestore rules — that is the final task and requires the user's go-ahead.

---

## File Structure

- `lib/core/constants/role_permissions.dart` — add `addProduct` to staff (Task 1)
- `test/core/constants/role_permissions_test.dart` — staff/cashier/admin addProduct (Task 1)
- `firestore.rules` — products `create` allows staff (Task 2)
- `tools/firestore-rules-test/test/rules.test.js` — staff create allowed, cashier denied (Task 2)
- `lib/domain/usecases/product/create_product_usecase.dart` — decode cost code for non-admin (Task 3)
- `lib/presentation/providers/product_provider.dart` — inject `CostCodeRepository` (Task 3)
- `test/domain/usecases/product/create_product_usecase_test.dart` — staff success + invalid code (Task 3)
- `lib/presentation/mobile/screens/inventory/product_form_screen.dart` — staff create UI + branch (Task 4)
- `lib/presentation/mobile/screens/inventory/inventory_screen.dart` — gate Add Product on permission (Task 5)

---

## Task 1: Grant staff the `addProduct` permission

**Files:**
- Modify: `lib/core/constants/role_permissions.dart` (staff set ~line 117-122)
- Test: `test/core/constants/role_permissions_test.dart`

- [ ] **Step 1: Add failing tests**

Append this group inside `main()` in `test/core/constants/role_permissions_test.dart` (before the final closing `}`):

```dart
  group('RolePermissions — addProduct', () {
    test('cashier does NOT have addProduct', () {
      expect(
        RolePermissions.hasPermission(UserRole.cashier, Permission.addProduct),
        isFalse,
      );
    });

    test('staff HAS addProduct', () {
      expect(
        RolePermissions.hasPermission(UserRole.staff, Permission.addProduct),
        isTrue,
      );
    });

    test('admin HAS addProduct', () {
      expect(
        RolePermissions.hasPermission(UserRole.admin, Permission.addProduct),
        isTrue,
      );
    });
  });
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `flutter test test/core/constants/role_permissions_test.dart`
Expected: FAIL on "staff HAS addProduct" (staff currently lacks it).

- [ ] **Step 3: Add the permission to staff**

In `lib/core/constants/role_permissions.dart`, in `_staffPermissions`, replace:

```dart
    // Inventory (edit without price, no cost visibility)
    Permission.viewInventory,
    Permission.editProductLimited,
    // Note: viewProductCost is NOT included
    // Note: addProduct is NOT included (admin only)
    // Note: deleteProduct is NOT included (admin only)
```

with:

```dart
    // Inventory (edit without price, no cost visibility)
    Permission.viewInventory,
    Permission.editProductLimited,
    // Staff add products by entering a cost CODE; the numeric cost is
    // decoded in CreateProductUseCase and never shown in the staff UI.
    Permission.addProduct,
    // Note: viewProductCost is NOT included
    // Note: deleteProduct is NOT included (admin only)
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `flutter test test/core/constants/role_permissions_test.dart`
Expected: PASS (all 3 new tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/role_permissions.dart test/core/constants/role_permissions_test.dart
git commit -m "feat(permissions): grant staff addProduct"
```

---

## Task 2: Allow staff to create products in Firestore rules

**Files:**
- Modify: `firestore.rules` (products collection, ~line 74-75)
- Test: `tools/firestore-rules-test/test/rules.test.js` (`/products` describe, ~line 176-192)

- [ ] **Step 1: Update the rules test to the new expectation**

In `tools/firestore-rules-test/test/rules.test.js`, replace the existing test:

```js
  it("only admin can create products", async () => {
    await assertFails(
      as("cashier").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
    await assertFails(
      as("staff").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
    await assertSucceeds(
      as("admin").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
  });
```

with:

```js
  it("admin and staff can create products; cashier cannot", async () => {
    // Staff create products via cost-code entry (decoded app-side), so the
    // rules allow staff create. Cashier still cannot.
    await assertFails(
      as("cashier").collection("products").doc("p-2").set({ sku: "X", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
    await assertSucceeds(
      as("staff").collection("products").doc("p-3").set({ sku: "Y", price: 1, cost: 125, costCode: "NBF", quantity: 0, isActive: true })
    );
    await assertSucceeds(
      as("admin").collection("products").doc("p-4").set({ sku: "Z", price: 1, cost: 0.5, costCode: "A", quantity: 0, isActive: true })
    );
  });

  it("inactive staff cannot create products", async () => {
    await assertFails(
      as("inactiveStaff").collection("products").doc("p-5").set({ sku: "W", price: 1, cost: 1, costCode: "N", quantity: 0, isActive: true })
    );
  });
```

Then add an `inactiveStaff` user. In the `USERS` map near the top of the file, add:

```js
  inactiveStaff: { uid: "inactive-staff-1", role: "staff", isActive: false },
```

(The `beforeEach` seeds every user in `USERS`, so no other change is needed.)

- [ ] **Step 2: Run the rules suite, verify the new test fails**

Run: `cd tools/firestore-rules-test && JAVA_HOME="$(/usr/libexec/java_home -v 19)" npm test`
Expected: FAIL — "admin and staff can create products; cashier cannot" fails on the staff `assertSucceeds` (rules currently allow create for admin only).

- [ ] **Step 3: Relax the products create rule**

In `firestore.rules`, in the `match /products/{productId}` block, replace:

```
      // Only admin can create/delete products
      allow create, delete: if isAdmin() && isActiveUser();
```

with:

```
      // Admin and staff can create products. Staff enter a cost CODE that the
      // app decodes to cost, so there is no field-level cost constraint here.
      // Cashier cannot create. Delete stays admin-only.
      allow create: if (isAdmin() || hasRole('staff')) && isActiveUser();
      allow delete: if isAdmin() && isActiveUser();
```

- [ ] **Step 4: Run the rules suite, verify all pass**

Run: `cd tools/firestore-rules-test && JAVA_HOME="$(/usr/libexec/java_home -v 19)" npm test`
Expected: PASS — new create test and inactive-staff test green; the existing "only admin can delete products" test still passes.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(rules): allow staff to create products"
```

---

## Task 3: Decode the cost code in `CreateProductUseCase`

**Files:**
- Modify: `lib/domain/usecases/product/create_product_usecase.dart`
- Modify: `lib/presentation/providers/product_provider.dart:151-156`
- Test: `test/domain/usecases/product/create_product_usecase_test.dart`

- [ ] **Step 1: Update the use-case test (constructor, staff success, invalid code)**

Replace the whole body of `test/domain/usecases/product/create_product_usecase_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/cost_code_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _MockCostCodeRepository extends Mock implements CostCodeRepository {}

class _FakeProduct extends Fake implements ProductEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

ProductEntity _product({String name = 'Coke', String costCode = 'NBF'}) =>
    ProductEntity(
      id: '',
      sku: 'SKU-001',
      name: name,
      costCode: costCode,
      cost: 0,
      price: 25,
      quantity: 100,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProduct());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;
  late _MockCostCodeRepository costCodeRepo;
  late CreateProductUseCase useCase;

  setUp(() {
    repo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();
    costCodeRepo = _MockCostCodeRepository();
    useCase = CreateProductUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
      costCodeRepository: costCodeRepo,
    );

    when(() => costCodeRepo.getCostCodeMapping())
        .thenAnswer((_) async => CostCodeEntity.defaultMapping());
    when(() => repo.createProduct(
          product: any(named: 'product'),
          createdBy: any(named: 'createdBy'),
          createdByName: any(named: 'createdByName'),
        )).thenAnswer((inv) async =>
        (inv.namedArguments[#product] as ProductEntity).copyWith(id: 'p-1'));
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CreateProductUseCase', () {
    test('admin creates successfully (cost used as-is)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: _product().copyWith(cost: 12),
      );

      expect(result.success, true);
      expect(result.data?.id, 'p-1');
      expect(result.data?.cost, 12);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('staff creates successfully; cost decoded from cost code', () async {
      // Default mapping: N=1, B=2, F=5 -> "NBF" decodes to 125.
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: _product(costCode: 'NBF'),
      );

      expect(result.success, true);
      expect(result.data?.cost, 125);
    });

    test('staff with invalid cost code fails, nothing written', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: _product(costCode: '###'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-cost-code');
      verifyNever(() => repo.createProduct(
            product: any(named: 'product'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
          ));
    });

    test('cashier denied (addProduct admin/staff only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: _product(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('inactive admin denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        product: _product(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `flutter test test/domain/usecases/product/create_product_usecase_test.dart`
Expected: FAIL to compile — `CreateProductUseCase` has no `costCodeRepository` parameter yet.

- [ ] **Step 3: Implement the decode in the use case**

Replace the whole file `lib/domain/usecases/product/create_product_usecase.dart` with:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/cost_code_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Creates a product. Permission: [Permission.addProduct] (admin + staff).
///
/// Admins enter a numeric cost directly. Non-admins (staff) enter a cost
/// CODE; this use case decodes it to the real cost so the numeric value never
/// lives in the UI layer.
class CreateProductUseCase {
  final ProductRepository _repository;
  final ActivityLogger _logger;
  final CostCodeRepository _costCodeRepository;

  CreateProductUseCase({
    required ProductRepository repository,
    required ActivityLogger logger,
    required CostCodeRepository costCodeRepository,
  })  : _repository = repository,
        _logger = logger,
        _costCodeRepository = costCodeRepository;

  Future<UseCaseResult<ProductEntity>> execute({
    required UserEntity actor,
    required ProductEntity product,
  }) async {
    try {
      assertPermission(actor, Permission.addProduct);

      var toCreate = product;

      // Non-admin actors submit a cost CODE, not a number. Decode it here so
      // the numeric cost is derived authoritatively in logic, not the UI.
      if (actor.role != UserRole.admin) {
        final mapping = await _costCodeRepository.getCostCodeMapping();
        final decoded = mapping.decode(product.costCode);
        if (decoded == null) {
          return const UseCaseResult.failure(
            message: 'Invalid cost code',
            code: 'invalid-cost-code',
          );
        }
        toCreate = product.copyWith(
          cost: decoded,
          costCode: mapping.encode(decoded),
        );
      }

      final created = await _repository.createProduct(
        product: toCreate,
        createdBy: actor.id,
        createdByName: actor.displayName,
      );

      await _logger.log(
        type: ActivityType.inventory,
        action: 'Created product: ${created.name}',
        details: 'SKU ${created.sku} • ₱${created.price.toStringAsFixed(2)}',
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: created.id,
        entityType: 'product',
      );

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to create product: $e');
    }
  }
}
```

- [ ] **Step 4: Wire the new dependency in the provider**

In `lib/presentation/providers/product_provider.dart`, add this import alongside the others at the top:

```dart
import 'package:maki_mobile_pos/presentation/providers/cost_code_provider.dart';
```

Then replace:

```dart
final createProductUseCaseProvider = Provider<CreateProductUseCase>((ref) {
  return CreateProductUseCase(
    repository: ref.watch(productRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});
```

with:

```dart
final createProductUseCaseProvider = Provider<CreateProductUseCase>((ref) {
  return CreateProductUseCase(
    repository: ref.watch(productRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
    costCodeRepository: ref.watch(costCodeRepositoryProvider),
  );
});
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `flutter test test/domain/usecases/product/create_product_usecase_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 6: Run analyzer on touched files**

Run: `flutter analyze lib/domain/usecases/product/create_product_usecase.dart lib/presentation/providers/product_provider.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/usecases/product/create_product_usecase.dart lib/presentation/providers/product_provider.dart test/domain/usecases/product/create_product_usecase_test.dart
git commit -m "feat(products): decode staff cost code into cost on create"
```

---

## Task 4: Staff create UI in the product form

No widget-test harness exists for this screen, so this task is implement + analyze + manual verification. Make the edits, then verify by hand.

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

- [ ] **Step 1: Add a cost-code controller**

After line 43 (`final _costController = TextEditingController();`) add:

```dart
  final _costCodeController = TextEditingController();
```

After line 144 (`_costController.dispose();`) add:

```dart
    _costCodeController.dispose();
```

- [ ] **Step 2: Extend the capability flags for staff-on-create**

Replace (lines ~162-170):

```dart
    // Determine edit capabilities based on role
    final bool canEditPrice = userRole == UserRole.admin;
    final bool canEditCost = userRole == UserRole.admin;
    final bool canViewCost = userRole == UserRole.admin;
    final bool canEditSku =
        !widget.isEditing; // SKU never editable after creation
    final bool canSelectSupplier = userRole == UserRole.admin;
    // Cashier can reach the edit form but may only change the product name.
    final bool isNameOnly = userRole == UserRole.cashier;
```

with:

```dart
    // Determine edit capabilities based on role
    final bool isCreating = !widget.isEditing;
    // Staff may set the price only while creating (not when editing existing).
    final bool canEditPrice = userRole == UserRole.admin ||
        (userRole == UserRole.staff && isCreating);
    final bool canEditCost = userRole == UserRole.admin;
    final bool canViewCost = userRole == UserRole.admin;
    final bool canEditSku =
        !widget.isEditing; // SKU never editable after creation
    final bool canSelectSupplier = userRole == UserRole.admin;
    // Cashier can reach the edit form but may only change the product name.
    final bool isNameOnly = userRole == UserRole.cashier;
    // Staff create products by entering a cost CODE; the numeric cost field
    // stays admin-only and is decoded to cost in CreateProductUseCase.
    final bool showCostCodeField = userRole == UserRole.staff && isCreating;
```

- [ ] **Step 3: Let staff attach an image on create**

Replace (line ~287):

```dart
                        enabled: userRole == UserRole.admin || isNameOnly,
```

with:

```dart
                        enabled: userRole == UserRole.admin ||
                            isNameOnly ||
                            (userRole == UserRole.staff && isCreating),
```

- [ ] **Step 4: Render the Cost Code field (staff create only)**

Immediately AFTER the cost-field block that ends at line ~419 (the closing of `if (showCostField) Column(...)`, right before the `// Quantity` comment at line ~421), insert:

```dart
                    // Cost Code — staff enter the product's letter code; the
                    // app decodes it to the real cost in CreateProductUseCase.
                    // The numeric cost is never shown to staff.
                    if (showCostCodeField)
                      Column(
                        children: [
                          TextFormField(
                            controller: _costCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Cost Code *',
                              prefixIcon: Icon(CupertinoIcons.lock),
                              helperText: 'Enter the product cost code',
                            ),
                            validator: (value) {
                              final code = value?.trim() ?? '';
                              if (code.isEmpty) return 'Cost code is required';
                              if (!ref.read(isValidCostCodeProvider(code))) {
                                return 'Invalid cost code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
```

- [ ] **Step 5: Add a staff branch to the create logic**

In `_save` (or the save handler), find the create branch — the `} else {` with `// ==================== CREATE LOGIC (ADMIN ONLY) ====================` at line ~901. Replace that single line:

```dart
      } else {
        // ==================== CREATE LOGIC (ADMIN ONLY) ====================
```

with a staff branch followed by the existing admin branch:

```dart
      } else if (userRole == UserRole.staff) {
        // ==================== STAFF CREATE (cost via code) ====================
        // cost is left 0 here; CreateProductUseCase decodes costCode -> cost.
        final product = ProductEntity(
          id: '',
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          costCode: _costCodeController.text.trim(),
          cost: 0,
          price: double.tryParse(_priceController.text) ?? 0.0,
          quantity: int.tryParse(_quantityController.text) ?? 0,
          reorderLevel: int.tryParse(_reorderLevelController.text) ?? 10,
          unit: _unitController.text.trim().isEmpty
              ? 'pcs'
              : _unitController.text.trim(),
          supplierId: null,
          supplierName: null,
          isActive: true,
          createdAt: DateTime.now(),
          barcodes: List<String>.from(_barcodes),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        final productOps = ref.read(productOperationsProvider.notifier);
        final created = await productOps.createProduct(
          actor: currentUser,
          product: product,
        );
        if (created == null) throw Exception('Failed to create product');

        if (_pendingImageBytes != null) {
          try {
            final storage = ref.read(productImageStorageServiceProvider);
            final url = await storage.upload(
              productId: created.id,
              bytes: _pendingImageBytes!,
            );
            await productOps.updateProduct(
              actor: currentUser,
              product: created.copyWith(imageUrl: url),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Image upload failed — product saved without image.',
                  ),
                ),
              );
            }
          }
        }
      } else {
        // ==================== CREATE LOGIC (ADMIN ONLY) ====================
```

(The existing admin create code below the comment is unchanged; you are only inserting the staff branch above it and keeping the `else {` for admin.)

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/product_form_screen.dart`
Expected: No issues. (`isValidCostCodeProvider`, `CupertinoIcons`, and `ProductEntity` are already reachable through the existing `providers.dart`, `cupertino.dart`, and `entities.dart` imports.)

- [ ] **Step 7: Manual verification**

Run the app (`flutter run`) and, logged in as **staff**:
1. Open Inventory → Add Product. Confirm: **no** numeric "Cost" field; a **"Cost Code"** field is shown; Price and SKU are editable.
2. Enter name, SKU, price, quantity, and a valid cost code (e.g. `NBF`). Save. Confirm the product is created (no permission error).
3. In Firestore, confirm the new product's `cost` equals the decoded value (e.g. 125 for `NBF` with the default mapping) and `costCode` is set.
4. Enter an invalid cost code (e.g. `###`) and confirm save is blocked with "Invalid cost code".
As **admin**, confirm the create form is unchanged (numeric Cost field present) and still works.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/product_form_screen.dart
git commit -m "feat(inventory): staff create products via cost code"
```

---

## Task 5: Gate the inventory Add Product button on permission

**Files:**
- Modify: `lib/presentation/mobile/screens/inventory/inventory_screen.dart`

- [ ] **Step 1: Compute the capability flag**

Confirm `Permission` is imported. If `flutter analyze` (Step 4) reports `Permission` undefined, add at the top:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
```

After line 35 (`final isAdmin = currentUser?.role == UserRole.admin;`) add:

```dart
    final canAddProduct =
        currentUser?.hasPermission(Permission.addProduct) ?? false;
```

- [ ] **Step 2: Gate the overflow "Add Product" menu item**

Replace the overflow `itemBuilder` (lines ~87-112) so the add item is conditional:

```dart
            itemBuilder: (context) => [
              if (canAddProduct)
                const PopupMenuItem(
                  value: 'add',
                  child: ListTile(
                    leading: Icon(CupertinoIcons.add),
                    title: Text('Add Product'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(CupertinoIcons.cloud_upload),
                  title: Text('Import CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(CupertinoIcons.cloud_download),
                  title: Text('Export'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
```

- [ ] **Step 3: Gate the bottom Add Product button**

Replace the `bottomNavigationBar` (lines ~134-144):

```dart
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _handleMenuAction('add'),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Add Product'),
          ),
        ),
      ),
```

with:

```dart
      bottomNavigationBar: canAddProduct
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleMenuAction('add'),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('Add Product'),
                ),
              ),
            )
          : null,
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/presentation/mobile/screens/inventory/inventory_screen.dart`
Expected: No issues.

- [ ] **Step 5: Manual verification**

Run the app:
- As **cashier**: Inventory shows **no** bottom Add Product button, and the overflow menu has **no** "Add Product" item (Import/Export still present).
- As **staff** and **admin**: both Add Product entry points are present.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/inventory/inventory_screen.dart
git commit -m "feat(inventory): hide Add Product from cashier"
```

---

## Task 6: Full verification + deploy

- [ ] **Step 1: Run the full Dart test suite**

Run: `flutter test`
Expected: PASS (no regressions; new product/permission tests green).

- [ ] **Step 2: Run the full rules suite**

Run: `cd tools/firestore-rules-test && JAVA_HOME="$(/usr/libexec/java_home -v 19)" npm test`
Expected: PASS.

- [ ] **Step 3: Analyze the whole project**

Run: `flutter analyze`
Expected: No new issues.

- [ ] **Step 4: Deploy Firestore rules (REQUIRES USER GO-AHEAD)**

This is a production change. Confirm with the user before running:

```bash
firebase deploy --only firestore:rules --project maki-mobile-pos
```

Then verify the deployed ruleset contains the staff create rule (active ruleset `createTime` is recent and the source contains `hasRole('staff')` in the products `create`).

---

## Self-Review

- **Spec coverage:** A (button gating) → Task 5; B (staff permission) → Task 1; C (form cost-code field + staff create branch) → Task 4; D (use-case decode) → Task 3; E (Firestore rules) → Task 2; testing → Tasks 1-3 (automated) + Tasks 4-5 (manual) + Task 6 (full run). All spec sections covered.
- **Placeholder scan:** none — every code/edit step contains full content and exact strings.
- **Type consistency:** `CreateProductUseCase({repository, logger, costCodeRepository})` matches the provider wiring (Task 3 Step 4) and the test setUp (Task 3 Step 1); `isValidCostCodeProvider(code)` returns `bool` (used in the form validator); `mapping.decode/encode` from `CostCodeEntity`; `costCodeRepositoryProvider` and `CostCodeRepository.getCostCodeMapping()` match the existing definitions.
