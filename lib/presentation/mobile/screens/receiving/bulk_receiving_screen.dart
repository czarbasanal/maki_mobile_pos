import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/inventory_widgets.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/receiving_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen for bulk stock receiving.
class BulkReceivingScreen extends ConsumerStatefulWidget {
  final String? receivingId;

  const BulkReceivingScreen({
    super.key,
    this.receivingId,
  });

  @override
  ConsumerState<BulkReceivingScreen> createState() =>
      _BulkReceivingScreenState();
}

class _BulkReceivingScreenState extends ConsumerState<BulkReceivingScreen> {
  // Owned by us so we can clear the field after a row is added.
  // Autocomplete needs both a textEditingController and a focusNode
  // when one of them is passed in.
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _quantityController = TextEditingController(text: '1');
  final _costController = TextEditingController();
  ProductEntity? _selectedProduct;

  bool get _isAdmin =>
      ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (widget.receivingId != null) {
      // Load existing receiving
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(currentReceivingProvider.notifier)
            .loadReceiving(widget.receivingId!);
      });
    } else {
      // Initialize new receiving
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentReceivingProvider.notifier).initNewReceiving();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receivingState = ref.watch(currentReceivingProvider);

    final isReadOnly = receivingState.isReadOnly;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.receiving),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isReadOnly ? 'Receiving Details' : 'Receive Stock'),
            Text(
              receivingState.referenceNumber,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'RobotoMono',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: isReadOnly
            ? const []
            : [
                // Import CSV button
                IconButton(
                  icon: const Icon(LucideIcons.uploadCloud),
                  tooltip: 'Import CSV',
                  onPressed: () => _showCsvImport(context),
                ),
                // Save as draft
                TextButton.icon(
                  onPressed: receivingState.isEmpty ? null : _saveDraft,
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text('Draft'),
                ),
              ],
      ),
      body: Column(
        children: [
          if (isReadOnly) _buildReadOnlyBanner(receivingState),

          // Supplier selection
          _buildSupplierSection(receivingState),

          // Product entry section (hidden when read-only)
          if (!isReadOnly) _buildProductEntrySection(theme),

          // Items list
          Expanded(
            child: _buildItemsList(receivingState),
          ),

          // Summary + action — Complete in edit mode, Done in read-only.
          _buildBottomSection(theme, receivingState),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner(CurrentReceivingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.successText(isDark);
    final completedAt = state.completedAt;
    final dateText = completedAt != null
        ? DateFormat('MMM d, y • h:mm a').format(completedAt)
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      color: AppColors.successFill(isDark),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.checkCircle,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              dateText != null
                  ? 'Completed on $dateText. Read-only.'
                  : 'Completed. Read-only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierSection(CurrentReceivingState state) {
    final suppliersAsync = ref.watch(suppliersProvider);

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(LucideIcons.briefcase, color: muted),
          const SizedBox(width: 12),
          Expanded(
            child: suppliersAsync.when(
              data: (suppliers) {
                return AppDropdown<String>(
                  initialValue: state.supplierId,
                  decoration: const InputDecoration(
                    labelText: 'Supplier (optional)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No supplier'),
                    ),
                    ...suppliers.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        )),
                  ],
                  // Disabled when read-only — passing null to onChanged
                  // greys the field out and blocks selection.
                  onChanged: state.isReadOnly
                      ? null
                      : (value) {
                          final supplier = suppliers.firstWhere(
                            (s) => s.id == value,
                            orElse: () => suppliers.first,
                          );
                          ref
                              .read(currentReceivingProvider.notifier)
                              .setSupplier(
                                value,
                                value != null ? supplier.name : null,
                              );
                        },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load suppliers'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductEntrySection(ThemeData theme) {
    return AppCard(
      radius: AppRadius.field,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Product',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // Product search — supplying our own controller and focus
          // node so _addItem can clear the field after a row is added.
          Autocomplete<ProductEntity>(
            textEditingController: _searchController,
            focusNode: _searchFocusNode,
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) return [];
              final products = await ref.read(
                productSearchProvider(textEditingValue.text).future,
              );
              return products;
            },
            displayStringForOption: (product) => product.name,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Search product by name or SKU',
                  prefixIcon: const Icon(LucideIcons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: () {
                            controller.clear();
                            setState(() => _selectedProduct = null);
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => onSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final product = options.elementAt(index);
                        return ListTile(
                          title: Text(
                            product.name,
                            style: AppTextStyles.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                              '${product.sku} • Stock: ${product.quantity}'),
                          trailing: _isAdmin
                              ? Text(
                                  product.cost.toCurrency(),
                                )
                              : null,
                          onTap: () => onSelected(product),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (product) {
              setState(() {
                _selectedProduct = product;
                _costController.text = product.cost.toStringAsFixed(2);
              });
            },
          ),

          // Quantity and cost inputs
          if (_selectedProduct != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      suffixText: _selectedProduct!.unit,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                if (_isAdmin) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Cost',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _addItem,
                  child: const Text('Add'),
                ),
              ],
            ),
            // Cost difference warning — admin only.
            if (_isAdmin && _costController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildCostWarning(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCostWarning() {
    final newCost = double.tryParse(_costController.text) ?? 0;
    final originalCost = _selectedProduct?.cost ?? 0;

    if ((newCost - originalCost).abs() < 0.01) {
      return const SizedBox.shrink();
    }

    final isIncrease = newCost > originalCost;
    final difference = (newCost - originalCost).abs();
    final percentChange = originalCost > 0
        ? (difference / originalCost * 100).toStringAsFixed(1)
        : '0';

    // A cost change of either direction spawns a new SKU variation — the
    // notice carries a single warning semantic, not up/down coloring.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warn = AppColors.warningIcon(isDark);
    final fg = AppColors.warningBadgeText(isDark);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: warn.withValues(alpha: isDark ? 0.34 : 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            isIncrease ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isIncrease
                  ? 'Cost increased by $percentChange% - A new SKU variation will be created'
                  : 'Cost decreased by $percentChange% - A new SKU variation will be created',
              style: TextStyle(fontSize: 12, color: fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(CurrentReceivingState state) {
    if (state.isEmpty) {
      // SingleChildScrollView handles the overflow when the keyboard
      // shrinks the Expanded slot — without it the icon + texts no
      // longer fit and Flutter throws RenderFlex overflowed.
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.shoppingCart, size: 64, color: muted),
              const SizedBox(height: 16),
              Text(
                'No items added yet',
                style: TextStyle(fontSize: 18, color: muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Search and add products above',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = state.items[index];
        // On completed lines, allow opening stock adjustment for the
        // product (using the variation id when one was created).
        final pid = item.newProductId ?? item.productId;
        return ReceivingItemRow(
          item: item,
          readOnly: state.isReadOnly,
          onQuantityChanged: (quantity) {
            ref.read(currentReceivingProvider.notifier).updateItemQuantity(
                  item.id,
                  quantity,
                );
          },
          onRemove: () {
            ref.read(currentReceivingProvider.notifier).removeItem(item.id);
          },
          onAdjustStock: state.isReadOnly && pid != null
              ? () => _openStockAdjustment(pid)
              : null,
        );
      },
    );
  }

  Future<void> _openStockAdjustment(String productId) async {
    final product = await ref.read(productByIdProvider(productId).future);
    if (!mounted) return;
    if (product == null) {
      context.showErrorSnackBar('Product no longer exists');
      return;
    }
    await StockAdjustmentDialog.show(context: context, product: product);
  }

  Widget _buildBottomSection(ThemeData theme, CurrentReceivingState state) {
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.itemCount} products',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    Text(
                      '${state.totalQuantity} total units',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
                if (_isAdmin)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Cost',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      Text(
                        state.totalCost.toCurrency(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Error message — only relevant during edit; suppress when
            // viewing a completed receiving.
            if (state.errorMessage != null && !state.isReadOnly)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),

            // Bottom action — Complete in edit mode; nothing in read-only
            // (the back arrow handles navigation, and there's no edit to
            // commit, so a button would just be visual noise).
            if (!state.isReadOnly)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  boxShadow: isDark
                      ? AppShadows.primaryButtonGold
                      : AppShadows.primaryButton,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: state.isEmpty || state.isProcessing
                        ? null
                        : _confirmAndComplete,
                    icon: state.isProcessing
                        ? const SizedBox.shrink()
                        : const Icon(LucideIcons.checkCircle, size: 18),
                    label: state.isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Complete Receiving'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    if (_selectedProduct == null) return;

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0;

    if (quantity <= 0) {
      context.showWarningSnackBar('Please enter a valid quantity');
      return;
    }

    // Get cost code from the provider
    final costCode = ref.read(encodeCostProvider(cost));

    ref.read(currentReceivingProvider.notifier).addItem(
          ReceivingItemEntity(
            id: '',
            productId: _selectedProduct!.id,
            sku: _selectedProduct!.sku,
            name: _selectedProduct!.name,
            quantity: quantity,
            unit: _selectedProduct!.unit,
            unitCost: cost,
            costCode: costCode,
          ),
        );

    // Reset form
    setState(() {
      _selectedProduct = null;
      _quantityController.text = '1';
      _costController.clear();
    });
    _searchController.clear();
  }

  Future<void> _saveDraft() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final result =
        await ref.read(currentReceivingProvider.notifier).saveAsDraft(
              createdBy: currentUser.id,
              createdByName: currentUser.displayName,
            );

    if (result != null && mounted) {
      context.showSuccessSnackBar('Draft saved');
    }
  }

  /// Resolves which lines have a unit cost that differs from the parent
  /// product's current cost. Used by the completion confirmation dialog so
  /// the user can see — before posting — which lines will spawn a SKU
  /// variation.
  Future<List<_PriceChangePreview>> _resolvePriceChanges() async {
    final state = ref.read(currentReceivingProvider);
    final changes = <_PriceChangePreview>[];
    for (final item in state.items) {
      if (item.productId == null) continue;
      final product =
          await ref.read(productByIdProvider(item.productId!).future);
      if (product == null) continue;
      if ((item.unitCost - product.cost).abs() > 0.01) {
        changes.add(_PriceChangePreview(
          item: item,
          oldCost: product.cost,
          newCost: item.unitCost,
        ));
      }
    }
    return changes;
  }

  Future<void> _confirmAndComplete() async {
    final changes = await _resolvePriceChanges();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final muted = theme.colorScheme.onSurfaceVariant;
        return AlertDialog(
          title: const Text('Complete Receiving?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (changes.isEmpty)
                  Text(
                    _isAdmin
                        ? 'No price changes detected. Stock will be added to existing products.'
                        : 'Stock will be added to existing products.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  )
                else ...[
                  Text(
                    '${changes.length} ${changes.length == 1 ? 'line has' : 'lines have'} a different cost than the current product. A new SKU variation will be created for each.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 12),
                    for (final c in changes) _PriceChangeRow(change: c),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Post Receiving'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _completeReceiving();
    }
  }

  Future<void> _completeReceiving() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final result = await ref.read(currentReceivingProvider.notifier).complete(
          createdBy: currentUser.id,
          createdByName: currentUser.displayName,
        );

    if (result != null && mounted) {
      context.showSuccessSnackBar('Stock received successfully!');
      context.goBackOr(RoutePaths.receiving);
    }
  }

  void _showCsvImport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CsvImportDialog(
        onImport: (items) {
          for (final item in items) {
            ref.read(currentReceivingProvider.notifier).addItem(item);
          }
        },
      ),
    );
  }
}

/// One pending price change surfaced in the completion confirmation.
class _PriceChangePreview {
  const _PriceChangePreview({
    required this.item,
    required this.oldCost,
    required this.newCost,
  });

  final ReceivingItemEntity item;
  final double oldCost;
  final double newCost;
}

class _PriceChangeRow extends StatelessWidget {
  const _PriceChangeRow({required this.change});
  final _PriceChangePreview change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final up = change.newCost > change.oldCost;
    final color = up ? AppColors.costUp(isDark) : AppColors.costDown(isDark);
    final symbol = AppConstants.currencySymbol;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.item.name,
            style: AppTextStyles.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Text(
                '$symbol${change.oldCost.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.arrowRight, size: 12, color: muted),
              const SizedBox(width: 6),
              Text(
                '$symbol${change.newCost.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
