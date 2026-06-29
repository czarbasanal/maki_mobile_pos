import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Status intent for a dialog's leading glyph chip + primary action.
enum AppDialogIntent { neutral, destructive, success, error }

/// The one dialog shell every overlay confirm/input/error/success is built on.
/// Centered card over the scrim, 24px inset, radius 24, soft elevation
/// (light) / hairline (dark). Header (optional leading glyph chip + title +
/// optional close) → content slot → right-aligned action row (Cancel text +
/// filled primary). See the 06b/modals handoff.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.leadingIcon,
    this.intent = AppDialogIntent.neutral,
    this.onClose,
    this.actions = const [],
  });

  final String title;
  final Widget content;
  final IconData? leadingIcon;
  final AppDialogIntent intent;
  final VoidCallback? onClose;
  final List<Widget> actions;

  static Color scrimColor(bool dark) =>
      dark ? const Color(0x99000000) : const Color(0x52111C1D);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.lightCard,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: dark
            ? const BorderSide(color: AppColors.darkHairline)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  _LeadingChip(icon: leadingIcon!, intent: intent),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(LucideIcons.x,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            content,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeadingChip extends StatelessWidget {
  const _LeadingChip({required this.icon, required this.intent});
  final IconData icon;
  final AppDialogIntent intent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    late Color tint;
    late Color color;
    switch (intent) {
      case AppDialogIntent.neutral:
        tint = dark ? const Color(0x29E8B84C) : const Color(0x17283E46);
        color = theme.colorScheme.primary;
        break;
      case AppDialogIntent.destructive:
      case AppDialogIntent.error:
        tint = dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336);
        color = dark ? AppColors.errorOnDark : AppColors.error;
        break;
      case AppDialogIntent.success:
        tint = dark ? const Color(0x294CAF50) : AppColors.successLight;
        color = AppColors.successText(dark);
        break;
    }
    return Container(
      width: 42,
      height: 42,
      decoration:
          BoxDecoration(color: tint, borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// Body copy color for dialog content.
Color appDialogBodyColor(bool dark) =>
    dark ? AppColors.darkTextSecondary : const Color(0xFF5A6468);

/// Cancel (text, left) action.
Widget appDialogCancel(BuildContext context, String label,
    {VoidCallback? onTap}) {
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  return TextButton(
    onPressed: onTap ?? () => Navigator.of(context).pop(false),
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w600, color: muted)),
  );
}

/// Filled primary action (right). Pass [loading] to show a spinner and
/// disable the button (e.g. while a save is in flight).
Widget appDialogPrimary(BuildContext context, String label,
    {required VoidCallback onTap, Color? color, bool loading = false}) {
  final theme = Theme.of(context);
  final bg = color ?? theme.colorScheme.primary;
  final fg = color != null ? Colors.white : theme.colorScheme.onPrimary;
  return FilledButton(
    onPressed: loading ? null : onTap,
    style: FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Text(label),
  );
}

/// Neutral or destructive 2-action confirm. Returns true on primary, false
/// on cancel / barrier dismiss.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData? icon,
  bool destructive = false,
  String? warningText,
}) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AppDialog(
        title: title,
        intent:
            destructive ? AppDialogIntent.destructive : AppDialogIntent.neutral,
        // Leading chip carries the caller's action glyph (e.g. trash-2 for
        // delete); the alert-triangle lives only on the warning line below.
        leadingIcon: icon,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                  fontSize: 14.5, height: 1.55, color: appDialogBodyColor(dark)),
            ),
            if (destructive) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertTriangle,
                      size: 15,
                      color: dark ? AppColors.errorOnDark : AppColors.error),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      warningText ?? 'This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: dark ? AppColors.errorOnDark : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          appDialogCancel(ctx, cancelLabel,
              onTap: () => Navigator.of(ctx).pop(false)),
          appDialogPrimary(ctx, confirmLabel,
              color: destructive ? AppColors.error : theme.colorScheme.primary,
              onTap: () => Navigator.of(ctx).pop(true)),
        ],
      );
    },
  );
  return result ?? false;
}

/// Shared error dialog (single OK). Replaces the old empty error_dialog.dart.
Future<void> showAppErrorDialog(
  BuildContext context, {
  String title = 'Something went wrong',
  required String message,
  String buttonLabel = 'OK',
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<void>(
    context: context,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (ctx) => AppDialog(
      title: title,
      intent: AppDialogIntent.error,
      leadingIcon: LucideIcons.alertCircle,
      content: Text(
        message,
        style: TextStyle(
            fontSize: 14.5, height: 1.55, color: appDialogBodyColor(dark)),
      ),
      actions: [
        appDialogPrimary(ctx, buttonLabel,
            onTap: () => Navigator.of(ctx).pop()),
      ],
    ),
  );
}
