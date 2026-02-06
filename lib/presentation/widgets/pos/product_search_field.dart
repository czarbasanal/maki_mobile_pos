import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSearchChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSearchChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = widget.controller.text.trim();
    setState(() {
      _showResults = query.isNotEmpty && widget.focusNode.hasFocus;
    });

    if (_showResults) {
      _showOverlay();
    } else {
      _removeOverlay();
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
      builder: (context) => Positioned(
        width: context.findRenderObject() != null
            ? (context.findRenderObject() as RenderBox).size.width
            : 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: _buildSearchResults(),
          ),
        ),
      ),
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
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    widget.focusNode.requestFocus();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Scan barcode',
                onPressed: _openBarcodeScanner,
              ),
            ],
          ),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
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
    final query = widget.controller.text.trim();

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final searchResults = ref.watch(productSearchProvider(query));

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

          return ListView.builder(
            shrinkWrap: true,
            itemCount: products.length > 10 ? 10 : products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.isOutOfStock
                      ? Colors.red[100]
                      : product.isLowStock
                          ? Colors.orange[100]
                          : Colors.green[100],
                  child: Text(
                    product.name[0].toUpperCase(),
                    style: TextStyle(
                      color: product.isOutOfStock
                          ? Colors.red[700]
                          : product.isLowStock
                              ? Colors.orange[700]
                              : Colors.green[700],
                    ),
                  ),
                ),
                title: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${product.sku} • ₱${product.price.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Stock: ${product.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: product.isOutOfStock
                            ? Colors.red
                            : product.isLowStock
                                ? Colors.orange
                                : Colors.grey[600],
                        fontWeight: product.isLowStock || product.isOutOfStock
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
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
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
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
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Scan or type barcode...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
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
