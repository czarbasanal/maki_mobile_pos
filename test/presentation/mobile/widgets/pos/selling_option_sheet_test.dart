import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/selling_option_sheet.dart';

ProductEntity product(List<SellingOptionEntity> options, {String unit = 'pcs'}) => ProductEntity(
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: unit,
      isActive: true,
      createdAt: DateTime(2026, 7, 29),
      sellingOptions: options,
    );

void main() {
  const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  Future<void> open(WidgetTester tester, ProductEntity p,
      {required void Function(SellingOptionEntity?) onResult}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => onResult(await showSellingOptionSheet(context, p)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every option with its label and set price', (tester) async {
    await open(tester, product([by6, by3]), onResult: (_) {});
    expect(find.text('By 6'), findsOneWidget);
    expect(find.text('By 3'), findsOneWidget);
    expect(find.textContaining('600'), findsOneWidget);
    expect(find.textContaining('330'), findsOneWidget);
  });

  testWidgets('shows the per-piece price as a caption', (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    expect(find.textContaining('110'), findsOneWidget);
  });

  testWidgets('shows on-hand pieces in the header', (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('returns the tapped option', (tester) async {
    SellingOptionEntity? result;
    await open(tester, product([by6, by3]), onResult: (r) => result = r);
    await tester.tap(find.text('By 3'));
    await tester.pumpAndSettle();
    expect(result, by3);
  });

  testWidgets('returns null when dismissed', (tester) async {
    SellingOptionEntity? result = by6;
    await open(tester, product([by6]), onResult: (r) => result = r);
    Navigator.of(tester.element(find.text('By 6'))).pop();
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('opens even for a single option so the price is shown', (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    expect(find.text('By 3'), findsOneWidget);
  });

  testWidgets(
      'an option needing more pieces than on hand still warns but stays tappable',
      (tester) async {
    // 20 pieces needed, only 12 on hand — must not block the sale.
    const shortOption =
        SellingOptionEntity(id: 'o3', label: 'By 20', pieces: 20, price: 2000);
    SellingOptionEntity? result;
    await open(tester, product([shortOption]), onResult: (r) => result = r);

    // Warns: some low-stock indicator is shown for the short option.
    expect(find.textContaining('Low stock'), findsOneWidget);

    // Does not block: tapping it still resolves the option.
    await tester.tap(find.text('By 20'));
    await tester.pumpAndSettle();
    expect(result, shortOption);
  });

  testWidgets('does not warn when there is enough stock for the option',
      (tester) async {
    await open(tester, product([by3]), onResult: (_) {});
    expect(find.textContaining('Low stock'), findsNothing);
  });

  testWidgets(
      'uses the product\'s own unit as the per-piece suffix, not a hardcoded "pc"',
      (tester) async {
    await open(tester, product([by3], unit: 'box'), onResult: (_) {});
    expect(find.textContaining('/box'), findsOneWidget);
    expect(find.textContaining('/pc'), findsNothing);
  });
}
