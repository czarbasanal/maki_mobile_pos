import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/job_order_bill_out.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/discount_input_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/job_orders/job_order_dialogs.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/add_products_sheet.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_item_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/fee_line_row.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/fee_section.dart'
    show showAddFeeLineDialog;
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
import 'package:uuid/uuid.dart';

/// Screen for editing/viewing a job order and converting to checkout.
class JobOrderEditScreen extends ConsumerStatefulWidget {
  final String jobOrderId;

  const JobOrderEditScreen({
    super.key,
    required this.jobOrderId,
  });

  @override
  ConsumerState<JobOrderEditScreen> createState() => _JobOrderEditScreenState();
}

class _JobOrderEditScreenState extends ConsumerState<JobOrderEditScreen> {
  /// Local working copy so labor/mechanic edits render instantly; each edit is
  /// persisted through the FULL updateJobOrder path (NOT updateJobOrderItems, which
  /// writes only `items` and would drop labor).
  JobOrderEntity? _working;

  /// Notes edit buffer — seeded from the loaded ticket once (per job order id),
  /// committed on focus loss so we don't write Firestore per keystroke.
  TextEditingController? _notesCtrl;
  String? _notesSeededForId;

  JobOrderEntity _sync(JobOrderEntity fromProvider) {
    final current = _working;
    if (current == null || current.id != fromProvider.id) {
      _working = fromProvider;
    }
    return _working!;
  }

  TextEditingController _notesControllerFor(JobOrderEntity jobOrder) {
    if (_notesCtrl == null || _notesSeededForId != jobOrder.id) {
      _notesCtrl?.dispose();
      _notesCtrl = TextEditingController(text: jobOrder.notes ?? '');
      _notesSeededForId = jobOrder.id;
    }
    return _notesCtrl!;
  }

  void _commitNotes() {
    final base = _working;
    final typed = _notesCtrl?.text.trim();
    if (base == null || typed == null || typed == (base.notes ?? '')) return;
    final next = typed.isEmpty
        ? base.copyWith(clearNotes: true, updatedAt: DateTime.now())
        : base.copyWith(notes: typed, updatedAt: DateTime.now());
    _persist(next);
  }

  @override
  void dispose() {
    _notesCtrl?.dispose();
    super.dispose();
  }

  Future<void> _persist(JobOrderEntity next) async {
    setState(() => _working = next);
    final actor = ref.read(currentUserProvider).valueOrNull;
    final updated = actor == null
        ? null
        : await ref
            .read(jobOrderOperationsProvider.notifier)
            .updateJobOrder(actor: actor, jobOrder: next);
    // The edit rendered optimistically; if the write failed, resync to the
    // server copy instead of letting the screen lie about the ticket.
    if (updated == null && mounted) {
      setState(() => _working = null);
      ref.invalidate(jobOrderByIdProvider(widget.jobOrderId));
      context.showErrorSnackBar('Failed to save changes — ticket reloaded');
    }
  }

  /// The motorcycle being serviced can change mid-job — the header picker
  /// persists edits like the mechanic picker. The picker only ever reports
  /// null ("— None —") or a canonical model name; clearing re-arms the
  /// existing "Set the motorcycle model to bill out" gate.
  void _onModelChanged(String? model) {
    final base = _working;
    if (base == null || model == base.motorcycleModel) return;
    final next = (model == null)
        ? base.copyWith(clearMotorcycleModel: true, updatedAt: DateTime.now())
        : base.copyWith(motorcycleModel: model, updatedAt: DateTime.now());
    _persist(next);
  }

  void _onMechanicChanged(String? id, String? name) {
    final base = _working;
    if (base == null) return;
    final next = (id == null)
        ? base.copyWith(clearMechanic: true, updatedAt: DateTime.now())
        : base.copyWith(
            mechanicId: id, mechanicName: name, updatedAt: DateTime.now());
    _persist(next);
  }

  Future<void> _addLabor(JobOrderEntity jobOrder) async {
    final result = await showLaborLineDialog(context);
    if (result == null) return;
    await _persist(jobOrder.addLaborLine(LaborLineEntity(
      id: const Uuid().v4(),
      description: result.description,
      fee: result.fee,
    )));
  }

  Future<void> _removeLabor(JobOrderEntity jobOrder, String lineId) async {
    await _persist(jobOrder.removeLaborLine(lineId));
  }

