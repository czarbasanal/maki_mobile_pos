import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Navigation extension methods for BuildContext.
extension NavigationExtensions on BuildContext {
  /// Navigates back, or to dashboard if can't pop.
  void goBackOrDashboard() {
    if (canPop()) {
      pop();
    } else {
      go(RoutePaths.dashboard);
    }
  }

  /// Navigates back, or to a fallback path if can't pop.
  void goBackOr(String fallbackPath) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackPath);
    }
  }

  /// Shows a snackbar with the given message.
  ///
  /// Default styling matches the app's airy/minimal language: solid lightened
  /// fill, 1.5pt border in the accent color, and dark accent text. Pass
  /// [accent] / [textColor] / [background] / [icon] to vary the semantic
  /// intent (success / warning / error). The convenience wrappers below
  /// cover the common cases; call this directly only for one-off styling.
  void showSnackBar(
    String message, {
    Color accent = AppColors.lightAccent,
    Color? textColor,
    Color? background,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final fg = textColor ?? accent;
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // Solid lightened fill + 1.5pt border applied to the SnackBar
          // itself (rather than nesting a Container inside .content) so
          // Material's surfaceTint doesn't paint over us in M3.
          backgroundColor: background ?? AppColors.lightSurfaceMuted,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: accent, width: 1.5),
          ),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.x, color: fg, size: 18),
                tooltip: 'Dismiss',
                onPressed: messenger.hideCurrentSnackBar,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ],
          ),
        ),
      );
  }

  /// Shows a success snackbar — green outline + lightened fill, dark parity.
  void showSuccessSnackBar(String message) {
    final dark = Theme.of(this).brightness == Brightness.dark;
    showSnackBar(
      message,
      accent: dark ? const Color(0x804CAF50) : AppColors.success,
      textColor: dark ? AppColors.successOnDark : AppColors.successDark,
      background:
          dark ? const Color(0x294CAF50) : AppColors.successLight,
      icon: LucideIcons.checkCircle2,
    );
  }

  /// Shows a warning snackbar — amber outline + lightened fill, dark parity.
  void showWarningSnackBar(String message) {
    final dark = Theme.of(this).brightness == Brightness.dark;
    showSnackBar(
      message,
      accent: dark ? const Color(0x80F5B547) : const Color(0xFFF0A23C),
      textColor: dark ? AppColors.warningOnDark : const Color(0xFFB5701A),
      background:
          dark ? const Color(0x29F5B547) : const Color(0xFFFFF4E0),
      icon: LucideIcons.alertTriangle,
    );
  }

  /// Shows an error snackbar — red outline + lightened fill, dark parity.
  void showErrorSnackBar(String message) {
    final dark = Theme.of(this).brightness == Brightness.dark;
    showSnackBar(
      message,
      accent: dark ? const Color(0x80FF6B5E) : AppColors.error,
      textColor: dark ? AppColors.errorOnDark : AppColors.errorDark,
      background: dark ? const Color(0x29FF6B5E) : const Color(0xFFFDECEA),
      icon: LucideIcons.alertCircle,
    );
  }

  /// Shows a confirmation dialog on the shared [AppDialog] shell.
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
    IconData? icon,
  }) {
    return showAppConfirmDialog(
      this,
      title: title,
      message: message,
      confirmLabel: confirmText,
      cancelLabel: cancelText,
      destructive: isDangerous,
      icon: icon,
    );
  }
}
