import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Uniform blocking "waiting" dialog shown while an async mutation runs —
/// a spinner + a verb message ("Saving…", "Deleting…", "Updating…"). Matches
/// the [AppDialog] surface language (radius 24, card fill + dark hairline).
///
/// Don't construct directly — drive it via [WaitingDialog.runWithWaiting].
class AppWaitingDialog extends StatelessWidget {
  const AppWaitingDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: dark
            ? const BorderSide(color: AppColors.darkHairline)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 18),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runs an async [action] behind a blocking [AppWaitingDialog].
extension WaitingDialog on BuildContext {
  /// Shows the waiting dialog with [message], awaits [action], then dismisses
  /// the dialog — returning the action's value (or rethrowing its error, so
  /// callers keep their own try/catch). [action] must NOT navigate; the screen
  /// navigates after this returns.
  Future<T> runWithWaiting<T>(
    Future<T> Function() action, {
    required String message,
  }) async {
    final navigator = Navigator.of(this, rootNavigator: true);
    final dark = Theme.of(this).brightness == Brightness.dark;
    showDialog<void>(
      context: this,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: AppDialog.scrimColor(dark),
      builder: (_) => PopScope(
        canPop: false,
        child: AppWaitingDialog(message: message),
      ),
    );
    try {
      return await action();
    } finally {
      if (navigator.canPop()) navigator.pop();
    }
  }
}
