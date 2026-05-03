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
  /// Default styling matches the app's airy/minimal language: translucent
  /// fill, solid 1.5pt border in the accent color, and dark accent text.
  /// Pass [accent] / [textColor] / [icon] to vary the semantic intent
  /// (success / warning / error). The convenience wrappers below cover
  /// the common cases; call this directly only for one-off styling.
  void showSnackBar(
    String message, {
    Color accent = AppColors.lightAccent,
    Color? textColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final fg = textColor ?? accent;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          content: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
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
              ],
            ),
          ),
        ),
      );
  }

  /// Shows a success snackbar — green outline + translucent green fill.
  void showSuccessSnackBar(String message) {
    showSnackBar(
      message,
      accent: AppColors.success,
      textColor: AppColors.successDark,
      icon: Icons.check_circle_outline,
    );
  }

  /// Shows a warning snackbar — amber outline + translucent amber fill.
  void showWarningSnackBar(String message) {
    showSnackBar(
      message,
      accent: AppColors.warningDark,
      textColor: AppColors.warningDark,
      icon: Icons.warning_amber_rounded,
    );
  }

  /// Shows an error snackbar — red outline + translucent red fill.
  void showErrorSnackBar(String message) {
    showSnackBar(
      message,
      accent: AppColors.error,
      textColor: AppColors.errorDark,
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
