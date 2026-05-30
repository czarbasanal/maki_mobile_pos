import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/csv_import_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';

ProductEntity _p(String sku, double cost) => ProductEntity(
      id: 'p-$sku',
      sku: sku,
      name: 'Existing $sku',
      costCode: 'X',
      cost: cost,
      price: cost * 1.5,
      quantity: 0,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('quoted-comma row parses into a single classified row',
      (tester) async {
    final key = GlobalKey<CsvImportDialogState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith(
            (ref) => Stream.value([_p('ABC', 10)]),
          ),
        ],
        child: MaterialApp(
          home: CsvImportDialog(
            key: key,
            onImport: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const csv =
        'sku,name,category,unit,cost,price,quantity,reorder_level\n'
        'ABC,"Widget, Large",Hardware,pcs,10,15,3,0\n';
    await key.currentState!.parseAndClassifyForTest(csv);
    await tester.pumpAndSettle();

    // One classified row (the quoted comma did NOT split the name column).
    expect(find.text('Widget, Large'), findsOneWidget);
    // Existing SKU at matching cost → Match badge.
    expect(find.text('Match'), findsWidgets);
  });
}
