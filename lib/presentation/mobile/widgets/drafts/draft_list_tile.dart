import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:intl/intl.dart';

/// Displays a single draft in the list.
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateFormat = DateFormat('MMM d, h:mm a');
    final updatedAt = draft.updatedAt ?? draft.createdAt;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: outlined doc icon + name/date + total
              Row(
                children: [
                  Icon(
                    CupertinoIcons.doc_text,
                    color: muted,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${AppConstants.currencySymbol}${draft.grandTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        draft.totalItemCount == 1
                            ? '1 item'
                            : '${draft.totalItemCount} items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
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
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onDeleteTap != null) ...[
                    IconButton(
                      icon: const Icon(CupertinoIcons.trash),
                      onPressed: onDeleteTap,
                      tooltip: 'Delete draft',
                      visualDensity: VisualDensity.compact,
                      color: muted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  FilledButton.icon(
                    onPressed: onLoadTap,
                    icon: const Icon(CupertinoIcons.cart_badge_plus, size: 18),
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
        ),
      ),
    );
  }

  Widget _buildItemsPreview(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;

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
          ...previewItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTextStyles.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '×${item.quantity}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Text(
                      '${AppConstants.currencySymbol}${item.grossAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
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
                style: theme.textTheme.bodySmall?.copyWith(
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
