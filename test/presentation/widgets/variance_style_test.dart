import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/variance_style.dart';

void main() {
  group('varianceStateOf', () {
    test('classifies by sign with a cent tolerance', () {
      expect(varianceStateOf(0), VarianceState.balanced);
      expect(varianceStateOf(0.004), VarianceState.balanced);
      expect(varianceStateOf(-0.004), VarianceState.balanced);
      expect(varianceStateOf(-20), VarianceState.short);
      expect(varianceStateOf(50), VarianceState.over);
    });
  });

  group('VarianceStyle.of', () {
    test('short = red trending-down, over = amber trending-up, balanced = green check',
        () {
      expect(VarianceStyle.of(-20, dark: false).icon, LucideIcons.trendingDown);
      expect(VarianceStyle.of(-20, dark: false).word, 'Short');
      expect(VarianceStyle.of(50, dark: false).icon, LucideIcons.trendingUp);
      expect(VarianceStyle.of(50, dark: false).word, 'Over');
      expect(VarianceStyle.of(0, dark: false).icon, LucideIcons.check);
      expect(VarianceStyle.of(0, dark: false).word, 'Balanced');
    });

    test('text color flips with theme', () {
      expect(VarianceStyle.of(-20, dark: false).text, const Color(0xFFF44336));
      expect(VarianceStyle.of(-20, dark: true).text, const Color(0xFFFF6B5E));
      expect(VarianceStyle.of(50, dark: false).text, const Color(0xFFF57C00));
      expect(VarianceStyle.of(0, dark: true).text, const Color(0xFF8FE39A));
    });

    test('every state resolves non-null tints in both themes', () {
      for (final v in [-20.0, 0.0, 50.0]) {
        for (final dark in [false, true]) {
          final s = VarianceStyle.of(v, dark: dark);
          expect(s.panelTint, isA<Color>());
          expect(s.pillTint, isA<Color>());
        }
      }
    });
  });
}
