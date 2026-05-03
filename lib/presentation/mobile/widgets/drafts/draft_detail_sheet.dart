import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:intl/intl.dart';

/// Bottom sheet showing full draft details.
class DraftDetailSheet extends StatelessWidget {
  final DraftEntity draft;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const DraftDetailSheet({
    super.key,
    required this.draft,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm + 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: hairline,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),

              // Header — outlined doc icon, title, date, close
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg - 4),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.doc_text,
                      color: muted,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat
                                .format(draft.updatedAt ?? draft.createdAt),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg - 4),
                  children: [
                    if (draft.hasDiscount)
                      _buildDiscountTypeIndicator(theme, hairline),
                    _SectionHeader('Items (${draft.items.length})'),
                    const SizedBox(height: AppSpacing.sm),
                    ...draft.items.map((item) => _buildItemRow(theme, item)),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader('Summary'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSummaryCard(theme),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader('Information'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildInfoCard(theme),
                    if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionHeader('Notes'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildNotesCard(theme),
                    ],
                    const SizedBox(height: AppSpacing.xxl + 32),
                  ],
                ),
              ),

              // Action buttons — hairline-bordered bar instead of shadow
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg - 4),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: hairline)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Delete: icon-only outlined button — labelled buttons
                      // collided with the primary action on narrow phones /
                      // large text scale.
                      OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        child: const Icon(CupertinoIcons.trash),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onLoad,
                          icon: const Icon(CupertinoIcons.cart_badge_plus),
                          label: const Text(
                            'Load into Cart',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscountTypeIndicator(ThemeData theme, Color hairline) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.tag,
            size: 16,
            color: AppColors.successDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              draft.discountType == DiscountType.percentage
                  ? 'Percentage Discounts Applied'
                  : 'Amount Discounts Applied',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.successDark,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ThemeData theme, SaleItemEntity item) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;

    final hasDiscount = item.hasDiscount;
    final netAmount = item.calculateNetAmount(
      isPercentage: draft.isPercentageDiscount,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: mutedFill,
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity badge — outlined, no fill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: theme.colorScheme.primary),
            ),
            child: Text(
              '×${item.quantity}',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${item.sku} • ${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (hasDiscount)
                  Text(
                    draft.isPercentageDiscount
                        ? '${item.discountValue.toStringAsFixed(0)}% off'
                        : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(2)} off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.successDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDiscount)
                Text(
                  '${AppConstants.currencySymbol}${item.grossAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: muted,
                  ),
                ),
              Text(
                '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasDiscount ? AppColors.successDark : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildSummaryRow(
              theme,
              'Subtotal',
              '${AppConstants.currencySymbol}${draft.subtotal.toStringAsFixed(2)}',
            ),
            if (draft.hasDiscount) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Discount',
                '-${AppConstants.currencySymbol}${draft.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1),
            ),
            _buildSummaryRow(
              theme,
              'Total',
              '${AppConstants.currencySymbol}${draft.grandTotal.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: valueColor != null ? FontWeight.w600 : null,
                ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildInfoRow(
              theme,
              CupertinoIcons.person,
              'Created by',
              draft.createdByName,
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            _buildInfoRow(
              theme,
              CupertinoIcons.calendar,
              'Created',
              dateFormat.format(draft.createdAt),
            ),
            if (draft.updatedAt != null) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              _buildInfoRow(
                theme,
                CupertinoIcons.arrow_2_circlepath,
                'Last updated',
                dateFormat.format(draft.updatedAt!),
              ),
            ],
            const SizedBox(height: AppSpacing.sm + 4),
            _buildInfoRow(
              theme,
              CupertinoIcons.cube_box,
              'Items',
              '${draft.totalItemCount} (${draft.uniqueProductCount} products)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.square_list,
                  size: 16,
                  color: muted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Notes',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(draft.notes!, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
