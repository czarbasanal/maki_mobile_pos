import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/void_request_entity.dart';

/// Status color/icon language for the Void Requests queue — pending = amber,
/// approved = green, rejected = red, with full dark parity. Drives the leading
/// icon square, the status pill, and the "N pending" count pill (07 handoff).
class VoidStatusStyle {
  const VoidStatusStyle({
    required this.squareIcon,
    required this.pillIcon,
    required this.iconColor,
    required this.textColor,
    required this.tint,
    required this.label,
  });

  /// Glyph for the 40×40 leading square.
  final IconData squareIcon;

  /// Glyph for the status pill (denser than the square glyph).
  final IconData pillIcon;

  /// Leading-square glyph color.
  final Color iconColor;

  /// Pill text + pill glyph color (and count-pill text for pending).
  final Color textColor;

  /// Square / pill tinted background.
  final Color tint;

  final String label;

  static VoidStatusStyle of(VoidRequestStatus status, {required bool dark}) {
    switch (status) {
      case VoidRequestStatus.pending:
        // Deep amber #C8881A in light has no token; gold-on-dark is warningOnDark.
        final c = dark ? AppColors.warningOnDark : const Color(0xFFC8881A);
        return VoidStatusStyle(
          squareIcon: LucideIcons.clock,
          pillIcon: LucideIcons.clock,
          iconColor: c,
          textColor: c,
          tint: dark ? const Color(0x24F5B547) : const Color(0x1FF57C00),
          label: 'Pending',
        );
      case VoidRequestStatus.approved:
        return VoidStatusStyle(
          squareIcon: LucideIcons.checkCircle2,
          pillIcon: LucideIcons.check,
          iconColor: dark ? AppColors.successOnDarkIcon : AppColors.successDark,
          textColor: dark ? AppColors.successOnDark : AppColors.successDark,
          tint: dark ? const Color(0x294CAF50) : AppColors.successLight,
          label: 'Approved',
        );
      case VoidRequestStatus.rejected:
        final c = dark ? AppColors.errorOnDark : AppColors.error;
        return VoidStatusStyle(
          squareIcon: LucideIcons.xCircle,
          pillIcon: LucideIcons.x,
          iconColor: c,
          textColor: c,
          tint: dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336),
          label: 'Rejected',
        );
    }
  }
}
