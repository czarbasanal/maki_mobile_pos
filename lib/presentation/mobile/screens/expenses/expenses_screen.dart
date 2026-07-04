import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/expense_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/summary_card.dart';
import 'package:intl/intl.dart';

/// Expenses dashboard.
///
/// Mini totals row (Today / Week-to-date / Month-to-date) sits above the
/// expense list. Filter dropdown and "View all" history link are added in
/// later chunks; for now this is the totals + flat list.
///
/// Role-based behavior:
/// - Admin: Full CRUD on expenses.
/// - Staff/Cashier: Can view and add expenses. Cannot edit or delete.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  static const int _recentLimit = 5;

  static final _dateFormat = DateFormat('MMM d, y • h:mm a');

  /// Selected category filter; `null` means "All" (no filter).
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final userRole = currentUser?.role ?? UserRole.cashier;
    final canAdd =
        RolePermissions.hasPermission(userRole, Permission.addExpense);
    final canEdit =
        RolePermissions.hasPermission(userRole, Permission.editExpense);
    final canDelete =
        RolePermissions.hasPermission(userRole, Permission.deleteExpense);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Expenses'),
      ),
      body: expensesAsync.when(
        data: (expenses) => _buildBody(expenses, canEdit: canEdit, canDelete: canDelete),
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(expensesProvider),
        ),
      ),
      bottomNavigationBar: canAdd
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(RoutePaths.expenseAdd),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add Expense'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(
    List<ExpenseEntity> expenses, {
    required bool canEdit,
    required bool canDelete,
  }) {
    // Apply the active category filter to the displayed list. Totals refresh
    // automatically because they are bound to ExpenseDateRangeParams that
    // include the same category.
    final filtered = _selectedCategory == null
        ? expenses
        : expenses.where((e) => e.category == _selectedCategory).toList();
    final recent = filtered.take(_recentLimit).toList();

    final headerItems = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: _CategoryFilterDropdown(
          selectedCategory: _selectedCategory,
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: _ExpenseTotalsRow(category: _selectedCategory),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: _RecentSectionHeader(
          onViewAll: () => _openHistory(context),
        ),
      ),
    ];

    if (recent.isEmpty) {
      return ListView(
        children: [
          ...headerItems,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyStateView(
              icon: LucideIcons.fileText,
              title: _selectedCategory == null ? 'No Expenses' : 'No matches',
              subtitle: _selectedCategory == null
                  ? 'Tap + to add an expense'
                  : 'No expenses in "$_selectedCategory" yet.',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      itemCount: recent.length + headerItems.length,
      itemBuilder: (context, index) {
        if (index < headerItems.length) {
          return headerItems[index];
        }
        final expense = recent[index - headerItems.length];
        return _buildExpenseCard(
          expense,
          canEdit: canEdit,
          canDelete: canDelete,
        );
      },
    );
  }

  void _openHistory(BuildContext context) {
    final query = _selectedCategory == null
        ? ''
        : '?category=${Uri.encodeQueryComponent(_selectedCategory!)}';
    context.push('${RoutePaths.expenseHistory}$query');
  }

  Widget _buildExpenseCard(
    ExpenseEntity expense, {
    required bool canEdit,
    required bool canDelete,
  }) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      child: ExpenseRow(
        description: expense.description,
        subtitle: _dateFormat.format(expense.createdAt),
        amount: expense.amount,
        hasReceipt: expense.receiptImageUrl != null,
        onTap: canEdit
            ? () => context.push('${RoutePaths.expenses}/edit/${expense.id}')
            : null,
        onLongPress:
            canDelete ? () => _confirmAndDelete(context, ref, expense) : null,
      ),
    );

    if (!canDelete) return row;

    return Dismissible(
      key: ValueKey('expense-${expense.id}'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) => _confirmAndDelete(context, ref, expense),
      child: row,
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.trash2, color: Colors.white, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmAndDelete(
      BuildContext context, WidgetRef ref, ExpenseEntity expense) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete expense?',
      message: '"${expense.description}" will be permanently deleted.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed) return false;

    try {
      final ok = await ref
          .read(expenseOperationsProvider.notifier)
          .deleteExpense(expense.id);
      if (!ok) throw Exception('Delete failed');
      if (context.mounted) {
        context.showSuccessSnackBar('Expense deleted');
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnackBar('Failed to delete: $e');
      }
      return false;
    }
  }
}

/// Three-up summary row — Today / Week-to-date / Month-to-date totals.
///
/// Each card watches [totalExpensesProvider] with its own date range. The
/// optional [category] threads through [ExpenseDateRangeParams.category].
class _ExpenseTotalsRow extends ConsumerWidget {
  const _ExpenseTotalsRow({this.category});

  final String? category;

  static final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final endOfToday = now.endOfDay;

    final todayParams = ExpenseDateRangeParams(
      startDate: now.startOfDay,
      endDate: endOfToday,
      category: category,
    );
    final weekParams = ExpenseDateRangeParams(
      startDate: now.startOfWeek,
      endDate: endOfToday,
      category: category,
    );
    final monthParams = ExpenseDateRangeParams(
      startDate: now.startOfMonth,
      endDate: endOfToday,
      category: category,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TotalCard(
              title: 'Today',
              icon: LucideIcons.sun,
              params: todayParams,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TotalCard(
              title: 'This Week',
              icon: LucideIcons.calendar,
              params: weekParams,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TotalCard(
              title: 'This Month',
              icon: LucideIcons.barChart3,
              params: monthParams,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends ConsumerWidget {
  const _TotalCard({
    required this.title,
    required this.icon,
    required this.params,
  });

  final String title;
  final IconData icon;
  final ExpenseDateRangeParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalExpensesProvider(params));
    return SummaryCard(
      title: title,
      value: totalAsync.maybeWhen(
        data: (total) => _ExpenseTotalsRow._currencyFormat.format(total),
        orElse: () => '—',
      ),
      icon: icon,
      compact: true,
      loading: totalAsync.isLoading,
    );
  }
}

/// Category filter dropdown sourced from the admin-managed expense list.
///
/// `null` selection means "All". When the active selection is no longer in
/// the active list (deactivated, deleted) it is shown inline as
/// `<name> (inactive)` so existing records remain understandable.
class _CategoryFilterDropdown extends ConsumerWidget {
  const _CategoryFilterDropdown({
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

        return AppDropdown<String?>(
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(LucideIcons.tag),
          ),
          items: items,
          onChanged: onChanged,
        );
      },
      loading: () => const FieldSkeleton(),
      error: (_, __) => const Text('Could not load categories'),
    );
  }
}

/// Section header rendered above the recent list. Title on the left,
/// `View all →` link on the right that opens the grouped month-year view.
class _RecentSectionHeader extends StatelessWidget {
  const _RecentSectionHeader({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('View all'),
              SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 14),
            ],
          ),
        ),
      ],
    );
  }
}
