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

/// One order line for this build pass — a velocity suggestion or a manually
/// added product. Quantity and checked-ness live in the productId-keyed maps
/// on the state, so a manual product that later qualifies as a suggestion
/// keeps whatever the user set.
class _Line {
  const _Line({
    required this.product,
    required this.qty,
    required this.checked,
    this.velocityPerDay,
  });

  final ProductEntity product;
  final int qty;
  final bool checked;
  final double? velocityPerDay; // null = manually added
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

  /// User adjustments keyed by productId — shared by suggestion and manual
  /// lines so state survives params changes and re-grouping.
  final Map<String, int> _qty = {};
  final Set<String> _unchecked = {};
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

  List<_Line> _buildLines(ReorderResult result) {
    final suggested = {for (final s in result.suggestions) s.product.id: s};
    return [
      for (final s in result.suggestions)
        _Line(
          product: s.product,
          qty: _qty[s.product.id] ?? s.suggestedQty,
          checked: !_unchecked.contains(s.product.id),
          velocityPerDay: s.velocityPerDay,
        ),
      for (final p in _manual)
        if (!suggested.containsKey(p.id))
          _Line(
            product: p,
            qty: _qty[p.id] ?? 1,
            checked: !_unchecked.contains(p.id),
          ),
    ];
  }

  Widget _buildBody(ReorderResult result) {
    final lines = _buildLines(result);
    // Group by supplier; suggestions arrive pre-sorted, manual lines join
    // their supplier's group or the no-supplier bucket (last).
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
                  children: [
                    for (final key in keys) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 4),
                        child: Text(key ?? 'No supplier',
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final line in groups[key]!) _row(line),
                    ],
                  ],
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
    final caption = line.velocityPerDay != null
        ? 'Stock ${p.quantity} • ${line.velocityPerDay!.toStringAsFixed(1)}/day'
        : 'Stock ${p.quantity} • added manually';
    return Row(
      children: [
        Checkbox(
          value: line.checked,
          onChanged: (v) => setState(() {
            v == true ? _unchecked.remove(p.id) : _unchecked.add(p.id);
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
                            _qty.putIfAbsent(matches[i].id, () => 1);
                            _unchecked.remove(matches[i].id);
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
