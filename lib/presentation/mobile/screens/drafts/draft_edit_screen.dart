import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen for editing/viewing a draft and converting to checkout.
class DraftEditScreen extends ConsumerStatefulWidget {
  final String draftId;

  const DraftEditScreen({
    super.key,
    required this.draftId,
  });

  @override
  ConsumerState<DraftEditScreen> createState() => _DraftEditScreenState();
}

class _DraftEditScreenState extends ConsumerState<DraftEditScreen> {
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(draftByIdProvider(widget.draftId));

    return draftAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Draft...')),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: ErrorStateView(
          message: 'Error loading draft: $error',
          action: ElevatedButton(
            onPressed: () => context.go(RoutePaths.drafts),
            child: const Text('Back to Drafts'),
          ),
        ),
      ),
      data: (draft) {
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Draft Not Found')),
            body: EmptyStateView(
              icon: Icons.search_off,
              title: 'Draft not found or has been deleted',
              action: ElevatedButton(
                onPressed: () => context.go(RoutePaths.drafts),
                child: const Text('Back to Drafts'),
              ),
            ),
          );
        }

        return _buildDraftContent(draft);
      },
    );
  }

  Widget _buildDraftContent(DraftEntity draft) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return LoadingOverlay(
      isLoading: _isLoading || _isDeleting,
      message: _isDeleting ? 'Deleting draft...' : 'Processing...',
      child: Scaffold(
        appBar: AppBar(
          title: Text(draft.name),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RoutePaths.drafts);
              }
            },
          ),
          actions: [
            // Delete button
            IconButton(
              icon: const Icon(CupertinoIcons.trash),
              onPressed: () => _confirmDelete(draft),
              tooltip: 'Delete Draft',
            ),
          ],
        ),
        body: Column(
          children: [
            // Draft info header
            Builder(builder: (context) {
              final muted = theme.colorScheme.onSurfaceVariant;
              final isDark = theme.brightness == Brightness.dark;
              final hairline = isDark
                  ? AppColors.darkHairline
                  : AppColors.lightHairline;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: hairline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.clock, size: 14, color: muted),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Created ${dateFormat.format(draft.createdAt)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    if (draft.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(CupertinoIcons.pencil, size: 14, color: muted),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Updated ${dateFormat.format(draft.updatedAt!)}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                    if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(draft.notes!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              );
            }),

            // Items list
            Expanded(
              child: draft.items.isEmpty
                  ? _buildEmptyItems()
                  : ListView.builder(
                      itemCount: draft.items.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        return _buildDraftItem(draft.items[index]);
                      },
                    ),
            ),

            // Summary and actions
            _buildSummarySection(draft),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyItems() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.cart, size: 56, color: muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No items in this draft',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftItem(SaleItemEntity item) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          children: [
            // Quantity badge — outlined, no fill
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  '${item.quantity}x',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
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
                    style: AppTextStyles.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.sku}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)} each',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            Text(
              '${AppConstants.currencySymbol}${item.grossAmount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(DraftEntity draft) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildSummaryRow(
              'Subtotal',
              '${AppConstants.currencySymbol}${draft.subtotal.toStringAsFixed(2)}',
            ),
            if (draft.totalDiscount > 0) ...[
              const SizedBox(height: 4),
              _buildSummaryRow(
                'Discount',
                '-${AppConstants.currencySymbol}${draft.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            const Divider(height: AppSpacing.md),
            _buildSummaryRow(
              'Total (${draft.totalItemCount} items)',
              '${AppConstants.currencySymbol}${draft.grandTotal.toStringAsFixed(2)}',
              isBold: true,
              valueStyle: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        draft.items.isEmpty ? null : () => _editInPos(draft),
                    icon: const Icon(CupertinoIcons.pencil),
                    label: const Text('Edit in POS'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: draft.items.isEmpty
                        ? null
                        : () => _proceedToCheckout(draft),
                    icon: const Icon(CupertinoIcons.cart_badge_plus),
                    label: const Text('Checkout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  Future<void> _editInPos(DraftEntity draft) async {
    setState(() => _isLoading = true);

    try {
      // Load draft into cart and consume it — see drafts_list_screen for
      // the rationale on destructive load.
      ref.read(cartProvider.notifier).loadFromDraft(draft);
      ref.read(selectedDraftProvider.notifier).state = null;
      final actor = ref.read(currentUserProvider).valueOrNull;
      if (actor != null) {
        ref
            .read(draftOperationsProvider.notifier)
            .deleteDraft(actor: actor, draftId: draft.id);
      }

      if (mounted) {
        // Navigate to POS
        context.go(RoutePaths.pos);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error loading draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _proceedToCheckout(DraftEntity draft) async {
    setState(() => _isLoading = true);

    try {
      // Load draft into cart and consume it — see drafts_list_screen for
      // the rationale on destructive load.
      ref.read(cartProvider.notifier).loadFromDraft(draft);
      ref.read(selectedDraftProvider.notifier).state = null;
      final actor = ref.read(currentUserProvider).valueOrNull;
      if (actor != null) {
        ref
            .read(draftOperationsProvider.notifier)
            .deleteDraft(actor: actor, draftId: draft.id);
      }

      if (mounted) {
        // Navigate to checkout
        context.go(RoutePaths.checkout);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error loading draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete(DraftEntity draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Text(
          'Are you sure you want to delete "${draft.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteDraft(draft);
    }
  }

  Future<void> _deleteDraft(DraftEntity draft) async {
    setState(() => _isDeleting = true);

    try {
      final actor = ref.read(currentUserProvider).value;
      if (actor == null) return;
      final success = await ref
          .read(draftOperationsProvider.notifier)
          .deleteDraft(actor: actor, draftId: draft.id);

      if (success && mounted) {
        context.showSuccessSnackBar('Draft deleted');
        context.go(RoutePaths.drafts);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error deleting draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}
