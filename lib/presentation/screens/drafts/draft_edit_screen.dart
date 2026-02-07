import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/common_widgets.dart';

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
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading draft: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(RoutePaths.drafts),
                child: const Text('Back to Drafts'),
              ),
            ],
          ),
        ),
      ),
      data: (draft) {
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Draft Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Draft not found or has been deleted'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go(RoutePaths.drafts),
                    child: const Text('Back to Drafts'),
                  ),
                ],
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
            icon: const Icon(Icons.arrow_back),
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
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(draft),
              tooltip: 'Delete Draft',
            ),
          ],
        ),
        body: Column(
          children: [
            // Draft info header
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Created ${dateFormat.format(draft.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (draft.updatedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Updated ${dateFormat.format(draft.updatedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (draft.notes != null && draft.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      draft.notes!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),

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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No items in this draft',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftItem(SaleItemEntity item) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Quantity badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${item.quantity}x',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.sku}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)} each',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Line total
            Text(
              '${AppConstants.currencySymbol}${item.grossAmount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(DraftEntity draft) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Summary rows
            _buildSummaryRow(
              'Subtotal',
              '${AppConstants.currencySymbol}${draft.subtotal.toStringAsFixed(2)}',
            ),
            if (draft.totalDiscount > 0) ...[
              const SizedBox(height: 4),
              _buildSummaryRow(
                'Discount',
                '-${AppConstants.currencySymbol}${draft.totalDiscount.toStringAsFixed(2)}',
                valueColor: Colors.green,
              ),
            ],
            const Divider(height: 16),
            _buildSummaryRow(
              'Total (${draft.totalItemCount} items)',
              '${AppConstants.currencySymbol}${draft.grandTotal.toStringAsFixed(2)}',
              isBold: true,
              valueStyle: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryAccent,
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // Edit in POS button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        draft.items.isEmpty ? null : () => _editInPos(draft),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit in POS'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Checkout button
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: draft.items.isEmpty
                        ? null
                        : () => _proceedToCheckout(draft),
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text('Checkout'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              ),
        ),
      ],
    );
  }

  Future<void> _editInPos(DraftEntity draft) async {
    setState(() => _isLoading = true);

    try {
      // Load draft into cart
      ref.read(cartProvider.notifier).loadFromDraft(draft);

      if (mounted) {
        // Navigate to POS
        context.go(RoutePaths.pos);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      // Load draft into cart
      ref.read(cartProvider.notifier).loadFromDraft(draft);

      if (mounted) {
        // Navigate to checkout
        context.go(RoutePaths.checkout);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              backgroundColor: Colors.red,
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
      final success = await ref
          .read(draftOperationsProvider.notifier)
          .deleteDraft(draft.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted'),
            backgroundColor: Colors.green,
          ),
        );
        context.go(RoutePaths.drafts);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}
