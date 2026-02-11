import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/discount_input_dialog.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/cart_item_tile.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/cart_summary.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/payment_section.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/product_search_field.dart';

/// Main POS screen for processing sales.
class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _amountReceivedController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Point of Sale'),
        actions: [
          // Drafts button with badge
          _buildDraftsButton(),
          // Clear cart button
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
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

    if (searchQuery.isEmpty) {
      return const Center(
        child: Text(
          'Search for products or scan barcode',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Use local in-memory search for instant results
    final searchResults = ref.watch(localProductSearchProvider(searchQuery));

    return searchResults.when(
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Text('No products found'),
          );
        }
        return ListView.builder(
          itemCount: products.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(product.name[0].toUpperCase()),
              ),
              title: Text(product.name),
              subtitle: Text(
                  '${product.sku} • ${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}'),
              trailing: Text(
                'Stock: ${product.quantity}',
                style: TextStyle(
                  color: product.isLowStock ? Colors.orange : Colors.grey,
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
                      // Discount type selector
                      _buildDiscountTypeSelector(cart),

                      // Cart items (inline, not separately scrollable)
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

                      // Cart Summary
                      CartSummary(cart: cart),

                      const Divider(height: 1),

                      // Payment Section
                      PaymentSection(
                        cart: cart,
                        amountController: _amountReceivedController,
                        onAmountChanged: _handleAmountChanged,
                        onPaymentMethodChanged: _handlePaymentMethodChanged,
                      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for products or scan barcode',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Discount type selector (Amount vs Percentage).
  Widget _buildDiscountTypeSelector(CartState cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Discount Type:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedButton<DiscountType>(
              segments: const [
                ButtonSegment(
                  value: DiscountType.amount,
                  label: Text('Amount (₱)'),
                  icon: Icon(Icons.attach_money),
                ),
                ButtonSegment(
                  value: DiscountType.percentage,
                  label: Text('Percent (%)'),
                  icon: Icon(Icons.percent),
                ),
              ],
              selected: {cart.discountType},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  _handleDiscountTypeChanged(selected.first);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Action buttons (Checkout, Save Draft).
  Widget _buildActionButtons(CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Save as Draft button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: cart.canSaveAsDraft ? _showSaveDraftDialog : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Draft'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Checkout button
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: cart.canCheckout ? _processCheckout : null,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Checkout ${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Drafts button with badge showing count.
  Widget _buildDraftsButton() {
    final draftCount = ref.watch(activeDraftCountProvider);

    return draftCount.when(
      data: (count) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: IconButton(
          icon: const Icon(Icons.drafts_outlined),
          tooltip: 'Drafts',
          onPressed: _navigateToDrafts,
        ),
      ),
      loading: () => IconButton(
        icon: const Icon(Icons.drafts_outlined),
        onPressed: _navigateToDrafts,
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.drafts_outlined),
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
            backgroundColor: Colors.orange,
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

  void _handleDiscountTypeChanged(DiscountType type) {
    final cart = ref.read(cartProvider);

    // Warn if there are existing discounts
    if (cart.hasDiscount) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change Discount Type?'),
          content: const Text(
            'Changing the discount type will reset all item discounts to zero. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(cartProvider.notifier).setDiscountType(type);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      ref.read(cartProvider.notifier).setDiscountType(type);
    }
  }

  void _showDiscountDialog(dynamic item, DiscountType discountType) {
    showDialog(
      context: context,
      builder: (context) => DiscountInputDialog(
        itemName: item.name,
        currentDiscount: item.discountValue,
        discountType: discountType,
        maxAmount: item.grossAmount,
        onApply: (value) {
          ref.read(cartProvider.notifier).applyItemDiscount(item.id, value);
        },
      ),
    );
  }

  void _handleAmountChanged(String value) {
    final amount = double.tryParse(value) ?? 0;
    ref.read(cartProvider.notifier).setAmountReceived(amount);
  }

  void _handlePaymentMethodChanged(PaymentMethod method) {
    ref.read(cartProvider.notifier).setPaymentMethod(method);
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
              backgroundColor: Colors.red,
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
            border: OutlineInputBorder(),
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
        ? await draftOps.updateDraft(draft: draft, updatedBy: currentUser.id)
        : await draftOps.createDraft(draft);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cart.isFromDraft ? 'Draft updated' : 'Draft saved'),
          backgroundColor: Colors.green,
        ),
      );
      cartNotifier.reset();
    }
  }

  Future<void> _processCheckout() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final cartNotifier = ref.read(cartProvider.notifier);

    // Set processing state
    cartNotifier.setProcessing(true);

    try {
      // Create the use case
      final useCase = ProcessSaleUseCase(
        saleRepository: ref.read(saleRepositoryProvider),
        productRepository: ref.read(productRepositoryProvider),
        draftRepository: ref.read(draftRepositoryProvider),
      );

      // Build sale entity from cart
      final sale = cartNotifier.toSale(
        saleNumber: '', // Will be generated by use case
        cashierId: currentUser.id,
        cashierName: currentUser.displayName,
      );

      // Process the sale (creates sale, deducts inventory, converts draft)
      final result = await useCase.execute(sale: sale);

      if (result.success && result.sale != null) {
        // Reset cart
        cartNotifier.resetAfterCheckout();

        // Clear selected draft
        ref.read(selectedDraftProvider.notifier).state = null;

        // Invalidate providers to refresh data
        ref.invalidate(todaysSalesProvider);
        ref.invalidate(todaysSalesSummaryProvider);
        ref.invalidate(activeDraftsProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(lowStockProductsProvider);

        if (mounted) {
          // Show success with change info
          _showCheckoutSuccessDialog(result.sale!);
        }
      } else {
        throw Exception(result.errorMessage ?? 'Failed to process sale');
      }
    } catch (e) {
      cartNotifier.setError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCheckoutSuccessDialog(dynamic sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 64,
        ),
        title: const Text('Sale Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sale #${sale.saleNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildReceiptRow('Total', sale.grandTotal),
            _buildReceiptRow('Received', sale.amountReceived),
            const Divider(),
            _buildReceiptRow(
              'Change',
              sale.changeGiven,
              isHighlighted: true,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _searchFocusNode.requestFocus();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, double amount,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlighted ? 18 : 14,
            ),
          ),
          Text(
            '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlighted ? 18 : 14,
              color: isHighlighted ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDrafts() {
    context.push(RoutePaths.drafts);
  }
}
