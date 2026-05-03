import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/permissions/permissions.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/petty_cash_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/petty_cash/cut_off_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Petty cash dashboard. Lists recent transactions and shows the running
/// balance. Admin-only (gated by [Permission.managePettyCash]).
class PettyCashScreen extends ConsumerWidget {
  const PettyCashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(pettyCashBalanceProvider);
    final recordsAsync = ref.watch(pettyCashRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Petty Cash'),
        actions: [
          PermissionGate(
            permission: Permission.performCutOff,
            child: IconButton(
              tooltip: 'End-of-day cut-off',
              icon: const Icon(CupertinoIcons.function),
              onPressed: () => _openCutOff(context, ref),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _BalanceHeader(balanceAsync: balanceAsync),
          const Divider(height: 1),
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const EmptyStateView(
                    icon: CupertinoIcons.money_dollar_circle,
                    title: 'No petty cash transactions yet',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pettyCashRecordsProvider);
                    ref.invalidate(pettyCashBalanceProvider);
                  },
                  child: ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _RecordTile(record: records[i]),
                  ),
                );
              },
              loading: () => const LoadingView(),
              error: (e, _) => ErrorStateView(
                message: 'Failed to load records: $e',
                onRetry: () => ref.invalidate(pettyCashRecordsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: Permission.managePettyCash,
        child: FloatingActionButton.extended(
          onPressed: () => context.go(RoutePaths.pettyCashNew),
          icon: const Icon(CupertinoIcons.add),
          label: const Text('New entry'),
        ),
      ),
    );
  }

  Future<void> _openCutOff(BuildContext context, WidgetRef ref) async {
    final balance = await ref.read(pettyCashBalanceProvider.future);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => CutOffDialog(currentBalance: balance),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final AsyncValue<double> balanceAsync;

  const _BalanceHeader({required this.balanceAsync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current balance',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              )),
          const SizedBox(height: 4),
          balanceAsync.when(
            data: (balance) => Text(
              '${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            loading: () => const SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text('—', style: theme.textTheme.headlineMedium),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final PettyCashEntity record;

  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isOut =
        record.type == PettyCashType.cashOut || record.amount < 0;
    final isCutOff = record.type == PettyCashType.cutOff;
    final color = isCutOff
        ? Colors.indigo
        : (isOut ? Colors.red.shade700 : Colors.green.shade700);
    final sign = isOut ? '-' : '+';
    final dateFormat = DateFormat('MMM d, h:mm a');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(40),
        child: Icon(
          isCutOff
              ? CupertinoIcons.function
              : (isOut ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up),
          color: color,
        ),
      ),
      title: Text(record.description),
      subtitle: Text(
        '${record.type.displayName} • ${dateFormat.format(record.createdAt)} • ${record.createdByName}',
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isCutOff
                ? '${AppConstants.currencySymbol}${record.amount.toStringAsFixed(2)}'
                : '$sign${AppConstants.currencySymbol}${record.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            'Bal: ${AppConstants.currencySymbol}${record.balance.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
