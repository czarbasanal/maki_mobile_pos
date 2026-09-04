// updatedByName — Record history's "who last touched this" (web-admin
// parity: mirrors Expense.updatedByName). Stamped by UpdateExpenseUseCase
// from the actor, never trusted from a client-supplied value; never written
// at create (toCreateMap has no updatedBy/updatedByName either — both are
// update-only fields).
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  ExpenseEntity entity({String? updatedByName, String? updatedBy}) =>
      ExpenseEntity(
        id: 'e-1',
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'Bern',
        updatedBy: updatedBy,
        updatedByName: updatedByName,
      );

  group('ExpenseEntity.updatedByName', () {
    test('copyWith sets it', () {
      final updated = entity().copyWith(updatedByName: 'Czar');
      expect(updated.updatedByName, 'Czar');
    });

    test('participates in equality', () {
      expect(entity(updatedByName: 'Czar') == entity(updatedByName: 'Bern'),
          isFalse);
    });
  });

  group('ExpenseModel.updatedByName', () {
    test('round-trips through entity and the update map, but never the create map', () {
      final model = ExpenseModel.fromEntity(
        entity(updatedBy: 'u-2', updatedByName: 'Czar'),
      );
      expect(model.toEntity().updatedByName, 'Czar');
      expect(model.toMap()['updatedByName'], 'Czar');
      expect(model.toUpdateMap()['updatedByName'], 'Czar');
      // Never written at create — mirrors updatedBy's own posture (no
      // audit-editor identity exists until the first edit).
      expect(model.toCreateMap().containsKey('updatedByName'), isFalse);
    });

    test('reads from a Firestore map and defaults to null (legacy record, or never edited)', () {
      final withName = ExpenseModel.fromMap(
          {'description': 'd', 'updatedByName': 'Czar'}, 'e-1');
      expect(withName.updatedByName, 'Czar');
      final without = ExpenseModel.fromMap({'description': 'd'}, 'e-1');
      expect(without.updatedByName, isNull);
    });
  });
}
