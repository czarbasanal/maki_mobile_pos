import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';

void main() {
  test('canonicalModelName trims + collapses whitespace, keeps case', () {
    expect(canonicalModelName('  Nmax   155 '), 'Nmax 155');
    expect(canonicalModelName('Click'), 'Click');
  });

  test('normalizedModelKey lower-cases the canonical form', () {
    expect(normalizedModelKey('  nMaX '), 'nmax');
    expect(normalizedModelKey('Click 125i'), 'click 125i');
    // "  Nmax   155 " and "nmax 155" collapse to the same key.
    expect(normalizedModelKey('  Nmax   155 '), normalizedModelKey('nmax 155'));
  });
}
