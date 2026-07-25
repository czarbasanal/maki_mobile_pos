import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('FeeLineEntity', () {
    late FeeLineEntity line;

    setUp(() {
      line = const FeeLineEntity(
        id: 'fee-1',
        name: 'Electric charge',
        amount: 50.0,
      );
    });

    test('holds the constructor values', () {
      expect(line.id, 'fee-1');
      expect(line.name, 'Electric charge');
      expect(line.amount, 50.0);
    });

    test('amount defaults to 0 when omitted', () {
      const noAmount = FeeLineEntity(id: 'fee-2', name: 'Air');
      expect(noAmount.amount, 0);
    });

    test('value equality holds for identical field values', () {
      const same = FeeLineEntity(
        id: 'fee-1',
        name: 'Electric charge',
        amount: 50.0,
      );
      expect(line, same);
      expect(line.hashCode, same.hashCode);
    });

    test('value equality fails when a field differs', () {
      const differentAmount = FeeLineEntity(
        id: 'fee-1',
        name: 'Electric charge',
        amount: 60.0,
      );
      expect(line == differentAmount, isFalse);
    });

    test('copyWith overrides only the supplied fields', () {
      final updated = line.copyWith(name: 'Tire changer', amount: 30.0);
      expect(updated.id, 'fee-1'); // unchanged
      expect(updated.name, 'Tire changer');
      expect(updated.amount, 30.0);
    });

    test('copyWith with no args returns an equal instance', () {
      expect(line.copyWith(), line);
    });

    test('props expose id, name, amount, description', () {
      expect(line.props, ['fee-1', 'Electric charge', 50.0, null]);
    });

    test('description defaults to null when omitted', () {
      expect(line.description, isNull);
    });

    test('holds description when provided', () {
      const withDescription = FeeLineEntity(
        id: 'fee-3',
        name: 'Charge Item',
        amount: 100.0,
        description: 'Battery replacement',
      );
      expect(withDescription.description, 'Battery replacement');
    });

    test('copyWith overrides description', () {
      final updated = line.copyWith(description: 'Custom note');
      expect(updated.description, 'Custom note');
      expect(updated.name, 'Electric charge'); // unchanged
    });

    test('value equality accounts for description', () {
      const withDescription = FeeLineEntity(
        id: 'fee-1',
        name: 'Electric charge',
        amount: 50.0,
        description: 'note',
      );
      expect(line == withDescription, isFalse);
    });

    test('displayLabel returns name when description is null', () {
      expect(line.displayLabel, 'Electric charge');
    });

    test('displayLabel returns name when description is empty/blank', () {
      const blank = FeeLineEntity(
        id: 'fee-4',
        name: 'Charge Item',
        amount: 100.0,
        description: '   ',
      );
      expect(blank.displayLabel, 'Charge Item');
    });

    test('displayLabel returns "name — description" when description is set',
        () {
      const withDescription = FeeLineEntity(
        id: 'fee-3',
        name: 'Charge Item',
        amount: 100.0,
        description: 'Battery replacement',
      );
      expect(withDescription.displayLabel, 'Charge Item — Battery replacement');
    });
  });
}
