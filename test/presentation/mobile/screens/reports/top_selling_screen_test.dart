import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/top_selling_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/top_products_card.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

Widget _harness() {
  return ProviderScope(
    overrides: [
      topSellingProductsProvider.overrideWith(
        (ref, params) async => <ProductSalesData>[],
      ),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
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
}
