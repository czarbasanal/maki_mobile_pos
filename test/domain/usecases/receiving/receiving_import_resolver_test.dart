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
