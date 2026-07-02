import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
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
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/save_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/job_order_badge_button.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_summary.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            boxShadow: AppShadows.pinnedHeader(
              dark: theme.brightness == Brightness.dark,
            ),
          ),
          child: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: () => context.goBackOr(RoutePaths.dashboard),
            ),
            title: const Text('Point of Sale'),
            actions: [
              // Drafts button with badge
              JobOrderBadgeButton(onPressed: _navigateToDrafts),
              // Clear cart button
              if (cart.isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.trash2),
                  tooltip: 'Clear Cart',
                  onPressed: _showClearCartDialog,
                ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
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
              title: Text(
                product.name,
                style: AppTextStyles.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${product.sku} • ${product.price.toCurrency()}',
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    children: [
                      // Cart items (inline, not separately scrollable).
                      // Discount type is now selected inside the per-item
                      // discount dialog instead of on the cart screen.
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cart.items.length,
                        padding: const EdgeInsets.symmetric(vertical: 6),
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
                      const SizedBox(height: AppSpacing.sm),
                      // Labor & Service — collapsible; empty for normal sales.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: AppCard(child: _buildLaborSection(cart)),
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      // Cart Summary — payment is now collected on the
                      // dedicated Checkout screen, not inline.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: AppCard(child: CartSummary(cart: cart)),
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shoppingCart, size: 56, color: muted),
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

  /// Collapsible "Labor & Service" block: mechanic picker + editable
  /// labor lines + an inline validity banner. Starts expanded when labor
  /// already exists so the cashier sees it on a reloaded service draft.
  Widget _buildLaborSection(CartState cart) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: cart.laborLines.isNotEmpty,
        // Wrench + chevron muted to match the handoff's quiet header.
        iconColor: muted,
        collapsedIconColor: muted,
        leading: const Icon(LucideIcons.wrench, size: 19),
        title: Text(
          'Labor & Service',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: cart.laborLines.isEmpty
            ? Text(
                'Optional — add mechanic labor',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: muted, fontSize: 12),
              )
            : Text(
                '${cart.laborLines.length} service(s) · ${cart.laborSubtotal.toCurrency()}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: muted, fontSize: 12),
              ),
        // Top inset gives the mechanic dropdown's floating "Mechanic" label
        // room above the field — at top:0 it was clipped (cut off).
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          MotorcycleModelPicker(
            selectedModel: cart.motorcycleModel,
            onChanged: (m) =>
                ref.read(cartProvider.notifier).setMotorcycleModel(m),
          ),
          const SizedBox(height: AppSpacing.sm),
          MechanicPicker(
            selectedMechanicId: cart.mechanicId,
            onChanged: (m) {
              final notifier = ref.read(cartProvider.notifier);
              if (m == null) {
                notifier.clearMechanic();
              } else {
                notifier.setMechanic(m.id, m.name);
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          ...cart.laborLines.map(
            (line) => LaborLineTile(
              line: line,
              onEdited: (description, fee) => ref
                  .read(cartProvider.notifier)
                  .updateLaborLine(line.id, description: description, fee: fee),
              onRemove: () =>
                  ref.read(cartProvider.notifier).removeLaborLine(line.id),
            ),
          ),
          if (cart.laborValidationError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildLaborError(cart.laborValidationError!),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddLaborDialog,
              icon: const Icon(LucideIcons.plus),
              label: const Text('Add labor line'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaborError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLaborDialog() {
    final descController = TextEditingController();
    final feeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierColor:
          AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
      builder: (context) => AppDialog(
        title: 'Add Labor / Service',
        leadingIcon: LucideIcons.wrench,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                style: AppTextStyles.fieldInput,
                controller: descController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Engine tune-up',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                style: AppTextStyles.fieldInput,
                controller: feeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Fee',
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Fee must be greater than 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          appDialogCancel(context, 'Cancel',
              onTap: () => Navigator.pop(context)),
          appDialogPrimary(context, 'Add', onTap: () {
            if (!formKey.currentState!.validate()) return;
            ref.read(cartProvider.notifier).addLaborLine(
                  description: descController.text.trim(),
                  fee: double.parse(feeController.text.trim()),
                );
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  /// Action buttons side by side — Save Draft (secondary, left) and
  /// Checkout (primary, right) share the same 50px height and lg corner
  /// radius. Both are gated on a non-empty, not-processing cart.
  Widget _buildActionButtons(CartState cart) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    // canSaveAsDraft = has items, not processing — same gate we want for
    // "proceed to checkout" since payment entry happens on the next screen.
    final canProceed = cart.canSaveAsDraft;
    return Container(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: canProceed ? _showSaveDraftDialog : null,
                    icon: const Icon(LucideIcons.clipboardPlus, size: 18),
                    // Scale down instead of wrapping — the label was cutting
                    // off to two lines on narrow screens.
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Save Job Order', maxLines: 1),
                    ),
                    style: OutlinedButton.styleFrom(shape: shape),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: canProceed
                        ? (isDark
                            ? AppShadows.primaryButtonGold
                            : AppShadows.primaryButton)
                        : null,
                  ),
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: canProceed ? _proceedToCheckout : null,
                      icon: const Icon(LucideIcons.arrowRight, size: 18),
                      label: const Text('Checkout'),
                      style: FilledButton.styleFrom(shape: shape),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    // Look up by barcode first (covers vendor codes mapped on the product),
    // then by SKU as a fall-back — see ProductRepositoryImpl.getProductByBarcode.
    final product = await ref.read(productByBarcodeProvider(barcode).future);

    if (product != null) {
      _addProductToCart(product);
    } else {
      if (mounted) {
        context.showWarningSnackBar('Product not found: $barcode');
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

  Future<void> _showClearCartDialog() async {
    final ok = await context.showConfirmDialog(
      title: 'Clear Cart?',
      message: 'This will remove all items from the cart.',
      confirmText: 'Clear',
      icon: LucideIcons.trash2,
      isDangerous: true,
    );
    if (ok) ref.read(cartProvider.notifier).reset();
  }

  Future<void> _showSaveDraftDialog() async {
    final cart = ref.read(cartProvider);

    // Cart was loaded from a draft — reuse the original title and skip
    // the prompt, since the user already named it the first time.
    final retainedName = cart.draftName?.trim() ?? '';
    if (retainedName.isNotEmpty) {
      _saveDraft(retainedName);
      return;
    }

    // Prefilled from the cart so choices made in Labor & Service carry over.
    final input = await showSaveJobOrderDialog(
      context,
      initialModel: cart.motorcycleModel,
      initialMechanicId: cart.mechanicId,
      initialMechanicName: cart.mechanicName,
    );
    if (input == null || !mounted) return;

    final notifier = ref.read(cartProvider.notifier);
    notifier.setMotorcycleModel(input.model);
    if (input.mechanicId == null) {
      notifier.clearMechanic();
    } else {
      notifier.setMechanic(input.mechanicId!, input.mechanicName ?? '');
    }
    _saveDraft(input.label);
  }

  Future<void> _saveDraft(String name) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final cartNotifier = ref.read(cartProvider.notifier);
    final draftOps = ref.read(draftOperationsProvider.notifier);
    final isUpdate = ref.read(cartProvider).isFromDraft;

    final draft = cartNotifier.toDraft(
      name: name,
      createdBy: currentUser.id,
      createdByName: currentUser.displayName,
    );

    // Block the UI while the write runs so a second tap can't fire a
    // duplicate save — createDraft writes a new auto-id doc on every call.
    final result = await context.runWithWaiting(
      () => isUpdate
          ? draftOps.updateDraft(actor: currentUser, draft: draft)
          : draftOps.createDraft(actor: currentUser, draft: draft),
      message: isUpdate ? 'Updating…' : 'Saving…',
    );

    if (result != null && mounted) {
      context.showSuccessSnackBar(
          isUpdate ? 'Job order updated' : 'Job order saved');
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
