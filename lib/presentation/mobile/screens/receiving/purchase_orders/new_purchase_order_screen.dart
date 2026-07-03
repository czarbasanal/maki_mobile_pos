import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
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
}

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
  final _coverController = TextEditingController(text: '30');

  /// Owned by the state, not the sheet — disposing a local controller right
  /// after showModalBottomSheet returns races the sheet's exit animation.
  final _searchController = TextEditingController();

  /// Products added via search that the current suggestions don't cover.
  final List<ProductEntity> _manual = [];

  /// User adjustments keyed by productId — shared across every bucket so
  /// state survives params changes and re-grouping. Checked-ness is an
  /// override on top of each bucket's default (suggestions checked, low/out
  /// unchecked).
  final Map<String, int> _qty = {};
  final Map<String, bool> _checkedOverride = {};
  bool _byStatus = true;
  bool _saving = false;

  int get _coverDays =>
      (int.tryParse(_coverController.text) ?? 30).clamp(1, 365);

  @override
  void dispose() {
    _coverController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = (windowDays: _windowDays, coverDays: _coverDays);
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
        if (claim(p.id))
          _line(p, _LineSource.outOfStock, defaultQty: topUp(p)),
      for (final p in result.lowStock)
        if (claim(p.id)) _line(p, _LineSource.lowStock, defaultQty: topUp(p)),
      for (final p in _manual)
        if (claim(p.id)) _line(p, _LineSource.added),
    ];
  }

  /// Section headers + rows for the active view. Status view walks the
  /// bucket order (recommended → out → low → added); supplier view groups
  /// the same lines by supplier name, no-supplier last.
  List<Widget> _sections(List<_Line> lines) {
    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(text, style: Theme.of(context).textTheme.titleSmall),
        );

    if (_byStatus) {
      return [
        for (final source in _LineSource.values) ...[
          if (lines.any((l) => l.source == source)) ...[
            header(source.label),
            for (final line in lines)
              if (line.source == source) _row(line),
          ],
        ],
      ];
    }

    final groups = <String?, List<_Line>>{};
    for (final line in lines) {
      groups.putIfAbsent(line.product.supplierName, () => []).add(line);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return [
      for (final key in keys) ...[
        header(key ?? 'No supplier'),
        for (final line in groups[key]!) _row(line),
      ],
    ];
  }

  Widget _buildBody(ReorderResult result) {
    final lines = _buildLines(result);
    final checkedCount = lines.where((l) => l.checked).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final days in const [30, 60, 90]) ...[
                ChoiceChip(
                  label: Text('${days}d'),
                  selected: _windowDays == days,
                  onSelected: (_) => setState(() => _windowDays = days),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _coverController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cover days',
                    isDense: true,
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('By status'),
                selected: _byStatus,
                onSelected: (_) => setState(() => _byStatus = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('By supplier'),
                selected: !_byStatus,
                onSelected: (_) => setState(() => _byStatus = false),
              ),
            ],
          ),
        ),
        if (result.capped)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Movement data may be incomplete (sales cap reached)'),
          ),
        Expanded(
          child: lines.isEmpty
              ? const EmptyStateView(
                  icon: LucideIcons.packageCheck,
                  title: 'No suggestions — everything is stocked',
                  subtitle: 'Add products manually with the search button',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: _sections(lines),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    checkedCount == 0 || _saving ? null : () => _save(lines),
                child: const Text('Save drafts'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(_Line line) {
    final p = line.product;
    final caption = switch (line.source) {
      _LineSource.recommended =>
        'Stock ${p.quantity} • ${line.velocityPerDay!.toStringAsFixed(1)}/day',
      _LineSource.outOfStock ||
      _LineSource.lowStock =>
        'Stock ${p.quantity} • reorder at ${p.reorderLevel}',
      _LineSource.added => 'Stock ${p.quantity} • added manually',
    };
    return Row(
      children: [
        Checkbox(
          value: line.checked,
          onChanged: (v) => setState(() {
            _checkedOverride[p.id] = v ?? false;
          }),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${p.sku} • $caption',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.minus, size: 16),
          onPressed: line.qty > 1
              ? () => setState(() => _qty[p.id] = line.qty - 1)
              : null,
        ),
        Text('${line.qty}'),
        IconButton(
          icon: const Icon(LucideIcons.plus, size: 16),
          onPressed: () => setState(() => _qty[p.id] = line.qty + 1),
        ),
      ],
    );
  }

  Future<void> _showAddProductSheet() async {
    // .future — the stream may not have emitted if nothing watches it yet.
    final products = await ref.read(productsProvider.future);
    if (!mounted) return;
    final controller = _searchController..clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final query = controller.text.trim().toLowerCase();
          final matches = products
              .where((p) =>
                  p.isActive &&
                  !_manual.any((m) => m.id == p.id) &&
                  (query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      p.sku.toLowerCase().contains(query)))
              .take(30)
              .toList();
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration:
                          const InputDecoration(hintText: 'Search name or SKU'),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(matches[i].name),
                        subtitle: Text(matches[i].sku),
                        onTap: () {
                          setState(() {
                            _manual.add(matches[i]);
                            // A deliberate add is always checked, even when
                            // the product also sits in a low/out bucket.
                            _checkedOverride[matches[i].id] = true;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
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
