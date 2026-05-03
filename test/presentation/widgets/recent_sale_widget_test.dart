import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/recent_sale_widget.dart';

SaleEntity _sale({
  String saleNumber = 'S-0001',
  String cashierName = 'Alice Bautista',
  PaymentMethod paymentMethod = PaymentMethod.cash,
}) {
  return SaleEntity(
    id: 'sale-1',
    saleNumber: saleNumber,
    items: [
      SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'SKU-001',
        name: 'Widget',
        quantity: 3,
        unitPrice: 100,
        unitCost: 60,
      ),
    ],
    paymentMethod: paymentMethod,
    amountReceived: 300,
    changeGiven: 0,
    cashierId: 'user-1',
    cashierName: cashierName,
    createdAt: DateTime(2026, 5, 4, 14, 35),
  );
}

Future<void> _pump(WidgetTester tester, List<SaleEntity> sales) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        todaysSalesProvider.overrideWith((ref) => Stream.value(sales)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: RecentSalesWidget(limit: 5),
        ),
      ),
    ),
  );
}

void main() {
  group('RecentSalesWidget — cashier first name on the tile', () {
    testWidgets('multi-word cashier name renders just the first token',
        (tester) async {
      await _pump(tester, [_sale(cashierName: 'Alice Bautista')]);
      await tester.pumpAndSettle();

      // Subtitle reads "Alice • 3 items • 2:35 PM" (substring match
      // keeps the assertion timezone-agnostic for the time portion).
      expect(find.textContaining('Alice • 3 items'), findsOneWidget);
      // The trailing surname must NOT be in the visible subtitle.
      expect(find.textContaining('Bautista'), findsNothing);
    });

    testWidgets('single-word cashier name passes through unchanged',
        (tester) async {
      await _pump(tester, [_sale(cashierName: 'Maria')]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Maria • 3 items'), findsOneWidget);
    });

    testWidgets('blank cashier name omits the cashier prefix entirely',
        (tester) async {
      await _pump(tester, [_sale(cashierName: '')]);
      await tester.pumpAndSettle();

      // No leading "• " since the prefix was skipped.
      expect(find.textContaining(' • 3 items'), findsNothing);
      // Item count + time still render.
      expect(find.textContaining('3 items'), findsOneWidget);
    });

    testWidgets('empty list shows the empty state instead of tiles',
        (tester) async {
      await _pump(tester, const []);
      await tester.pumpAndSettle();

      expect(find.text('No recent transactions'), findsOneWidget);
    });
  });
}
