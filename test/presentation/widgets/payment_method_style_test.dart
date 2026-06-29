import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/payment_method_style.dart';

void main() {
  group('PaymentMethodStyle', () {
    test('maps each method to its Lucide icon', () {
      expect(PaymentMethodStyle.iconFor(PaymentMethod.cash),
          LucideIcons.banknote);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.gcash),
          LucideIcons.smartphone);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.maya),
          LucideIcons.wallet);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.mixed),
          LucideIcons.layers);
      expect(PaymentMethodStyle.iconFor(PaymentMethod.salmon),
          LucideIcons.fish);
    });

    test('pill colors differ by theme', () {
      expect(PaymentMethodStyle.pillFg(PaymentMethod.cash, dark: false),
          const Color(0xFF2E7D32));
      expect(PaymentMethodStyle.pillFg(PaymentMethod.cash, dark: true),
          const Color(0xFF8FE39A));
      expect(PaymentMethodStyle.pillBg(PaymentMethod.gcash, dark: false),
          const Color(0xFFE3F0FF));
    });

    test('every method resolves a non-null bar fill in both themes', () {
      for (final m in PaymentMethod.values) {
        expect(PaymentMethodStyle.barFill(m, dark: false), isA<Color>());
        expect(PaymentMethodStyle.barFill(m, dark: true), isA<Color>());
        expect(PaymentMethodStyle.pillFg(m, dark: false), isA<Color>());
        expect(PaymentMethodStyle.pillBg(m, dark: true), isA<Color>());
      }
    });
  });
}
