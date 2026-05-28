import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/data/models/expense_model.dart';

void main() {
  group('ExpenseModel paidVia', () {
    test('defaults to cash when the field is missing (legacy records)', () {
      final model = ExpenseModel.fromMap({
        'description': 'Legacy expense',
        'amount': 100.0,
        'category': 'Utilities',
      }, 'exp-legacy');

      expect(model.paidVia, PaymentMethod.cash);
      expect(model.toEntity().paidVia, PaymentMethod.cash);
    });

    test('round-trips a non-cash paidVia through map serialization', () {
      final model = ExpenseModel.fromMap({
        'description': 'GCash supplies',
        'amount': 50.0,
        'category': 'Supplies',
        'paidVia': 'gcash',
      }, 'exp-1');

      expect(model.paidVia, PaymentMethod.gcash);
      expect(model.toMap()['paidVia'], 'gcash');
      expect(model.toCreateMap()['paidVia'], 'gcash');
      expect(model.toUpdateMap()['paidVia'], 'gcash');
    });

    test('entity copyWith updates paidVia', () {
      final entity = ExpenseModel.fromMap({
        'description': 'x',
        'amount': 1.0,
        'category': 'c',
      }, 'id').toEntity();

      expect(entity.copyWith(paidVia: PaymentMethod.maya).paidVia,
          PaymentMethod.maya);
    });
  });
}
