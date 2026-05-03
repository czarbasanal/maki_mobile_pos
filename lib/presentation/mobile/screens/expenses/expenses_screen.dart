import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Expenses list screen.
///
/// Role-based behavior:
/// - Admin: Full CRUD on expenses.
/// - Staff/Cashier: Can view and add expenses. Cannot edit or delete.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Expenses'),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const EmptyStateView(
              icon: CupertinoIcons.doc_text,
              title: 'No Expenses',
              subtitle: 'Tap + to add an expense',
            );
          }

          final currencyFormat = NumberFormat.currency(
            symbol: AppConstants.currencySymbol,
            decimalDigits: 2,
          );
          final dateFormat = DateFormat('MMM d, y • h:mm a');

          final theme = Theme.of(context);
          final muted = theme.colorScheme.onSurfaceVariant;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final card = Card(
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
                  ),
                  subtitle: Text(
                    dateFormat.format(expense.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  trailing: Text(
                    currencyFormat.format(expense.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: canEdit
                      ? () => context
                          .push('${RoutePaths.expenses}/edit/${expense.id}')
                      : null,
                  onLongPress: canDelete
                      ? () => _confirmAndDelete(context, ref, expense)
                      : null,
                ),
              );

              if (!canDelete) return card;

              return Dismissible(
                key: ValueKey('expense-${expense.id}'),
                direction: DismissDirection.endToStart,
                background: _buildDismissBackground(),
                confirmDismiss: (_) =>
                    _confirmAndDelete(context, ref, expense),
                child: card,
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(expensesProvider),
        ),
      ),
      // Primary action — available to all roles with addExpense permission.
      bottomNavigationBar: canAdd
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(RoutePaths.expenseAdd),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('Add Expense'),
                ),
              ),
            )
          : null,
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
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.delete, color: Colors.white),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

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
