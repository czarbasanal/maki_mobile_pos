import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/void_request_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/sales/void_status_style.dart';

void main() {
  group('VoidStatusStyle', () {
    test('icons: pending clock/clock, approved circle2/check, rejected x', () {
      final pending = VoidStatusStyle.of(VoidRequestStatus.pending, dark: false);
      expect(pending.squareIcon, LucideIcons.clock);
      expect(pending.pillIcon, LucideIcons.clock);

      final approved =
          VoidStatusStyle.of(VoidRequestStatus.approved, dark: false);
      expect(approved.squareIcon, LucideIcons.checkCircle2);
      expect(approved.pillIcon, LucideIcons.check);

      final rejected =
          VoidStatusStyle.of(VoidRequestStatus.rejected, dark: false);
      expect(rejected.squareIcon, LucideIcons.xCircle);
      expect(rejected.pillIcon, LucideIcons.x);
    });

    test('labels are capitalized', () {
      expect(VoidStatusStyle.of(VoidRequestStatus.pending, dark: false).label,
          'Pending');
      expect(VoidStatusStyle.of(VoidRequestStatus.approved, dark: false).label,
          'Approved');
      expect(VoidStatusStyle.of(VoidRequestStatus.rejected, dark: false).label,
          'Rejected');
    });

    test('colors flip with theme; approved dark splits icon vs text', () {
      expect(VoidStatusStyle.of(VoidRequestStatus.pending, dark: false).textColor,
          const Color(0xFFC8881A));
      expect(VoidStatusStyle.of(VoidRequestStatus.pending, dark: true).textColor,
          const Color(0xFFF5B547));

      final approvedDark =
          VoidStatusStyle.of(VoidRequestStatus.approved, dark: true);
      expect(approvedDark.iconColor, const Color(0xFF5FC86A));
      expect(approvedDark.textColor, const Color(0xFF8FE39A));
    });

    test('every status resolves a non-null tint in both themes', () {
      for (final s in VoidRequestStatus.values) {
        for (final dark in [false, true]) {
          expect(VoidStatusStyle.of(s, dark: dark).tint, isA<Color>());
        }
      }
    });
  });
}
