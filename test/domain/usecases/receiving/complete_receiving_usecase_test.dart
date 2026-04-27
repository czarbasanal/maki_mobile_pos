import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/receiving/complete_receiving_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

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

ReceivingEntity _receiving({
  String id = 'rcv-1',
  String referenceNumber = 'RCV-001',
  double totalCost = 1500,
  String? supplierName = 'ACME Foods',
}) =>
    ReceivingEntity(
      id: id,
      referenceNumber: referenceNumber,
      supplierId: 'sup-1',
      supplierName: supplierName,
      items: const [],
      totalCost: totalCost,
      totalQuantity: 24,
      status: ReceivingStatus.completed,
      createdAt: DateTime(2025, 1, 1, 9),
      completedAt: DateTime(2025, 1, 1, 9, 5),
      createdBy: 'u-staff',
      createdByName: 'staff user',
      completedBy: 'u-staff',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockReceivingRepository repo;
  late _MockActivityLogRepository logRepo;
  late CompleteReceivingUseCase useCase;

  setUp(() {
    repo = _MockReceivingRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CompleteReceivingUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CompleteReceivingUseCase', () {
    test('staff completes receiving successfully', () async {
      when(() => repo.completeReceiving(
            receivingId: any(named: 'receivingId'),
            completedBy: any(named: 'completedBy'),
          )).thenAnswer((_) async => _receiving());

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        receivingId: 'rcv-1',
      );

      expect(result.success, true);
      expect(result.data?.status, ReceivingStatus.completed);
      verify(() => repo.completeReceiving(
            receivingId: 'rcv-1',
            completedBy: 'u-staff',
          )).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('admin completes receiving successfully', () async {
      when(() => repo.completeReceiving(
            receivingId: any(named: 'receivingId'),
            completedBy: any(named: 'completedBy'),
          )).thenAnswer((_) async => _receiving());

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        receivingId: 'rcv-1',
      );

      expect(result.success, true);
      verify(() => repo.completeReceiving(
            receivingId: 'rcv-1',
            completedBy: 'u-admin',
          )).called(1);
    });

    test('cashier is denied (no receiveStock permission)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        receivingId: 'rcv-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.completeReceiving(
            receivingId: any(named: 'receivingId'),
            completedBy: any(named: 'completedBy'),
          ));
    });

    test('inactive staff is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff, isActive: false),
        receivingId: 'rcv-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.completeReceiving(
            receivingId: any(named: 'receivingId'),
            completedBy: any(named: 'completedBy'),
          ));
    });

    test('repository failure surfaces as failed UseCaseResult', () async {
      when(() => repo.completeReceiving(
            receivingId: any(named: 'receivingId'),
            completedBy: any(named: 'completedBy'),
          )).thenThrow(Exception('Firestore unavailable'));

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        receivingId: 'rcv-1',
      );

      expect(result.success, false);
      expect(result.errorMessage, contains('Firestore unavailable'));
    });
  });
}
