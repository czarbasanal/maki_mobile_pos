import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Which bucket a line belongs to in the status view. Priority order — an
/// item appears once, in the first bucket it qualifies for.
enum _LineSource {
  recommended('Recommended'),
  outOfStock('Out of stock'),
  lowStock('Low stock'),
  added('Added');

  final String label;
  const _LineSource(this.label);

  /// Zero-velocity buckets start unchecked so they never silently pad an
  /// order; suggestions and deliberate manual adds start checked.
  bool get defaultChecked =>
      this == _LineSource.recommended || this == _LineSource.added;
}

/// One order line for this build pass. Quantity and checked-ness live in the
/// productId-keyed maps on the state, so an item that moves between buckets
/// (params change, manual add that becomes suggested) keeps whatever the
/// user set.
class _Line {
  const _Line({
    required this.product,
    required this.qty,
    required this.checked,
    required this.source,
    this.velocityPerDay,
  });

  final ProductEntity product;
  final int qty;
  final bool checked;
  final _LineSource source;
  final double? velocityPerDay;

  /// Expected cost of this line — the same `product.cost` that `_save` writes
  /// as the item's unitCost, so preview subtotals and the persisted PO share
  /// one costing rule.
  double get lineCost => qty * product.cost;
}

/// Grouping mode — presentation only; selection and quantities carry over.
enum _ViewMode { byStatus, bySupplier }

/// Drafts purchase orders from stock movement: adjustable window/cover,
/// per-supplier grouping, search-to-add, one draft PO per supplier on save.
class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  const NewPurchaseOrderScreen({super.key});

  @override
  ConsumerState<NewPurchaseOrderScreen> createState() =>
      NewPurchaseOrderScreenState();
}

