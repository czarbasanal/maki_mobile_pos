# Unify Receiving CSV Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the inline receiving CSV dialog a thin client of the batch-import pipeline by extracting a shared `ReceivingImportResolver`, so both paths use one RFC-4180 parser, one classification, one set of validation rules, and consistent cost-code encoding.

**Architecture:** Extract steps 2–3 (create new products + build receiving items) of `BatchImportReceivingUseCase` into a new domain service `ReceivingImportResolver`. The batch use case and the rewritten `CsvImportDialog` both call it. A shared `ImportPreview` widget renders the identical classification preview in both screens.

**Tech Stack:** Flutter, Riverpod (StateNotifier/Provider), `csv` package, `file_picker`, `mocktail` + `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-05-30-unify-receiving-csv-import-design.md](../specs/2026-05-30-unify-receiving-csv-import-design.md)

---

## File Structure

- **Create** `lib/domain/usecases/receiving/receiving_import_resolver.dart` — `ResolvedImport`, `ReceivingImportException`, `ReceivingImportResolver.resolve(...)`. Owns new-product creation + item building.
- **Modify** `lib/domain/usecases/receiving/batch_import_receiving_usecase.dart` — delegate steps 2–3 to the resolver; keep permission/draft/complete orchestration.
- **Modify** `lib/presentation/providers/receiving_provider.dart` — add `receivingImportResolverProvider`; rewire `batchImportReceivingUseCaseProvider`.
- **Create** `lib/presentation/mobile/widgets/receiving/import_preview.dart` — shared `ImportPreview` widget (summary chips + error list + classified row tiles).
- **Modify** `lib/presentation/mobile/screens/receiving/batch_import_screen.dart` — use `ImportPreview`; remove the moved private widgets.
- **Modify** `lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart` — rewrite as a `ConsumerStatefulWidget` thin client.
- **Create** `test/domain/usecases/receiving/receiving_import_resolver_test.dart` — resolver unit tests.
- **Modify** `test/domain/usecases/receiving/batch_import_receiving_usecase_test.dart` — construct via resolver.
- **Create** `test/presentation/widgets/csv_import_dialog_test.dart` — dialog widget test.

---

### Task 1: ReceivingImportResolver

**Files:**
- Create: `lib/domain/usecases/receiving/receiving_import_resolver.dart`
- Test: `test/domain/usecases/receiving/receiving_import_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/usecases/receiving/receiving_import_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/receiving_import_resolver.dart';

class _MockCreateProductUseCase extends Mock implements CreateProductUseCase {}

class _FakeProductEntity extends Fake implements ProductEntity {}

class _FakeUserEntity extends Fake implements UserEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

