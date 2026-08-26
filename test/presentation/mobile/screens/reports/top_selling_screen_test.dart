import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/top_selling_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/top_products_card.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

/// A [businessDayProvider] override with no timer, so the forced range a
/// daily-only role gets is a known shop wall-clock day.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;
}

Widget _harness({UserEntity? user, DateTime? businessDay}) {
  return ProviderScope(
    overrides: [
      topSellingProductsProvider.overrideWith(
        (ref, params) async => <ProductSalesData>[],
      ),
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      if (businessDay != null)
        businessDayProvider
            .overrideWith(() => _FixedBusinessDayNotifier(businessDay)),
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
    // businessDayProvider now holds a shop wall-clock midnight, so pin it.
    final today = shopWall(2026, 8, 26);
    await tester.pumpWidget(
      _harness(user: _user(UserRole.cashier), businessDay: today),
    );
    await tester.pump();

    expect(find.byType(DateRangePicker), findsNothing);
    expect(find.textContaining("Showing today's"), findsOneWidget);

    final card = tester.widget<TopProductsCard>(find.byType(TopProductsCard));
    expect(card.startDate, today);
    expect(
      card.endDate,
      DateTime(today.year, today.month, today.day, 23, 59, 59),
    );
  });

  testWidgets('admin keeps the date-range picker', (tester) async {
    await tester.pumpWidget(_harness(user: _user(UserRole.admin)));
    await tester.pump();
    expect(find.byType(DateRangePicker), findsOneWidget);
  });
}
