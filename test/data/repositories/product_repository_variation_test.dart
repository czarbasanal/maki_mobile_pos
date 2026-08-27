import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductRepositoryImpl repo;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = ProductRepositoryImpl(firestore: firestore);
    await firestore.collection('products').doc('base1').set({
      'sku': '00020152',
      'name': 'BELT BANDO SKYDRIVE',
      'category': 'CVT',
      'nameKey': 'bando belt skydrive|cvt',
      'cost': 120.0,
      'price': 250.0,
      'quantity': 5,
      'reorderLevel': 0,
      'unit': 'pcs',
      'isActive': true,
      'costCode': 'NBS',
      'barcodes': <String>[],
      'searchKeywords': <String>[],
      'sellingOptions': <Map<String, dynamic>>[],
    });
  });

  test('getProductByNameKey finds an active product by its key', () async {
    final found = await repo.getProductByNameKey('bando belt skydrive|cvt');
    expect(found?.sku, '00020152');
  });

  test('getProductByNameKey returns null when nothing matches', () async {
    expect(await repo.getProductByNameKey('nothing|here'), isNull);
  });

  test(
      'getProductByNameKey prefers the BASE product over a variation '
      'sharing the same nameKey', () async {
    // A cost variation inherits its base's name/category, so it carries the
    // SAME nameKey. Recreate the base AFTER the variation so it would sort
    // second by insertion order without a baseSku filter, and assert the
    // lookup still returns the base, not the variation.
    await firestore.collection('products').doc('base1').delete();
    await firestore.collection('products').doc('a_variation_first').set({
      'sku': '00020152-1',
      'name': 'BELT BANDO SKYDRIVE',
      'category': 'CVT',
      'nameKey': 'bando belt skydrive|cvt',
      'baseSku': '00020152',
      'variationNumber': 1,
      'cost': 130.0,
      'price': 250.0,
      'quantity': 0,
      'reorderLevel': 0,
      'unit': 'pcs',
      'isActive': true,
      'costCode': 'NBT',
      'barcodes': <String>[],
      'searchKeywords': <String>[],
      'sellingOptions': <Map<String, dynamic>>[],
    });
    await firestore.collection('products').doc('base1').set({
      'sku': '00020152',
      'name': 'BELT BANDO SKYDRIVE',
      'category': 'CVT',
      'nameKey': 'bando belt skydrive|cvt',
      'cost': 120.0,
      'price': 250.0,
      'quantity': 5,
      'reorderLevel': 0,
      'unit': 'pcs',
      'isActive': true,
      'costCode': 'NBS',
      'barcodes': <String>[],
      'searchKeywords': <String>[],
      'sellingOptions': <Map<String, dynamic>>[],
    });

    final found = await repo.getProductByNameKey('bando belt skydrive|cvt');
    expect(found?.sku, '00020152');
  });

  test('createVariation uses the given price when one is passed', () async {
    final base = (await repo.getProductByNameKey('bando belt skydrive|cvt'))!;
    final v = await repo.createVariation(
      originalProduct: base,
      newCost: 130,
      newCostCode: 'NBT',
      newPrice: 300,
      createdBy: 'u1',
    );
    expect(v.price, 300);
    expect(v.cost, 130);
  });

  test('createVariation INHERITS the base price when none is passed', () async {
    // Receiving relies on this — receiving_repository_impl.dart:298 passes no
    // price and must keep the base's SRP.
    final base = (await repo.getProductByNameKey('bando belt skydrive|cvt'))!;
    final v = await repo.createVariation(
      originalProduct: base,
      newCost: 130,
      newCostCode: 'NBT',
      createdBy: 'u1',
    );
    expect(v.price, 250);
  });

  test('a variation starts at zero stock with no barcodes', () async {
    final base = (await repo.getProductByNameKey('bando belt skydrive|cvt'))!;
    final v = await repo.createVariation(
      originalProduct: base, newCost: 130, newCostCode: 'NBT', createdBy: 'u1',
    );
    expect(v.quantity, 0);
    expect(v.barcodes, isEmpty);
  });
}
