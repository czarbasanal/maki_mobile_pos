import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/supplier_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/supplier/create_supplier_usecase.dart';
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
      id: '',
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
  late CreateSupplierUseCase useCase;

  setUp(() {
    repo = _MockSupplierRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CreateSupplierUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.createSupplier(
          supplier: any(named: 'supplier'),
          createdBy: any(named: 'createdBy'),
        )).thenAnswer((inv) async =>
        (inv.namedArguments[#supplier] as SupplierEntity).copyWith(id: 'sup-1'));
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CreateSupplierUseCase', () {
    test('admin creates supplier successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        supplier: _supplier(),
      );

      expect(result.success, true);
      expect(result.data?.id, 'sup-1');
      verify(() => repo.createSupplier(
            supplier: any(named: 'supplier'),
            createdBy: 'u-admin',
          )).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('cashier is denied (addSupplier is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        supplier: _supplier(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.createSupplier(
            supplier: any(named: 'supplier'),
            createdBy: any(named: 'createdBy'),
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

    test('repository failure surfaces as failed UseCaseResult', () async {
      when(() => repo.createSupplier(
            supplier: any(named: 'supplier'),
            createdBy: any(named: 'createdBy'),
          )).thenThrow(Exception('Firestore unavailable'));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        supplier: _supplier(),
      );

      expect(result.success, false);
      expect(result.errorMessage, contains('Firestore unavailable'));
    });
  });
}
