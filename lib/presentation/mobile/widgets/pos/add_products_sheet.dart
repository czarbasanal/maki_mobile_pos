import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';

/// How the shared add-products sheet is dismissed.
enum AddProductsSheetDismiss {
  /// X icon in the title row (Job Orders add-parts pattern).
  closeIcon,

  /// Pinned right-aligned Done button (PO add-products pattern).
  doneButton,
}

/// Product-picker bottom sheet shared by the Job Orders editor ("Add parts")
/// and the New Purchase Order screen ("Add products"): grab handle, title
/// row, [ProductSearchField] with inline results + barcode scan. Stays open
/// so several picks accumulate; the host screen updates live via [onProduct].
class AddProductsSheet extends ConsumerStatefulWidget {
  const AddProductsSheet({
    super.key,
    required this.title,
    required this.onProduct,
    this.dismiss = AddProductsSheetDismiss.closeIcon,
    this.showSessionCount = false,
    this.showPrice = true,
    this.allowOutOfStock = false,
    this.dedupeAgainst,
    this.clearQueryOnPick = false,
  });

  final String title;
  final void Function(ProductEntity) onProduct;
  final AddProductsSheetDismiss dismiss;

  /// Show "N added this session" in the title row.
  final bool showSessionCount;
  final bool showPrice;
  final bool allowOutOfStock;

  /// Non-null enables dedupe, seeded with the ids already on the host
  /// screen: repeat picks are skipped, already-added rows chip as "Added",
  /// and a duplicate barcode scan warns instead of silently doing nothing.
  final Set<String>? dedupeAgainst;

  /// Clear the query and refocus after each row-tap pick (JO behavior).
  /// Barcode adds clear without refocusing — the scan flow deliberately
  /// keeps the keyboard down.
  final bool clearQueryOnPick;

  @override
  ConsumerState<AddProductsSheet> createState() => _AddProductsSheetState();
}

class _AddProductsSheetState extends ConsumerState<AddProductsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final Set<String> _added = {...?widget.dedupeAgainst};
  int _session = 0;

  bool get _dedupe => widget.dedupeAgainst != null;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(ProductEntity p, {bool refocus = true}) {
    if (_dedupe && _added.contains(p.id)) return;
    widget.onProduct(p);
    // Only rebuild when something observable changed (the Added chips or the
    // session count); a plain JO pick keeps no sheet-side state.
    if (_dedupe || widget.showSessionCount) {
      setState(() {
        if (_dedupe) _added.add(p.id);
        _session++;
      });
    }
    if (widget.clearQueryOnPick) {
      _controller.clear();
      if (refocus) _focusNode.requestFocus();
    }
  }

  Future<void> _onBarcode(String barcode) async {
    final p = await ref.read(productByBarcodeProvider(barcode).future);
    if (!mounted) return;
    if (p == null) {
      context.showWarningSnackBar('Product not found: $barcode');
    } else if (_dedupe && _added.contains(p.id)) {
      // A silent no-op reads as a failed scan — say why nothing changed.
      context.showWarningSnackBar('Already added: ${p.name}');
    } else {
      // No refocus after a camera scan — the scan flow drops the keyboard on
      // purpose and popping it back up would cover the results per scan.
      _add(p, refocus: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Fixed-height sheet with an in-flow scrollable results panel, clamped so
    // sheet + keyboard never exceed the screen. Upper bound floored at 0 — a
    // very short window (split-screen + keyboard) would otherwise make clamp
    // throw.
    final sheetHeight = (screenHeight * 0.62)
        .clamp(0.0, math.max(0.0, screenHeight - bottomInset - 120))
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.showSessionCount)
                    Text(
                      '$_session added this session',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (widget.dismiss == AddProductsSheetDismiss.closeIcon)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ProductSearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  inlineResults: true,
                  showPrice: widget.showPrice,
                  allowOutOfStock: widget.allowOutOfStock,
                  addedIds: _dedupe ? _added : const {},
                  hintText: 'Search name, SKU, or scan barcode',
                  onProductSelected: _add,
                  onBarcodeScanned: _onBarcode,
                ),
              ),
              if (widget.dismiss == AddProductsSheetDismiss.doneButton) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
