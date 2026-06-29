import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// The one bottom-sheet shell: rounded (top 24) surface flush to the screen
/// edges, a single grab handle, a header (leading glyph + title/subtitle +
/// optional close), a body slot, and an optional pinned footer that respects
/// SafeArea + keyboard insets. Used directly for auto-height sheets and as the
/// chrome for draggable/form sheets. See the modals handoff (Shell 2).
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leadingIcon,
    this.onClose,
    this.footer,
    this.bodyExpands = false,
  });

  final String title;
  final Widget body;
  final String? subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onClose;
  final Widget? footer;

  /// When true the body is wrapped in [Expanded] (for draggable/full-height
  /// sheets); otherwise the sheet hugs its content (action/radio/picker).
  final bool bodyExpands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final hairline = dark ? AppColors.darkHairline : AppColors.lightDivider;
    final muted = theme.colorScheme.onSurfaceVariant;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(leadingIcon, size: 22, color: muted),
            ),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700, fontSize: 18, height: 1.2)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: TextStyle(fontSize: 13, color: muted)),
                ],
              ],
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(LucideIcons.x, size: 20, color: muted),
              ),
            ),
        ],
      ),
    );

    final bodyWrapped = Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: hairline))),
      child: body,
    );

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: dark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x80000000) : const Color(0x29111C1D),
            blurRadius: 34,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: bodyExpands ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          header,
          if (bodyExpands) Expanded(child: bodyWrapped) else bodyWrapped,
          if (footer != null)
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: hairline))),
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(top: false, child: footer!),
            ),
        ],
      ),
    );
  }
}

/// Presents [child] as a modal bottom sheet on the shared scrim.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (_) => child,
  );
}

/// One tappable row in an action / radio sheet.
class AppSheetAction<T> {
  const AppSheetAction({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final T value;
}

/// Action-list (or radio) bottom sheet. Returns the tapped row's value, or
/// null on dismiss. When [selected] is provided each row shows a radio ring.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  required List<AppSheetAction<T>> actions,
  T? selected,
  bool radio = false,
}) {
  return showAppBottomSheet<T>(
    context,
    child: Builder(builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final ink = theme.colorScheme.onSurface;
      final bodyColor = appDialogBodyColor(theme.brightness == Brightness.dark);
      final hairline = theme.brightness == Brightness.dark
          ? AppColors.darkHairline
          : AppColors.lightDivider;
      final unselectedRing = theme.brightness == Brightness.dark
          ? AppColors.darkInputBorder
          : const Color(0xFFD8D8D8);

      return AppBottomSheet(
        leadingIcon: icon,
        title: title,
        onClose: () => Navigator.of(sheetContext).pop(),
        body: Column(
          children: [
            for (var i = 0; i < actions.length; i++)
              InkWell(
                onTap: () => Navigator.of(sheetContext).pop(actions[i].value),
                child: Container(
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border:
                              Border(top: BorderSide(color: hairline))),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      Icon(actions[i].icon, size: 23, color: bodyColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          actions[i].label,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: (radio && actions[i].value == selected)
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: ink,
                          ),
                        ),
                      ),
                      if (radio)
                        _RadioDot(
                          selected: actions[i].value == selected,
                          color: theme.colorScheme.primary,
                          ring: unselectedRing,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
          ],
        ),
      );
    }),
  );
}

class _RadioDot extends StatelessWidget {
  const _RadioDot(
      {required this.selected, required this.color, required this.ring});
  final bool selected;
  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? color : ring, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            )
          : null,
    );
  }
}
