import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/product_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('ProductModel', () {
    late ProductModel testProduct;

    setUp(() {
      testProduct = ProductModel.create(
        sku: 'TEST-001',
        name: 'Test Product',
        costCode: 'NBF',
        cost: 125,
        price: 200,
        quantity: 50,
        reorderLevel: 10,
        unit: 'pcs',
      );
    });

    test('should create product with correct values', () {
      expect(testProduct.sku, 'TEST-001');
      expect(testProduct.name, 'Test Product');
      expect(testProduct.costCode, 'NBF');
      expect(testProduct.cost, 125);
      expect(testProduct.price, 200);
      expect(testProduct.quantity, 50);
      expect(testProduct.isActive, true);
    });

    test('toEntity should convert to ProductEntity', () {
      final entity = testProduct.toEntity();

      expect(entity, isA<ProductEntity>());
      expect(entity.sku, testProduct.sku);
      expect(entity.name, testProduct.name);
      expect(entity.cost, testProduct.cost);
      expect(entity.price, testProduct.price);
    });

    test('fromEntity should convert from ProductEntity', () {
      final entity = testProduct.toEntity();
      final model = ProductModel.fromEntity(entity);

      expect(model.sku, entity.sku);
      expect(model.name, entity.name);
      expect(model.cost, entity.cost);
      expect(model.price, entity.price);
    });

    test('toMap should serialize correctly', () {
      final map = testProduct.toMap();

      expect(map['sku'], 'TEST-001');
      expect(map['name'], 'Test Product');
      expect(map['costCode'], 'NBF');
      expect(map['cost'], 125);
      expect(map['price'], 200);
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'sku': 'MAP-001',
        'name': 'Map Product',
        'costCode': 'BSC',
        'cost': 200,
        'price': 350,
        'quantity': 25,
        'reorderLevel': 5,
        'unit': 'box',
        'isActive': true,
      };

      final model = ProductModel.fromMap(map, 'doc-id');

      expect(model.id, 'doc-id');
      expect(model.sku, 'MAP-001');
      expect(model.name, 'Map Product');
      expect(model.cost, 200);
      expect(model.price, 350);
    });

    test('createVariation should create product variation', () {
      final variation = testProduct.createVariation(
        newSku: 'TEST-001-1',
        newCostCode: 'NQS',
        newCost: 130,
        variationNum: 1,
      );

      expect(variation.sku, 'TEST-001-1');
      expect(variation.costCode, 'NQS');
      expect(variation.cost, 130);
      expect(variation.baseSku, 'TEST-001');
      expect(variation.variationNumber, 1);
      expect(variation.name, testProduct.name); // Same name
      expect(variation.price, testProduct.price); // Same price
    });

    test('searchKeywords should be generated', () {
      expect(testProduct.searchKeywords, isNotEmpty);
      expect(testProduct.searchKeywords.contains('test'), true);
    });
  });

  group('ProductEntity computed properties', () {
    late ProductEntity product;

    setUp(() {
      product = ProductEntity(
        id: 'test-id',
        sku: 'TEST-001',
        name: 'Test Product',
        costCode: 'NBF',
        cost: 100,
        price: 150,
        quantity: 50,
        reorderLevel: 10,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime.now(),
      );
    });

    test('profit should calculate correctly', () {
      expect(product.profit, 50); // 150 - 100
    });

    test('profitMargin should calculate correctly', () {
      expect(product.profitMargin, closeTo(33.33, 0.01)); // (50/150) * 100
    });

    test('markup should calculate correctly', () {
      expect(product.markup, 50); // (50/100) * 100
    });

    test('inventoryValueAtCost should calculate correctly', () {
      expect(product.inventoryValueAtCost, 5000); // 100 * 50
    });

    test('inventoryValueAtPrice should calculate correctly', () {
      expect(product.inventoryValueAtPrice, 7500); // 150 * 50
    });

    test('potentialProfit should calculate correctly', () {
      expect(product.potentialProfit, 2500); // 50 * 50
    });

    test('stockStatus should return correct status', () {
      expect(product.stockStatus, StockStatus.inStock);

      final lowStock = product.copyWith(quantity: 10);
      expect(lowStock.stockStatus, StockStatus.lowStock);

      final outOfStock = product.copyWith(quantity: 0);
      expect(outOfStock.stockStatus, StockStatus.outOfStock);
    });

    test('getEncodedCost should use cost code mapping', () {
      final costCodeMapping = CostCodeEntity.defaultMapping();

      final productWithoutCode = product.copyWith(costCode: '');
      expect(productWithoutCode.getEncodedCost(costCodeMapping), 'NSC'); // 100
    });
  });
}
