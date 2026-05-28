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
