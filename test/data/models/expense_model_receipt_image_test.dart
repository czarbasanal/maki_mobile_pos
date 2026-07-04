import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  ExpenseEntity entity({String? receiptImageUrl}) => ExpenseEntity(
        id: 'e-1',
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'Czar',
        receiptImageUrl: receiptImageUrl,
      );

  group('ExpenseEntity.receiptImageUrl', () {
    test('copyWith sets and clears the url', () {
      final withUrl = entity().copyWith(receiptImageUrl: 'https://x/r.jpg');
      expect(withUrl.receiptImageUrl, 'https://x/r.jpg');
      expect(
          withUrl.copyWith(clearReceiptImageUrl: true).receiptImageUrl, isNull);
      // copyWith without the arg preserves the existing value
      expect(
          withUrl.copyWith(description: 'x').receiptImageUrl, 'https://x/r.jpg');
    });

    test('participates in equality', () {
      expect(entity(receiptImageUrl: 'a') == entity(receiptImageUrl: 'b'),
          isFalse);
    });
  });

  group('ExpenseModel.receiptImageUrl', () {
    test('round-trips through entity and maps', () {
      final model =
          ExpenseModel.fromEntity(entity(receiptImageUrl: 'https://x/r.jpg'));
      expect(model.toEntity().receiptImageUrl, 'https://x/r.jpg');
      expect(model.toMap()['receiptImageUrl'], 'https://x/r.jpg');
      expect(model.toCreateMap()['receiptImageUrl'], 'https://x/r.jpg');
      expect(model.toUpdateMap()['receiptImageUrl'], 'https://x/r.jpg');
    });

    test('reads from a Firestore map and defaults to null', () {
      final withUrl = ExpenseModel.fromMap(
          {'description': 'd', 'receiptImageUrl': 'https://x/r.jpg'}, 'e-1');
      expect(withUrl.receiptImageUrl, 'https://x/r.jpg');
      final without = ExpenseModel.fromMap({'description': 'd'}, 'e-1');
      expect(without.receiptImageUrl, isNull);
    });
  });
}