ProductEntity _existing({String sku = 'ABC', double cost = 10}) => ProductEntity(
      id: 'p-$sku',
      sku: sku,
      name: 'Existing $sku',
      costCode: 'X',
      cost: cost,
      price: cost * 1.5,
      quantity: 0,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

ParsedImportRow _row({
  int rowNumber = 2,
  String sku = 'ABC',
  String name = 'Item',
  double cost = 10,
  double price = 15,
  int quantity = 5,
}) =>
    ParsedImportRow(
      rowNumber: rowNumber,
      sku: sku,
      name: name,
      category: null,
      unit: 'pcs',
      cost: cost,
      price: price,
      quantity: quantity,
      reorderLevel: 0,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeUserEntity());
  });

  late _MockCreateProductUseCase createProduct;
  late ReceivingImportResolver resolver;
  late CostCodeEntity mapping;

  setUp(() {
    createProduct = _MockCreateProductUseCase();
    mapping = CostCodeEntity.defaultMapping();
    resolver = ReceivingImportResolver(createProductUseCase: createProduct);
  });

  void stubCreateEchoesId(String id) {
    when(() => createProduct.execute(
          actor: any(named: 'actor'),
          product: any(named: 'product'),
        )).thenAnswer((inv) async {
      final candidate =
          inv.namedArguments[const Symbol('product')] as ProductEntity;
      return UseCaseResult.successData(candidate.copyWith(id: id));
    });
  }

  group('ReceivingImportResolver', () {
    test('existing match → item targets existing id, no product created',
        () async {
      final classified = classifyRows(
        rows: [_row(sku: 'ABC', cost: 10)],
        activeProducts: [_existing(sku: 'ABC', cost: 10)],
      );

      final result = await resolver.resolve(
        actor: _user(UserRole.staff),
        classified: classified,
        costCodeMapping: mapping,
      );

      expect(result.createdProducts, isEmpty);
      expect(result.items, hasLength(1));
      expect(result.items.first.productId, 'p-ABC');
      expect(result.items.first.unitCost, 10);
      verifyNever(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          ));
    });

    test('cost mismatch → item carries the new CSV cost against existing id',
        () async {
      final classified = classifyRows(
        rows: [_row(sku: 'ABC', cost: 12)],
        activeProducts: [_existing(sku: 'ABC', cost: 10)],
      );
      expect(classified.first, isA<CostMismatchRow>());

      final result = await resolver.resolve(
        actor: _user(UserRole.staff),
        classified: classified,
        costCodeMapping: mapping,
      );

      expect(result.createdProducts, isEmpty);
      expect(result.items.first.productId, 'p-ABC');
      expect(result.items.first.unitCost, 12);
    });

    test('new product row creates a product and item targets new id',
        () async {
      stubCreateEchoesId('p-NEW');
      final classified = classifyRows(
        rows: [_row(sku: 'NEW-1', cost: 8)],
        activeProducts: const [],
      );
      expect(classified.first, isA<NewProductRow>());

      final result = await resolver.resolve(
        actor: _user(UserRole.admin),
        classified: classified,
        costCodeMapping: mapping,
      );

      expect(result.createdProducts, hasLength(1));
      expect(result.items.first.productId, 'p-NEW');
      verify(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          )).called(1);
    });

    test('GENERATE literal produces a non-literal generated SKU', () async {
      stubCreateEchoesId('p-AUTO');
      final classified = classifyRows(
        rows: [_row(sku: 'GENERATE', name: 'Brand New', cost: 8)],
        activeProducts: const [],
      );

      await resolver.resolve(
        actor: _user(UserRole.admin),
        classified: classified,
        costCodeMapping: mapping,
      );

      final captured = verify(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: captureAny(named: 'product'),
          )).captured;
      final product = captured.single as ProductEntity;
      expect(product.sku, isNot(equals(kSkuGenerateLiteral)));
      expect(product.sku, isNotEmpty);
      expect(product.quantity, 0);
    });

    test('new-product row without addProduct permission throws', () async {
      final classified = classifyRows(
        rows: [_row(sku: 'NEW-1')],
        activeProducts: const [],
      );

      expect(
        () => resolver.resolve(
          actor: _user(UserRole.cashier),
          classified: classified,
          costCodeMapping: mapping,
        ),
        throwsA(isA<AppException>()),
      );
      verifyNever(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          ));
    });

    test('product creation failure throws ReceivingImportException', () async {
      when(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          )).thenAnswer(
        (_) async => const UseCaseResult.failure(message: 'boom'),
      );
      final classified = classifyRows(
        rows: [_row(sku: 'NEW-1', name: 'X')],
        activeProducts: const [],
      );

      expect(
        () => resolver.resolve(
          actor: _user(UserRole.admin),
          classified: classified,
          costCodeMapping: mapping,
        ),
        throwsA(isA<ReceivingImportException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/usecases/receiving/receiving_import_resolver_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../receiving_import_resolver.dart'` (file not yet created).

- [ ] **Step 3: Write the implementation**

Create `lib/domain/usecases/receiving/receiving_import_resolver.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';

/// Output of resolving classified import rows into receiving items.
///
/// [items] is one [ReceivingItemEntity] per classified row (existing,
/// cost-mismatch, and new). [createdProducts] holds the products materialized
/// for new-product rows, in row order, for caller awareness.
class ResolvedImport {
  final List<ReceivingItemEntity> items;
  final List<ProductEntity> createdProducts;
  const ResolvedImport({required this.items, required this.createdProducts});
}

/// Thrown when resolution cannot complete (e.g. a product fails to create).
/// Subclass of [AppException] so callers can use [UseCaseResult.fromException].
class ReceivingImportException extends AppException {
  const ReceivingImportException({required super.message, super.code});
}

/// Shared resolution step for both CSV import flows (batch screen + inline
/// dialog). Given classified rows it:
///
/// 1. Asserts [Permission.addProduct] only when the classification contains
///    at least one [NewProductRow].
/// 2. Creates a fresh product (quantity 0, costCode-encoded, supplier from
///    caller) for every [NewProductRow]. SKU is honored as-typed, or generated
///    from the name when the row uses the `GENERATE` literal.
/// 3. Builds a [ReceivingItemEntity] for every classified row. Existing and
///    cost-mismatch rows target the stored `existing.id` and pass the new CSV
///    cost — the receiving completion pipeline spawns the SKU variation for the
///    cost-mismatch case (see receiving_repository_impl).
///
/// Throws [ReceivingImportException] if any product creation fails; products
/// already created in this run are left in place (matches existing batch
/// behavior).
class ReceivingImportResolver {
  final CreateProductUseCase _createProductUseCase;
  final Uuid _uuid;

  ReceivingImportResolver({
    required CreateProductUseCase createProductUseCase,
    Uuid? uuid,
  })  : _createProductUseCase = createProductUseCase,
        _uuid = uuid ?? const Uuid();

  Future<ResolvedImport> resolve({
    required UserEntity actor,
    required List<ClassifiedRow> classified,
    required CostCodeEntity costCodeMapping,
    String? supplierId,
    String? supplierName,
  }) async {
    final hasNewProducts = classified.whereType<NewProductRow>().isNotEmpty;
    if (hasNewProducts) {
      assertPermission(actor, Permission.addProduct);
    }

    // Materialize new products, tracked by row number so item-building can
    // join them back without relying on identity.
    final createdByRow = <int, ProductEntity>{};
    final createdProducts = <ProductEntity>[];
    for (final c in classified) {
      if (c is! NewProductRow) continue;
      final row = c.row;
      final sku = row.autoGenerateSku
          ? SkuGenerator.generateForName(row.name)
          : row.sku;

      final candidate = ProductEntity(
        id: '',
        sku: sku,
        name: row.name,
        costCode: costCodeMapping.encode(row.cost),
        cost: row.cost,
        price: row.price,
        quantity: 0,
        reorderLevel: row.reorderLevel,
        unit: row.unit,
        supplierId: supplierId,
        supplierName: supplierName,
        isActive: true,
        createdAt: DateTime.now(),
        category: row.category,
      );

      final result = await _createProductUseCase.execute(
        actor: actor,
        product: candidate,
      );
      if (!result.success || result.data == null) {
        throw ReceivingImportException(
          message:
              'Could not create product for row ${row.rowNumber} (${row.name}): '
              '${result.errorMessage ?? "unknown error"}',
        );
      }
      createdByRow[row.rowNumber] = result.data!;
      createdProducts.add(result.data!);
    }

    final items = <ReceivingItemEntity>[];
    for (final c in classified) {
      final row = c.row;
      final ProductEntity targetProduct;
      if (c is ExistingMatchRow) {
        targetProduct = c.existing;
      } else if (c is CostMismatchRow) {
        targetProduct = c.existing;
      } else if (c is NewProductRow) {
        targetProduct = createdByRow[row.rowNumber]!;
      } else {
        throw StateError('Unknown ClassifiedRow subtype: ${c.runtimeType}');
      }

      items.add(ReceivingItemEntity(
        id: _uuid.v4(),
        productId: targetProduct.id,
        sku: targetProduct.sku,
        name: targetProduct.name,
        quantity: row.quantity,
        unit: row.unit.isEmpty ? targetProduct.unit : row.unit,
        unitCost: row.cost,
        costCode: costCodeMapping.encode(row.cost),
      ));
    }

    return ResolvedImport(items: items, createdProducts: createdProducts);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/usecases/receiving/receiving_import_resolver_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/receiving/receiving_import_resolver.dart \
        test/domain/usecases/receiving/receiving_import_resolver_test.dart
git commit -m "feat(receiving): add shared ReceivingImportResolver

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Refactor BatchImportReceivingUseCase to use the resolver

**Files:**
- Modify: `lib/domain/usecases/receiving/batch_import_receiving_usecase.dart`
- Modify: `test/domain/usecases/receiving/batch_import_receiving_usecase_test.dart`

- [ ] **Step 1: Update the existing test to construct via the resolver**

The existing tests already mock `createProduct` and verify `createProduct.execute`. Keep them valid by wrapping the same mock in a real resolver. In `test/domain/usecases/receiving/batch_import_receiving_usecase_test.dart`:

Add the import near the other use-case imports:

```dart
import 'package:maki_mobile_pos/domain/usecases/receiving/receiving_import_resolver.dart';
```

Replace the `useCase = BatchImportReceivingUseCase(...)` construction in `setUp` (currently passing `createProductUseCase: createProduct`) with:

```dart
    useCase = BatchImportReceivingUseCase(
      receivingRepository: receivingRepo,
      resolver: ReceivingImportResolver(createProductUseCase: createProduct),
      completeReceivingUseCase: completeReceiving,
    );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/usecases/receiving/batch_import_receiving_usecase_test.dart`
Expected: FAIL — `No named parameter with the name 'resolver'` (constructor not yet updated).

- [ ] **Step 3: Refactor the use case**

In `lib/domain/usecases/receiving/batch_import_receiving_usecase.dart`:

Replace the imports of `sku_generator.dart`, `cost_code_entity.dart` usage stays, `create_product_usecase.dart` and `permission_assert.dart` — specifically remove the `create_product_usecase.dart` and `sku_generator.dart` imports and add the resolver import. The final import block should be:

```dart
import 'package:uuid/uuid.dart';

import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/receiving_import_resolver.dart';
```

Replace the fields + constructor (the `_createProductUseCase` field and its constructor param) with a resolver field:

```dart
  final ReceivingRepository _receivingRepository;
  final ReceivingImportResolver _resolver;
  final CompleteReceivingUseCase _completeReceivingUseCase;
  final Uuid _uuid;

  BatchImportReceivingUseCase({
    required ReceivingRepository receivingRepository,
    required ReceivingImportResolver resolver,
    required CompleteReceivingUseCase completeReceivingUseCase,
    Uuid? uuid,
  })  : _receivingRepository = receivingRepository,
        _resolver = resolver,
        _completeReceivingUseCase = completeReceivingUseCase,
        _uuid = uuid ?? const Uuid();
```

Replace the body of `execute` (from the `try {` block through `final saved = ...`/completion) so steps 2–3 call the resolver. The new `execute` body is:

```dart
    try {
      assertPermission(actor, Permission.bulkReceive);
      assertPermission(actor, Permission.receiveStock);

      if (classified.isEmpty) {
        return UseCaseResult.failure(message: 'No rows to import.');
      }

      // Steps 2–3: create new products + build items (shared resolver, which
      // also asserts addProduct when new-product rows are present).
      final resolved = await _resolver.resolve(
        actor: actor,
        classified: classified,
        costCodeMapping: costCodeMapping,
        supplierId: supplierId,
        supplierName: supplierName,
      );
      final items = resolved.items;

      // Step 4: persist draft.
      final referenceNumber =
          await _receivingRepository.generateReferenceNumber();
      final totalCost = items.fold<double>(
        0,
        (sum, i) => sum + i.unitCost * i.quantity,
      );
      final totalQuantity = items.fold<int>(0, (sum, i) => sum + i.quantity);

      final draft = ReceivingEntity(
        id: '',
        referenceNumber: referenceNumber,
        supplierId: supplierId,
        supplierName: supplierName,
        items: items,
        totalCost: totalCost,
        totalQuantity: totalQuantity,
        status: ReceivingStatus.draft,
        notes: notes,
        createdAt: DateTime.now(),
        createdBy: actor.id,
        createdByName: actor.displayName,
      );

      final saved = await _receivingRepository.createReceiving(draft);

      // Step 5: complete the receiving (stock + price history + audit).
      return await _completeReceivingUseCase.execute(
        actor: actor,
        receivingId: saved.id,
      );
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Batch import failed: $e');
    }
```

Note: the `costCodeMapping`, `supplierId`, `supplierName`, `notes` parameters of `execute` are unchanged. The `_uuid` field is retained (no longer used for item ids since the resolver owns that, but keep it to avoid touching the constructor signature consumers rely on — if `flutter analyze` flags it as unused, remove the field and its constructor param in this same step).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/domain/usecases/receiving/batch_import_receiving_usecase_test.dart`
Expected: PASS (all existing tests green).

- [ ] **Step 5: Run analyzer on the changed files**

Run: `flutter analyze lib/domain/usecases/receiving/batch_import_receiving_usecase.dart`
Expected: No issues. (If `_uuid` is reported unused, remove the field + its constructor initializer and re-run.)

- [ ] **Step 6: Commit**

```bash
git add lib/domain/usecases/receiving/batch_import_receiving_usecase.dart \
        test/domain/usecases/receiving/batch_import_receiving_usecase_test.dart
git commit -m "refactor(receiving): batch use case delegates to ReceivingImportResolver

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Wire the resolver provider

**Files:**
- Modify: `lib/presentation/providers/receiving_provider.dart:7` (imports) and `:29-37` (use-case providers)

- [ ] **Step 1: Add the resolver import**

In `lib/presentation/providers/receiving_provider.dart`, add after the existing `batch_import_receiving_usecase.dart` import (line 7):

```dart
import 'package:maki_mobile_pos/domain/usecases/receiving/receiving_import_resolver.dart';
```

- [ ] **Step 2: Add the resolver provider and rewire the use case provider**

Replace the existing `batchImportReceivingUseCaseProvider` block (lines 29-37) with:

```dart
final receivingImportResolverProvider =
    Provider<ReceivingImportResolver>((ref) {
  return ReceivingImportResolver(
    createProductUseCase: ref.watch(createProductUseCaseProvider),
  );
});

final batchImportReceivingUseCaseProvider =
    Provider<BatchImportReceivingUseCase>((ref) {
  return BatchImportReceivingUseCase(
    receivingRepository: ref.watch(receivingRepositoryProvider),
    resolver: ref.watch(receivingImportResolverProvider),
    completeReceivingUseCase: ref.watch(completeReceivingUseCaseProvider),
  );
});
```

- [ ] **Step 3: Verify it analyzes clean**

Run: `flutter analyze lib/presentation/providers/receiving_provider.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/receiving_provider.dart
git commit -m "feat(receiving): provide ReceivingImportResolver

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Extract the shared ImportPreview widget

**Files:**
- Create: `lib/presentation/mobile/widgets/receiving/import_preview.dart`
- Modify: `lib/presentation/mobile/screens/receiving/batch_import_screen.dart`

- [ ] **Step 1: Create the shared widget**

Create `lib/presentation/mobile/widgets/receiving/import_preview.dart`. Move the four private widget classes `_SummaryChips`, `_Chip`, `_ErrorList`, and `_ClassifiedRowTile` **verbatim** out of `batch_import_screen.dart` (lines 427-489 and 526-637) into this file, keeping them private to this file, and add a public `ImportPreview` wrapper that composes them. Keep `_Banner` (lines 491-524) in `batch_import_screen.dart` — it is screen-specific (permission banner). Full file content:

```dart
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';

/// Shared preview of a parsed + classified CSV import: summary chips, a
/// skipped-rows error list, and one tile per classified row. Used by both the
/// batch import screen and the inline receiving CSV dialog.
class ImportPreview extends StatelessWidget {
  const ImportPreview({
    super.key,
    required this.parseResult,
    required this.classified,
  });

  final ParseResult parseResult;
  final List<ClassifiedRow> classified;

  @override
  Widget build(BuildContext context) {
    final existing = classified.whereType<ExistingMatchRow>().length;
    final mismatch = classified.whereType<CostMismatchRow>().length;
    final newProducts = classified.whereType<NewProductRow>().length;
    final errors = parseResult.errors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryChips(
          existing: existing,
          mismatch: mismatch,
          newProducts: newProducts,
          errors: errors.length,
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ErrorList(errors: errors),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final c in classified) _ClassifiedRowTile(c: c),
      ],
    );
  }
}

// ---- moved verbatim from batch_import_screen.dart ----

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.existing,
    required this.mismatch,
    required this.newProducts,
    required this.errors,
  });

  final int existing;
  final int mismatch;
  final int newProducts;
  final int errors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _Chip(label: 'Match', count: existing, color: AppColors.success),
        _Chip(
          label: 'Cost variation',
          count: mismatch,
          color: AppColors.warningDark,
        ),
        _Chip(label: 'New product', count: newProducts, color: AppColors.info),
        if (errors > 0)
          _Chip(label: 'Errors', count: errors, color: AppColors.error),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(0x22),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.errors});

  final List<ParseError> errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.error),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skipped rows:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$e',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassifiedRowTile extends StatelessWidget {
  const _ClassifiedRowTile({required this.c});

  final ClassifiedRow c;

  ({String label, Color color}) _badge() {
    if (c is ExistingMatchRow) {
      return (label: 'Match', color: AppColors.success);
    }
    if (c is CostMismatchRow) {
      return (label: 'Variation', color: AppColors.warningDark);
    }
    return (label: 'New', color: AppColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final badge = _badge();
    final row = c.row;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${row.sku} • ${row.quantity} ${row.unit} • cost ${row.cost.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: badge.color.withAlpha(0x22),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge.label,
                style: TextStyle(
                  color: badge.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Delete the now-moved classes from batch_import_screen.dart**

In `lib/presentation/mobile/screens/receiving/batch_import_screen.dart`, delete the class declarations `_SummaryChips` (lines 427-458), `_Chip` (460-489), `_ErrorList` (526-562), and `_ClassifiedRowTile` (564-637). **Keep** `_Banner` (491-524) and `_CsvFormatHelp` and `_SupplierFilter`.

- [ ] **Step 3: Use ImportPreview inside `_buildPreview`**

Add the import near the top of `batch_import_screen.dart` (after line 13):

```dart
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/import_preview.dart';
```

In `_buildPreview`, replace the `_SummaryChips(...)` widget and the trailing `if (parseErrors.isNotEmpty) ... _ErrorList ...` block and the `for (final c in classified) _ClassifiedRowTile(c: c)` line (lines 219-239) with a single `ImportPreview`, keeping the permission banner. The children list of the `ListView` (lines 218-240) becomes:

```dart
            children: [
              if (blockedByPermission) ...[
                _Banner(
                  color: AppColors.error,
                  icon: CupertinoIcons.exclamationmark_circle,
                  text:
                      'This file contains $newProducts new product(s). Auto-creating products requires admin permission.',
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              ImportPreview(
                parseResult: _parseResult ??
                    const ParseResult(rows: [], errors: []),
                classified: classified,
              ),
            ],
```

(The local `existing`/`mismatch` counts at lines 202-205 are now only used for nothing else — remove the now-unused `existing` and `mismatch` locals if `flutter analyze` flags them; `newProducts`, `hasNewProducts`, `canAddProduct`, `blockedByPermission` are still used.)

- [ ] **Step 4: Verify analyzer is clean**

Run: `flutter analyze lib/presentation/mobile/screens/receiving/batch_import_screen.dart lib/presentation/mobile/widgets/receiving/import_preview.dart`
Expected: No issues. (Remove any locals/imports it reports as unused.)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/receiving/import_preview.dart \
        lib/presentation/mobile/screens/receiving/batch_import_screen.dart
git commit -m "refactor(receiving): extract shared ImportPreview widget

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Rewrite CsvImportDialog as a thin client

**Files:**
- Modify (rewrite): `lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart`
- Create: `test/presentation/widgets/csv_import_dialog_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/presentation/widgets/csv_import_dialog_test.dart`. This test drives the dialog's parse/classify/preview path directly via a public, file-pick-free entry so it can run headless (the rewrite in Step 2 exposes `parseAndClassifyForTest`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/csv_import_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';

ProductEntity _p(String sku, double cost) => ProductEntity(
      id: 'p-$sku',
      sku: sku,
      name: 'Existing $sku',
      costCode: 'X',
      cost: cost,
      price: cost * 1.5,
      quantity: 0,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('quoted-comma row parses into a single classified row',
      (tester) async {
    final key = GlobalKey<CsvImportDialogState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith(
            (ref) => Stream.value([_p('ABC', 10)]),
          ),
        ],
        child: MaterialApp(
          home: CsvImportDialog(
            key: key,
            onImport: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const csv =
        'sku,name,category,unit,cost,price,quantity,reorder_level\n'
        'ABC,"Widget, Large",Hardware,pcs,10,15,3,0\n';
    await key.currentState!.parseAndClassifyForTest(csv);
    await tester.pumpAndSettle();

    // One classified row (the quoted comma did NOT split the name column).
    expect(find.text('Widget, Large'), findsOneWidget);
    // Existing SKU at matching cost → Match badge.
    expect(find.text('Match'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/widgets/csv_import_dialog_test.dart`
Expected: FAIL — `CsvImportDialogState` / `parseAndClassifyForTest` not defined (dialog not yet rewritten).

- [ ] **Step 3: Rewrite the dialog**

Replace the entire contents of `lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart` with:

```dart
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/import_preview.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Dialog for importing receiving items from a CSV into the current receiving
/// form. Thin client of the shared batch-import pipeline: it parses with
/// [parseBatchImportCsv], classifies against active inventory, previews via
/// [ImportPreview], and on confirm resolves rows with [ReceivingImportResolver]
/// (creating new products inline) before handing items back through [onImport].
class CsvImportDialog extends ConsumerStatefulWidget {
  final void Function(List<ReceivingItemEntity> items) onImport;

  const CsvImportDialog({super.key, required this.onImport});

  @override
  ConsumerState<CsvImportDialog> createState() => CsvImportDialogState();
}

class CsvImportDialogState extends ConsumerState<CsvImportDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  ParseResult? _parseResult;
  List<ClassifiedRow>? _classified;

  Future<void> _selectFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parseResult = null;
      _classified = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final bytes = picked.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not read file contents.';
        });
        return;
      }
      await parseAndClassifyForTest(utf8.decode(bytes));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse CSV: $e';
      });
    }
  }

  /// Parses + classifies [content] against a snapshot of active products and
  /// updates state. Named `…ForTest` because it is the headless seam the widget
  /// test drives, but it is the same code path `_selectFile` uses after reading
  /// bytes.
  @visibleForTesting
  Future<void> parseAndClassifyForTest(String content) async {
    final parsed = parseBatchImportCsv(content);
    final products = await ref.read(productsProvider.future);
    final classified = classifyRows(
      rows: parsed.rows,
      activeProducts: products.where((p) => p.isActive).toList(),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _parseResult = parsed;
      _classified = classified;
    });
  }

  Future<void> _confirm() async {
    final classified = _classified;
    if (classified == null || classified.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        throw Exception('User not signed in.');
      }
      final mapping = await ref.read(costCodeMappingProvider.future);
      final form = ref.read(currentReceivingProvider);
      final resolver = ref.read(receivingImportResolverProvider);
      final resolved = await resolver.resolve(
        actor: user,
        classified: classified,
        costCodeMapping: mapping,
        supplierId: form.supplierId,
        supplierName: form.supplierName,
      );
      if (!mounted) return;
      widget.onImport(resolved.items);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classified = _classified;
    final canImport =
        classified != null && classified.isNotEmpty && !_isLoading;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(CupertinoIcons.cloud_upload),
          SizedBox(width: 12),
          Text('Import from CSV'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Columns (in order): sku, name, category, unit, cost, price, '
                'quantity, reorder_level. Header row required; first column '
                'must be "sku". Use GENERATE in the sku column to auto-create.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _isLoading && _parseResult == null
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: _isLoading ? null : _selectFile,
                        icon: const Icon(CupertinoIcons.folder_open),
                        label: const Text('Select CSV file'),
                      ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              if (_parseResult != null && classified != null) ...[
                const SizedBox(height: AppSpacing.md),
                ImportPreview(
                  parseResult: _parseResult!,
                  classified: classified,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (classified != null && classified.isNotEmpty)
          FilledButton(
            onPressed: canImport ? _confirm : null,
            child: Text('Import ${classified.length} row(s)'),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/presentation/widgets/csv_import_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify the dialog's caller still compiles**

`bulk_receiving_screen.dart`'s `_showCsvImport` passes `onImport: (items) { ... addItem ... }` and is unchanged. Confirm analyzer is clean across the touched UI:

Run: `flutter analyze lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart \
        test/presentation/widgets/csv_import_dialog_test.dart
git commit -m "refactor(receiving): CSV dialog becomes thin client of shared pipeline

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Full-suite verification

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS (no regressions).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: No new issues introduced by this work.

- [ ] **Step 3: Manual smoke (optional, device/emulator)**

Open Bulk Receiving → Import CSV. Select an 8-column CSV containing a quoted-comma name, an existing SKU at matching cost, an existing SKU at a different cost, and a `GENERATE` row. Confirm the preview shows Match / Cost variation / New chips, and that confirming adds items to the current receiving form. Complete the receiving and verify stock + variation behavior matches the batch screen.

---

## Notes for the implementer

- **Eager product creation tradeoff:** In the dialog, `_confirm` creates new products *before* the user completes the in-progress receiving. Abandoning the form afterward leaves orphan zero-stock products. This is intentional for v1 (matches batch behavior); do not attempt to defer creation here.
- **Cost-mismatch handling is unchanged:** the resolver passes the new CSV cost on the item against the existing product id; `completeReceiving` → `_processReceivingItem` spawns the SKU variation. Do not add variation logic to the resolver.
- **Decimal costs vs cost codes:** `CostCodeEntity.encode` truncates decimals — pre-existing behavior, out of scope.
