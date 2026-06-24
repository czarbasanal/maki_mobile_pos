import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'dart:typed_data';

import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/inventory_widgets.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_image_uploader.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/services/product_image_storage_service.dart';

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
  final _costCodeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _unitController = TextEditingController();
  // Pending text for a *new* barcode; the committed list lives in
  // [_barcodes]. Empty after each add.
  final _barcodeInputController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();

  // Focus node on the product name field — when auto-SKU is on, the SKU
  // re-rolls each time this loses focus so the prefix tracks the typed name
  // without flickering on every keystroke.
  final _nameFocusNode = FocusNode();

  String? _selectedSupplierId;
  // Mapped scan codes for this product. Edited via the chip input below;
  // a fresh string typed into [_barcodeInputController] is committed via
  // [_addBarcodeFromInput].
  final List<String> _barcodes = [];
  // Inline validation message rendered under the chip input.
  String? _barcodeError;
  bool _isLoading = false;
  bool _isSaving = false;
  // SKU auto-generation: default ON for new products. Hidden / inert on edit
  // since the existing SKU is locked once a product has sale/receiving refs.
  bool _autoGenerateSku = true;
  ProductEntity? _existingProduct;

  // Image-upload state. Bytes are held in-memory so the user can cancel
  // the form without burning a Storage write; the actual upload happens
  // in _handleSubmit on save.
  Uint8List? _pendingImageBytes;
  bool _imageMarkedForRemoval = false;

  @override
  void initState() {
    super.initState();
    _reorderLevelController.text = '${AppConstants.defaultReorderLevel}';
    _unitController.text = 'pcs';

    // Keep the live margin recap (under the Pricing pair) in sync as the
    // price/cost fields are edited.
    _priceController.addListener(_onPriceOrCostChanged);
    _costController.addListener(_onPriceOrCostChanged);

    if (widget.productId != null) {
      _loadProduct();
    } else {
      // Seed an initial auto-generated SKU so the field isn't blank on first
      // paint. Re-rolls when the name field blurs and on the explicit refresh.
      _skuController.text = SkuGenerator.generateForName(null);
      _nameFocusNode.addListener(_onNameFocusChange);
    }
  }

  void _onPriceOrCostChanged() {
    if (mounted) setState(() {});
  }

  // ---- Bundle 04 layout helpers (sectioned cards + pinned submit) ----

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, top: 18, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _sectionCard({required List<Widget> children}) => AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  /// Info-tinted banner stating a role's edit limits.
  Widget _roleBanner(String text) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: AppColors.infoDark, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.infoDark),
              ),
            ),
          ],
        ),
      );

  /// Dims + blocks a field for roles that can't edit it (cashier). Gentler
  /// than the old 0.38 opacity; the role banner states the reason.
  Widget _lockable(bool locked, Widget child) => locked
      ? Opacity(opacity: 0.6, child: AbsorbPointer(child: child))
      : child;

  Widget _priceField(bool canEditPrice) => TextFormField(
        key: const Key('product-price-field'),
        controller: _priceController,
        decoration: InputDecoration(
          labelText: 'Selling (${AppConstants.currencySymbol}) *',
          prefixIcon: const Icon(LucideIcons.tag),
          helperText: canEditPrice ? null : 'Only admin can change price',
          helperStyle: const TextStyle(
            color: AppColors.warningDark,
            fontStyle: FontStyle.italic,
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: canEditPrice,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Price is required';
          final price = double.tryParse(value);
          if (price == null || price < 0) return 'Enter a valid price';
          return null;
        },
      );

  Widget _costField(bool canEditCost) => TextFormField(
        key: const Key('product-cost-field'),
        controller: _costController,
        decoration: InputDecoration(
          labelText: 'Cost (${AppConstants.currencySymbol}) *',
          prefixIcon: const Icon(AppIcons.peso),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: canEditCost,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Cost is required';
          final cost = double.tryParse(value);
          if (cost == null || cost < 0) return 'Enter a valid cost';
          return null;
        },
      );

  Widget _costCodeField() => TextFormField(
        controller: _costCodeController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Cost Code *',
          prefixIcon: Icon(LucideIcons.lock),
          helperText: 'Enter the product cost code',
        ),
        validator: (value) {
          final code = value?.trim() ?? '';
          if (code.isEmpty) return 'Cost code is required';
          if (!ref.read(isValidCodeProvider(code))) return 'Invalid cost code';
          return null;
        },
      );

  Widget _quantityField(bool isNameOnly) => TextFormField(
        controller: _quantityController,
        enabled: !isNameOnly,
        decoration: const InputDecoration(
          labelText: 'Quantity *',
          prefixIcon: Icon(LucideIcons.hash),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Quantity is required';
          final qty = int.tryParse(value);
          if (qty == null || qty < 0) return 'Enter a valid quantity';
          return null;
        },
      );

  Widget _reorderField(bool isNameOnly) => TextFormField(
        controller: _reorderLevelController,
        enabled: !isNameOnly,
        decoration: const InputDecoration(
          labelText: 'Reorder at',
          prefixIcon: Icon(LucideIcons.alertTriangle),
          helperText: 'Alert when stock falls below this level',
        ),
        keyboardType: TextInputType.number,
      );

  Widget _supplierField(AsyncValue<List<SupplierEntity>> suppliersAsync) =>
      suppliersAsync.when(
        data: (suppliers) {
          final items = <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No supplier'),
            ),
            ...suppliers.map(
              (s) => DropdownMenuItem<String>(
                value: s.id,
                child: Text(s.name),
              ),
            ),
          ];
          final selected = _selectedSupplierId;
          final safe =
              items.any((i) => i.value == selected) ? selected : null;
          return AppDropdown<String>(
            initialValue: safe,
            key: ValueKey('supplier:$safe:${suppliers.length}'),
            decoration: const InputDecoration(
              labelText: 'Supplier',
              prefixIcon: Icon(LucideIcons.briefcase),
            ),
            items: items,
            onChanged: (value) {
              setState(() => _selectedSupplierId = value);
            },
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const Text('Could not load suppliers'),
      );

  /// Live margin recap shown under the Pricing pair (only when both > 0 and
  /// cost ≤ price). "Margin 28% · ₱70.00 per unit" — the % bold-green.
  Widget _marginLine() {
    final price = double.tryParse(_priceController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0;
    if (price <= 0 || cost <= 0 || cost > price) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final green = AppColors.successText(isDark);
    final muted = theme.colorScheme.onSurfaceVariant;
    final pct = ((price - cost) / price * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2),
      child: Row(
        children: [
          Icon(LucideIcons.trendingUp, size: 15, color: green),
          const SizedBox(width: 6),
          Text('Margin ', style: TextStyle(fontSize: 12, color: muted)),
          Text('$pct%',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: green)),
          Text(' · ${(price - cost).toCurrency()} per unit',
              style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }

  /// Pinned bottom submit bar (mirrors the sale-detail footer).
  Widget _buildSubmitFooter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: DecoratedBox(
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
              key: const Key('product-form-submit'),
              onPressed: _isSaving ? null : _handleSubmit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.save, size: 18),
              label: Text(widget.isEditing ? 'Update Product' : 'Add Product'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onNameFocusChange() {
    if (_nameFocusNode.hasFocus) return;
    if (!_autoGenerateSku) return;
    setState(() {
      _skuController.text =
          SkuGenerator.generateForName(_nameController.text);
    });
  }

  /// Re-rolls the SKU using the current product name. No-op when
  /// [_autoGenerateSku] is off — manual mode is the user's text verbatim.
  void _regenerateSku() {
    if (!_autoGenerateSku) return;
    setState(() {
      _skuController.text =
          SkuGenerator.generateForName(_nameController.text);
    });
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
        _unitController.text = product.unit;
        _barcodes
          ..clear()
          ..addAll(product.barcodes);
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
    _costCodeController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    _unitController.dispose();
    _barcodeInputController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final userRole = currentUser?.role ?? UserRole.cashier;
    final inventoryState = ref.watch(inventoryStateProvider);

    // Determine edit capabilities based on role
    final bool isCreating = !widget.isEditing;
    // Staff may set the price only while creating (not when editing existing).
    final bool canEditPrice = userRole == UserRole.admin ||
        (userRole == UserRole.staff && isCreating);
    final bool canEditCost = userRole == UserRole.admin;
    final bool canViewCost = userRole == UserRole.admin;
    // Admin may edit the SKU of an existing product; anyone who can create may
    // set it at create time. Staff/cashier keep the SKU locked once a product
    // exists.
    final bool canEditSku = isCreating || userRole == UserRole.admin;
    // The Auto/Manual generator is a create-time convenience only; on edit the
    // admin types the SKU directly.
    final bool skuFieldEnabled = isCreating
        ? (canEditSku && !_autoGenerateSku)
        : (userRole == UserRole.admin);
    final bool canSelectSupplier = userRole == UserRole.admin;
    // Cashier can reach the edit form but may only change the product name.
    final bool isNameOnly = userRole == UserRole.cashier;
    // Staff create products by entering a cost CODE; the numeric cost field
    // stays admin-only and is decoded to cost in CreateProductUseCase.
    final bool showCostCodeField = userRole == UserRole.staff && isCreating;
    // Cost is hidden by default. Admin reveals it via the AppBar toggle
    // (password-confirmed). On create, the field is always shown because
    // the admin needs to enter a cost value.
    final bool showCostField =
        canViewCost && (!widget.isEditing || inventoryState.showCost);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
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
          if (widget.isEditing &&
              _existingProduct != null &&
              userRole == UserRole.admin)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(
                LucideIcons.trash2,
                color: AppColors.error,
              ),
              onPressed: _isSaving ? null : _confirmDelete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userRole == UserRole.staff && widget.isEditing)
                            _roleBanner(
                                'You can edit product details except price and cost fields.'),
                          if (isNameOnly && widget.isEditing)
                            _roleBanner(
                                'You can edit the product name and image.'),

                          // Product image — bytes held in memory, uploaded on save.
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: ProductImageUploader(
                              existingUrl: _imageMarkedForRemoval
                                  ? null
                                  : _existingProduct?.imageUrl,
                              pendingBytes: _pendingImageBytes,
                              enabled: userRole == UserRole.admin ||
                                  isNameOnly ||
                                  (userRole == UserRole.staff && isCreating),
                              onChanged: (bytes, {required removed}) {
                                setState(() {
                                  if (removed) {
                                    _pendingImageBytes = null;
                                    _imageMarkedForRemoval = true;
                                  } else {
                                    _pendingImageBytes = bytes;
                                    _imageMarkedForRemoval = false;
                                  }
                                });
                              },
                            ),
                          ),

                          _sectionHeader('IDENTITY'),
                          _sectionCard(children: [
                            if (isCreating)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('Auto-generate SKU'),
                                subtitle: Text(
                                  _autoGenerateSku
                                      ? 'Built from category + random suffix'
                                      : 'Type the SKU manually',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                value: _autoGenerateSku,
                                onChanged: (v) {
                                  setState(() {
                                    _autoGenerateSku = v;
                                    if (v) {
                                      _skuController.text =
                                          SkuGenerator.generateForName(
                                        _nameController.text,
                                      );
                                    }
                                  });
                                },
                              ),
                            TextFormField(
                              key: const Key('product-sku-field'),
                              controller: _skuController,
                              decoration: InputDecoration(
                                labelText: 'SKU *',
                                prefixIcon: const Icon(LucideIcons.qrCode),
                                helperText:
                                    (!isCreating && userRole == UserRole.admin)
                                        ? 'Changing the SKU keeps past sales & '
                                            'receiving history intact.'
                                        : null,
                                suffixIcon: (isCreating && _autoGenerateSku)
                                    ? IconButton(
                                        tooltip: 'Regenerate',
                                        icon: const Icon(LucideIcons.refreshCw),
                                        onPressed: _regenerateSku,
                                      )
                                    : null,
                              ),
                              enabled: skuFieldEnabled,
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'SKU is required';
                                if (!SkuGenerator.isValidSku(v)) {
                                  return 'Use only letters, numbers, and hyphens (max 50)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              decoration: const InputDecoration(
                                labelText: 'Product Name *',
                                prefixIcon: Icon(LucideIcons.box),
                              ),
                              validator: (value) => value?.isEmpty == true
                                  ? 'Name is required'
                                  : null,
                            ),
                          ]),

                          _sectionHeader('PRICING'),
                          _sectionCard(children: [
                            if (showCostField)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _priceField(canEditPrice)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _costField(canEditCost)),
                                ],
                              )
                            else
                              _priceField(canEditPrice),
                            if (showCostCodeField) ...[
                              const SizedBox(height: 14),
                              _costCodeField(),
                            ],
                            if (showCostField) _marginLine(),
                          ]),

                          _sectionHeader('STOCK'),
                          _sectionCard(children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _quantityField(isNameOnly)),
                                const SizedBox(width: 10),
                                Expanded(child: _reorderField(isNameOnly)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _lockable(
                              isNameOnly,
                              _AdminListDropdownField(
                                kind: CategoryKind.unit,
                                controller: _unitController,
                                label: 'Unit',
                                icon: LucideIcons.ruler,
                                onChanged: (value) {
                                  setState(() {
                                    _unitController.text = value ?? '';
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildBarcodesField(enabled: !isNameOnly),
                          ]),

                          _sectionHeader('CLASSIFICATION'),
                          _sectionCard(children: [
                            _lockable(
                              isNameOnly,
                              _AdminListDropdownField(
                                kind: CategoryKind.product,
                                controller: _categoryController,
                                label: 'Category',
                                icon: LucideIcons.layoutGrid,
                                includeNoneOption: true,
                                onChanged: (value) {
                                  setState(() {
                                    _categoryController.text = value ?? '';
                                  });
                                },
                              ),
                            ),
                            if (canSelectSupplier) ...[
                              const SizedBox(height: 14),
                              _supplierField(suppliersAsync),
                            ],
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _notesController,
                              enabled: !isNameOnly,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                prefixIcon: Icon(LucideIcons.list),
                              ),
                              maxLines: 3,
                            ),
                          ]),

                          if (widget.isEditing && _existingProduct != null) ...[
                            _sectionHeader('AUDIT'),
                            _AuditInfoCard(product: _existingProduct!),
                          ],

                          // Price history is admin-only data; show the link for
                          // any admin editing a product (no longer gated behind
                          // the cost-eye toggle).
                          if (canViewCost && widget.isEditing) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                '/inventory/${widget.productId}/price-history',
                              ),
                              icon: const Icon(LucideIcons.clock),
                              label: const Text('View price history'),
                            ),
                          ],

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildSubmitFooter(context),
              ],
            ),
    );
  }

  /// Renders the existing barcodes as deletable chips plus a single
  /// text field for adding a new code. Add fires on the suffix button
  /// or on keyboard submit; duplicates within this product are
  /// rejected inline (cross-product duplicates are caught by the
  /// repository on save).
  Widget _buildBarcodesField({bool enabled = true}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Barcodes',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_barcodes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final code in _barcodes)
                InputChip(
                  label: Text(code),
                  onDeleted: enabled
                      ? () {
                          setState(() {
                            _barcodes.remove(code);
                            _barcodeError = null;
                          });
                        }
                      : null,
                ),
            ],
          ),
        ],
        if (enabled) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _barcodeInputController,
            decoration: InputDecoration(
              labelText: 'Add barcode',
              hintText: 'e.g. 4806504801108',
              prefixIcon: const Icon(LucideIcons.scanLine),
              errorText: _barcodeError,
              suffixIcon: IconButton(
                tooltip: 'Add',
                icon: const Icon(LucideIcons.plus),
                onPressed: _addBarcodeFromInput,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addBarcodeFromInput(),
          ),
        ],
      ],
    );
  }

  void _addBarcodeFromInput() {
    final raw = _barcodeInputController.text.trim();
    if (raw.isEmpty) {
      setState(() => _barcodeError = null);
      return;
    }
    if (_barcodes.contains(raw)) {
      setState(() => _barcodeError = 'Already added');
      return;
    }
    setState(() {
      _barcodes.add(raw);
      _barcodeInputController.clear();
      _barcodeError = null;
    });
  }

  /// Confirms a consequential SKU change before saving. Returns true when the
  /// admin chooses to proceed.
  Future<bool?> _confirmSkuChange({
    required String oldSku,
    required String newSku,
    required int variationCount,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change SKU?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$oldSku  →  $newSku',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '• Past sales and receiving records keep their original SKU.',
            ),
            const Text('• The old SKU stays scannable (added to barcodes).'),
            if (variationCount > 0)
              Text(
                '• $variationCount linked variation(s) will be re-pointed to '
                'the new SKU.',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change SKU'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final product = _existingProduct;
    if (product == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Delete "${product.name}"? This product will be hidden from POS '
          'and inventory lists. Past sales and receivings that reference '
          'it remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    setState(() => _isSaving = true);
    final ok = await ref
        .read(productOperationsProvider.notifier)
        .deactivateProduct(actor: currentUser, productId: product.id);

    if (!mounted) return;
    if (ok) {
      ref.invalidate(productsProvider);
      context.showSuccessSnackBar('Product deleted');
      context.goBackOr(RoutePaths.inventory);
    } else {
      setState(() => _isSaving = false);
      context.showErrorSnackBar('Failed to delete product');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Commit any pending text in the "Add barcode" input so the user
    // doesn't silently lose a barcode they typed but didn't tap Add for.
    final pendingBarcode = _barcodeInputController.text.trim();
    if (pendingBarcode.isNotEmpty && !_barcodes.contains(pendingBarcode)) {
      _barcodes.add(pendingBarcode);
      _barcodeInputController.clear();
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      final userRole = currentUser.role;

      if (widget.isEditing && _existingProduct != null) {
        // ==================== UPDATE LOGIC ====================
        if (userRole == UserRole.admin) {
          // Admin: full update including price and cost

          // A SKU change is consequential — confirm it (and surface how many
          // variation links will be re-pointed) before saving.
          final newSku = _skuController.text.trim();
          final skuChanged = newSku != _existingProduct!.sku;
          if (skuChanged) {
            final childCount = await ref
                .read(productVariationChildrenCountProvider(
                        _existingProduct!.sku)
                    .future)
                .catchError((_) => 0);
            if (!mounted) return;
            final confirmed = await _confirmSkuChange(
              oldSku: _existingProduct!.sku,
              newSku: newSku,
              variationCount: childCount,
            );
            // Returning here triggers the `finally` block, which resets the
            // saving spinner.
            if (confirmed != true) return;
          }

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

          // Resolve the new imageUrl ahead of the single update call so
          // we don't write twice. Order matters: upload first, then
          // delete-existing only if upload succeeded.
          String? newImageUrl;
          var clearImage = false;
          if (_pendingImageBytes != null) {
            try {
              final storage = ref.read(productImageStorageServiceProvider);
              newImageUrl = await storage.upload(
                productId: _existingProduct!.id,
                bytes: _pendingImageBytes!,
              );
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Image upload failed — product saved without image.',
                    ),
                  ),
                );
              }
            }
          } else if (_imageMarkedForRemoval) {
            final storage =
                ref.read(productImageStorageServiceProvider);
            await storage.delete(productId: _existingProduct!.id);
            clearImage = true;
          }

          final product = _existingProduct!.copyWith(
            sku: newSku,
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
            barcodes: List<String>.from(_barcodes),
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            imageUrl: newImageUrl,
            clearImageUrl: clearImage,
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
            barcodes: List<String>.from(_barcodes),
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
        } else if (userRole == UserRole.cashier) {
          // Cashier: update name and image. All other fields preserved.
          String? newImageUrl;
          var clearImage = false;
          if (_pendingImageBytes != null) {
            try {
              final storage = ref.read(productImageStorageServiceProvider);
              newImageUrl = await storage.upload(
                productId: _existingProduct!.id,
                bytes: _pendingImageBytes!,
              );
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Image upload failed — product saved without image.',
                    ),
                  ),
                );
              }
            }
          } else if (_imageMarkedForRemoval) {
            final storage = ref.read(productImageStorageServiceProvider);
            await storage.delete(productId: _existingProduct!.id);
            clearImage = true;
          }

          final product = _existingProduct!.copyWith(
            name: _nameController.text.trim(),
            price: _existingProduct!.price,
            cost: _existingProduct!.cost,
            costCode: _existingProduct!.costCode,
            quantity: _existingProduct!.quantity,
            reorderLevel: _existingProduct!.reorderLevel,
            unit: _existingProduct!.unit,
            supplierId: _existingProduct!.supplierId,
            supplierName: _existingProduct!.supplierName,
            barcodes: List<String>.from(_existingProduct!.barcodes),
            category: _existingProduct!.category,
            notes: _existingProduct!.notes,
            imageUrl: newImageUrl,
            clearImageUrl: clearImage,
          );
          final productOps = ref.read(productOperationsProvider.notifier);
          final result = await productOps.updateProduct(
            actor: currentUser,
            product: product,
          );
          if (result == null) throw Exception('Failed to update product');
        }
      } else if (userRole == UserRole.staff) {
        // ==================== STAFF CREATE (cost via code) ====================
        // Staff enter a cost CODE; decode it to the real cost here. The
        // numeric value is never shown in the UI. The form validator already
        // rejected invalid codes, so decode is non-null in practice.
        final code = _costCodeController.text.trim();
        final decodedCost = ref.read(decodeCostProvider(code)) ?? 0.0;
        final product = ProductEntity(
          id: '',
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          costCode: code,
          cost: decodedCost,
          price: double.tryParse(_priceController.text) ?? 0.0,
          quantity: int.tryParse(_quantityController.text) ?? 0,
          reorderLevel: int.tryParse(_reorderLevelController.text) ?? 10,
          unit: _unitController.text.trim().isEmpty
              ? 'pcs'
              : _unitController.text.trim(),
          supplierId: null,
          supplierName: null,
          isActive: true,
          createdAt: DateTime.now(),
          barcodes: List<String>.from(_barcodes),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        final productOps = ref.read(productOperationsProvider.notifier);
        final created = await productOps.createProduct(
          actor: currentUser,
          product: product,
        );
        if (created == null) throw Exception('Failed to create product');

        if (_pendingImageBytes != null) {
          try {
            final storage = ref.read(productImageStorageServiceProvider);
            final url = await storage.upload(
              productId: created.id,
              bytes: _pendingImageBytes!,
            );
            await productOps.updateProduct(
              actor: currentUser,
              product: created.copyWith(imageUrl: url),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Image upload failed — product saved without image.',
                  ),
                ),
              );
            }
          }
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
          barcodes: List<String>.from(_barcodes),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        final productOps = ref.read(productOperationsProvider.notifier);
        final created = await productOps.createProduct(
          actor: currentUser,
          product: product,
        );
        if (created == null) throw Exception('Failed to create product');

        // If the user picked an image, upload it now (we needed the id
        // first) and update the product with the resolved URL.
        if (_pendingImageBytes != null) {
          try {
            final storage = ref.read(productImageStorageServiceProvider);
            final url = await storage.upload(
              productId: created.id,
              bytes: _pendingImageBytes!,
            );
            await productOps.updateProduct(
              actor: currentUser,
              product: created.copyWith(imageUrl: url),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Image upload failed — product saved without image.',
                  ),
                ),
              );
            }
          }
        }
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

