import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('LaborLineEntity', () {
    late LaborLineEntity line;

    setUp(() {
      line = const LaborLineEntity(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 450.0,
      );
    });

    test('holds the constructor values', () {
      expect(line.id, 'labor-1');
      expect(line.description, 'Engine tune-up');
      expect(line.fee, 450.0);
    });

    test('fee defaults to 0 when omitted', () {
      const noFee = LaborLineEntity(id: 'labor-2', description: 'Diagnostics');
      expect(noFee.fee, 0);
    });

    test('value equality holds for identical field values', () {
      const same = LaborLineEntity(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 450.0,
      );
      expect(line, same);
      expect(line.hashCode, same.hashCode);
    });

    test('value equality fails when a field differs', () {
      const differentFee = LaborLineEntity(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 500.0,
      );
      expect(line == differentFee, isFalse);
    });

    test('copyWith overrides only the supplied fields', () {
      final updated = line.copyWith(description: 'Brake bleed', fee: 200.0);
      expect(updated.id, 'labor-1'); // unchanged
      expect(updated.description, 'Brake bleed');
      expect(updated.fee, 200.0);
    });

    test('copyWith with no args returns an equal instance', () {
      expect(line.copyWith(), line);
    });

    test('props expose id, description, fee', () {
      expect(line.props, ['labor-1', 'Engine tune-up', 450.0]);
    });
  });
}
