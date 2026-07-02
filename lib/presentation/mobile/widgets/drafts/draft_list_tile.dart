import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:intl/intl.dart';

/// Displays a single draft in the list, on the elevated theme.
///
/// Neutral-by-default: every draft reads with the same muted `clipboard-list`
/// glyph in a neutral tile — no status/category color is invented. Color is
/// reserved for the slate/gold primary (total, qty, Service-job badge, Open)
/// and the red destructive delete. The model chip stays neutral.
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
                  color: AppColors.neutralTileFill(dark),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(LucideIcons.clipboardList, size: 20, color: muted),
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
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: const Text('Open'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    Color? border,
    Color? fill,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          // Flexible: model names are free-form text and must ellipsize
          // instead of overflowing the tile.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          if (draft.laborLines.isNotEmpty ||
              (draft.motorcycleModel?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (draft.laborLines.isNotEmpty)
                    _chip(
                      icon: LucideIcons.wrench,
                      label: 'Service job',
                      color: theme.colorScheme.primary,
                      border: theme.colorScheme.primary,
                    ),
                  if (draft.motorcycleModel?.isNotEmpty ?? false)
                    _chip(
                      icon: LucideIcons.bike,
                      label: draft.motorcycleModel!,
                      color: muted,
                      fill: AppColors.neutralTileFill(isDark),
                    ),
                ],
              ),
            ),
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
                      // Net, so preview lines sum to the tile's total even
                      // when a part carries a per-item discount.
                      item
                          .calculateNetAmount(
                            isPercentage: draft.isPercentageDiscount,
                          )
                          .toCurrency(),
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
