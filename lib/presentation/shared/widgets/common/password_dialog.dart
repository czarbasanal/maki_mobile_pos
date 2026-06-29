import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_password_dialog.dart';

/// Reusable password verification dialog.
///
/// Thin wrapper over the unified [showAppPasswordDialog] shell — kept for its
/// established `.show(...)` call sites (void sale, cost-code map, cost display).
/// Retains the 3-attempt lockout behavior.
class PasswordDialog {
  const PasswordDialog._();

  /// Shows the password dialog and returns true if verified successfully.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmButtonText = 'Confirm',
    Color? confirmButtonColor,
    required Future<bool> Function(String password) onVerify,
  }) {
    return showAppPasswordDialog(
      context,
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmButtonText,
      confirmColor: confirmButtonColor,
      onVerify: onVerify,
      maxAttempts: 3,
      infoNote: 'This action requires authentication for security.',
    );
  }
}
