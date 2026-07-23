import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_expense_list.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// End-of-day review + close flow for the current business day.
///
/// Shows the sales + expenses figures, captures the opening float and counted
/// cash, surfaces the variance, and persists the closing. If the day is
/// already closed, renders the saved record read-only.
class EndOfDayScreen extends ConsumerStatefulWidget {
  const EndOfDayScreen({super.key});

  @override
  ConsumerState<EndOfDayScreen> createState() => _EndOfDayScreenState();
}

class _EndOfDayScreenState extends ConsumerState<EndOfDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _floatController = TextEditingController();
  final _countedController = TextEditingController();
  final _plateDpController = TextEditingController();
  final _plateDeliveryController = TextEditingController();
  final _notesController = TextEditingController();
  bool _busy = false;

  /// Same-day expenses removed from this closing's reconciliation. Session
  /// state only — persisted onto the closing when the day is closed.
  final Set<String> _excludedIds = {};

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _countedController.dispose();
    _plateDpController.dispose();
    _plateDeliveryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _float => double.tryParse(_floatController.text) ?? 0;
  double? get _counted => double.tryParse(_countedController.text);
  double get _plateDp => double.tryParse(_plateDpController.text) ?? 0;
  double get _plateDelivery =>
      double.tryParse(_plateDeliveryController.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final existingAsync = ref.watch(dailyClosingForDateProvider(_today));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        title: const Text('End-of-Day Closing'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history),
            tooltip: 'History',
            onPressed: () => context.pushNamed(RouteNames.endOfDayHistory),
          ),
        ],
      ),
      body: existingAsync.when(
        loading: () => const FormSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Error: $e',
          onRetry: () => ref.invalidate(dailyClosingForDateProvider(_today)),
        ),
        data: (existing) => existing != null
            ? _ClosedView(closing: existing, date: _today)
            : _buildReview(),
      ),
    );
  }

  Widget _buildReview() {
    final dataAsync = ref.watch(dailyClosingDataProvider(_today));
    return dataAsync.when(
      loading: () => const FormSkeleton(),
      error: (e, _) => ErrorStateView(
        message: 'Error: $e',
        onRetry: () => ref.invalidate(dailyClosingDataProvider(_today)),
      ),
      data: (data) {
        final draft = data.draftExcluding(_excludedIds);
        final expected = draft.expectedCashFor(
          _float,
          plateNoDp: _plateDp,
          plateNoDelivery: _plateDelivery,
        );
        final counted = _counted;
        final variance = counted == null ? null : counted - expected;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClosingSectionCard(
                  icon: LucideIcons.receipt,
                  title: 'Sales',
                  children: [
                    ClosingKvRow(
                        label: 'Gross sales', value: _peso(draft.grossSales)),
                    ClosingKvRow(
                        label: 'Cash sales', value: _peso(draft.cashSales)),
                    ClosingKvRow(
                        label: 'Non-cash sales',
                        value: _peso(draft.nonCashSales)),
                    if (draft.gcashSales > 0)
                      ClosingKvRow(
                          label: 'GCash',
                          value: _peso(draft.gcashSales),
                          indented: true),
                    if (draft.mayaSales > 0)
                      ClosingKvRow(
                          label: 'Maya',
                          value: _peso(draft.mayaSales),
                          indented: true),
                    ClosingKvRow(
                        label: 'Discounts', value: _peso(draft.totalDiscounts)),
                    if (draft.laborRevenue > 0)
                      ClosingKvRow(
                          label: 'Labor revenue (service)',
                          value: _peso(draft.laborRevenue)),
                    ClosingKvRow(
                        label: 'Sales count', value: '${draft.salesCount}'),
                    if (draft.salmonReceivable > 0)
                      ClosingKvRow(
                          label: 'Salmon receivable (next day)',
                          value: _peso(draft.salmonReceivable)),
                  ],
                ),
                const SizedBox(height: 12),
                ClosingSectionCard(
                  icon: LucideIcons.arrowDownCircle,
                  title: 'Expenses',
                  trailing: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => context.push(RoutePaths.expenseAdd),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Add Expense'),
                  ),
                  children: [
                    if (data.expenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No expenses today',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      ClosingExpenseList(
                        expenses: data.expenses,
                        excludedIds: _excludedIds,
                        enabled: !_busy,
                        onToggle: (id) => setState(() {
                          _excludedIds.contains(id)
                              ? _excludedIds.remove(id)
                              : _excludedIds.add(id);
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: AppColors.hairline(
                              Theme.of(context).brightness == Brightness.dark),
                        ),
                      ),
                      ClosingKvRow(
                          label: 'Total expenses',
                          value: _peso(draft.totalExpenses)),
                      ClosingKvRow(
                          label: 'Cash expenses',
                          value: _peso(draft.cashExpenses)),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                ClosingSectionCard(
                  icon: LucideIcons.clipboardList,
                  title: 'Plate No Orders',
                  children: [
                    ClosingField(
                      label: 'Plate No DP',
                      controller: _plateDpController,
                      enabled: !_busy,
                      hintText: '0',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    ClosingField(
                      label: 'Plate No Delivery',
                      controller: _plateDeliveryController,
                      enabled: !_busy,
                      hintText: '0',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClosingSectionCard(
                  icon: LucideIcons.calculator,
                  title: 'Cash reconciliation',
                  children: [
                    ClosingField(
                      label: 'Opening float',
                      controller: _floatController,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _expectedCashPanel(expected),
                    const SizedBox(height: 12),
                    ClosingField(
                      label: 'Counted cash',
                      controller: _countedController,
                      enabled: !_busy,
                      required: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Counted cash is required';
                        }
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    if (variance != null) ...[
                      const SizedBox(height: 12),
                      VariancePanel(variance: variance),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                ClosingField(
                  label: 'Notes',
                  controller: _notesController,
                  enabled: !_busy,
                  pesoPrefix: false,
                  hintText: 'Optional…',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                _closeDayButton(),
                const SizedBox(height: 9),
                Text(
                  "Closing locks the day — it can't be edited afterward.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _expectedCashPanel(double expected) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.emphasisTint(dark),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Expected cash',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(
            _peso(expected),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _closeDayButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF44336).withValues(alpha: 0.42),
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _busy
              ? const SizedBox.shrink()
              : const Icon(LucideIcons.lock, size: 18),
          label: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Close Day'),
        ),
      ),
    );
  }

  String _peso(double v) =>
      '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    final confirmed = await context.showConfirmDialog(
      title: 'Close this day?',
      message:
          'This saves the end-of-day closing. It cannot be edited afterward.',
      confirmText: 'Close Day',
      icon: LucideIcons.lock,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    final notes = _notesController.text.trim();
    final saved =
        await ref.read(dailyClosingOperationsProvider.notifier).closeDay(
              date: _today,
              openingFloat: _float,
              countedCash: _counted ?? 0,
              plateNoDp: _plateDp,
              plateNoDelivery: _plateDelivery,
              excludedExpenseIds: Set.of(_excludedIds),
              notes: notes.isEmpty ? null : notes,
            );
    if (!mounted) return;
    setState(() => _busy = false);

    if (saved == null) {
      final err = ref.read(dailyClosingOperationsProvider).error;
      context.showErrorSnackBar('Could not close day: ${err ?? 'unknown'}');
      return;
    }
    context.showSuccessSnackBar('Day closed');
  }
}

/// Read-only view of an already-saved closing.
///
/// Watches today's live sales summary so it can warn when sales were recorded
/// (or voided) after the day was closed — the snapshot is immutable, so those
/// later sales aren't reflected in the figures or counted cash below.
class _ClosedView extends ConsumerWidget {
  final DailyClosingEntity closing;
  final DateTime date;

  const _ClosedView({required this.closing, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The comparison draft must honor the snapshot's exclusions, or an
    // excluded expense would read as phantom "cash expenses after close".
    final liveData = ref.watch(dailyClosingDataProvider(date)).valueOrNull;
    final liveDraft =
        liveData?.draftExcluding(closing.excludedExpenseIds.toSet());
    final activity = liveDraft == null
        ? null
        : PostCloseActivity.between(closing: closing, current: liveDraft);
    final showActivity = activity != null && activity.hasChanged;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showActivity) ...[
            PostCloseWarningBanner(
                message: _postCloseMessage(context, activity)),
            const SizedBox(height: 12),
          ],
          ClosedByBanner(
            text: 'Closed by ${closing.closedByName} at '
                '${TimeOfDay.fromDateTime(closing.closedAt).format(context)}',
          ),
          const SizedBox(height: 12),
          ClosingSectionCard(
            icon: LucideIcons.receipt,
            title: 'Sales',
            children: [
              ClosingKvRow(
                  label: 'Gross sales', value: _peso(closing.grossSales)),
              ClosingKvRow(
                  label: 'Cash sales', value: _peso(closing.cashSales)),
              ClosingKvRow(
                  label: 'Non-cash sales', value: _peso(closing.nonCashSales)),
              if (closing.gcashSales > 0)
                ClosingKvRow(
                    label: 'GCash',
                    value: _peso(closing.gcashSales),
                    indented: true),
              if (closing.mayaSales > 0)
                ClosingKvRow(
                    label: 'Maya',
                    value: _peso(closing.mayaSales),
                    indented: true),
              ClosingKvRow(
                  label: 'Discounts', value: _peso(closing.totalDiscounts)),
              if (closing.laborRevenue > 0)
                ClosingKvRow(
                    label: 'Labor revenue (service)',
                    value: _peso(closing.laborRevenue)),
              if (closing.salmonReceivable > 0)
                ClosingKvRow(
                    label: 'Salmon receivable',
                    value: _peso(closing.salmonReceivable)),
            ],
          ),
          const SizedBox(height: 12),
          ClosingSectionCard(
            icon: LucideIcons.arrowDownCircle,
            title: 'Expenses',
            children: [
              ClosingKvRow(
                  label: 'Total expenses', value: _peso(closing.totalExpenses)),
              ClosingKvRow(
                  label: 'Cash expenses', value: _peso(closing.cashExpenses)),
            ],
          ),
          if (closing.plateNoDp > 0 || closing.plateNoDelivery > 0) ...[
            const SizedBox(height: 12),
            ClosingSectionCard(
              icon: LucideIcons.clipboardList,
              title: 'Plate No Orders',
              children: [
                ClosingKvRow(
                    label: 'Plate No DP', value: _peso(closing.plateNoDp)),
                ClosingKvRow(
                    label: 'Plate No Delivery',
                    value: _peso(closing.plateNoDelivery)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ClosingSectionCard(
            icon: LucideIcons.calculator,
            title: 'Cash reconciliation',
            children: [
              ClosingKvRow(
                  label: 'Opening float', value: _peso(closing.openingFloat)),
              ClosingKvRow(
                  label: 'Expected cash', value: _peso(closing.expectedCash)),
              ClosingKvRow(
                  label: 'Counted cash', value: _peso(closing.countedCash)),
              const SizedBox(height: 6),
              VariancePanel(variance: closing.variance),
            ],
          ),
          if (showActivity) ...[
            const SizedBox(height: 12),
            _afterCloseCard(context, activity),
          ],
          if (closing.notes != null) ...[
            const SizedBox(height: 12),
            ClosingSectionCard(
              icon: LucideIcons.stickyNote,
              title: 'Notes',
              children: [
                Text(
                  closing.notes!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _postCloseMessage(BuildContext context, PostCloseActivity activity) {
    final closedTime = TimeOfDay.fromDateTime(closing.closedAt).format(context);
    final amount =
        '${AppConstants.currencySymbol}${activity.grossDelta.abs().toCurrencyWithoutSymbol()}';
    return activity.isAdditional
        ? '${activity.extraSales} sale${activity.extraSales == 1 ? '' : 's'} '
            'totaling $amount were recorded after this day was closed at '
            '$closedTime. See "After close" below for the updated cash on hand.'
        : 'Activity changed after this day was closed at $closedTime. '
            'See "After close" below for the updated cash on hand.';
  }

  Widget _afterCloseCard(BuildContext context, PostCloseActivity activity) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String signed(double v) =>
        '${v >= 0 ? '+' : '-'}${AppConstants.currencySymbol}${v.abs().toCurrencyWithoutSymbol()}';

    return ClosingSectionCard(
      icon: LucideIcons.clock,
      title: 'After close',
      iconColor: AppColors.warningIcon(isDark),
      children: [
        ClosingKvRow(
          label: 'Sales after close',
          value: '${activity.extraSales >= 0 ? '+' : ''}${activity.extraSales}'
              ' · ${signed(activity.grossDelta)}',
        ),
        ClosingKvRow(
            label: 'Cash collected after close',
            value: signed(activity.cashSalesDelta)),
        if (activity.cashExpensesDelta.abs() > 0.005)
          ClosingKvRow(
              label: 'Cash expenses after close',
              value: signed(-activity.cashExpensesDelta)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Divider(height: 1, color: AppColors.hairline(isDark)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Updated cash on hand',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            Text(
              _peso(activity.updatedCashOnHand),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _peso(double v) =>
      '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';
}
