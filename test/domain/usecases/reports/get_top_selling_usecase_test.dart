import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/reports/get_top_selling_usecase.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  late _MockSaleRepository repo;

  setUp(() {
    repo = _MockSaleRepository();
    when(() => repo.getTopSellingProducts(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const []);
  });

  GetTopSellingUseCase makeUseCase({DateTime? now}) => GetTopSellingUseCase(
        repository: repo,
        now: now == null ? null : (() => now),
      );

  group('GetTopSellingUseCase', () {
    test('admin gets full year range', () async {
      final useCase = makeUseCase();
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );

      expect(result.success, true);
      verify(() => repo.getTopSellingProducts(
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 12, 31),
            limit: 10,
          )).called(1);
    });

    test('cashier with daily-only restricted to today', () async {
      final today = DateTime(2025, 6, 15, 12);
      final useCase = makeUseCase(now: today);

      final wide = await useCase.execute(
        actor: _user(UserRole.cashier),
        startDate: DateTime(2025, 6, 14),
        endDate: DateTime(2025, 6, 15),
      );
      expect(wide.success, false);
      expect(wide.errorCode, 'daily-only');

      final ok = await useCase.execute(
        actor: _user(UserRole.cashier),
        startDate: DateTime(2025, 6, 15),
        endDate: DateTime(2025, 6, 15, 23, 59, 59, 999),
      );
      expect(ok.success, true);
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
  });
}
