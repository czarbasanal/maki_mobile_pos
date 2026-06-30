import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_style.dart';

void main() {
  group('ActivityLogStyle.of', () {
    test('financial actions (sale/void/refund) use the success color', () {
      for (final t in [
        ActivityType.sale,
        ActivityType.voidSale,
        ActivityType.refund
      ]) {
        expect(ActivityLogStyle.of(t, dark: false).iconColor,
            AppColors.successDark,
            reason: '$t should be financial-green in light');
      }
    });

    test('security-related actions use the error color', () {
      for (final t in [
        ActivityType.security,
        ActivityType.authentication,
        ActivityType.userManagement,
        ActivityType.passwordVerified,
        ActivityType.passwordFailed,
      ]) {
        expect(ActivityLogStyle.of(t, dark: false).iconColor,
            const Color(0xFFE5392B),
            reason: '$t should be security-red in light');
      }
    });

    test('non-security/non-financial actions are neutral (slate)', () {
      // login/logout/role-changed are deliberately NEUTRAL — they are not
      // flagged by ActivityType.isSecurityRelated.
      for (final t in [
        ActivityType.login,
        ActivityType.logout,
        ActivityType.roleChanged,
        ActivityType.settings,
        ActivityType.receiving,
      ]) {
        expect(ActivityLogStyle.of(t, dark: false).iconColor,
            AppColors.brandSlate,
            reason: '$t should be neutral in light');
      }
    });

    test('the three category tile fills are distinct', () {
      final financial = ActivityLogStyle.of(ActivityType.sale, dark: false);
      final security = ActivityLogStyle.of(ActivityType.security, dark: false);
      final neutral = ActivityLogStyle.of(ActivityType.settings, dark: false);
      expect(financial.tileFill, isNot(security.tileFill));
      expect(security.tileFill, isNot(neutral.tileFill));
      expect(financial.tileFill, isNot(neutral.tileFill));
    });

    test('dark variant differs from light for each category', () {
      for (final t in [
        ActivityType.sale,
        ActivityType.security,
        ActivityType.settings
      ]) {
        expect(
          ActivityLogStyle.of(t, dark: true).iconColor,
          isNot(ActivityLogStyle.of(t, dark: false).iconColor),
          reason: 'dark icon color should differ from light for $t',
        );
      }
    });

    test('every activity type maps to a distinct-ish semantic icon', () {
      final icons = <ActivityType, IconData>{
        for (final t in ActivityType.values)
          t: ActivityLogStyle.of(t, dark: false).icon,
      };
      // A handful of pinned mappings to lock the semantics.
      expect(icons[ActivityType.login], isNotNull);
      expect(icons[ActivityType.sale], isNot(icons[ActivityType.voidSale]));
      expect(icons[ActivityType.passwordVerified],
          isNot(icons[ActivityType.passwordFailed]));
    });
  });
}
