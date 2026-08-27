import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/import_preview.dart';

ParsedImportRow _row({String name = 'Widget', String? category = 'Hardware'}) =>
    ParsedImportRow(
      rowNumber: 2,
      sku: 'GENERATE',
      name: name,
      category: category,
      unit: 'pcs',
      cost: 10,
      price: 15,
      quantity: 5,
      reorderLevel: 0,
    );

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: '00020152',
      name: 'Widget',
      category: 'Hardware',
      costCode: 'X',
      cost: 10,
      price: 15,
      quantity: 5,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets(
      'flipping a duplicate-name row to "Create as new" moves it out of the '
      'Duplicate name chip and into New product', (tester) async {
    final duplicateRow = DuplicateNameRow(row: _row(), existing: _product());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ImportPreview(
          parseResult: const ParseResult(rows: [], errors: []),
          classified: [duplicateRow],
          resolutions: const {2: DuplicateNameResolution.newProduct},
        ),
      ),
    ));

    // Resolved to "new" — the summary chip must not show a stale count for
    // the duplicate (the per-row status badge on the tile itself, which
    // still legitimately says "Duplicate name", is untouched), and the New
    // product chip must reflect the resolved row.
    expect(find.text('New product · 1'), findsOneWidget);
    expect(find.textContaining('Duplicate name ·'), findsNothing);
  });
}
