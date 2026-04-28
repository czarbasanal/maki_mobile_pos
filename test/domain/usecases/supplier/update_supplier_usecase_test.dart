import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/supplier_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/supplier/update_supplier_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockSupplierRepository extends Mock implements SupplierRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeSupplier extends Fake implements SupplierEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

SupplierEntity _supplier({String name = 'ACME Foods'}) => SupplierEntity(
      id: 'sup-1',
      name: name,
      transactionType: TransactionType.cash,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSupplier());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockSupplierRepository repo;
  late _MockActivityLogRepository logRepo;
  late UpdateSupplierUseCase useCase;

  setUp(() {
    repo = _MockSupplierRepository();
    logRepo = _MockActivityLogRepository();
    useCase = UpdateSupplierUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.updateSupplier(
          supplier: any(named: 'supplier'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((inv) async => inv.namedArguments[#supplier] as SupplierEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('UpdateSupplierUseCase', () {
    test('admin updates supplier successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        supplier: _supplier(name: 'ACME Foods Inc.'),
      );

      expect(result.success, true);
      expect(result.data?.name, 'ACME Foods Inc.');
      verify(() => repo.updateSupplier(
            supplier: any(named: 'supplier'),
            updatedBy: 'u-admin',
          )).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('cashier is denied (editSupplier is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        supplier: _supplier(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.updateSupplier(
            supplier: any(named: 'supplier'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('staff is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        supplier: _supplier(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('inactive admin is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        supplier: _supplier(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