  Future<void> _addFee(
    JobOrderEntity jobOrder,
    List<ShopFeeEntity> activeFees,
  ) async {
    final result = await showAddFeeLineDialog(context, activeFees: activeFees);
    if (result == null) return;
    await _persist(jobOrder.addFeeLine(result));
  }

  Future<void> _removeFee(JobOrderEntity jobOrder, String lineId) async {
    await _persist(jobOrder.removeFeeLine(lineId));
  }

  Future<void> _removeItem(JobOrderEntity jobOrder, String itemId) =>
      _persist(jobOrder.removeItem(itemId));

  SaleItemEntity _saleItemFromProduct(ProductEntity product) => SaleItemEntity(
        id: const Uuid().v4(),
        productId: product.id,
        sku: product.sku,
        name: product.name,
        unitPrice: product.price,
        unitCost: product.cost,
        quantity: 1,
        unit: product.unit,
      );

  /// Appends a product to the current working ticket (uses [_working] so
  /// several parts added in one sitting accumulate) and persists it.
  Future<void> _addProduct(ProductEntity product) {
    final current = _working;
    if (current == null) return Future.value();
    return _persist(current.addItem(_saleItemFromProduct(product)));
  }

  void _onAddParts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => AddProductsSheet(
        title: 'Add parts',
        clearQueryOnPick: true,
        onProduct: _addProduct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobOrderAsync = ref.watch(jobOrderByIdProvider(widget.jobOrderId));

    return jobOrderAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading…')),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: ErrorStateView(
          message: 'Error loading job order: $error',
          action: ElevatedButton(
            onPressed: () => context.go(RoutePaths.jobOrders),
            child: const Text('Back to Job Orders'),
          ),
        ),
      ),
      data: (jobOrder) {
        if (jobOrder == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Job Order Not Found')),
            body: EmptyStateView(
              icon: Icons.search_off,
              title: 'Job order not found or has been deleted',
              action: ElevatedButton(
                onPressed: () => context.go(RoutePaths.jobOrders),
                child: const Text('Back to Job Orders'),
              ),
            ),
          );
        }

        return _buildJobOrderContent(_sync(jobOrder));
      },
    );
  }

  Widget _buildJobOrderContent(JobOrderEntity jobOrder) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    // System back (gesture / hardware button) bypasses the chevron handler
    // AND the notes field's blur commit — catch it here.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _commitNotes();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            jobOrder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              fontFamily: AppTextStyles.monoFontFamily,
            ),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () {
              // This screen has no save button — leaving IS the save gesture
              // for a still-focused notes edit, and pop-blur timing is not
              // guaranteed to fire the Focus commit.
              _commitNotes();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RoutePaths.jobOrders);
              }
            },
          ),
          actions: [
            // Delete button (red)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              color: AppColors.costUp(theme.brightness == Brightness.dark),
              onPressed: () => _confirmDelete(jobOrder),
              tooltip: 'Delete Job Order',
            ),
          ],
        ),
        body: Column(
          children: [
            // ONE scroll region — header, parts and labor scroll together
            // (POS cart pattern); the summary + Bill out stay pinned below.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  children: [
                    // Job Order info header
                    Builder(builder: (context) {
                      final muted = theme.colorScheme.onSurfaceVariant;
                      final isDark = theme.brightness == Brightness.dark;
                      final hairline = isDark
                          ? AppColors.darkHairline
                          : AppColors.lightHairline;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: hairline)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Motorcycle model — the bill-out gate, editable in
                            // place (the serviced bike can change mid-job).
                            MotorcycleModelPicker(
                              selectedModel: jobOrder.motorcycleModel,
                              onChanged: _onModelChanged,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(LucideIcons.clock, size: 14, color: muted),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Created ${dateFormat.format(jobOrder.createdAt)}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: muted),
                                ),
                              ],
                            ),
                            if (jobOrder.updatedAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(LucideIcons.squarePen,
                                      size: 14, color: muted),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Updated ${dateFormat.format(jobOrder.updatedAt!)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: muted),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Focus(
                              onFocusChange: (hasFocus) {
                                if (!hasFocus) _commitNotes();
                              },
                              child: TextField(
                                style: AppTextStyles.fieldInput,
                                controller: _notesControllerFor(jobOrder),
                                minLines: 1,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                  hintText: 'e.g. customer requests',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Parts header + Add action
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
                      child: Row(
                        children: [
                          Icon(LucideIcons.package,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Parts',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _onAddParts,
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Add parts'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items list — inline, not separately scrollable.
                    jobOrder.items.isEmpty
                        ? SizedBox(height: 220, child: _buildEmptyItems())
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: jobOrder.items.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) {
                              return _buildJobOrderItem(
                                  jobOrder, jobOrder.items[index]);
                            },
                          ),

                    // Labor & Service (mechanic + labor lines) — editable
                    // anytime.
                    _buildLaborSection(jobOrder),

                    // Shop Fees — editable anytime, same reuse route as Labor
                    // (shared FeeLineRow + add-fee dialog from Task 5a).
                    _buildFeeSection(jobOrder),
                  ],
                ),
              ),
            ),

            // Sticky footer: summary + Bill out.
            _buildSummarySection(jobOrder),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyItems() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shoppingCart, size: 56, color: muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No parts on this job order yet',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  /// Parts render with the same card as the POS cart (name/✕, SKU · price,
  /// cost pill, qty stepper, per-item discount, swipe-to-delete) — one card
  /// language wherever parts are edited.
  Widget _buildJobOrderItem(JobOrderEntity jobOrder, SaleItemEntity item) {
    return CartItemTile(
      item: item,
      discountType: jobOrder.discountType,
      onQuantityChanged: (qty) =>
          _persist(jobOrder.updateItemQuantity(item.id, qty)),
      onDiscountTap: () => _showItemDiscountDialog(jobOrder, item),
      onRemove: () => _removeItem(jobOrder, item.id),
    );
  }

  void _showItemDiscountDialog(JobOrderEntity jobOrder, SaleItemEntity item) {
    // Same construction as the POS register's discount flow; writes go
    // through the ticket's persist path instead of the cart.
    final hasOtherDiscounts =
        jobOrder.items.any((other) => other.id != item.id && other.hasDiscount);
    showDialog(
      context: context,
      builder: (context) => DiscountInputDialog(
        itemName: item.name,
        currentDiscount: item.discountValue,
        discountType: jobOrder.discountType,
        maxAmount: item.grossAmount,
        hasOtherDiscounts: hasOtherDiscounts,
        onApply: (value) =>
            _persist((_working ?? jobOrder).applyItemDiscount(item.id, value)),
        onTypeChanged: (type) =>
            _persist((_working ?? jobOrder).changeDiscountType(type)),
      ),
    );
  }

  Widget _buildLaborSection(JobOrderEntity jobOrder) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wrench, size: 16, color: muted),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Labor & Service',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addLabor(jobOrder),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Labor'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          // Room above the picker so its floating "Mechanic" label isn't
          // clipped (same fix as the POS labor section).
          const SizedBox(height: AppSpacing.sm),
          MechanicPicker(
            selectedMechanicId: jobOrder.mechanicId,
            onChanged: (m) => _onMechanicChanged(m?.id, m?.name),
          ),
          // Bounded + scrollable — same treatment as the POS labor section.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: jobOrder.laborLines
                  .map(
                    (line) => LaborLineRow(
                      line: line,
                      onEdited: (description, fee) => _persist(
                        jobOrder.updateLaborLine(
                          line.copyWith(description: description, fee: fee),
                        ),
                      ),
                      onRemove: () => _removeLabor(jobOrder, line.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Shop Fees — mirrors [_buildLaborSection]'s shell (bordered container,
  /// header row + Add action, bounded scrollable rows) but with the shared
  /// [FeeLineRow] + [showAddFeeLineDialog] from Task 5a's POS section
  /// instead of building its own picker.
  Widget _buildFeeSection(JobOrderEntity jobOrder) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final muted = theme.colorScheme.onSurfaceVariant;
    // Watched so the picker's data is warmed up before "Add Fee" is tapped,
    // same reasoning as the POS FeeSection.
    final activeFees =
        ref.watch(activeShopFeesProvider).valueOrNull ?? const [];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receipt, size: 16, color: muted),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Shop Fees',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addFee(jobOrder, activeFees),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Fee'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          // Bounded + scrollable — same treatment as the labor section.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: jobOrder.feeLines
                  .map(
                    (line) => FeeLineRow(
                      line: line,
                      onAmountEdited: (amount) => _persist(
                        jobOrder.updateFeeLine(line.copyWith(amount: amount)),
                      ),
                      onRemove: () => _removeFee(jobOrder, line.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(JobOrderEntity jobOrder) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SummaryRow(
              label: 'Subtotal',
              value: jobOrder.subtotal.toCurrency(),
            ),
            if (jobOrder.totalDiscount > 0) ...[
              const SizedBox(height: 4),
              SummaryRow(
                label: 'Discount',
                value: '-${jobOrder.totalDiscount.toCurrency()}',
                valueColor: AppColors.successText(isDark),
              ),
            ],
            if (jobOrder.laborLines.isNotEmpty) ...[
              const SizedBox(height: 4),
              SummaryRow(
                label: jobOrder.laborLines.length == 1
                    ? 'Labor (1 service)'
                    : 'Labor (${jobOrder.laborLines.length} services)',
                value: jobOrder.laborSubtotal.toCurrency(),
              ),
            ],
            if (jobOrder.feeLines.isNotEmpty) ...[
              const SizedBox(height: 4),
              SummaryRow(
                label: 'Shop Fees (${jobOrder.feeLines.length})',
                value: jobOrder.feesTotal.toCurrency(),
              ),
            ],
            // Total row: "Total" 15/700 + "(n items)" 12.5/500 muted inline;
            // value 18/700 in onSurface. Border-top replaces the generic Divider.
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkHairline
                        : const Color(0xFFE5E3DE),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Total ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: '(${jobOrder.totalItemCount} items)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    jobOrder.grandTotal.toCurrency(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: jobOrder.hasBillableContent &&
                        ref.watch(unsettledBusinessDayProvider).valueOrNull ==
                            null
                    ? () => _billOut(jobOrder)
                    : null,
                icon: const Icon(LucideIcons.shoppingCart),
                label: const Text('Bill out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bills out the ticket. Non-destructive: loads it into the register cart
  /// (setting sourceJobOrderId so the sale carries a jobOrderId) WITHOUT deleting it.
  /// A successful sale marks the ticket converted (ProcessSaleUseCase
  /// `_reconcileJobOrder`); an abandoned checkout leaves the ticket intact.
  Future<void> _billOut(JobOrderEntity jobOrder) async {
    // Tapping a button doesn't blur the notes field, so a focused edit would
    // otherwise miss the blur commit and the sale would carry stale notes.
    // _persist updates _working synchronously before its await, so the
    // refreshed copy is ready right after this call.
    _commitNotes();
    final ticket = _working ?? jobOrder;
    if (!jobOrderReadyToBillOut(ticket)) {
      context.showWarningSnackBar('Set the motorcycle model to bill out');
      return;
    }

    if (ref.read(unsettledBusinessDayProvider).valueOrNull != null) {
      context.showWarningSnackBar(
        'Close the previous day before billing out',
      );
      return;
    }

    // Guard: don't clobber an unfinished walk-in sale sitting in the
    // register. hasBillableContent (not isNotEmpty) so a fee-only register
    // cart is not silently clobbered without warning.
    final cart = ref.read(cartProvider);
    if (cart.hasBillableContent) {
      final proceed = await showAppConfirmDialog(
        context,
        title: 'Register in use',
        message: 'There is an unfinished sale in the register. Bill out this '
            'job order anyway? The current sale will be cleared.',
        confirmLabel: 'Bill out',
        icon: LucideIcons.refreshCw,
      );
      if (!proceed || !mounted) return;
    }

    ref.read(cartProvider.notifier).loadFromJobOrder(ticket);
    ref.read(selectedJobOrderProvider.notifier).state = null;
    if (mounted) context.go(RoutePaths.checkout);
  }

  Future<void> _confirmDelete(JobOrderEntity jobOrder) async {
    await showDeleteJobOrderDialog(
        context, jobOrder, () => _deleteJobOrder(jobOrder));
  }

  Future<void> _deleteJobOrder(JobOrderEntity jobOrder) async {
    try {
      final actor = ref.read(currentUserProvider).value;
      if (actor == null) return;
      final success = await context.runWithWaiting(
        () => ref
            .read(jobOrderOperationsProvider.notifier)
            .deleteJobOrder(actor: actor, jobOrderId: jobOrder.id),
        message: 'Deleting…',
      );

      if (success && mounted) {
        context.showSuccessSnackBar('Job order deleted');
        context.go(RoutePaths.jobOrders);
      } else if (!success && mounted) {
        // Deleting stays creator-or-admin even though editing is shared —
        // surface the rejection instead of a silent dead tap.
        final err = ref.read(jobOrderOperationsProvider).asError?.error;
        context
            .showErrorSnackBar(err?.toString() ?? 'Failed to delete job order');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error deleting job order: $e');
      }
    }
  }
}
