import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// A CRUD row for the admin list editors (categories, mechanics).
///
/// Soft-shadow [AppCard] (radius 14) with an optional leading neutral glyph
/// tile, a title, and trailing edit (`square-pen`) + archive/reactivate icon
/// buttons. Inactive rows render the name struck-through + grey with an
/// "Inactive" subtitle and a green `rotate-ccw` reactivate action in place of
/// archive — deactivate never deletes.
class SettingsCrudRow extends StatelessWidget {
  const SettingsCrudRow({
    super.key,
    required this.name,
    required this.isActive,
    required this.onEdit,
    required this.onToggleActive,
    this.leadingIcon,
  });

  final String name;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  /// When non-null, a neutral glyph tile is shown before the title (mechanics
  /// use `wrench`; category rows have none).
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final tileBg = dark ? const Color(0x1F93A0A3) : const Color(0x0F283E46);
    final inactiveText = dark ? const Color(0xFF6C797C) : const Color(0xFF9AA0A3);
    final reactivate = AppColors.costDown(dark); // green: #2E7D32 / #8FE39A

    return AppCard(
      radius: 14,
      onTap: onEdit,
      padding: EdgeInsets.fromLTRB(leadingIcon != null ? 12 : 16, 8, 8, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 42),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(leadingIcon, size: 18, color: muted),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? theme.colorScheme.onSurface
                          : inactiveText,
                      decoration:
                          isActive ? null : TextDecoration.lineThrough,
                      decorationColor: inactiveText,
                    ),
                  ),
                  if (!isActive) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Inactive',
                      style: TextStyle(fontSize: 12, color: inactiveText),
                    ),
                  ],
                ],
              ),
            ),
            _RowIconButton(
              icon: LucideIcons.squarePen,
              color: muted,
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            _RowIconButton(
              icon: isActive ? LucideIcons.archive : LucideIcons.rotateCcw,
              color: isActive ? muted : reactivate,
              tooltip: isActive ? 'Deactivate' : 'Reactivate',
              onPressed: onToggleActive,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// Slate/gold "Add" FAB used by the list editors (radius 16, `plus` + label).
class SettingsAddFab extends StatelessWidget {
  const SettingsAddFab({super.key, required this.onPressed, this.label = 'Add'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.plus, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
