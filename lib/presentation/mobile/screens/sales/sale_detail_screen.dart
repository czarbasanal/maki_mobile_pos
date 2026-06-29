import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/request_void_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/void_sale_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Screen displaying sale details with void option.
class SaleDetailScreen extends ConsumerWidget {
  final String saleId;

  const SaleDetailScreen({
    super.key,
    required this.saleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleByIdProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        title: const Text('Sale Details'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileText),
            tooltip: 'View Receipt',
            onPressed: () {
              final sale = saleAsync.valueOrNull;
              if (sale != null) {
                _showReceipt(context, sale);
              }
            },
          ),
        ],
      ),
      body: saleAsync.when(
        data: (sale) {
          if (sale == null) {
            return const EmptyStateView(
              icon: LucideIcons.fileText,
              title: 'Sale not found',
            );
          }
          final costMapping = ref.watch(costCodeMappingProvider).valueOrNull ??
              CostCodeEntity.defaultMapping();
          return _buildSaleDetails(context, ref, sale, costMapping);
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(saleByIdProvider(saleId)),
        ),
      ),
    );
  }

  Widget _buildSaleDetails(
    BuildContext context,
    WidgetRef ref,
    SaleEntity sale,
    CostCodeEntity costMapping,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');
    final isVoided = sale.status == SaleStatus.voided;

    final scroll = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner for voided sales
          if (isVoided) _buildVoidedBanner(theme, sale),

          // Sale header
          _buildSaleHeader(theme, sale, dateFormat),

          const SizedBox(height: 24),

          // Items section
          _buildSectionHeader(theme, 'Items'),
          const SizedBox(height: 8),
          _buildItemsList(theme, sale, costMapping),

          const SizedBox(height: 24),

          // Payment section
          _buildSectionHeader(theme, 'Payment'),
          const SizedBox(height: 8),
          _buildPaymentCard(theme, sale),

          const SizedBox(height: 24),

          // Details section
          _buildSectionHeader(theme, 'Details'),
          const SizedBox(height: 8),
          _buildDetailsCard(theme, sale, dateFormat),

          // Void info for voided sales
          if (isVoided) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Void Information'),
            const SizedBox(height: 8),
            _buildVoidInfoCard(theme, sale, dateFormat),
          ],

          // Notes
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Notes'),
            const SizedBox(height: 8),
            _buildNotesCard(theme, sale),
          ],
        ],
      ),
    );

    // Void affordance pinned to the bottom (footer over the scroll). Voided
    // sales — and users without a void permission — get no action bar.
    final footer = isVoided ? null : _buildVoidFooter(context, ref, sale);
    return Column(
      children: [
        Expanded(child: scroll),
        if (footer != null) footer,
      ],
    );
  }

  Widget _buildVoidedBanner(ThemeData theme, SaleEntity sale) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.xCircle, color: AppColors.error, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOIDED',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (sale.voidReason != null)
                  Text(
                    sale.voidReason!,
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleHeader(
    ThemeData theme,
    SaleEntity sale,
    DateFormat dateFormat,
  ) {
    final voided = sale.status == SaleStatus.voided;
    return AppCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            // Sale number
            Text(
              sale.saleNumber,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Date
            Text(
              dateFormat.format(sale.createdAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Grand total
            Text(
              sale.grandTotal.toCurrency(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: voided
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
                decoration: voided ? TextDecoration.lineThrough : null,
              ),
            ),
            // Status badge
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: voided ? AppColors.error : AppColors.success,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                sale.status.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildItemsList(
    ThemeData theme,
    SaleEntity sale,
    CostCodeEntity costMapping,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...sale.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == sale.items.length - 1 &&
                sale.laborLines.isEmpty;
            final netAmount = item.calculateNetAmount(
              isPercentage: sale.isPercentageDiscount,
            );

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.sku} • ${item.unitPrice.toCurrency()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Code: ${costMapping.encode(item.unitCost)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (item.hasDiscount)
                          Text(
                            sale.isPercentageDiscount
                                ? '${item.discountValue.toStringAsFixed(0)}% discount'
                                : '${item.discountValue.toCurrency()} discount',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.successText(isDark),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    netAmount.toCurrency(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
          ...sale.laborLines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final isLast = index == sale.laborLines.length - 1;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      LucideIcons.wrench,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.description,
                          style: AppTextStyles.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Labor',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    line.fee.toCurrency(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(ThemeData theme, SaleEntity sale) {
    final isDark = theme.brightness == Brightness.dark;
    final green = AppColors.successText(isDark);
    final mechanic = sale.mechanicName;
    final laborLabel = (mechanic != null && mechanic.isNotEmpty)
        ? 'Labor · $mechanic'
        : 'Labor';
    final cur = AppConstants.currencySymbol;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SummaryRow(
            label: 'Subtotal',
            value: '$cur${sale.subtotal.toStringAsFixed(2)}',
          ),
          if (sale.hasDiscount) ...[
            const SizedBox(height: AppSpacing.sm),
            SummaryRow(
              label: 'Discount',
              value: '-$cur${sale.totalDiscount.toStringAsFixed(2)}',
              valueColor: green,
            ),
          ],
          if (sale.laborLines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SummaryRow(
              label: laborLabel,
              value: '$cur${sale.laborSubtotal.toStringAsFixed(2)}',
            ),
          ],
          const Divider(height: 24),
          // Single hero: the header total is the glance target, so Total here is
          // a strong recap row (16/700, default ink) — not the 26px hero variant.
          _buildTotalRecap(theme, '$cur${sale.grandTotal.toStringAsFixed(2)}'),
          const Divider(height: 24),
          SummaryRow(
            label: 'Received',
            value: '$cur${sale.amountReceived.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          // Change: a tinted success block when there's change to return; a plain
          // row at zero (no empty green box).
          if (sale.changeGiven > 0)
            _buildChangeBlock(theme, '$cur${sale.changeGiven.toStringAsFixed(2)}')
          else
            SummaryRow(
              label: 'Change',
              value: '$cur${sale.changeGiven.toStringAsFixed(2)}',
              valueColor: green,
            ),
          if (sale.effectiveTenders.length > 1) ...[
            const Divider(height: 24),
            ..._tenderRows(theme, sale),
          ],
        ],
      ),
    );
  }

  /// Payment "Total" recap — strong but not the hero (the header total is).
  Widget _buildTotalRecap(ThemeData theme, String value) {
    final style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text('Total', style: style), Text(value, style: style)],
    );
  }

  /// Change-due as a filled success-tint block (shown only when change > 0).
  Widget _buildChangeBlock(ThemeData theme, String value) {
    final isDark = theme.brightness == Brightness.dark;
    final green = AppColors.successText(isDark);
    return Container(
      key: const Key('sale-change-block'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successFill(isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isDark
            ? Border.all(color: AppColors.success.withValues(alpha: 0.40))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Change',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: green),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: green),
          ),
        ],
      ),
    );
  }

  List<Widget> _tenderRows(ThemeData theme, SaleEntity sale) {
    String label(PaymentMethod m) {
      if (sale.paymentMethod == PaymentMethod.salmon) {
        return m == PaymentMethod.salmon
            ? 'Salmon balance'
            : 'Downpayment (${m.displayName})';
      }
      return m.displayName;
    }

    return sale.effectiveTenders.entries
        .map((e) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: SummaryRow(
                label: label(e.key),
                value:
                    e.value.toCurrency(),
              ),
            ))
        .toList();
  }

  Widget _buildDetailsCard(
    ThemeData theme,
    SaleEntity sale,
    DateFormat dateFormat,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _buildDetailRow(
            theme,
            LucideIcons.user,
            'Cashier',
            sale.cashierName,
          ),
          if (sale.mechanicName != null && sale.mechanicName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              LucideIcons.wrench,
              'Mechanic',
              sale.mechanicName!,
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            theme,
            LucideIcons.creditCard,
            'Payment Method',
            sale.paymentMethod.displayName,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            theme,
            LucideIcons.shoppingBag,
            'Items',
            '${sale.totalItemCount} (${sale.uniqueProductCount} products)',
          ),
          if (sale.draftId != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              LucideIcons.inbox,
              'From Draft',
              'Yes',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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

  Widget _buildVoidInfoCard(
    ThemeData theme,
    SaleEntity sale,
    DateFormat dateFormat,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            theme,
            LucideIcons.user,
            'Voided by',
            sale.voidedByName ?? 'Unknown',
          ),
          if (sale.voidedAt != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              LucideIcons.clock,
              'Voided at',
              dateFormat.format(sale.voidedAt!),
            ),
          ],
          if (sale.voidReason != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.fileText,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.voidReason!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme, SaleEntity sale) {
    final isDark = theme.brightness == Brightness.dark;
    // Readable amber: raw #FFC107 was nearly invisible on the light tint, so the
    // label/icon darken in light and use the gold accent in dark. Body = ink.
    const gold = Color(0xFFE8B84C);
    final tintBase = isDark ? gold : AppColors.warning;
    final labelColor = isDark ? gold : const Color(0xFF8A6100);
    final iconColor = isDark ? gold : const Color(0xFF9A6B00);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tintBase.withValues(alpha: isDark ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tintBase.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.stickyNote, size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.w600, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(sale.notes!),
        ],
      ),
    );
  }

  /// Chooses the right void affordance for the current user and sale state.
  Widget? _buildVoidAction(BuildContext context, WidgetRef ref, SaleEntity sale) {
    final user = ref.watch(currentUserProvider).value;
    final pendingAsync = ref.watch(pendingVoidRequestForSaleProvider(sale.id));
    final hasPending =
        pendingAsync.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    if (hasPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.clock, size: 18),
            SizedBox(width: 8),
            Text('Void pending approval'),
          ],
        ),
      );
    }

    final canVoidDirect = user?.hasPermission(Permission.voidSale) ?? false;
    final canRequest = user?.hasPermission(Permission.requestVoidSale) ?? false;

    if (canVoidDirect) {
      return _buildVoidButton(context, ref, sale);
    }
    if (canRequest) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => RequestVoidDialog.show(
            context: context,
            sale: sale,
            onRequested: () => context.showSuccessSnackBar(
                'Void request sent — awaiting admin approval'),
          ),
          icon: const Icon(LucideIcons.xCircle),
          label: const Text('Request Void'),
          style: _voidButtonStyle(context),
        ),
      );
    }
    return null;
  }

  /// Pinned bottom action bar holding the void affordance — null when there's
  /// nothing to show (voided sale or no permission), so no empty bar renders.
  Widget? _buildVoidFooter(BuildContext context, WidgetRef ref, SaleEntity sale) {
    final action = _buildVoidAction(context, ref, sale);
    if (action == null) return null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: action,
        ),
      ),
    );
  }

  /// Outlined-red void button style — white fill in light, transparent fill +
  /// a lighter red text in dark.
  ButtonStyle _voidButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.styleFrom(
      foregroundColor: isDark ? const Color(0xFFFF6B5E) : AppColors.error,
      backgroundColor: isDark ? null : AppColors.lightCard,
      side: const BorderSide(color: AppColors.error),
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  Widget _buildVoidButton(
    BuildContext context,
    WidgetRef ref,
    SaleEntity sale,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleVoid(context, ref, sale),
        icon: const Icon(LucideIcons.xCircle),
        label: const Text('Void This Sale'),
        style: _voidButtonStyle(context),
      ),
    );
  }

  void _handleVoid(
    BuildContext context,
    WidgetRef ref,
    SaleEntity sale,
  ) {
    VoidSaleDialog.show(
      context: context,
      sale: sale,
      onVoided: () {
        context.showSuccessSnackBar('Sale voided successfully');
        ref.invalidate(saleByIdProvider(saleId));
      },
    );
  }

  void _showReceipt(BuildContext context, SaleEntity sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ReceiptWidget(
          sale: sale,
          scrollController: scrollController,
        ),
      ),
    );
  }
}
