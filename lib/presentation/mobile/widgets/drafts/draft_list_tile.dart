import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:intl/intl.dart';

/// Displays a single draft in the list, on the elevated theme.
///
/// Neutral-by-default: every draft reads with the same muted `file-text` glyph
/// in a neutral tile — no status/category color is invented. Color is reserved
/// for the slate/gold primary (total, qty, Service-job badge, Load) and the red
/// destructive delete.
class DraftListTile extends StatelessWidget {
  final DraftEntity draft;
  final VoidCallback onTap;
  final VoidCallback onLoadTap;

  /// Null when the current user lacks permission to delete this draft.
  final VoidCallback? onDeleteTap;

  const DraftListTile({
    super.key,
    required this.draft,
    required this.onTap,
    required this.onLoadTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateFormat = DateFormat('MMM d, h:mm a');
    final updatedAt = draft.updatedAt ?? draft.createdAt;

    return AppCard(
      radius: AppRadius.lg,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Head: neutral doc tile + name/date + total/count
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0x1F93A0A3)
                      : const Color(0x0F283E46),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.shoppingCart, size: 20, color: muted),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(updatedAt),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    draft.grandTotal.toCurrency(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    draft.totalItemCount == 1
                        ? '1 item'
                        : '${draft.totalItemCount} items',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          _buildItemsPreview(context),
          const SizedBox(height: AppSpacing.sm + 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'By ${draft.createdByName}',
                  style: TextStyle(fontSize: 12, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDeleteTap != null) ...[
                IconButton(
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: onDeleteTap,
                  tooltip: 'Delete job order',
                  visualDensity: VisualDensity.compact,
                  color: AppColors.costUp(dark),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              FilledButton.icon(
                onPressed: onLoadTap,
                icon: const Icon(LucideIcons.shoppingCart, size: 18),
                label: const Text('Load'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsPreview(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkInputBorder : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted;

    final previewItems = draft.items.take(3).toList();
    final remainingCount = draft.items.length - previewItems.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: mutedFill,
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.laborLines.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: theme.colorScheme.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.wrench,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Service job',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ...previewItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '×${item.quantity}',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Text(
                      item.grossAmount.toCurrency(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+$remainingCount more item${remainingCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
