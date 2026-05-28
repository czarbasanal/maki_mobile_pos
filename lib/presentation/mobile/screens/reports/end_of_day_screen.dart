import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

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
  final _notesController = TextEditingController();
  bool _busy = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _countedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _float => double.tryParse(_floatController.text) ?? 0;
  double? get _counted => double.tryParse(_countedController.text);

  @override
  Widget build(BuildContext context) {
    final existingAsync = ref.watch(dailyClosingForDateProvider(_today));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        title: const Text('End-of-Day Closing'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.clock),
            tooltip: 'History',
            onPressed: () => context.pushNamed(RouteNames.endOfDayHistory),
          ),
        ],
      ),
      body: existingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (existing) => existing != null
            ? _ClosedView(closing: existing, date: _today)
            : _buildReview(),
      ),
    );
  }

  Widget _buildReview() {
    final draftAsync = ref.watch(dailyClosingDraftProvider(_today));
    return draftAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (draft) {
        final expected = draft.expectedCashFor(_float);
        final counted = _counted;
        final variance = counted == null ? null : counted - expected;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('Sales', [
                  _row('Gross sales', draft.grossSales),
                  _row('Cash sales', draft.cashSales),
                  _row('Non-cash sales', draft.nonCashSales),
                  _row('Discounts', draft.totalDiscounts),
                  _rowText('Sales count', '${draft.salesCount}'),
                  if (draft.salmonReceivable > 0)
                    _row('Salmon receivable (next day)',
                        draft.salmonReceivable),
                ]),
                const SizedBox(height: 16),
                _section('Expenses', [
                  _row('Total expenses', draft.totalExpenses),
                  _row('Cash expenses', draft.cashExpenses),
                ]),
                const SizedBox(height: 16),
                _section('Cash reconciliation', [
                  TextFormField(
                    controller: _floatController,
                    enabled: !_busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Opening float',
                      prefixText: '₱ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _row('Expected cash', expected, emphasize: true),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countedController,
                    enabled: !_busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Counted cash *',
                      prefixText: '₱ ',
                    ),
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
                    _varianceRow(variance),
                  ],
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  enabled: !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Close Day'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close this day?'),
        content: const Text(
          'This saves the end-of-day closing. It cannot be edited afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close Day'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final notes = _notesController.text.trim();
    final saved =
        await ref.read(dailyClosingOperationsProvider.notifier).closeDay(
              date: _today,
              openingFloat: _float,
              countedCash: _counted ?? 0,
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

  Widget _section(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool emphasize = false}) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            '${AppConstants.currencySymbol}${value.toCurrencyWithoutSymbol()}',
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _rowText(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _varianceRow(double variance) {
    final theme = Theme.of(context);
    final color = variance == 0
        ? AppColors.successDark
        : (variance < 0 ? AppColors.error : AppColors.warningDark);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Variance', style: theme.textTheme.bodyMedium),
        Text(
          '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toCurrencyWithoutSymbol()}',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
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
    final theme = Theme.of(context);
    final variance = closing.variance;
    final varianceColor = variance == 0
        ? AppColors.successDark
        : (variance < 0 ? AppColors.error : AppColors.warningDark);

    final liveDraft = ref.watch(dailyClosingDraftProvider(date)).valueOrNull;
    final activity = liveDraft == null
        ? null
        : PostCloseActivity.between(closing: closing, current: liveDraft);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activity != null && activity.hasChanged) ...[
            _postCloseBanner(context, activity),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.successDark),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_seal,
                    color: AppColors.successDark),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Closed by ${closing.closedByName} at '
                    '${TimeOfDay.fromDateTime(closing.closedAt).format(context)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(context, 'Sales', {
            'Gross sales': closing.grossSales,
            'Cash sales': closing.cashSales,
            'Non-cash sales': closing.nonCashSales,
            'Discounts': closing.totalDiscounts,
            if (closing.salmonReceivable > 0)
              'Salmon receivable': closing.salmonReceivable,
          }),
          const SizedBox(height: 16),
          _card(context, 'Expenses', {
            'Total expenses': closing.totalExpenses,
            'Cash expenses': closing.cashExpenses,
          }),
          const SizedBox(height: 16),
          _card(context, 'Cash reconciliation', {
            'Opening float': closing.openingFloat,
            'Expected cash': closing.expectedCash,
            'Counted cash': closing.countedCash,
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Variance', style: theme.textTheme.titleMedium),
                Text(
                  '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toCurrencyWithoutSymbol()}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: varianceColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (activity != null && activity.hasChanged) ...[
            const SizedBox(height: 16),
            _afterCloseSection(context, activity),
          ],
          if (closing.notes != null) ...[
            const SizedBox(height: 16),
            Text('Notes: ${closing.notes}', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _postCloseBanner(BuildContext context, PostCloseActivity activity) {
    final theme = Theme.of(context);
    final closedTime =
        TimeOfDay.fromDateTime(closing.closedAt).format(context);
    final amount =
        '${AppConstants.currencySymbol}${activity.grossDelta.abs().toCurrencyWithoutSymbol()}';

    final message = activity.isAdditional
        ? '${activity.extraSales} sale${activity.extraSales == 1 ? '' : 's'} '
            'totaling $amount were recorded after this day was closed at '
            '$closedTime. See "After close" below for the updated cash on hand.'
        : 'Activity changed after this day was closed at $closedTime. '
            'See "After close" below for the updated cash on hand.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle,
              color: AppColors.warningDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.warningDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _afterCloseSection(BuildContext context, PostCloseActivity activity) {
    final theme = Theme.of(context);
    String signed(double v) =>
        '${v >= 0 ? '+' : '-'}${AppConstants.currencySymbol}${v.abs().toCurrencyWithoutSymbol()}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('After close',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            _kvText(
              context,
              'Sales after close',
              '${activity.extraSales >= 0 ? '+' : ''}${activity.extraSales} '
                  '· ${signed(activity.grossDelta)}',
            ),
            _kvText(context, 'Cash collected after close',
                signed(activity.cashSalesDelta)),
            if (activity.cashExpensesDelta.abs() > 0.005)
              _kvText(context, 'Cash expenses after close',
                  signed(-activity.cashExpensesDelta)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Updated cash on hand',
                    style: theme.textTheme.titleMedium),
                Text(
                  '${AppConstants.currencySymbol}${activity.updatedCashOnHand.toCurrencyWithoutSymbol()}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvText(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, Map<String, double> rows) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            ...rows.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: theme.textTheme.bodyMedium),
                    Text(
                      '${AppConstants.currencySymbol}${e.value.toCurrencyWithoutSymbol()}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
