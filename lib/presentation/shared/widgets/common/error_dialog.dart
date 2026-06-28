import 'package:flutter/widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Canonical error dialog (previously an empty file). A single-OK alert on the
/// shared [AppDialog] shell — red `alert-circle` chip + message.
Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Something went wrong',
  required String message,
  String buttonLabel = 'OK',
}) {
  return showAppErrorDialog(
    context,
    title: title,
    message: message,
    buttonLabel: buttonLabel,
  );
}
