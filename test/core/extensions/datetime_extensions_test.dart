import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';

void main() {
  test('toFriendlyDateTime renders "Jul 3, 9:41 AM"', () {
    expect(DateTime(2026, 7, 3, 9, 41).toFriendlyDateTime(), 'Jul 3, 9:41 AM');
    expect(DateTime(2026, 12, 25, 14, 5).toFriendlyDateTime(), 'Dec 25, 2:05 PM');
  });
}
