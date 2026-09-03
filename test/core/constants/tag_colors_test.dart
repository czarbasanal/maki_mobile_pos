import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/tag_colors.dart';

void main() {
  test('eight canonical tokens, in lockstep with the web list', () {
    expect(TagColors.tokens, [
      'gray', 'red', 'amber', 'green', 'teal', 'blue', 'purple', 'pink',
    ]);
  });

  test('normalize falls back to gray', () {
    expect(TagColors.normalize('green'), 'green');
    expect(TagColors.normalize('neon'), 'gray');
    expect(TagColors.normalize(null), 'gray');
  });

  test('styleFor resolves every token in both brightnesses', () {
    for (final token in TagColors.tokens) {
      expect(TagColors.styleFor(token, false).bg, isNotNull);
      expect(TagColors.styleFor(token, true).fg, isNotNull);
    }
    // Unknown token renders as gray, never throws.
    expect(TagColors.styleFor('neon', false).bg, TagColors.styleFor('gray', false).bg);
  });
}
