import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Search field for finding products by name, SKU, or barcode.
class ProductSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<ProductEntity> onProductSelected;
  final ValueChanged<String> onBarcodeScanned;

  const ProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onProductSelected,
    required this.onBarcodeScanned,
  });

  @override
  ConsumerState<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
  bool _showResults = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSearchChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onSearchChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = widget.controller.text.trim();

    if (query.isEmpty) {
      _debounceTimer?.cancel();
      setState(() {
        _showResults = false;
        _debouncedQuery = '';
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _showResults = widget.focusNode.hasFocus;
    });

    // Debounce the search query to avoid excessive rebuilds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _debouncedQuery = query;
        });
        if (_showResults) {
          _showOverlay();
        }
      }
    });

    // Show overlay immediately (with previous results or loading)
    if (_showResults) {
      _showOverlay();
    }
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      // Delay to allow tap on result
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    } else if (widget.controller.text.isNotEmpty) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final hairline =
            isDark ? AppColors.darkHairline : AppColors.lightHairline;
        return Positioned(
          width: context.findRenderObject() != null
              ? (context.findRenderObject() as RenderBox).size.width
              : 300,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 60),
            child: Material(
              elevation: 0,
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildSearchResults(),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: 'Search products or scan barcode...',
          prefixIcon: const Icon(CupertinoIcons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: () {
                    widget.controller.clear();
                    widget.focusNode.requestFocus();
                  },
                ),
              IconButton(
                icon: const Icon(CupertinoIcons.qrcode_viewfinder),
                tooltip: 'Scan barcode',
                onPressed: _openBarcodeScanner,
              ),
            ],
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          // Treat as barcode scan if it looks like a SKU
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            widget.onBarcodeScanned(trimmed);
          }
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_debouncedQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    final searchResults = ref.watch(localProductSearchProvider(_debouncedQuery));

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: searchResults.when(
        data: (products) {
          if (products.isEmpty) {
            return const ListTile(
              leading: Icon(Icons.search_off),
              title: Text('No products found'),
            );
          }

          final theme = Theme.of(context);
          final muted = theme.colorScheme.onSurfaceVariant;
          return ListView.builder(
            shrinkWrap: true,
            itemCount: products.length > 10 ? 10 : products.length,
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
                  '${product.sku} • ₱${product.price.toStringAsFixed(2)}',
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
                enabled: !product.isOutOfStock,
                onTap: product.isOutOfStock
                    ? null
                    : () {
                        widget.onProductSelected(product);
                        _removeOverlay();
                      },
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ListTile(
          leading: const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: AppColors.error,
          ),
          title: Text('Error: $error'),
        ),
      ),
    );
  }

  void _openBarcodeScanner() async {
    // TODO: Implement barcode scanning with a package like mobile_scanner
    // For now, show a dialog to manually enter barcode
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Barcode/SKU'),
          // Scroll the content so the soft keyboard never makes the
          // dialog overflow when its max height shrinks.
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Scan or type barcode...',
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (barcode != null && barcode.isNotEmpty) {
      widget.onBarcodeScanned(barcode);
    }
  }
}
