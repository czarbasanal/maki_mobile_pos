import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/users/role_style.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Soft-shadow [AppCard] row for a user in the management list (bundle 12).
///
/// Role-tinted avatar + name/email + role badge + "Since" date, with a blue
/// "You" tag on the current user and a 0.6-opacity / strikethrough / red
/// "Inactive" treatment for deactivated users. Trailing overflow menu
/// (Deactivate / Reactivate) for other users; a chevron for the current user.
class UserListTile extends StatelessWidget {
  final UserEntity user;
  final bool isCurrentUser;
  final VoidCallback onTap;
  final VoidCallback? onToggleActive;
  final VoidCallback? onDelete;

  const UserListTile({
    super.key,
    required this.user,
    required this.isCurrentUser,
    required this.onTap,
    this.onToggleActive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final role = RoleStyle.of(user.role, dark: dark);
    final dateFormat = DateFormat('MMM d, y');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Opacity(
          opacity: user.isActive ? 1.0 : 0.6,
          child: Row(
            children: [
              // Role-tinted avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: role.tileTint,
                ),
                alignment: Alignment.center,
                child: Icon(role.icon, color: role.color, size: 23),
              ),
              const SizedBox(width: 12),

              // Name / email / role + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: user.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 7),
                          _Tag(
                            label: 'You',
                            color: AppColors.infoBadgeText(dark),
                            bg: AppColors.info.withValues(alpha: 0.13),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 12.5, color: muted),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _RoleBadge(role: role),
                        const SizedBox(width: 8),
                        if (!user.isActive)
                          _Tag(
                            label: 'Inactive',
                            color: AppColors.errorText(dark),
                            bg: AppColors.error.withValues(alpha: 0.12),
                          )
                        else
                          Expanded(
                            child: Text(
                              'Since ${dateFormat.format(user.createdAt)}',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Trailing action
              if (onToggleActive != null)
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.moreVertical, color: muted, size: 20),
                  onSelected: (action) {
                    if (action == 'toggle') onToggleActive?.call();
                    if (action == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive
                                ? LucideIcons.userX
                                : LucideIcons.userCheck,
                            size: 18,
                            color: user.isActive
                                ? AppColors.errorText(dark)
                                : AppColors.successText(dark),
                          ),
                          const SizedBox(width: 12),
                          Text(user.isActive ? 'Deactivate' : 'Reactivate'),
                        ],
                      ),
                    ),
                    if (!user.isActive && onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.trash2,
                              size: 18,
                              color: AppColors.errorText(dark),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style:
                                  TextStyle(color: AppColors.errorText(dark)),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else
                Icon(LucideIcons.chevronRight, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Role badge pill — role icon + label on a role-tinted, role-bordered fill.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final RoleStyle role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: role.badgeBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: role.badgeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 12, color: role.badgeTextColor),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: role.badgeTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status tag (You / Inactive) — tinted pill with bold caption text.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}
