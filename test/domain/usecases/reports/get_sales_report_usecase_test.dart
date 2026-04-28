import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_sales_report_usecase.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

SalesSummary _summary({double net = 1234.56}) => SalesSummary(
      totalSalesCount: 5,
      voidedSalesCount: 0,
      grossAmount: net + 100,
      totalDiscounts: 100,
      netAmount: net,
      totalCost: net * 0.6,
      totalProfit: net * 0.4,
      byPaymentMethod: const {},
    );

void main() {
  late _MockSaleRepository repo;

  setUp(() {
    repo = _MockSaleRepository();
    when(() => repo.getSalesSummary(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => _summary());
  });

  GetSalesReportUseCase makeUseCase({DateTime? now}) => GetSalesReportUseCase(
        repository: repo,
        now: now == null ? null : (() => now),
      );

  group('GetSalesReportUseCase', () {
    test('admin gets full date range', () async {
      final useCase = makeUseCase();
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );

      expect(result.success, true);
      expect(result.data?.netAmount, 1234.56);
      verify(() => repo.getSalesSummary(
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 12, 31),
          )).called(1);
    });

    test('cashier with daily-only is restricted to today', () async {
      final today = DateTime(2025, 6, 15, 12);
      final useCase = makeUseCase(now: today);

      // Asking for today — allowed.
      final ok = await useCase.execute(
        actor: _user(UserRole.cashier),
        startDate: DateTime(2025, 6, 15),
        endDate: DateTime(2025, 6, 15, 23, 59, 59, 999),
      );
      expect(ok.success, true);

      // Asking for yesterday — rejected.
      final yesterday = await useCase.execute(
        actor: _user(UserRole.cashier),
        startDate: DateTime(2025, 6, 14),
        endDate: DateTime(2025, 6, 15, 23, 59, 59, 999),
      );
      expect(yesterday.success, false);
      expect(yesterday.errorCode, 'daily-only');

      // Asking for tomorrow — rejected.
      final tomorrow = await useCase.execute(
        actor: _user(UserRole.cashier),
        startDate: DateTime(2025, 6, 15),
        endDate: DateTime(2025, 6, 16),
      );
      expect(tomorrow.success, false);
      expect(tomorrow.errorCode, 'daily-only');
    });

    test('staff with daily-only is restricted to today', () async {
      final today = DateTime(2025, 6, 15, 12);
      final useCase = makeUseCase(now: today);

      final wide = await useCase.execute(
        actor: _user(UserRole.staff),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );
      expect(wide.success, false);
      expect(wide.errorCode, 'daily-only');
    });

    test('admin (no daily-only) can request full year ranges', () async {
      final today = DateTime(2025, 6, 15);
      final useCase = makeUseCase(now: today);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );
      expect(result.success, true);
    });

    test('inactive user denied', () async {
      final useCase = makeUseCase();
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 1),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('repository failure surfaces as failed UseCaseResult', () async {
      when(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenThrow(Exception('Firestore unavailable'));
      final useCase = makeUseCase();

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 31),
      );
      expect(result.success, false);
      expect(result.errorMessage, contains('Firestore unavailable'));
    });
  });
}
