import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/sale_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

SaleEntity _sale({SaleStatus status = SaleStatus.completed, String? reason}) =>
    SaleEntity(
      id: 's-1',
      saleNumber: 'SALE-0042',
      items: const [
        SaleItemEntity(
          id: 'i-1',
          productId: 'p-1',
          sku: 'SKU-001',
          name: 'Brake Pad',
          unitPrice: 100.0,
          unitCost: 60.0,
          quantity: 1,
        ),
      ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 100.0,
      changeGiven: 0,
      cashierId: 'u-cashier',
      cashierName: 'Cashier',
      createdAt: DateTime(2026, 8, 30),
      status: status,
      voidedAt: status == SaleStatus.voided ? DateTime(2026, 8, 30, 18) : null,
      voidReason: reason,
    );

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@shop.test',
      displayName: 'Czar',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _harness(SaleEntity sale) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        saleByIdProvider(sale.id).overrideWith((ref) async => sale),
      ],
      child: const MaterialApp(home: SaleDetailScreen(saleId: 's-1')),
    );

Future<void> _pump(WidgetTester tester, SaleEntity sale) async {
  await tester.pumpWidget(_harness(sale));
  await tester.pump();
  await tester.pump();
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('a voided sale reads as voided', () {
    testWidgets('strikes the sale number, not only the total', (tester) async {
      await _pump(tester, _sale(status: SaleStatus.voided));

      expect(_styleOf(tester, 'SALE-0042').decoration,
          TextDecoration.lineThrough);
    });

    testWidgets('offers a disabled Voided button, not an empty footer',
        (tester) async {
      // The button used to vanish, which reads the same as "you are not
      // allowed to void this" rather than "this is already voided".
      await _pump(tester, _sale(status: SaleStatus.voided));

      expect(find.text('Void This Sale'), findsNothing);
      final btn = tester.widget<OutlinedButton>(
          find.ancestor(of: find.text('Voided'), matching: find.byType(OutlinedButton)));
      expect(btn.onPressed, isNull);
    });

    testWidgets('a completed sale keeps its number unstruck and its action',
        (tester) async {
      await _pump(tester, _sale());

      expect(_styleOf(tester, 'SALE-0042').decoration, isNot(TextDecoration.lineThrough));
      expect(find.text('Void This Sale'), findsOneWidget);
    });
  });
}
