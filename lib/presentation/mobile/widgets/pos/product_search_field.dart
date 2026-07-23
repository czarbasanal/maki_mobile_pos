import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/barcode_scanner_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/common/product_thumb.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Search field for finding products by name, SKU, or barcode.
///
/// Results render as a floating dropdown by default (POS register). With
/// [inlineResults] the panel renders in-flow below the field instead — used
/// by the add-parts sheet, whose fixed height gives results room to scroll.
class ProductSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<ProductEntity> onProductSelected;
  final ValueChanged<String> onBarcodeScanned;
  final bool inlineResults;
  final String hintText;

  /// Show the sale price on result rows (POS/JO default). The PO add sheet
  /// hides it — that surface is deliberately price-free.
  final bool showPrice;

  /// Keep zero-stock rows tappable (purchase orders exist to restock them).
  final bool allowOutOfStock;

  /// Rows whose product id is in this set render a tinted "Added" chip
  /// instead of the + button and cannot be re-added.
  final Set<String> addedIds;

  const ProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onProductSelected,
    required this.onBarcodeScanned,
    this.inlineResults = false,
    this.hintText = 'Search products or scan barcode...',
    this.showPrice = true,
    this.allowOutOfStock = false,
    this.addedIds = const {},
  });

  @override
  ConsumerState<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
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
      setState(() => _debouncedQuery = '');
      _removeOverlay();
      return;
    }

    // Rebuild the field (e.g. the clear button) and ensure the dropdown is
    // present — but do NOT tear it down and re-insert it on every keystroke.
    setState(() {});
    if (!widget.inlineResults && widget.focusNode.hasFocus) _ensureOverlay();

    // Debounce only the query the results provider watches; the overlay is
    // rebuilt in place (markNeedsBuild) rather than recreated, so typing stays
    // smooth and the list doesn't flicker.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || query != widget.controller.text.trim()) return;
      if (widget.inlineResults) {
        setState(() => _debouncedQuery = query);
      } else {
        _debouncedQuery = query;
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  void _onFocusChanged() {
    if (widget.inlineResults) return;
    if (!widget.focusNode.hasFocus) {
      // Delay to allow tap on result
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    } else if (widget.controller.text.isNotEmpty) {
      _ensureOverlay();
    }
  }

  /// Inserts the results dropdown once; if it already exists, rebuilds it in
  /// place instead of recreating it (avoids per-keystroke flicker).
  void _ensureOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      // Deliberately ignores the overlay's own context: every lookup below
      // (render box for the field's x, theme, screen size) must resolve
      // against the FIELD's context, not the overlay subtree's.
      builder: (overlayContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final hairline =
            isDark ? AppColors.darkHairline : AppColors.lightHairline;
        final muted = theme.colorScheme.onSurfaceVariant;
        // Full-screen-width dropdown: anchor to the field via the layer
        // link, then shift left by the field's own x so the panel spans
        // the screen regardless of how the field is inset.
        const edgeMargin = 8.0;
        final fieldBox = context.findRenderObject() as RenderBox?;
        final fieldDx =
            fieldBox?.localToGlobal(Offset.zero).dx ?? edgeMargin;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final hasQuery = widget.controller.text.trim().isNotEmpty;
        return Positioned(
          width: screenWidth - edgeMargin * 2,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(edgeMargin - fieldDx, 60),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasQuery)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm + 4,
                          AppSpacing.sm + 2,
                          AppSpacing.sm + 4,
                          4,
                        ),
                        child: Text(
                          'Search results',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    Flexible(child: _buildSearchResults()),
                  ],
                ),
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
    if (widget.inlineResults) {
      // NOTE: inline mode requires a bounded-height parent (the add-parts
      // sheet's fixed height) — the results panel is an Expanded scrollable.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(context),
          const SizedBox(height: AppSpacing.sm + 2),
          Expanded(child: _buildSearchResults()),
        ],
      );
    }
    return _buildField(context);
  }

  Widget _buildField(BuildContext context) {
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
                style: AppTextStyles.fieldInput,
                controller: widget.controller,
                focusNode: widget.focusNode,
                decoration: InputDecoration(
                  hintText: widget.hintText,
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
      // Nothing typed → no dropdown. Typed but debounce still pending → a brief
      // loader rather than an empty box.
      if (widget.controller.text.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final searchResults =
        ref.watch(localProductSearchProvider(_debouncedQuery));

    return Container(
      constraints:
          widget.inlineResults ? null : const BoxConstraints(maxHeight: 300),
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

          // Overlay: compact dropdown capped at 10. Inline: the sheet's
          // full-height panel scrolls through every match (no silent cap).
          return ListView.builder(
            shrinkWrap: !widget.inlineResults,
            itemCount: widget.inlineResults
                ? products.length
                : (products.length > 10 ? 10 : products.length),
            itemBuilder: (context, index) => _buildResultRow(products[index]),
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

  /// Elevated-theme result row: thumbnail · name + mono "SKU · N in stock" ·
  /// price · filled + add button. Row tap and + both add the product.
  Widget _buildResultRow(ProductEntity product) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final disabled = !widget.allowOutOfStock && product.isOutOfStock;
    final added = widget.addedIds.contains(product.id);

    void select() {
      widget.onProductSelected(product);
      if (!widget.inlineResults) _removeOverlay();
    }

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        onTap: disabled || added ? null : select,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: hairline)),
          ),
          child: Row(
            children: [
              ProductThumb(name: product.name, imageUrl: product.imageUrl),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wraps instead of truncating — the dropdown now spans
                    // the full screen width, so long part names stay legible.
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${product.sku} · ${product.quantity} in stock',
                      style: TextStyle(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showPrice) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${AppConstants.currencySymbol}'
                  '${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
              // Already-added rows chip instead of the + button; otherwise a
              // 30px rounded-square add button per the mock, hidden on
              // out-of-stock rows so nothing dead reads as tappable.
              if (added)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.sm + 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.emphasisTint(isDark),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Added',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else if (!disabled) ...[
                const SizedBox(width: AppSpacing.sm + 2),
                InkWell(
                  onTap: select,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
