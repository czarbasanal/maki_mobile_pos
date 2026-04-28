import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_profit_report_usecase.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

SalesSummary _summary() => const SalesSummary(
      totalSalesCount: 5,
      voidedSalesCount: 0,
      grossAmount: 1500,
      totalDiscounts: 100,
      netAmount: 1400,
      totalCost: 800,
      totalProfit: 600,
      byPaymentMethod: {},
    );

void main() {
  late _MockSaleRepository repo;
  late GetProfitReportUseCase useCase;

  setUp(() {
    repo = _MockSaleRepository();
    useCase = GetProfitReportUseCase(repository: repo);

    when(() => repo.getSalesSummary(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => _summary());
  });

  group('GetProfitReportUseCase', () {
    test('admin retrieves profit report', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 31),
      );

      expect(result.success, true);
      expect(result.data?.totalProfit, 600);
    });

    test('cashier denied (viewProfitReports is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 1),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.getSalesSummary(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ));
    });

    test('staff denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 1),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('inactive admin denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 1),
      );
      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
