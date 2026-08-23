import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/job_order/update_job_order_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockJobOrderRepository extends Mock implements JobOrderRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

class _FakeJobOrder extends Fake implements JobOrderEntity {}

UserEntity _user(UserRole role, {String? id, bool isActive = true}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

JobOrderEntity _draft({
  String id = 'd-1',
  String createdBy = 'u-cashier',
  String name = 'Lunch order',
}) =>
    JobOrderEntity(
      id: id,
      name: name,
      items: const [],
      discountType: DiscountType.amount,
      createdBy: createdBy,
      createdByName: '$createdBy user',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
    registerFallbackValue(_FakeJobOrder());
  });

  late _MockJobOrderRepository repo;
  late UpdateJobOrderUseCase useCase;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockJobOrderRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = UpdateJobOrderUseCase(
        repository: repo, logger: ActivityLogger(logRepo));
    when(() => repo.updateJobOrder(
              jobOrder: any(named: 'jobOrder'),
              updatedBy: any(named: 'updatedBy'),
            ))
        .thenAnswer(
            (inv) async => inv.namedArguments[#jobOrder] as JobOrderEntity);
  });

  group('UpdateJobOrderUseCase', () {
    test('owner can update their own jobOrder', () async {
      final jobOrder = _draft(createdBy: 'u-cashier');
      when(() => repo.getJobOrderById('d-1')).thenAnswer((_) async => jobOrder);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        jobOrder: jobOrder.copyWith(name: 'Renamed'),
      );

      expect(result.success, true);
      expect(result.data?.name, 'Renamed');
    });

    test('admin can update any jobOrder', () async {
      final jobOrder = _draft(createdBy: 'u-cashier');
      when(() => repo.getJobOrderById('d-1')).thenAnswer((_) async => jobOrder);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        jobOrder: jobOrder.copyWith(name: 'Admin renamed'),
      );

      expect(result.success, true);
    });

    // Ticket edits stay creator-or-admin (user decision 2026-07-02). Bill-out
    // conversion by any active user is a rules-level exception that bypasses
    // this use case (ProcessSaleUseCase calls the repository directly).
    test('non-owner cashier cannot update someone elses job order', () async {
      final jobOrder = _draft(createdBy: 'u-other');
      when(() => repo.getJobOrderById('d-1')).thenAnswer((_) async => jobOrder);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier, id: 'u-cashier'),
        jobOrder: jobOrder.copyWith(name: 'Renamed by cashier'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
      verifyNever(() => repo.updateJobOrder(
            jobOrder: any(named: 'jobOrder'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('staff cannot update another user\'s job order', () async {
      final jobOrder = _draft(createdBy: 'u-cashier');
      when(() => repo.getJobOrderById('d-1')).thenAnswer((_) async => jobOrder);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        jobOrder: jobOrder.copyWith(name: 'Renamed'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
    });

    test('rejects updates to a converted (billed-out) ticket', () async {
      final jobOrder = _draft(createdBy: 'u-cashier');
      when(() => repo.getJobOrderById('d-1'))
          .thenAnswer((_) async => jobOrder.copyWith(isConverted: true));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        jobOrder: jobOrder.copyWith(name: 'Stale edit'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'already-converted');
      verifyNever(() => repo.updateJobOrder(
            jobOrder: any(named: 'jobOrder'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('returns not-found for missing jobOrder', () async {
      when(() => repo.getJobOrderById('missing')).thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        jobOrder: _draft(id: 'missing'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'not-found');
    });

    test('inactive user denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier, isActive: false),
        jobOrder: _draft(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
