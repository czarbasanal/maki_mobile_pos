import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

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
                icon: Icon(Icons.close, color: fg, size: 18),
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

  /// Shows a success snackbar — green outline + solid light-green fill.
  void showSuccessSnackBar(String message) {
    showSnackBar(
      message,
      accent: AppColors.success,
      textColor: AppColors.successDark,
      background: AppColors.successLight,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows a warning snackbar — amber outline + solid light-amber fill.
  void showWarningSnackBar(String message) {
    showSnackBar(
      message,
      accent: AppColors.warningDark,
      textColor: AppColors.warningDark,
      background: AppColors.warningLight,
      icon: Icons.warning_amber_rounded,
    );
  }

  /// Shows an error snackbar — red outline + solid light-red fill.
  void showErrorSnackBar(String message) {
    showSnackBar(
      message,
      accent: AppColors.error,
      textColor: AppColors.errorDark,
      background: AppColors.errorLight,
      icon: Icons.error_outline,
    );
  }

  /// Shows a confirmation dialog.
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  confirmColor ?? (isDangerous ? Colors.red : null),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
