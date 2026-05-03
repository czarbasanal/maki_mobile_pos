import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/string_extensions.dart';

void main() {
  group('firstName', () {
    test('returns the first space-separated token', () {
      expect('Alice Bautista'.firstName, 'Alice');
    });

    test('returns the whole string when there is no whitespace', () {
      expect('Alice'.firstName, 'Alice');
    });

    test('returns empty for empty input', () {
      expect(''.firstName, '');
    });

    test('returns empty for whitespace-only input', () {
      expect('   '.firstName, '');
    });

    test('trims leading whitespace', () {
      expect('  Alice Bautista'.firstName, 'Alice');
    });

    test('handles multiple internal spaces', () {
      expect('Alice   Bautista'.firstName, 'Alice');
    });

    test('handles tabs as separators', () {
      expect('Alice\tBautista'.firstName, 'Alice');
    });

    test('preserves casing', () {
      expect('alice bautista'.firstName, 'alice');
      expect('ALICE BAUTISTA'.firstName, 'ALICE');
    });

    test('handles middle names — only the first token is returned', () {
      expect('Maria Clara De los Santos'.firstName, 'Maria');
    });
  });
}
