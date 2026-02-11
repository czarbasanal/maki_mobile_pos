import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Screen for creating or editing a product.
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _unitController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedSupplierId;
  bool _isLoading = false;
  bool _isSaving = false;
  ProductEntity? _existingProduct;

  @override
  void initState() {
    super.initState();
    _reorderLevelController.text = '${AppConstants.defaultReorderLevel}';
    _unitController.text = 'pcs';

    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final product =
          await ref.read(productByIdProvider(widget.productId!).future);
      if (product != null && mounted) {
        _existingProduct = product;
        _skuController.text = product.sku;
        _nameController.text = product.name;
        _priceController.text = product.price.toString();
        _costController.text = product.cost.toString();
        _quantityController.text = product.quantity.toString();
        _reorderLevelController.text = product.reorderLevel.toString();
        _unitController.text = product.unit ?? 'pcs';
        _barcodeController.text = product.barcode ?? '';
        _categoryController.text = product.category ?? '';
        _notesController.text = product.notes ?? '';
        _selectedSupplierId = product.supplierId;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    _unitController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final canViewCost = currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.inventory),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SKU
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU *',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                      enabled: !widget.isEditing,
                      validator: (value) =>
                          value?.isEmpty == true ? 'SKU is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        prefixIcon: Icon(Icons.inventory_2),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Name is required' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Price and Cost row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Selling Price *',
                              prefixText: '₱ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              if (value?.isEmpty == true) return 'Required';
                              if (double.tryParse(value!) == null)
                                return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (canViewCost)
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              decoration: const InputDecoration(
                                labelText: 'Cost *',
                                prefixText: '₱ ',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) {
                                if (value?.isEmpty == true) return 'Required';
                                if (double.tryParse(value!) == null)
                                  return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quantity and Reorder Level row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Initial Quantity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _reorderLevelController,
                            decoration: const InputDecoration(
                              labelText: 'Reorder Level',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Unit
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(),
                        hintText: 'e.g., pcs, kg, box',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Barcode
                    TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: () {
                            // TODO: Implement barcode scanning
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Supplier dropdown
                    suppliersAsync.when(
                      data: (suppliers) => DropdownButtonFormField<String?>(
                        value: _selectedSupplierId,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
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
                          setState(() => _selectedSupplierId = value);
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading suppliers'),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(widget.isEditing
                                ? 'Update Product'
                                : 'Add Product'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      // Encode cost to cost code
      final costValue = double.tryParse(_costController.text) ?? 0.0;
      final costCode = ref.read(encodeCostProvider(costValue));

      // Get supplier name for denormalization
      String? supplierName;
      if (_selectedSupplierId != null) {
        final suppliers = ref.read(suppliersProvider).value;
        supplierName = suppliers
            ?.where((s) => s.id == _selectedSupplierId)
            .firstOrNull
            ?.name;
      }

      final product = ProductEntity(
        id: widget.isEditing ? _existingProduct!.id : '',
        sku: _skuController.text.trim(),
        name: _nameController.text.trim(),
        costCode: costCode,
        cost: costValue,
        price: double.tryParse(_priceController.text) ?? 0.0,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        reorderLevel: int.tryParse(_reorderLevelController.text) ?? 10,
        unit: _unitController.text.trim().isEmpty
            ? 'pcs'
            : _unitController.text.trim(),
        supplierId: _selectedSupplierId,
        supplierName: supplierName,
        isActive: true,
        createdAt: widget.isEditing
            ? _existingProduct!.createdAt
            : DateTime.now(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final productOps = ref.read(productOperationsProvider.notifier);

      if (widget.isEditing) {
        final result = await productOps.updateProduct(
          product: product,
          updatedBy: currentUser.id,
        );
        if (result == null) throw Exception('Failed to update product');
      } else {
        final result = await productOps.createProduct(
          product: product,
          createdBy: currentUser.id,
        );
        if (result == null) throw Exception('Failed to create product');
      }

      if (mounted) {
        // Ensure inventory list refreshes with fresh data
        ref.invalidate(productsProvider);
        context.showSuccessSnackBar(
          widget.isEditing ? 'Product updated' : 'Product added',
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.inventory);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
