import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/batch_import_receiving_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

class _MockCreateProductUseCase extends Mock implements CreateProductUseCase {}

class _MockCompleteReceivingUseCase extends Mock
    implements CompleteReceivingUseCase {}

class _FakeProductEntity extends Fake implements ProductEntity {}

class _FakeReceivingEntity extends Fake implements ReceivingEntity {}

class _FakeUserEntity extends Fake implements UserEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

ProductEntity _existing({
  String sku = 'ABC',
  double cost = 10,
}) =>
    ProductEntity(
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

ReceivingEntity _completed() => ReceivingEntity(
      id: 'rcv-1',
      referenceNumber: 'RCV-001',
      items: const [],
      totalCost: 0,
      totalQuantity: 0,
      status: ReceivingStatus.completed,
      createdAt: DateTime(2026, 1, 1),
      completedAt: DateTime(2026, 1, 1, 1),
      createdBy: 'u-admin',
      createdByName: 'admin user',
      completedBy: 'u-admin',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeReceivingEntity());
    registerFallbackValue(_FakeUserEntity());
  });

  late _MockReceivingRepository receivingRepo;
  late _MockCreateProductUseCase createProduct;
  late _MockCompleteReceivingUseCase completeReceiving;
  late BatchImportReceivingUseCase useCase;
  late CostCodeEntity mapping;

  setUp(() {
    receivingRepo = _MockReceivingRepository();
    createProduct = _MockCreateProductUseCase();
    completeReceiving = _MockCompleteReceivingUseCase();
    mapping = CostCodeEntity.defaultMapping();
    useCase = BatchImportReceivingUseCase(
      receivingRepository: receivingRepo,
      createProductUseCase: createProduct,
      completeReceivingUseCase: completeReceiving,
    );

    when(() => receivingRepo.generateReferenceNumber())
        .thenAnswer((_) async => 'RCV-001');
    when(() => receivingRepo.createReceiving(any()))
        .thenAnswer((inv) async {
      final r = inv.positionalArguments.first as ReceivingEntity;
      return r.copyWith(id: 'rcv-1');
    });
    when(() => completeReceiving.execute(
          actor: any(named: 'actor'),
          receivingId: any(named: 'receivingId'),
        )).thenAnswer((_) async => UseCaseResult.successData(_completed()));
  });

  group('BatchImportReceivingUseCase', () {
    test('empty classified yields failure', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        classified: const [],
        costCodeMapping: mapping,
      );
      expect(result.success, isFalse);
      verifyNever(() => receivingRepo.createReceiving(any()));
    });

    test('cashier (no bulkReceive) is denied', () async {
      final classified = classifyRows(
        rows: [_row()],
        activeProducts: [_existing()],
      );
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        classified: classified,
        costCodeMapping: mapping,
      );
      expect(result.success, isFalse);
      verifyNever(() => receivingRepo.createReceiving(any()));
    });

    test('staff with new-product row is denied (lacks addProduct)', () async {
      final classified = classifyRows(
        rows: [_row(sku: 'NEW-1')],
        activeProducts: const [],
      );
      // Sanity: classifier did produce a NewProductRow.
      expect(classified.first, isA<NewProductRow>());

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        classified: classified,
        costCodeMapping: mapping,
      );
      expect(result.success, isFalse);
      verifyNever(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          ));
      verifyNever(() => receivingRepo.createReceiving(any()));
    });

    test('staff with all-existing rows succeeds — no createProduct calls',
        () async {
      final classified = classifyRows(
        rows: [_row(sku: 'ABC', cost: 10)],
        activeProducts: [_existing(sku: 'ABC', cost: 10)],
      );

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        classified: classified,
        costCodeMapping: mapping,
      );
      expect(result.success, isTrue);
      verifyNever(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          ));
      verify(() => receivingRepo.createReceiving(any())).called(1);
      verify(() => completeReceiving.execute(
            actor: any(named: 'actor'),
            receivingId: 'rcv-1',
          )).called(1);
    });

    test('admin with new-product row creates the product first', () async {
      // Stub createProduct to return the candidate echoed back with an id.
      when(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          )).thenAnswer((inv) async {
        final candidate =
            inv.namedArguments[const Symbol('product')] as ProductEntity;
        return UseCaseResult.successData(candidate.copyWith(id: 'p-NEW'));
      });

      final classified = classifyRows(
        rows: [_row(sku: 'NEW-1', cost: 12, quantity: 3)],
        activeProducts: const [],
      );

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        classified: classified,
        costCodeMapping: mapping,
      );
      expect(result.success, isTrue);

      final captured = verify(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: captureAny(named: 'product'),
          )).captured;
      expect(captured, hasLength(1));
      final product = captured.single as ProductEntity;
      expect(product.sku, 'NEW-1');
      expect(product.cost, 12);
      // New products start at zero stock; the receiving line adds quantity.
      expect(product.quantity, 0);

      verify(() => receivingRepo.createReceiving(any())).called(1);
    });

    test('GENERATE literal triggers auto-SKU on the created product',
        () async {
      when(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: any(named: 'product'),
          )).thenAnswer((inv) async {
        final candidate =
            inv.namedArguments[const Symbol('product')] as ProductEntity;
        return UseCaseResult.successData(candidate.copyWith(id: 'p-AUTO'));
      });

      final classified = classifyRows(
        rows: [_row(sku: 'GENERATE', name: 'Brand New', cost: 8)],
        activeProducts: const [],
      );

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        classified: classified,
        costCodeMapping: mapping,
      );
      expect(result.success, isTrue);

      final captured = verify(() => createProduct.execute(
            actor: any(named: 'actor'),
            product: captureAny(named: 'product'),
          )).captured;
      final product = captured.single as ProductEntity;
      // Auto-SKU should NOT be the literal — it was generated from the name.
      expect(product.sku, isNot(equals(kSkuGenerateLiteral)));
      expect(product.sku, isNotEmpty);
    });
  });
}
