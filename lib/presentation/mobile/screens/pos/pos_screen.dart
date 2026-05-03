import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/discount_input_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_item_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_summary.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';

/// Main POS screen for processing sales.
class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Point of Sale'),
        actions: [
          // Drafts button with badge
          _buildDraftsButton(),
          // Clear cart button
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(CupertinoIcons.trash),
              tooltip: 'Clear Cart',
              onPressed: _showClearCartDialog,
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use side-by-side layout for wider screens
            if (constraints.maxWidth >= 800) {
              return _buildWideLayout(cart, theme);
            }
            return _buildNarrowLayout(cart, theme);
          },
        ),
      ),
    );
  }

  /// Wide layout for tablets - products on left, cart on right.
  Widget _buildWideLayout(CartState cart, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Product search and results
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildSearchSection(),
              Expanded(
                child: _buildProductSearchResults(),
              ),
            ],
          ),
        ),
        // Divider
        const VerticalDivider(width: 1),
        // Right side - Cart
        Expanded(
          flex: 2,
          child: _buildCartSection(cart, theme),
        ),
      ],
    );
  }

  /// Narrow layout for phones - tabs or stacked.
  Widget _buildNarrowLayout(CartState cart, ThemeData theme) {
    return Column(
      children: [
        // Search section
        _buildSearchSection(),
        // Cart section (expandable)
        Expanded(
          child: _buildCartSection(cart, theme),
        ),
      ],
    );
  }

  /// Product search input section.
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ProductSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onProductSelected: _addProductToCart,
        onBarcodeScanned: _handleBarcodeScanned,
      ),
    );
  }

  /// Product search results (for wide layout).
  Widget _buildProductSearchResults() {
    final searchQuery = _searchController.text.trim();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (searchQuery.isEmpty) {
      return Center(
        child: Text(
          'Search for products or scan barcode',
          style: TextStyle(color: muted),
        ),
      );
    }

    // Use local in-memory search for instant results
    final searchResults = ref.watch(localProductSearchProvider(searchQuery));

    return searchResults.when(
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('No products found'));
        }
        return ListView.builder(
          itemCount: products.length,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemBuilder: (context, index) {
            final product = products[index];
            final stockColor = product.isOutOfStock
                ? AppColors.error
                : product.isLowStock
                    ? AppColors.warning
                    : AppColors.success;
            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: stockColor, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    product.name[0].toUpperCase(),
                    style: TextStyle(
                      color: stockColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              title: Text(product.name),
              subtitle: Text(
                '${product.sku} • ${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              trailing: Text(
                'Stock: ${product.quantity}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: product.isLowStock || product.isOutOfStock
                      ? stockColor
                      : muted,
                  fontWeight: product.isLowStock || product.isOutOfStock
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () => _addProductToCart(product),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  /// Cart section with items, discounts, and payment.
  /// Everything scrolls except the action buttons which stay fixed at bottom.
  Widget _buildCartSection(CartState cart, ThemeData theme) {
    return Column(
      children: [
        // Scrollable area: cart items, summary, payment
        Expanded(
          child: cart.isEmpty
              ? _buildEmptyCart()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Cart items (inline, not separately scrollable).
                      // Discount type is now selected inside the per-item
                      // discount dialog instead of on the cart screen.
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cart.items.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return CartItemTile(
                            item: item,
                            discountType: cart.discountType,
                            onQuantityChanged: (qty) =>
                                _updateItemQuantity(item.id, qty),
                            onDiscountTap: () =>
                                _showDiscountDialog(item, cart.discountType),
                            onRemove: () => _removeItem(item.id),
                          );
                        },
                      ),

                      const Divider(height: 1),

                      // Cart Summary — payment is now collected on the
                      // dedicated Checkout screen, not inline.
                      CartSummary(cart: cart),
                    ],
                  ),
                ),
        ),

        // Fixed action buttons at bottom
        if (cart.isNotEmpty) _buildActionButtons(cart),
      ],
    );
  }

  /// Empty cart placeholder.
  Widget _buildEmptyCart() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.cart, size: 56, color: muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cart is empty',
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Search for products or scan barcode',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  /// Action buttons stacked vertically — both span the full viewport
  /// width, share the same 64px height, and use the same lg corner
  /// radius as the Confirm Payment button on the checkout screen.
  /// Proceed-to-Checkout sits on top as the primary action; Save as
  /// Draft sits below as the secondary path.
  Widget _buildActionButtons(CartState cart) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton.icon(
              // canSaveAsDraft = has items, not processing — same gate
              // we want for "proceed to checkout" since payment entry
              // happens on the next screen.
              onPressed: cart.canSaveAsDraft ? _proceedToCheckout : null,
              icon: const Icon(CupertinoIcons.arrow_right),
              label: const Text('Proceed to Checkout'),
              style: FilledButton.styleFrom(shape: shape),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton.icon(
              onPressed: cart.canSaveAsDraft ? _showSaveDraftDialog : null,
              icon: const Icon(CupertinoIcons.tray_arrow_down),
              label: const Text('Save as Draft'),
              style: OutlinedButton.styleFrom(shape: shape),
            ),
          ),
        ],
      ),
    );
  }

  /// Drafts button with badge showing count.
  ///
  /// The Badge wraps the Icon (not the IconButton), so the count anchors
  /// to the 24×24 icon corner instead of the 48×48 hit target — keeps the
  /// number visually attached to the drafts glyph.
  Widget _buildDraftsButton() {
    final draftCount = ref.watch(activeDraftCountProvider);

    return draftCount.when(
      data: (count) => IconButton(
        tooltip: 'Drafts',
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(CupertinoIcons.envelope),
        ),
        onPressed: _navigateToDrafts,
      ),
      loading: () => IconButton(
        icon: const Icon(CupertinoIcons.envelope),
        onPressed: _navigateToDrafts,
      ),
      error: (_, __) => IconButton(
        icon: const Icon(CupertinoIcons.envelope),
        onPressed: _navigateToDrafts,
      ),
    );
  }

  // ==================== EVENT HANDLERS ====================

  void _addProductToCart(dynamic product) {
    ref.read(cartProvider.notifier).addProduct(product);
    _searchController.clear();
    _searchFocusNode.requestFocus();

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handleBarcodeScanned(String barcode) async {
    // Search for product by barcode/SKU
    final product = await ref.read(productBySkuProvider(barcode).future);

    if (product != null) {
      _addProductToCart(product);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found: $barcode'),
            backgroundColor: AppColors.warningDark,
          ),
        );
      }
    }
  }

  void _updateItemQuantity(String itemId, int quantity) {
    ref.read(cartProvider.notifier).updateItemQuantity(itemId, quantity);
  }

  void _removeItem(String itemId) {
    ref.read(cartProvider.notifier).removeItem(itemId);
    HapticFeedback.mediumImpact();
  }

  void _showDiscountDialog(dynamic item, DiscountType discountType) {
    final cart = ref.read(cartProvider);
    // Has any *other* item already accrued a discount? If so, switching
    // the discount type from inside the modal will reset their values.
    final hasOtherDiscounts = cart.items.any(
      (other) => other.id != item.id && other.hasDiscount,
    );

    showDialog(
      context: context,
      builder: (context) => DiscountInputDialog(
        itemName: item.name,
        currentDiscount: item.discountValue,
        discountType: discountType,
        maxAmount: item.grossAmount,
        hasOtherDiscounts: hasOtherDiscounts,
        onApply: (value) {
          ref.read(cartProvider.notifier).applyItemDiscount(item.id, value);
        },
        onTypeChanged: (type) {
          ref.read(cartProvider.notifier).setDiscountType(type);
        },
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text('This will remove all items from the cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(cartProvider.notifier).reset();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSaveDraftDialog() {
    final nameController = TextEditingController();
    final cart = ref.read(cartProvider);

    // Pre-fill with draft name if editing
    if (cart.isFromDraft) {
      final selectedDraft = ref.read(selectedDraftProvider);
      nameController.text = selectedDraft?.name ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cart.isFromDraft ? 'Update Draft' : 'Save as Draft'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Draft Name',
            hintText: 'e.g., Table 5, Customer waiting',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a draft name')),
                );
                return;
              }
              Navigator.pop(context);
              _saveDraft(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft(String name) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final cartNotifier = ref.read(cartProvider.notifier);
    final draftOps = ref.read(draftOperationsProvider.notifier);
    final cart = ref.read(cartProvider);

    final draft = cartNotifier.toDraft(
      name: name,
      createdBy: currentUser.id,
      createdByName: currentUser.displayName,
    );

    final result = cart.isFromDraft
        ? await draftOps.updateDraft(actor: currentUser, draft: draft)
        : await draftOps.createDraft(actor: currentUser, draft: draft);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cart.isFromDraft ? 'Draft updated' : 'Draft saved'),
          backgroundColor: AppColors.successDark,
        ),
      );
      cartNotifier.reset();
    }
  }

  /// Navigate to the dedicated Checkout screen — payment entry and the
  /// final "Confirm Payment" step happen there. The cart provider keeps
  /// the items, so the back button on the Checkout screen returns the
  /// user to a fully populated cart.
  void _proceedToCheckout() {
    context.push(RoutePaths.checkout);
  }

  void _navigateToDrafts() {
    context.push(RoutePaths.drafts);
  }
}
