import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_bottom_sheet.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/summary_row.dart';
import 'package:intl/intl.dart';

/// Bottom sheet showing full draft details, on the elevated theme.
///
/// Mirrors the redesigned Sale Detail (bundle 03): neutral `file-text` header
/// tile, `AppCard` Items / Summary / Information / Notes sections, slate/gold
/// qty pills. Footer = icon-only Delete (error outline) + filled Load into Cart.
class DraftDetailSheet extends StatelessWidget {
  final DraftEntity draft;
  final VoidCallback onLoad;

  /// Null when the current user lacks permission to delete this draft.
  final VoidCallback? onDelete;

  const DraftDetailSheet({
    super.key,
    required this.draft,
    required this.onLoad,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return AppBottomSheet(
          leadingIcon: LucideIcons.fileText,
          title: draft.name,
          subtitle: dateFormat.format(draft.updatedAt ?? draft.createdAt),
          onClose: () => Navigator.pop(context),
          bodyExpands: true,
          body: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg - 4),
            children: [
              if (draft.hasDiscount) _buildDiscountTypeIndicator(theme, dark),
              _SectionHeader('Items (${draft.items.length})'),
              const SizedBox(height: AppSpacing.sm),
              _buildItemsCard(theme),
              const SizedBox(height: 18),
              const _SectionHeader('Summary'),
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryCard(context, dark),
              const SizedBox(height: 18),
              const _SectionHeader('Information'),
              const SizedBox(height: AppSpacing.sm),
              _buildInfoCard(theme),
              if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _SectionHeader('Notes'),
                const SizedBox(height: AppSpacing.sm),
                _buildNotesCard(theme, dark),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
          footer: Row(
            children: [
              if (onDelete != null) ...[
                // Delete: icon-only error-outlined square (52×50).
                SizedBox(
                  width: 52,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.costUp(dark),
                      side: BorderSide(color: AppColors.costUp(dark)),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                    ),
                    child: const Icon(LucideIcons.trash2, size: 20),
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onLoad,
                    icon: const Icon(LucideIcons.shoppingCart, size: 18),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscountTypeIndicator(ThemeData theme, bool dark) {
    final green = AppColors.successText(dark);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.successFill(dark),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.tag, size: 16, color: green),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              draft.discountType == DiscountType.percentage
                  ? 'Percentage Discounts Applied'
                  : 'Amount Discounts Applied',
              style: TextStyle(
                fontSize: 14,
                color: green,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final hairline = dark ? AppColors.darkHairline : const Color(0xFFF0F0F0);
    final rows = <Widget>[];
    for (var i = 0; i < draft.items.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, color: hairline));
      }
      rows.add(_buildItemRow(theme, draft.items[i]));
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(children: rows),
    );
  }

  Widget _buildItemRow(ThemeData theme, SaleItemEntity item) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    final green = AppColors.successText(dark);

    final hasDiscount = item.hasDiscount;
    final netAmount = item.calculateNetAmount(
      isPercentage: draft.isPercentageDiscount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity pill — slate/gold filled, radius 7.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '×${item.quantity}',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.sku} • ${item.unitPrice.toCurrency()} / ${item.unit}',
                  style: TextStyle(
                    fontFamily: AppTextStyles.monoFontFamily,
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
                if (hasDiscount)
                  Text(
                    draft.isPercentageDiscount
                        ? '${item.discountValue.toStringAsFixed(0)}% off'
                        : '${item.discountValue.toCurrency()} off',
                    style: TextStyle(
                      fontSize: 12,
                      color: green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDiscount)
                Text(
                  item.grossAmount.toCurrency(),
                  style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                    color: muted,
                  ),
                ),
              Text(
                netAmount.toCurrency(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: hasDiscount ? green : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool dark) {
    final theme = Theme.of(context);
    final green = AppColors.successText(dark);
    final innerDivider = dark ? AppColors.darkHairline : const Color(0xFFF0F0F0);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SummaryRow(label: 'Subtotal', value: draft.subtotal.toCurrency()),
          if (draft.hasDiscount) ...[
            const SizedBox(height: AppSpacing.sm),
            SummaryRow(
              label: 'Discount',
              value: '-${draft.totalDiscount.toCurrency()}',
              valueColor: green,
            ),
          ],
          if (draft.laborLines.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1, color: innerDivider),
            ),
            ...draft.laborLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SummaryRow(
                  label: line.description,
                  value: line.fee.toCurrency(),
                ),
              ),
            ),
            SummaryRow(
              label: 'Labor',
              value: draft.laborSubtotal.toCurrency(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: innerDivider),
          ),
          // Total row: 14/600 label + 16/700 value, both in onSurface (not primary).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                draft.grandTotal.toCurrency(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _buildInfoRow(
            theme,
            LucideIcons.user,
            'Created by',
            draft.createdByName,
          ),
          if (draft.mechanicName != null &&
              draft.mechanicName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            _buildInfoRow(
              theme,
              LucideIcons.wrench,
              'Mechanic',
              draft.mechanicName!,
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 4),
          _buildInfoRow(
            theme,
            LucideIcons.calendar,
            'Created',
            dateFormat.format(draft.createdAt),
          ),
          if (draft.updatedAt != null) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            _buildInfoRow(
              theme,
              LucideIcons.edit,
              'Last updated',
              dateFormat.format(draft.updatedAt!),
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 4),
          _buildInfoRow(
            theme,
            LucideIcons.box,
            'Items',
            '${draft.totalItemCount} (${draft.uniqueProductCount} products)',
          ),
        ],
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
        Icon(icon, size: 19, color: muted),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildNotesCard(ThemeData theme, bool dark) {
    final fill = dark ? const Color(0x1AE8B84C) : const Color(0x1FFFC107);
    final border = dark ? const Color(0x47E8B84C) : const Color(0x57B7831A);
    final glyph = dark ? AppColors.primaryAccent : const Color(0xFF9A6B00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.stickyNote, size: 16, color: glyph),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              draft.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                height: 1.5,
                color: appDialogBodyColor(dark),
              ),
            ),
          ),
        ],
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
      style: TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