/// Audit-info block shown on the edit-product form. Lists who created and
/// last updated the product, with timestamps. Resolves user IDs to display
/// names via [userByIdProvider]; falls back to the raw UID if the user
/// can't be fetched and to a dash when the field is missing.
class _AuditInfoCard extends ConsumerWidget {
  const _AuditInfoCard({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    // Clean AppCard (the section's "AUDIT" header supplies the heading) —
    // soft shadow / dark hairline, no inner title or border.
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Created', dateFormat.format(product.createdAt)),
          _userRow(
            ref,
            theme,
            muted,
            'Created by',
            product.createdBy,
            denormalisedName: product.createdByName,
          ),
          if (product.updatedAt != null)
            _row(context, 'Last updated',
                dateFormat.format(product.updatedAt!)),
          _userRow(
            ref,
            theme,
            muted,
            'Updated by',
            product.updatedBy,
            denormalisedName: product.updatedByName,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userRow(
    WidgetRef ref,
    ThemeData theme,
    Color muted,
    String label,
    String? userId, {
    String? denormalisedName,
  }) {
    // Prefer the denormalised name persisted on the product doc — non-admin
    // viewers can't read other users' docs (firestore.rules), so the
    // userByIdProvider lookup falls back to the raw UID for them. The
    // denormalised name is set at write time and visible to everyone.
    if (denormalisedName != null && denormalisedName.isNotEmpty) {
      return _row(ref.context, label, denormalisedName);
    }
    if (userId == null || userId.isEmpty) {
      return _row(ref.context, label, '—');
    }
    final userAsync = ref.watch(userByIdProvider(userId));
    final value = userAsync.when(
      data: (user) {
        final name = user?.displayName.trim();
        return (name != null && name.isNotEmpty) ? name : '—';
      },
      loading: () => '—',
      // Firestore rules deny non-admin reads of other users' docs — show
      // dash rather than a meaningless UID.
      error: (_, __) => '—',
    );
    return _row(ref.context, label, value);
  }
}

/// Dropdown bound to a [TextEditingController] holding an admin-managed
/// list value (product category, unit, …).
///
/// Items = active entries from [kind] ∪ {controller's current value if
/// not in the active list, shown as "(inactive)"}. When [includeNoneOption]
/// is true (e.g. category is optional), an empty selection emits null;
/// when false (e.g. unit is required), there's no null option.
///
/// The widget reads the controller text directly so the surrounding form's
/// save logic — which still reads `controller.text` — keeps working
/// unchanged when we swap a free-text field for this dropdown.
class _AdminListDropdownField extends ConsumerWidget {
  const _AdminListDropdownField({
    required this.kind,
    required this.controller,
    required this.onChanged,
    required this.label,
    required this.icon,
    this.includeNoneOption = false,
  });

  final CategoryKind kind;
  final TextEditingController controller;
  final ValueChanged<String?> onChanged;
  final String label;
  final IconData icon;
  final bool includeNoneOption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(activeCategoriesProvider(kind));

    return entriesAsync.when(
      data: (entries) {
        final current = controller.text.trim();
        final activeNames =
            entries.map((c) => c.name).toSet().toList(); // de-dupe
        final isOrphan = current.isNotEmpty && !activeNames.contains(current);

        // Build the items list first so we can validate that `value` matches
        // exactly one item — Flutter's Dropdown asserts this and crashes
        // otherwise. If it doesn't match, fall back to null (no selection).
        final items = <DropdownMenuItem<String>>[
          if (includeNoneOption)
            const DropdownMenuItem<String>(
              value: null,
              child: Text('(none)'),
            ),
          ...activeNames.map(
            (name) => DropdownMenuItem<String>(
              value: name,
              child: Text(name),
            ),
          ),
          if (isOrphan)
            DropdownMenuItem<String>(
              value: current,
              child: Text(
                '$current (inactive)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ];

        final candidate = current.isEmpty ? null : current;
        final matches = items.where((i) => i.value == candidate).length;
        final safeValue = matches == 1 ? candidate : null;

        return AppDropdown<String>(
          initialValue: safeValue,
          key: ValueKey('${kind.name}:$safeValue:${activeNames.length}'),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
          items: items,
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => Text('Could not load ${kind.pluralLabel}'),
    );
  }
}
