import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/app_text_styles.dart';

void main() {
  test('mono token is the bundled RobotoMono family', () {
    expect(AppTextStyles.monoFontFamily, 'RobotoMono');
  });

  test('code and costCode styles carry the mono family', () {
    expect(AppTextStyles.code.fontFamily, 'RobotoMono');
    expect(AppTextStyles.costCode.fontFamily, 'RobotoMono');
  });
}
