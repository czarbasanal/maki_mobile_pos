import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_style.dart';

/// One row in the audit feed: a semantic glyph tile + action/time, optional
/// details, and an actor line (user icon + name + outlined role badge).
/// Read-only; rendered inside a per-day [AppCard] by the screen.
class ActivityLogRow extends StatelessWidget {
  const ActivityLogRow({super.key, required this.log, required this.dark});

  final ActivityLogEntity log;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = ActivityLogStyle.of(log.type, dark: dark);
    final timeStr = DateFormat('h:mm a').format(log.createdAt);
    final hasDetails = log.details != null && log.details!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading glyph tile — filled category tint + semantic Lucide icon.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: style.tileFill,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(style.icon, size: 19, color: style.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        log.action,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        timeStr,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 12, color: muted),
                      ),
                    ),
                  ],
                ),
                if (hasDetails) ...[
                  const SizedBox(height: 3),
                  Text(
                    log.details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.45,
                      color: muted,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(LucideIcons.user, size: 13, color: muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        log.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 12, color: muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: log.userRole, dark: dark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined role pill — admin reads a touch stronger than other roles.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.dark});
  final String role;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase() == 'admin';
    final Color text;
    final Color border;
    if (dark) {
      text = isAdmin ? const Color(0xFFB7C2C4) : const Color(0xFF93A0A3);
      border = isAdmin ? const Color(0xFF33464A) : const Color(0xFF2C3C3E);
    } else {
      text = isAdmin ? const Color(0xFF5A6468) : const Color(0xFF8A9296);
      border = isAdmin ? const Color(0xFFD7DBD9) : const Color(0xFFE4E4E2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: text,
        ),
      ),
    );
  }
}
