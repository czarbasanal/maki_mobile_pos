import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/expense_filters.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Full expense history grouped by month and year.
///
/// Reads from the same [expensesProvider] stream the dashboard uses (most
/// recent 50). Pagination beyond that is out of scope for now — extend the
/// provider when needed. Honours an optional initial category filter passed
/// via route query param so deep-linking from the dashboard preserves
/// context.
class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  static final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );
  static final _dateFormat = DateFormat('MMM d, y');
  static final _monthHeaderFormat = DateFormat('MMMM y');

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.expenses),
        ),
        title: const Text('Expense History'),
      ),
      body: expensesAsync.when(
        data: (expenses) => _buildBody(expenses),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(expensesProvider),
        ),
      ),
    );
  }

  Widget _buildBody(List<ExpenseEntity> expenses) {
    final filtered = _selectedCategory == null
        ? expenses
        : expenses.where((e) => e.category == _selectedCategory).toList();
    final groups = groupExpensesByMonthYear(filtered);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: _HistoryCategoryFilter(
              selectedCategory: _selectedCategory,
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
          ),
        ),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateView(
              icon: CupertinoIcons.doc_text,
              title: _selectedCategory == null ? 'No Expenses' : 'No matches',
              subtitle: _selectedCategory == null
                  ? 'Recorded expenses will appear here.'
                  : 'No expenses in "$_selectedCategory" yet.',
            ),
          )
        else
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: _MonthHeader(
                label: _monthHeaderFormat.format(group.monthStart),
                count: group.items.length,
                total: group.items.fold<double>(0, (sum, e) => sum + e.amount),
              ),
            ),
            SliverList.builder(
              itemCount: group.items.length,
              itemBuilder: (context, i) => _ExpenseHistoryItem(
                expense: group.items[i],
                dateFormat: _dateFormat,
                currencyFormat: _currencyFormat,
              ),
            ),
          ],
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.md)),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
          Text(
            '$count • ${NumberFormat.currency(symbol: AppConstants.currencySymbol, decimalDigits: 2).format(total)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _ExpenseHistoryItem extends StatelessWidget {
  const _ExpenseHistoryItem({
    required this.expense,
    required this.dateFormat,
    required this.currencyFormat,
  });

  final ExpenseEntity expense;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        leading: Icon(
          CupertinoIcons.doc_plaintext,
          color: muted,
          size: 24,
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${dateFormat.format(expense.date)} • ${expense.category}',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        trailing: Text(
          currencyFormat.format(expense.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Local copy of the dashboard's category filter dropdown. Kept private to
/// this file to avoid a premature shared-widget extraction; lift to a public
/// widget if a third call site appears.
class _HistoryCategoryFilter extends ConsumerWidget {
  const _HistoryCategoryFilter({
    required this.selectedCategory,
    required this.onChanged,
  });

  final String? selectedCategory;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync =
        ref.watch(activeCategoriesProvider(CategoryKind.expense));

    return categoriesAsync.when(
      data: (entries) {
        final activeNames = entries.map((e) => e.name).toSet().toList();
        final isOrphan = selectedCategory != null &&
            selectedCategory!.isNotEmpty &&
            !activeNames.contains(selectedCategory);

        final items = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All categories'),
          ),
          ...activeNames.map(
            (name) => DropdownMenuItem<String?>(
              value: name,
              child: Text(name),
            ),
          ),
          if (isOrphan)
            DropdownMenuItem<String?>(
              value: selectedCategory,
              child: Text(
                '$selectedCategory (inactive)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ];

        return DropdownButtonFormField<String?>(
          initialValue: selectedCategory,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(CupertinoIcons.tag),
          ),
          items: items,
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Could not load categories'),
    );
  }
}