class NewPurchaseOrderScreenState
    extends ConsumerState<NewPurchaseOrderScreen> {
  int _windowDays = 60;

  /// Cover days as displayed (updates per tap, clamped 1–365)…
  int _cover = 30;

  /// …and as applied to the suggestions provider (follows [_cover] after a
  /// short debounce so stepping doesn't refetch per tap).
  int _appliedCover = 30;
  Timer? _coverDebounce;

  /// Products added via search that the current suggestions don't cover.
  final List<ProductEntity> _manual = [];

  /// User adjustments keyed by productId — shared across every bucket so
  /// state survives params changes and re-grouping. Checked-ness is an
  /// override on top of each bucket's default (suggestions checked, low/out
  /// unchecked).
  final Map<String, int> _qty = {};
  final Map<String, bool> _checkedOverride = {};
  _ViewMode _view = _ViewMode.byStatus;
  bool _saving = false;

  @override
  void dispose() {
    _coverDebounce?.cancel();
    super.dispose();
  }

  void _setCover(int value) {
    final next = value.clamp(1, 365);
    if (next == _cover) return;
    setState(() => _cover = next);
    _coverDebounce?.cancel();
    _coverDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _appliedCover = _cover);
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = (windowDays: _windowDays, coverDays: _appliedCover);
    final resultAsync = ref.watch(reorderSuggestionsProvider(params));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Purchase Order'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: 'Add product',
            onPressed: _showAddProductSheet,
          ),
        ],
      ),
      body: resultAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(message: 'Failed to load: $e'),
        data: (result) => _buildBody(result),
      ),
    );
  }

  _Line _line(ProductEntity p, _LineSource source,
      {int defaultQty = 1, double? velocityPerDay}) {
    return _Line(
      product: p,
      qty: _qty[p.id] ?? defaultQty,
      checked: _checkedOverride[p.id] ?? source.defaultChecked,
      source: source,
      velocityPerDay: velocityPerDay,
    );
  }

  List<_Line> _buildLines(ReorderResult result) {
    final seen = <String>{};
    bool claim(String id) => seen.add(id);
    int topUp(ProductEntity p) {
      final target = p.reorderLevel - p.quantity;
      return target > 0 ? target : 1;
    }

    return [
      for (final s in result.suggestions)
        if (claim(s.product.id))
          _line(s.product, _LineSource.recommended,
              defaultQty: s.suggestedQty, velocityPerDay: s.velocityPerDay),
      for (final p in result.outOfStock)
        if (claim(p.id)) _line(p, _LineSource.outOfStock, defaultQty: topUp(p)),
      for (final p in result.lowStock)
        if (claim(p.id)) _line(p, _LineSource.lowStock, defaultQty: topUp(p)),
      for (final p in _manual)
        if (claim(p.id)) _line(p, _LineSource.added),
    ];
  }

  /// Section headers + rows for the active view. Status view walks the
  /// bucket order (recommended → out → low → added); supplier view groups
  /// the same lines by supplier name, no-supplier last, with the checked
  /// count + subtotal (what that supplier's PO will cost) on the right.
  List<Widget> _sections(List<_Line> lines) {
    if (_view == _ViewMode.byStatus) {
      const icons = {
        _LineSource.recommended: LucideIcons.trendingUp,
        _LineSource.outOfStock: LucideIcons.packageX,
        _LineSource.lowStock: LucideIcons.packageMinus,
        _LineSource.added: LucideIcons.circlePlus,
      };
      return [
        for (final source in _LineSource.values) ...[
          if (lines.any((l) => l.source == source)) ...[
            PoSectionHeader(
              icon: icons[source]!,
              label: source.label,
              trailing: '${lines.where((l) => l.source == source).length}',
            ),
            for (final line in lines)
              if (line.source == source) _row(line),
          ],
        ],
      ];
    }

    // Group by supplierId — the same key `_save` and the footer count use —
    // so a header's count/subtotal always describes exactly one created PO
    // (two suppliers sharing a display name get two sections).
    final groups = <String?, List<_Line>>{};
    for (final line in lines) {
      groups.putIfAbsent(line.product.supplierId, () => []).add(line);
    }
    String label(String? key) =>
        groups[key]!.first.product.supplierName ?? 'No supplier';
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return label(a).compareTo(label(b));
      });
    return [
      for (final key in keys) ...[
        _supplierHeader(label(key), groups[key]!),
        for (final line in groups[key]!) _row(line),
      ],
    ];
  }

  Widget _supplierHeader(String label, List<_Line> group) {
    final checked = group.where((l) => l.checked).toList();
    final subtotal = checked.fold<double>(0, (sum, l) => sum + l.lineCost);
    return PoSectionHeader(
      icon: LucideIcons.truck,
      label: label,
      trailing: '${checked.length} '
          '${checked.length == 1 ? 'item' : 'items'} · '
          '${subtotal.toCurrency()}',
    );
  }

  Widget _buildBody(ReorderResult result) {
    final lines = _buildLines(result);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _paramsCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _SegmentedCells<_ViewMode>(
            values: _ViewMode.values,
            labels: const {
              _ViewMode.byStatus: 'By status',
              _ViewMode.bySupplier: 'By supplier',
            },
            icons: const {
              _ViewMode.byStatus: LucideIcons.layers,
              _ViewMode.bySupplier: LucideIcons.truck,
            },
            selected: _view,
            keyPrefix: 'po-view',
            radius: 14,
            elevated: true,
            onChanged: (v) => setState(() => _view = v),
          ),
        ),
        if (result.capped)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: PoAmberNote(
              text: 'Movement data may be incomplete — the sales cap was '
                  'reached for this window.',
            ),
          ),
        Expanded(
          child: lines.isEmpty
              ? const EmptyStateView(
                  tiled: true,
                  icon: LucideIcons.packageCheck,
                  title: 'No suggestions — everything is stocked',
                  subtitle: 'Add products manually with the search button',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  children: _sections(lines),
                ),
        ),
        _footer(lines),
      ],
    );
  }

  Widget _paramsCard() {
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SegmentedCells<int>(
                  values: const [30, 60, 90],
                  labels: const {30: '30d', 60: '60d', 90: '90d'},
                  selected: _windowDays,
                  keyPrefix: 'po-window',
                  onChanged: (v) => setState(() => _windowDays = v),
                ),
              ),
              const SizedBox(width: 10),
              PoStepperButton(
                key: const Key('po-cover-minus'),
                icon: LucideIcons.minus,
                size: 30,
                radius: 9,
                onTap: _cover > 1 ? () => _setCover(_cover - 1) : null,
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    alignment: Alignment.center,
                    child: Text(
                      '$_cover',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'COVER',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              PoStepperButton(
                key: const Key('po-cover-plus'),
                icon: LucideIcons.plus,
                size: 30,
                radius: 9,
                onTap: _cover < 365 ? () => _setCover(_cover + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text.rich(
            TextSpan(
              text: 'Suggesting ',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '$_cover days of stock',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' from the last '),
                TextSpan(
                  text: '$_windowDays days',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' of sales — applies as you change it.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pinned footer: checked summary + running total (totals addition) over
  /// the live-count create button. The count mirrors the `_save` grouping —
  /// checked lines grouped by supplierId, no-supplier its own group.
  Widget _footer(List<_Line> lines) {
    final theme = Theme.of(context);
    final checked = lines.where((l) => l.checked).toList();
    final pcs = checked.fold<int>(0, (sum, l) => sum + l.qty);
    final total = checked.fold<double>(0, (sum, l) => sum + l.lineCost);
    final groupCount = checked.map((l) => l.product.supplierId).toSet().length;
    final label = checked.isEmpty
        ? 'Create purchase orders'
        : 'Create $groupCount purchase order${groupCount == 1 ? '' : 's'}';

    return PoFooter(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '${checked.length} '
                        '${checked.length == 1 ? 'item' : 'items'} '
                        'checked · $pcs pcs',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: ' · ${total.toCurrency()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'One PO per supplier',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('po-create-button'),
            onPressed: checked.isEmpty || _saving ? null : () => _save(lines),
            icon: const Icon(LucideIcons.clipboardPlus, size: 18),
            label: Text(label),
          ),
        ),
      ],
    );
  }

  Widget _row(_Line line) {
    final theme = Theme.of(context);
    final p = line.product;
    final caption = switch (line.source) {
      _LineSource.recommended =>
        'Stock ${p.quantity} · ${line.velocityPerDay!.toStringAsFixed(1)}/day',
      _LineSource.outOfStock ||
      _LineSource.lowStock =>
        'Stock ${p.quantity} · reorder at ${p.reorderLevel}',
      _LineSource.added => 'Stock ${p.quantity} · added manually',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _PoCheckbox(
              key: Key('po-check-${p.id}'),
              checked: line.checked,
              onChanged: (v) => setState(() => _checkedOverride[p.id] = v),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Opacity(
                opacity: line.checked ? 1 : 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.sku,
                      style: TextStyle(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: line.checked ? 1 : 0.62,
              child: Row(
                children: [
                  PoStepperButton(
                    icon: LucideIcons.minus,
                    onTap: line.qty > 1
                        ? () => setState(() => _qty[p.id] = line.qty - 1)
                        : null,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    child: Text(
                      '${line.qty}',
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  PoStepperButton(
                    icon: LucideIcons.plus,
                    onTap: () => setState(() => _qty[p.id] = line.qty + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _AddProductsSheet(
        initiallyAdded: _manual.map((p) => p.id).toSet(),
        onProduct: (p) {
          if (_manual.any((m) => m.id == p.id)) return;
          setState(() {
            _manual.add(p);
            // A deliberate add is always checked, even when the product also
            // sits in a low/out bucket.
            _checkedOverride[p.id] = true;
          });
        },
      ),
    );
  }

  Future<void> _save(List<_Line> lines) async {
    if (_saving) return;
    // .future rather than .valueOrNull — the provider may not have emitted
    // yet when nothing else in the tree watches it.
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;
    final checked = lines.where((l) => l.checked).toList();
    if (checked.isEmpty) return;
    setState(() => _saving = true);

    final repo = ref.read(purchaseOrderRepositoryProvider);
    final groups = <String?, List<_Line>>{};
    for (final line in checked) {
      groups.putIfAbsent(line.product.supplierId, () => []).add(line);
    }
    try {
      final created = await context.runWithWaiting(() async {
        var count = 0;
        for (final group in groups.values) {
          final refNumber = await repo.generateReferenceNumber();
          final first = group.first.product;
          final po = PurchaseOrderEntity(
            id: '',
            referenceNumber: refNumber,
            supplierId: first.supplierId,
            supplierName: first.supplierName,
            items: [
              for (final line in group)
                PurchaseOrderItemEntity(
                  id: line.product.id,
                  productId: line.product.id,
                  sku: line.product.sku,
                  name: line.product.name,
                  quantity: line.qty,
                  unit: line.product.unit,
                  unitCost: line.product.cost,
                  costCode: line.product.costCode,
                ),
            ],
            totalCost: 0,
            totalQuantity: 0,
            status: PurchaseOrderStatus.draft,
            createdAt: DateTime.now(),
            createdBy: user.id,
            createdByName: user.displayName,
          ).recalculateTotals();
          await repo.createPurchaseOrder(po);
          count++;
        }
        return count;
      }, message: 'Saving purchase orders…');
      if (!mounted) return;
      context.showSuccessSnackBar('Created $created purchase order(s)');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Add-products sheet — Job Orders add-parts pattern: grab handle · title +
/// session count · ProductSearchField (inline results, barcode scan, no
/// prices, out-of-stock addable) · pinned Done. Stays open so several
/// products accumulate; added rows chip as "Added".
class _AddProductsSheet extends ConsumerStatefulWidget {
  const _AddProductsSheet({
    required this.initiallyAdded,
    required this.onProduct,
  });

  /// Ids already added manually — their rows render the "Added" chip.
  final Set<String> initiallyAdded;
  final void Function(ProductEntity) onProduct;

  @override
  ConsumerState<_AddProductsSheet> createState() => _AddProductsSheetState();
}

class _AddProductsSheetState extends ConsumerState<_AddProductsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final Set<String> _added = {...widget.initiallyAdded};
  int _session = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(ProductEntity p) {
    if (_added.contains(p.id)) return;
    widget.onProduct(p);
    setState(() {
      _added.add(p.id);
      _session++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Fixed-height sheet with an in-flow scrollable results panel, clamped so
    // sheet + keyboard never exceed the screen (JO add-parts pattern). The
    // upper bound is floored at 0 — on a very short window (split-screen +
    // keyboard) a negative upper limit would make clamp throw.
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
                  const Expanded(
                    child: Text(
                      'Add products',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$_session added this session',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ProductSearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  inlineResults: true,
                  showPrice: false,
                  allowOutOfStock: true,
                  addedIds: _added,
                  hintText: 'Search name, SKU, or scan barcode',
                  onProductSelected: _add,
                  onBarcodeScanned: (barcode) async {
                    final p = await ref
                        .read(productByBarcodeProvider(barcode).future);
                    if (!context.mounted) return;
                    if (p == null) {
                      context
                          .showWarningSnackBar('Product not found: $barcode');
                    } else if (_added.contains(p.id)) {
                      // A silent no-op reads as a failed scan — say why
                      // nothing changed.
                      context.showWarningSnackBar('Already added: ${p.name}');
                    } else {
                      _add(p);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 22px rounded checkbox — checked = solid primary + on-primary check,
/// unchecked = 1.5px border.
class _PoCheckbox extends StatelessWidget {
  const _PoCheckbox(
      {super.key, required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      checked: checked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!checked),
        child: Container(
          width: 22,
          height: 22,
          decoration: checked
              ? BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(7),
                )
              : BoxDecoration(
                  border: Border.all(
                      color: AppColors.checkboxBorder(dark), width: 1.5),
                  borderRadius: BorderRadius.circular(7),
                ),
          child: checked
              ? Icon(LucideIcons.check,
                  size: 14, color: theme.colorScheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}

/// Bordered segmented control per the mock — equal cells, selected = faint
/// primary wash + 600 primary text. [elevated] fills with the card surface +
/// soft shadow (the view toggle); plain sits recessed on the params card.
class _SegmentedCells<T> extends StatelessWidget {
  const _SegmentedCells({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.icons,
    this.radius = 12,
    this.elevated = false,
  });

  final List<T> values;
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final String keyPrefix;
  final Map<T, IconData>? icons;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border =
        dark ? AppColors.darkInputBorder : AppColors.lightInputBorder;
    return Container(
      decoration: BoxDecoration(
        color: elevated ? (dark ? AppColors.darkCard : Colors.white) : null,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? AppShadows.card(dark: dark) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: _cell(context, values[i], first: i == 0, border: border),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, T v,
      {required bool first, required Color border}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isSel = v == selected;
    final name = v is Enum ? v.name : v.toString();
    final selectedTint =
        dark ? const Color(0x1FE8B84C) : const Color(0x1A283E46);
    final icon = icons?[v];
    return Semantics(
      button: true,
      selected: isSel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(v),
        child: Container(
          key: Key('$keyPrefix-$name'),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: icons == null ? 8 : 10),
          decoration: BoxDecoration(
            color: isSel ? selectedTint : Colors.transparent,
            border: first ? null : Border(left: BorderSide(color: border)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isSel
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                labels[v]!,
                style: TextStyle(
                  fontSize: icons == null ? 13 : 13.5,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                  color: isSel
                      ? theme.colorScheme.primary
                      : (icons == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
