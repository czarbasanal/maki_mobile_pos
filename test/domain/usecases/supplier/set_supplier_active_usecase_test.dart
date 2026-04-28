import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/supplier/set_supplier_active_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockSupplierRepository extends Mock implements SupplierRepository {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockSupplierRepository repo;
  late _MockActivityLogRepository logRepo;
  late SetSupplierActiveUseCase useCase;

  setUp(() {
    repo = _MockSupplierRepository();
    logRepo = _MockActivityLogRepository();
    useCase = SetSupplierActiveUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.deactivateSupplier(
          supplierId: any(named: 'supplierId'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((_) async {});
    when(() => repo.reactivateSupplier(
          supplierId: any(named: 'supplierId'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((_) async {});
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('SetSupplierActiveUseCase — deactivate', () {
    test('admin deactivates successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        supplierId: 'sup-1',
        active: false,
      );

      expect(result.success, true);
      verify(() => repo.deactivateSupplier(
            supplierId: 'sup-1',
            updatedBy: 'u-admin',
          )).called(1);
      verifyNever(() => repo.reactivateSupplier(
            supplierId: any(named: 'supplierId'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('cashier denied (deleteSupplier is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        supplierId: 'sup-1',
        active: false,
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.deactivateSupplier(
            supplierId: any(named: 'supplierId'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('staff denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        supplierId: 'sup-1',
        active: false,
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });

  group('SetSupplierActiveUseCase — reactivate', () {
    test('admin reactivates successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        supplierId: 'sup-1',
        active: true,
      );

      expect(result.success, true);
      verify(() => repo.reactivateSupplier(
            supplierId: 'sup-1',
            updatedBy: 'u-admin',
          )).called(1);
      verifyNever(() => repo.deactivateSupplier(
            supplierId: any(named: 'supplierId'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('cashier denied (editSupplier is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        supplierId: 'sup-1',
        active: true,
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('inactive admin denied (both branches)', () async {
      final inactive = _user(UserRole.admin, isActive: false);
      expect(
        (await useCase.execute(
                actor: inactive, supplierId: 's', active: false))
            .errorCode,
        'permission-denied',
      );
      expect(
        (await useCase.execute(actor: inactive, supplierId: 's', active: true))
            .errorCode,
        'permission-denied',
      );
    });
  });
}
