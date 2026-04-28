import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';
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

ProductEntity _product({String name = 'Coke'}) => ProductEntity(
      id: '',
      sku: 'SKU-001',
      name: name,
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
    registerFallbackValue(_FakeProduct());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;
  late CreateProductUseCase useCase;

  setUp(() {
    repo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CreateProductUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.createProduct(
          product: any(named: 'product'),
          createdBy: any(named: 'createdBy'),
        )).thenAnswer((inv) async =>
        (inv.namedArguments[#product] as ProductEntity).copyWith(id: 'p-1'));
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CreateProductUseCase', () {
    test('admin creates successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        product: _product(),
      );

      expect(result.success, true);
      expect(result.data?.id, 'p-1');
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('cashier denied (addProduct is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        product: _product(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('staff denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
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
