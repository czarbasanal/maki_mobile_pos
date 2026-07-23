import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/top_selling_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/top_products_card.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

Widget _harness({UserEntity? user}) {
  return ProviderScope(
    overrides: [
      topSellingProductsProvider.overrideWith(
        (ref, params) async => <ProductSalesData>[],
      ),
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
    ],
    child: const MaterialApp(home: TopSellingScreen()),
  );
}

void main() {
  testWidgets('defaults to the Today preset with a today date range',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    final picker =
        tester.widget<DateRangePicker>(find.byType(DateRangePicker));
    expect(picker.selectedPreset, DateRangePreset.today);

    final card = tester.widget<TopProductsCard>(find.byType(TopProductsCard));
    final now = DateTime.now();
    expect(card.startDate, DateTime(now.year, now.month, now.day));
    expect(
      card.endDate,
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  });

  testWidgets('daily-only roles get the lock banner instead of the picker',
      (tester) async {
    await tester.pumpWidget(_harness(user: _user(UserRole.cashier)));
    await tester.pump();

    expect(find.byType(DateRangePicker), findsNothing);
    expect(find.textContaining("Showing today's"), findsOneWidget);

    final card = tester.widget<TopProductsCard>(find.byType(TopProductsCard));
    final now = DateTime.now();
    expect(card.startDate, DateTime(now.year, now.month, now.day));
    expect(
      card.endDate,
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  });

  testWidgets('admin keeps the date-range picker', (tester) async {
    await tester.pumpWidget(_harness(user: _user(UserRole.admin)));
    await tester.pump();
    expect(find.byType(DateRangePicker), findsOneWidget);
  });
}
