import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Cash-count variance outcome (counted − expected).
enum VarianceState { balanced, short, over }

/// Classify a variance amount with a one-cent tolerance.
VarianceState varianceStateOf(double variance) {
  if (variance > 0.005) return VarianceState.over;
  if (variance < -0.005) return VarianceState.short;
  return VarianceState.balanced;
}

/// The shared color/icon/word language for cash-count variance — used by the
/// End-of-Day form, the closed view, and every Closing-History row. Balanced =
/// green, short = red, over = amber, with full dark parity (06b handoff).
class VarianceStyle {
  const VarianceStyle({
    required this.state,
    required this.text,
    required this.panelTint,
    required this.pillTint,
    required this.icon,
    required this.word,
  });

  final VarianceState state;
  final Color text;
  final Color panelTint;
  final Color pillTint;
  final IconData icon;
  final String word;

  static VarianceStyle of(double variance, {required bool dark}) {
    switch (varianceStateOf(variance)) {
      case VarianceState.balanced:
        return VarianceStyle(
          state: VarianceState.balanced,
          text: dark ? AppColors.successOnDark : AppColors.success,
          panelTint:
              dark ? const Color(0x294CAF50) : const Color(0x144CAF50),
          pillTint:
              dark ? const Color(0x294CAF50) : AppColors.successLight,
          icon: LucideIcons.check,
          word: 'Balanced',
        );
      case VarianceState.short:
        return VarianceStyle(
          state: VarianceState.short,
          text: dark ? AppColors.errorOnDark : AppColors.error,
          panelTint:
              dark ? const Color(0x1FFF6B5E) : const Color(0x12F44336),
          pillTint:
              dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336),
          icon: LucideIcons.trendingDown,
          word: 'Short',
        );
      case VarianceState.over:
        return VarianceStyle(
          state: VarianceState.over,
          text: dark ? AppColors.warningOnDark : AppColors.warningDark,
          panelTint:
              dark ? const Color(0x1FF5B547) : const Color(0x17F57C00),
          pillTint:
              dark ? const Color(0x24F5B547) : const Color(0x1FF57C00),
          icon: LucideIcons.trendingUp,
          word: 'Over',
        );
    }
  }
}
