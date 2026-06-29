import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// Per-[PaymentMethod] visual language for the Reports surfaces — the Lucide
/// glyph, the list-row pill (foreground + tinted fill), and the Sales-Report
/// breakdown bar fill. Light/dark values come straight from the 06a handoff.
class PaymentMethodStyle {
  const PaymentMethodStyle._();

  static IconData iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return LucideIcons.banknote;
      case PaymentMethod.gcash:
        return LucideIcons.smartphone;
      case PaymentMethod.maya:
        return LucideIcons.wallet;
      case PaymentMethod.mixed:
        return LucideIcons.layers;
      case PaymentMethod.salmon:
        return LucideIcons.fish;
    }
  }

  /// Pill text + icon color.
  static Color pillFg(PaymentMethod m, {required bool dark}) {
    switch (m) {
      case PaymentMethod.cash:
        return dark ? const Color(0xFF8FE39A) : const Color(0xFF2E7D32);
      case PaymentMethod.gcash:
        return dark ? const Color(0xFF7FB6FF) : const Color(0xFF024A99);
      case PaymentMethod.maya:
        return dark ? const Color(0xFFB8C4C4) : const Color(0xFF283E46);
      case PaymentMethod.mixed:
        return dark ? const Color(0xFF9FB0B0) : const Color(0xFF5A6468);
      case PaymentMethod.salmon:
        return dark ? const Color(0xFFB8C4C4) : const Color(0xFF5A6468);
    }
  }

  /// Pill tinted background.
  static Color pillBg(PaymentMethod m, {required bool dark}) {
    switch (m) {
      case PaymentMethod.cash:
        return dark ? const Color(0x294CAF50) : const Color(0xFFE8F5E9);
      case PaymentMethod.gcash:
        return dark ? const Color(0x33007DFE) : const Color(0xFFE3F0FF);
      case PaymentMethod.maya:
        return dark ? const Color(0x12FFFFFF) : const Color(0x12283E46);
      case PaymentMethod.mixed:
        return dark ? const Color(0x0FFFFFFF) : const Color(0x0F283E46);
      case PaymentMethod.salmon:
        return dark ? const Color(0x12FFFFFF) : const Color(0x0F283E46);
    }
  }

  /// Sales-Report payment-breakdown progress-bar fill.
  static Color barFill(PaymentMethod m, {required bool dark}) {
    switch (m) {
      case PaymentMethod.cash:
        return dark ? const Color(0xFF5FC86A) : const Color(0xFF4CAF50);
      case PaymentMethod.gcash:
        return dark ? const Color(0xFF5AA9F0) : const Color(0xFF007DFE);
      case PaymentMethod.maya:
      case PaymentMethod.mixed:
      case PaymentMethod.salmon:
        return dark ? const Color(0xFF9FB0B0) : const Color(0xFF283E46);
    }
  }
}
