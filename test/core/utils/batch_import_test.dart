import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

ProductEntity _product({
  required String sku,
  required double cost,
  String name = 'Test',
}) =>
    ProductEntity(
      id: 'p-$sku',
      sku: sku,
      name: name,
      costCode: 'X',
      cost: cost,
      price: cost * 1.5,
      quantity: 0,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

const _header = 'sku,name,category,unit,cost,price,quantity,reorder_level\n';

void main() {
  group('parseBatchImportCsv', () {
    test('empty content yields empty rows + one error', () {
      final result = parseBatchImportCsv('');
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
    });

    test('header only yields empty rows + no errors', () {
      final result = parseBatchImportCsv(_header);
      expect(result.rows, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('header missing sku column rejects file', () {
      final result = parseBatchImportCsv('foo,bar\nA,B\n');
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, contains('sku'));
    });

    test('valid row parses with all fields', () {
      final result = parseBatchImportCsv(
        '${_header}ABC-1,Widget,Hardware,box,12.50,18.00,5,2\n',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      final row = result.rows.first;
      expect(row.sku, 'ABC-1');
      expect(row.name, 'Widget');
      expect(row.category, 'Hardware');
      expect(row.unit, 'box');
      expect(row.cost, 12.50);
      expect(row.price, 18.00);
      expect(row.quantity, 5);
      expect(row.reorderLevel, 2);
    });

    test('quoted name with embedded comma parses correctly (RFC 4180)', () {
      final result = parseBatchImportCsv(
        '$_header"ABC-2","Coca-Cola, 500ml",Beverages,pcs,15,25,10,5\n',
      );
      expect(result.errors, isEmpty);
      expect(result.rows.first.name, 'Coca-Cola, 500ml');
    });

    test('blank unit defaults to pcs and blank reorder defaults to 0', () {
      final result = parseBatchImportCsv(
        '${_header}ABC-3,Gadget,,,9,15,1,\n',
      );
      expect(result.errors, isEmpty);
      expect(result.rows.first.unit, 'pcs');
      expect(result.rows.first.reorderLevel, 0);
      expect(result.rows.first.category, isNull);
    });

    test('missing sku flags row as error', () {
      final result = parseBatchImportCsv(
        '$_header,Widget,Hardware,pcs,12,18,5,0\n',
      );
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, contains('sku'));
    });

    test('non-positive quantity flags row as error', () {
      final result = parseBatchImportCsv(
        '${_header}ABC-4,Widget,Hardware,pcs,12,18,0,0\n',
      );
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, contains('quantity'));
    });

    test('negative cost flags row as error', () {
      final result = parseBatchImportCsv(
        '${_header}ABC-5,Widget,Hardware,pcs,-1,18,5,0\n',
      );
      expect(result.rows, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.message, contains('cost'));
    });

    test('trailing blank row is skipped silently', () {
      final result = parseBatchImportCsv(
        '${_header}ABC-6,Widget,Hardware,pcs,12,18,5,0\n\n',
      );
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
    });

    test('GENERATE literal sets autoGenerateSku', () {
      final result = parseBatchImportCsv(
        '${_header}GENERATE,New Item,Hardware,pcs,12,18,5,0\n',
      );
      expect(result.rows.first.autoGenerateSku, isTrue);
    });
  });

  group('classifyRows', () {
    test('SKU not found yields NewProductRow', () {
      final rows = [
        ParsedImportRow(
          rowNumber: 2,
          sku: 'NEW-1',
          name: 'New',
          category: null,
          unit: 'pcs',
          cost: 10,
          price: 15,
          quantity: 5,
          reorderLevel: 0,
        ),
      ];
      final result = classifyRows(rows: rows, activeProducts: []);
      expect(result.single, isA<NewProductRow>());
    });

    test('GENERATE literal yields NewProductRow even with matching SKU', () {
      final rows = [
        ParsedImportRow(
          rowNumber: 2,
          sku: 'GENERATE',
          name: 'X',
          category: null,
          unit: 'pcs',
          cost: 10,
          price: 15,
          quantity: 5,
          reorderLevel: 0,
        ),
      ];
      final result = classifyRows(
        rows: rows,
        activeProducts: [_product(sku: 'GENERATE', cost: 10)],
      );
      expect(result.single, isA<NewProductRow>());
    });

    test('matching SKU + matching cost yields ExistingMatchRow', () {
      final rows = [
        ParsedImportRow(
          rowNumber: 2,
          sku: 'ABC',
          name: 'Widget',
          category: null,
          unit: 'pcs',
          cost: 12.50,
          price: 18,
          quantity: 5,
          reorderLevel: 0,
        ),
      ];
      final result = classifyRows(
        rows: rows,
        activeProducts: [_product(sku: 'ABC', cost: 12.50)],
      );
      expect(result.single, isA<ExistingMatchRow>());
    });

    test('cost within tolerance is treated as match', () {
      final rows = [
        ParsedImportRow(
          rowNumber: 2,
          sku: 'ABC',
          name: 'Widget',
          category: null,
          unit: 'pcs',
          cost: 12.504,
          price: 18,
          quantity: 5,
          reorderLevel: 0,
        ),
      ];
      final result = classifyRows(
        rows: rows,
        activeProducts: [_product(sku: 'ABC', cost: 12.50)],
      );
      expect(result.single, isA<ExistingMatchRow>());
    });

    test('cost outside tolerance yields CostMismatchRow', () {
      final rows = [
        ParsedImportRow(
          rowNumber: 2,
          sku: 'ABC',
          name: 'Widget',
          category: null,
          unit: 'pcs',
          cost: 13.00,
          price: 18,
          quantity: 5,
          reorderLevel: 0,
        ),
      ];
      final result = classifyRows(
        rows: rows,
        activeProducts: [_product(sku: 'ABC', cost: 12.50)],
      );
      expect(result.single, isA<CostMismatchRow>());
    });

    test('SKU lookup is case-insensitive', () {
      final rows = [
        ParsedImportRow(
          rowNumber: 2,
          sku: 'abc',
          name: 'Widget',
          category: null,
          unit: 'pcs',
          cost: 12.50,
          price: 18,
          quantity: 5,
          reorderLevel: 0,
        ),
      ];
      final result = classifyRows(
        rows: rows,
        activeProducts: [_product(sku: 'ABC', cost: 12.50)],
      );
      expect(result.single, isA<ExistingMatchRow>());
    });
  });
}
