import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/reject_void_request_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role) => UserEntity(
    id: 'u-${role.value}',
    email: '${role.value}@test',
    displayName: '${role.value} user',
    role: role,
    isActive: true,
    createdAt: DateTime(2025, 1, 1));

VoidRequestEntity _req() => VoidRequestEntity(
    id: 'vr-1',
    saleId: 's-1',
    saleNumber: 'SALE-0042',
    saleGrandTotal: 100,
    requestedBy: 'u-cashier',
    requestedByName: 'cashier user',
    requestedByRole: 'cashier',
    reason: 'wrong item',
    createdAt: DateTime(2025, 1, 1));

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  setUpAll(() => registerFallbackValue(VoidRequestStatus.pending));

  late _MockVoidRequestRepository repo;
  late RejectVoidRequestUseCase useCase;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockVoidRequestRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    useCase = RejectVoidRequestUseCase(
        repository: repo, logger: ActivityLogger(logRepo));
    when(() => repo.resolve(
          requestId: any(named: 'requestId'),
          saleId: any(named: 'saleId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        )).thenAnswer((_) async {});
  });

  test('admin rejects with reason', () async {
    final result = await useCase.execute(
        actor: _user(UserRole.admin),
        request: _req(),
        rejectionReason: 'not authorized');
    expect(result.success, isTrue);
    verify(() => repo.resolve(
          requestId: 'vr-1',
          saleId: 's-1',
          status: VoidRequestStatus.rejected,
          resolvedBy: 'u-admin',
          resolvedByName: 'admin user',
          rejectionReason: 'not authorized',
        )).called(1);
  });

  test('cashier denied', () async {
    final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        request: _req(),
        rejectionReason: 'x');
    expect(result.success, isFalse);
    expect(result.errorCode, 'permission-denied');
  });

  test('a rejection writes a void_sale log entry with the rejection reason',
      () async {
    when(() => repo.resolve(
          requestId: any(named: 'requestId'),
          saleId: any(named: 'saleId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        )).thenAnswer((_) async {});

    await useCase.execute(
      actor: _user(UserRole.admin),
      request: _req(),
      rejectionReason: 'sale is legitimate',
    );

    final logged = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>()
        .where((e) => e.type == ActivityType.voidSale)
        .toList();
    expect(logged, hasLength(1));
    expect(logged.single.action.toLowerCase(), contains('reject'));
    expect(logged.single.details, contains('sale is legitimate'));
  });
}
