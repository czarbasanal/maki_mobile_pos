import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/barcode_scanner_screen.dart';
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
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: isDark ? Border.all(color: hairline) : null,
                boxShadow: AppShadows.card(dark: isDark),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return CompositedTransformTarget(
      link: _layerLink,
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 20, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                decoration: const InputDecoration(
                  hintText: 'Search products or scan barcode...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
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
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: muted),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  widget.controller.clear();
                  widget.focusNode.requestFocus();
                },
              ),
            const SizedBox(width: 4),
            // Filled scan button — slate (light) / gold (dark).
            GestureDetector(
              onTap: _openBarcodeScanner,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  LucideIcons.scanLine,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
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
            return ListTile(
              leading: Icon(
                LucideIcons.searchX,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: const Text('No products found'),
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
                  '${product.sku} • ${AppConstants.currencySymbol}'
                  '${product.price.toStringAsFixed(2)}',
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
            LucideIcons.alertTriangle,
            color: AppColors.error,
          ),
          title: Text('Error: $error'),
        ),
      ),
    );
  }

  void _openBarcodeScanner() async {
    // Drop the keyboard before pushing the scanner — if the search field
    // is focused, the soft keyboard would otherwise overlap the preview
    // on its way out.
    widget.focusNode.unfocus();

    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (!mounted) return;
    if (barcode != null && barcode.isNotEmpty) {
      widget.onBarcodeScanned(barcode);
    }
  }
}
