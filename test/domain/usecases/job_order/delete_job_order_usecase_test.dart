import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/job_order/delete_job_order_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockJobOrderRepository extends Mock implements JobOrderRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {String? id, bool isActive = true}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

JobOrderEntity _draft({String createdBy = 'u-cashier'}) => JobOrderEntity(
      id: 'd-1',
      name: 'Lunch order',
      items: const [],
      discountType: DiscountType.amount,
      createdBy: createdBy,
      createdByName: '$createdBy user',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockJobOrderRepository repo;
  late DeleteJobOrderUseCase useCase;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockJobOrderRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = DeleteJobOrderUseCase(
        repository: repo, logger: ActivityLogger(logRepo));
    when(() => repo.deleteJobOrder(any())).thenAnswer((_) async {});
  });

  group('DeleteJobOrderUseCase', () {
    test('owner can delete their own jobOrder', () async {
      when(() => repo.getJobOrderById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        jobOrderId: 'd-1',
      );

      expect(result.success, true);
      verify(() => repo.deleteJobOrder('d-1')).called(1);
    });

    test('admin can delete any jobOrder', () async {
      when(() => repo.getJobOrderById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        jobOrderId: 'd-1',
      );

      expect(result.success, true);
      verify(() => repo.deleteJobOrder('d-1')).called(1);
    });

    test('non-owner cashier cannot delete', () async {
      when(() => repo.getJobOrderById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-other'));

      final result = await useCase.execute(
        actor: _user(UserRole.cashier, id: 'u-cashier'),
        jobOrderId: 'd-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
      verifyNever(() => repo.deleteJobOrder(any()));
    });

    test('staff cannot delete another user\'s jobOrder', () async {
      when(() => repo.getJobOrderById('d-1'))
          .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        jobOrderId: 'd-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'forbidden-not-owner');
    });

    test('idempotent on missing jobOrder (no error, repo not called)',
        () async {
      when(() => repo.getJobOrderById('gone')).thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        jobOrderId: 'gone',
      );

      expect(result.success, true);
      verifyNever(() => repo.deleteJobOrder(any()));
    });

    test('inactive user denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier, isActive: false),
        jobOrderId: 'd-1',
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });

  test('deleting a job order writes an activity entry, matching web', () async {
    when(() => repo.getJobOrderById('d-1'))
        .thenAnswer((_) async => _draft(createdBy: 'u-cashier'));

    await useCase.execute(actor: _user(UserRole.cashier), jobOrderId: 'd-1');

    final logged = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>()
        .where((e) => e.type == ActivityType.other)
        .toList();
    expect(logged, hasLength(1));
    expect(logged.single.action.toLowerCase(), contains('deleted job order'));
  });
}
