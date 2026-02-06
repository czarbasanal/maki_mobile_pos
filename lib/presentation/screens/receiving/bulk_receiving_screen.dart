import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/widgets/receiving/receiving_widgets.dart';

/// Screen for bulk stock receiving.
class BulkReceivingScreen extends ConsumerStatefulWidget {
  const BulkReceivingScreen({super.key});

  @override
  ConsumerState<BulkReceivingScreen> createState() =>
      _BulkReceivingScreenState();
}

class _BulkReceivingScreenState extends ConsumerState<BulkReceivingScreen> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _costController = TextEditingController();
  ProductEntity? _selectedProduct;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receivingState = ref.watch(currentReceivingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receive Stock'),
            Text(
              receivingState.referenceNumber,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          // Import CSV button
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: () => _showCsvImport(context),
          ),
          // Save as draft
          TextButton.icon(
            onPressed: receivingState.isEmpty ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Supplier selection
          _buildSupplierSection(receivingState),

          const Divider(height: 1),

          // Product entry section
          _buildProductEntrySection(theme),

          const Divider(height: 1),

          // Items list
          Expanded(
            child: _buildItemsList(receivingState),
          ),

          // Summary and complete button
          _buildBottomSection(theme, receivingState),
        ],
      ),
    );
  }

  Widget _buildSupplierSection(CurrentReceivingState state) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: suppliersAsync.when(
              data: (suppliers) {
                return DropdownButtonFormField<String>(
                  value: state.supplierId,
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
                  onChanged: (value) {
                    final supplier = suppliers.firstWhere(
                      (s) => s.id == value,
                      orElse: () => suppliers.first,
                    );
                    ref.read(currentReceivingProvider.notifier).setSupplier(
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Product',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Product search
          Autocomplete<ProductEntity>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) return [];
              final products = await ref.read(
                productSearchProvider(textEditingValue.text).future,
              );
              return products;
            },
            displayStringForOption: (product) => product.name,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              _searchController.text = controller.text;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Search product by name or SKU',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
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
                          title: Text(product.name),
                          subtitle: Text(
                              '${product.sku} • Stock: ${product.quantity}'),
                          trailing: Text(
                            '${AppConstants.currencySymbol}${product.cost.toStringAsFixed(2)}',
                          ),
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
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _addItem,
                  child: const Text('Add'),
                ),
              ],
            ),
            // Cost difference warning
            if (_costController.text.isNotEmpty) ...[
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isIncrease ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isIncrease ? Colors.orange[200]! : Colors.blue[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isIncrease ? Icons.trending_up : Icons.trending_down,
            color: isIncrease ? Colors.orange[700] : Colors.blue[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isIncrease
                  ? 'Cost increased by $percentChange% - A new SKU variation will be created'
                  : 'Cost decreased by $percentChange% - A new SKU variation will be created',
              style: TextStyle(
                fontSize: 12,
                color: isIncrease ? Colors.orange[700] : Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(CurrentReceivingState state) {
    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_shopping_cart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items added yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search and add products above',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return ReceivingItemRow(
          item: item,
          onQuantityChanged: (quantity) {
            ref.read(currentReceivingProvider.notifier).updateItemQuantity(
                  item.id,
                  quantity,
                );
          },
          onRemove: () {
            ref.read(currentReceivingProvider.notifier).removeItem(item.id);
          },
        );
      },
    );
  }

  Widget _buildBottomSection(ThemeData theme, CurrentReceivingState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
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
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      '${state.totalQuantity} total units',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Cost',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${state.totalCost.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Error message
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Complete button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isEmpty || state.isProcessing
                    ? null
                    : _completeReceiving,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: state.isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Complete Receiving'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved'),
          backgroundColor: Colors.green,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock received successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
