import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/product/deactivate_product_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

ProductEntity _product() => ProductEntity(
      id: 'p-1',
      sku: 'SKU-001',
      name: 'Coke',
      costCode: 'NBF',
      cost: 12,
      price: 25,
      quantity: 100,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;
  late DeactivateProductUseCase useCase;

  setUp(() {
    repo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();
    useCase = DeactivateProductUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.deactivateProduct(
          productId: any(named: 'productId'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((_) async {});
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('DeactivateProductUseCase', () {
    test('admin deactivates successfully', () async {
      when(() => repo.getProductById('p-1'))
          .thenAnswer((_) async => _product());

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        productId: 'p-1',
      );
      expect(result.success, true);
      verify(() => repo.deactivateProduct(
            productId: 'p-1',
            updatedBy: 'u-admin',
          )).called(1);
    });

    test('cashier denied (deleteProduct is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        productId: 'p-1',
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.deactivateProduct(
            productId: any(named: 'productId'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('staff denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        productId: 'p-1',
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('idempotent on missing product', () async {
      when(() => repo.getProductById('gone')).thenAnswer((_) async => null);
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        productId: 'gone',
      );
      expect(result.success, true);
      verifyNever(() => repo.deactivateProduct(
            productId: any(named: 'productId'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('inactive admin denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        productId: 'p-1',
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
