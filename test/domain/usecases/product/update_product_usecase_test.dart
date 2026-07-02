import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/product/update_product_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

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

ProductEntity _product({
  String name = 'Coke',
  double cost = 12,
  double price = 25,
  String costCode = 'NBF',
  int quantity = 100,
}) =>
    ProductEntity(
      id: 'p-1',
      sku: 'SKU-001',
      name: name,
      costCode: costCode,
      cost: cost,
      price: price,
      quantity: quantity,
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
  late UpdateProductUseCase useCase;

  setUp(() {
    repo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();
    useCase = UpdateProductUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.updateProduct(
          product: any(named: 'product'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((inv) async => inv.namedArguments[#product] as ProductEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('UpdateProductUseCase', () {
    test('admin can update any field including price/cost/costCode', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: original.copyWith(
          name: 'Coke 1L',
          price: 30,
          cost: 14,
          costCode: 'XYZ',
        ),
      );

      expect(result.success, true);
      verify(() => repo.updateProduct(
            product: any(named: 'product'),
            updatedBy: 'u-admin',
            updatedByName: 'admin user',
          )).called(1);
    });

    test('staff can update non-restricted fields', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: original.copyWith(
          name: 'Coke (renamed)',
          quantity: 90,
          reorderLevel: 5,
        ),
      );

      expect(result.success, true);
    });

    test('staff CANNOT change price', () async {
      final original = _product(price: 25);
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: original.copyWith(price: 30),
      );

      expect(result.success, false);
      expect(result.errorCode, 'restricted-fields');
      expect(result.errorMessage, contains('price'));
      verifyNever(() => repo.updateProduct(
            product: any(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    test('staff CANNOT change cost', () async {
      final original = _product(cost: 12);
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: original.copyWith(cost: 14),
      );

      expect(result.success, false);
      expect(result.errorCode, 'restricted-fields');
      expect(result.errorMessage, contains('cost'));
    });

    test('staff CANNOT change costCode', () async {
      final original = _product(costCode: 'NBF');
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: original.copyWith(costCode: 'XYZ'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'restricted-fields');
      expect(result.errorMessage, contains('costCode'));
    });

    test('staff attempting multiple restricted changes gets all in error msg',
        () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: original.copyWith(price: 30, cost: 14, costCode: 'X'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'restricted-fields');
      expect(result.errorMessage, contains('price'));
      expect(result.errorMessage, contains('cost'));
      expect(result.errorMessage, contains('costCode'));
    });

    test('cashier CAN change name (name-only tier)', () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: original.copyWith(name: 'Renamed by cashier'),
      );

      expect(result.success, true);
    });

    // Regression: a sale rung up while the cashier had the edit form open
    // decrements stock, so the form's snapshot no longer matches the live
    // doc. The name/image save must rebase onto the FRESH doc instead of
    // rejecting with restricted-fields (2026-07-02 shop bug: image uploaded
    // to Storage but the product update was refused).
    test(
        'cashier image+name save succeeds when a concurrent sale changed '
        'quantity, and keeps the fresh quantity', () async {
      final formSnapshot = _product(quantity: 17);
      final freshDoc = _product(quantity: 16); // sale happened mid-edit
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => freshDoc);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: formSnapshot.copyWith(
          name: 'Renamed by cashier',
          imageUrl: 'https://x/main.jpg',
        ),
      );

      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).captured;
      final saved = captured.single as ProductEntity;
      expect(saved.name, 'Renamed by cashier');
      expect(saved.imageUrl, 'https://x/main.jpg');
      // The stale 17 must never be written back over the live 16.
      expect(saved.quantity, 16);
    });

    test('cashier can clear the product image', () async {
      final original = _product().copyWith(imageUrl: 'https://x/old.jpg');
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: original.copyWith(clearImageUrl: true),
      );

      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).captured;
      expect((captured.single as ProductEntity).imageUrl, isNull);
    });

    test('cashier sku/price edits are ignored, not written (rebase)',
        () async {
      final original = _product();
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => original);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: original.copyWith(sku: 'CASH-NEW', price: 999),
      );

      // Rebase semantics: fields outside the name/image tier are taken from
      // the live doc, so a stray sku/price value is dropped rather than
      // failing the save (the form never offers those fields to a cashier).
      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).captured;
      final saved = captured.single as ProductEntity;
      expect(saved.sku, 'SKU-001');
      expect(saved.price, 25);
    });

    // Regression (2026-07-02): the form writes the quantity it loaded at
    // open. A sale mid-edit decrements stock; saving the form with an
    // untouched quantity field must NOT write the stale count back
    // (silently un-selling the item). quantityEdited=false → keep fresh.
    test(
        'admin save with untouched quantity keeps the fresh count '
        '(concurrent sale not un-sold)', () async {
      final freshDoc = _product(quantity: 16); // sale happened mid-edit
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => freshDoc);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: _product(quantity: 17, name: 'Renamed'), // stale snapshot
        quantityEdited: false,
      );

      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).captured;
      final saved = captured.single as ProductEntity;
      expect(saved.quantity, 16);
      expect(saved.name, 'Renamed');
    });

    test('admin deliberate quantity edit still writes the absolute value',
        () async {
      final freshDoc = _product(quantity: 16);
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => freshDoc);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: _product(quantity: 40), // physical count correction
        quantityEdited: true,
      );

      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).captured;
      expect((captured.single as ProductEntity).quantity, 40);
    });

    test('staff save with untouched quantity keeps the fresh count',
        () async {
      final freshDoc = _product(quantity: 16);
      when(() => repo.getProductById('p-1')).thenAnswer((_) async => freshDoc);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        product: _product(quantity: 17, name: 'Renamed'),
        quantityEdited: false,
      );

      expect(result.success, true);
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          )).captured;
      expect((captured.single as ProductEntity).quantity, 16);
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

    test('returns not-found for missing product', () async {
      when(() => repo.getProductById('missing')).thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: _product().copyWith(id: 'missing'),
      );
      expect(result.success, false);
      expect(result.errorCode, 'not-found');
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
