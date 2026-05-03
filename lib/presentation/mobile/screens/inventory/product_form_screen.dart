import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/inventory_widgets.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Screen for creating or editing a product.
///
/// Role-based behavior:
/// - Admin: Full edit access including price, cost, SKU, and all fields.
/// - Staff: Can edit all fields EXCEPT price, cost, and costCode.
///          The price/cost fields are visible but disabled.
/// - Cashier: Should not reach this screen (no edit permission).
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
    final userRole = currentUser?.role ?? UserRole.cashier;
    final inventoryState = ref.watch(inventoryStateProvider);

    // Determine edit capabilities based on role
    final bool canEditPrice = userRole == UserRole.admin;
    final bool canEditCost = userRole == UserRole.admin;
    final bool canViewCost = userRole == UserRole.admin;
    final bool canEditSku =
        !widget.isEditing; // SKU never editable after creation
    final bool canSelectSupplier = userRole == UserRole.admin;
    // Cost is hidden by default. Admin reveals it via the AppBar toggle
    // (password-confirmed). On create, the field is always shown because
    // the admin needs to enter a cost value.
    final bool showCostField =
        canViewCost && (!widget.isEditing || inventoryState.showCost);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.inventory),
        ),
        actions: [
          if (canViewCost && widget.isEditing)
            CostDisplayToggle(
              showCost: inventoryState.showCost,
              onToggle: (show) {
                ref
                    .read(inventoryStateProvider.notifier)
                    .toggleCostVisibility(show);
              },
            ),
        ],
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
                    // Role info banner for staff — outlined info pill
                    if (userRole == UserRole.staff && widget.isEditing)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.sm + 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.info),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.info_circle,
                              color: AppColors.infoDark,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'You can edit product details except price and cost fields.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.infoDark),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SKU
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU *',
                        prefixIcon: Icon(CupertinoIcons.qrcode),
                      ),
                      enabled: canEditSku,
                      validator: (value) =>
                          value?.isEmpty == true ? 'SKU is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        prefixIcon: Icon(CupertinoIcons.cube_box),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Price - disabled for staff
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText:
                            'Selling Price (${AppConstants.currencySymbol}) *',
                        prefixIcon: const Icon(CupertinoIcons.tag),
                        helperText:
                            canEditPrice ? null : 'Only admin can change price',
                        helperStyle: const TextStyle(
                          color: AppColors.warningDark,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: canEditPrice,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Price is required';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Cost - admin only. On create the field is shown so a
                    // cost can be entered; on edit it's hidden by default and
                    // revealed via the AppBar toggle.
                    if (showCostField)
                      Column(
                        children: [
                          TextFormField(
                            controller: _costController,
                            decoration: InputDecoration(
                              labelText:
                                  'Cost (${AppConstants.currencySymbol}) *',
                              prefixIcon: const Icon(AppIcons.peso),
                                  ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            enabled: canEditCost,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Cost is required';
                              }
                              final cost = double.tryParse(value);
                              if (cost == null || cost < 0) {
                                return 'Enter a valid cost';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Quantity
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Initial Quantity *',
                        prefixIcon: Icon(CupertinoIcons.number),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Quantity is required';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty < 0) {
                          return 'Enter a valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Reorder Level
                    TextFormField(
                      controller: _reorderLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
                        prefixIcon: Icon(CupertinoIcons.exclamationmark_triangle),
                        helperText: 'Alert when stock falls below this level',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Unit
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        prefixIcon: Icon(Icons.straighten),
                        hintText: 'e.g., pcs, kg, box',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Barcode
                    TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        prefixIcon: Icon(CupertinoIcons.barcode_viewfinder),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(CupertinoIcons.square_grid_2x2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Supplier - admin only can change supplier
                    if (canSelectSupplier)
                      suppliersAsync.when(
                        data: (suppliers) => DropdownButtonFormField<String>(
                          value: _selectedSupplierId,
                          decoration: const InputDecoration(
                            labelText: 'Supplier',
                            prefixIcon: Icon(CupertinoIcons.briefcase),
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
                        error: (_, __) =>
                            const Text('Could not load suppliers'),
                      ),

                    // Show supplier as read-only for staff
                    if (!canSelectSupplier &&
                        _existingProduct?.supplierName != null)
                      TextFormField(
                        initialValue: _existingProduct?.supplierName ?? 'None',
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          prefixIcon: Icon(CupertinoIcons.briefcase),
                          ),
                        enabled: false,
                      ),

                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(CupertinoIcons.list_bullet),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _handleSubmit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(CupertinoIcons.tray_arrow_down),
                        label: Text(widget.isEditing
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

      final userRole = currentUser.role;

      if (widget.isEditing && _existingProduct != null) {
        // ==================== UPDATE LOGIC ====================
        if (userRole == UserRole.admin) {
          // Admin: full update including price and cost
          final costValue = double.tryParse(_costController.text) ?? 0.0;
          final costCode = ref.read(encodeCostProvider(costValue));

          String? supplierName;
          if (_selectedSupplierId != null) {
            final suppliers = ref.read(suppliersProvider).value;
            supplierName = suppliers
                ?.where((s) => s.id == _selectedSupplierId)
                .firstOrNull
                ?.name;
          }

          final product = _existingProduct!.copyWith(
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
          final result = await productOps.updateProduct(
            actor: currentUser,
            product: product,
          );
          if (result == null) throw Exception('Failed to update product');
        } else if (userRole == UserRole.staff) {
          // Staff: update everything EXCEPT price, cost, costCode, supplierId
          // Keep original price, cost, costCode, and supplier
          final product = _existingProduct!.copyWith(
            name: _nameController.text.trim(),
            // Preserve original price, cost, costCode
            price: _existingProduct!.price,
            cost: _existingProduct!.cost,
            costCode: _existingProduct!.costCode,
            quantity: int.tryParse(_quantityController.text) ?? 0,
            reorderLevel: int.tryParse(_reorderLevelController.text) ?? 10,
            unit: _unitController.text.trim().isEmpty
                ? 'pcs'
                : _unitController.text.trim(),
            // Preserve original supplier
            supplierId: _existingProduct!.supplierId,
            supplierName: _existingProduct!.supplierName,
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
          final result = await productOps.updateProduct(
            actor: currentUser,
            product: product,
          );
          if (result == null) throw Exception('Failed to update product');
        }
      } else {
        // ==================== CREATE LOGIC (ADMIN ONLY) ====================
        final costValue = double.tryParse(_costController.text) ?? 0.0;
        final costCode = ref.read(encodeCostProvider(costValue));

        String? supplierName;
        if (_selectedSupplierId != null) {
          final suppliers = ref.read(suppliersProvider).value;
          supplierName = suppliers
              ?.where((s) => s.id == _selectedSupplierId)
              .firstOrNull
              ?.name;
        }

        final product = ProductEntity(
          id: '',
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
          createdAt: DateTime.now(),
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
        final result = await productOps.createProduct(
          actor: currentUser,
          product: product,
        );
        if (result == null) throw Exception('Failed to create product');
      }

      if (mounted) {
        ref.invalidate(productsProvider);
        context.showSuccessSnackBar(
          widget.isEditing
              ? 'Product updated successfully'
              : 'Product created successfully',
        );
        context.goBackOr(RoutePaths.inventory);
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
