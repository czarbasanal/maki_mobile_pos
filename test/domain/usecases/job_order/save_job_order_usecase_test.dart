import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/job_order_repository.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/job_order/save_job_order_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockJobOrderRepository extends Mock implements JobOrderRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

class _FakeJobOrder extends Fake implements JobOrderEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

JobOrderEntity _draft({String createdBy = '', String createdByName = ''}) =>
    JobOrderEntity(
      id: '',
      name: 'Lunch order',
      items: const [],
      discountType: DiscountType.amount,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
    registerFallbackValue(_FakeJobOrder());
  });

  late _MockJobOrderRepository repo;
  late SaveJobOrderUseCase useCase;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockJobOrderRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = SaveJobOrderUseCase(
        repository: repo, logger: ActivityLogger(logRepo));
    when(() => repo.createJobOrder(any())).thenAnswer((inv) async =>
        (inv.positionalArguments.first as JobOrderEntity).copyWith(id: 'd-1'));
  });

  group('SaveJobOrderUseCase', () {
    test('cashier saves jobOrder (saveJobOrder is held by all roles)',
        () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        jobOrder: _draft(),
      );

      expect(result.success, true);
      expect(result.data?.id, 'd-1');
    });

    test('staff saves jobOrder', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        jobOrder: _draft(),
      );
      expect(result.success, true);
    });

    test('admin saves jobOrder', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        jobOrder: _draft(),
      );
      expect(result.success, true);
    });

    test('stamps actor as createdBy + createdByName', () async {
      final captured = <JobOrderEntity>[];
      when(() => repo.createJobOrder(any())).thenAnswer((inv) async {
        final d = inv.positionalArguments.first as JobOrderEntity;
        captured.add(d);
        return d.copyWith(id: 'd-1');
      });

      await useCase.execute(
        actor: _user(UserRole.cashier),
        jobOrder: _draft(createdBy: 'WRONG', createdByName: 'WRONG'),
      );

      expect(captured.single.createdBy, 'u-cashier');
      expect(captured.single.createdByName, 'cashier user');
    });

    test('inactive user denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier, isActive: false),
        jobOrder: _draft(),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.createJobOrder(any()));
    });

    test('repository failure surfaces', () async {
      when(() => repo.createJobOrder(any()))
          .thenThrow(Exception('Firestore unavailable'));
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        jobOrder: _draft(),
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('Firestore unavailable'));
    });
  });

  test('saving a job order writes an activity entry, matching web', () async {
    await useCase.execute(actor: _user(UserRole.cashier), jobOrder: _draft());

    final logged = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>()
        .where((e) => e.type == ActivityType.other)
        .toList();
    expect(logged, hasLength(1));
    expect(logged.single.action, contains('Lunch order'));
    expect(logged.single.entityId, 'd-1');
  });
}
