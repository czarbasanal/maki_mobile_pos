import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Expenses'),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const EmptyStateView(
              icon: Icons.receipt_long,
              title: 'No Expenses',
              subtitle: 'Tap + to add an expense',
            );
          }

          final currencyFormat = NumberFormat.currency(
            symbol: AppConstants.currencySymbol,
            decimalDigits: 2,
          );
          final dateFormat = DateFormat('MMM d, y • h:mm a');

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: const Icon(Icons.receipt, color: Colors.orange),
                  ),
                  title: Text(
                    expense.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    dateFormat.format(expense.createdAt),
                  ),
                  trailing: Text(
                    currencyFormat.format(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  onTap: canEdit
                      ? () => context
                          .push('${RoutePaths.expenses}/edit/${expense.id}')
                      : null,
                  // Only show edit/delete for admin
                  onLongPress: canDelete
                      ? () => _showDeleteConfirmation(context, ref, expense)
                      : null,
                ),
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
      // FAB for adding expense - available to all roles with addExpense permission
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => context.push(RoutePaths.expenseAdd),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, ExpenseEntity expense) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(expenseOperationsProvider.notifier)
                    .deleteExpense(expense.id);
                if (context.mounted) {
                  context.showSuccessSnackBar('Expense deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showErrorSnackBar('Failed to delete: $e');
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
