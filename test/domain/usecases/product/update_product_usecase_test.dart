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
