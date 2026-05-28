import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Admin queue of void requests (opened from the dashboard notification bell).
class VoidRequestsScreen extends ConsumerWidget {
  const VoidRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voidRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Void Requests'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(voidRequestOperationsProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(message: 'Error: $e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyStateView(
              icon: CupertinoIcons.bell,
              title: 'No void requests',
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _row(context, ref, list[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    final df = DateFormat('MMM d, h:mm a');
    return ListTile(
      leading: Icon(
        r.isPending
            ? CupertinoIcons.clock
            : CupertinoIcons.check_mark_circled,
      ),
      title: Text(
        '${r.saleNumber} • ${AppConstants.currencySymbol}${r.saleGrandTotal.toStringAsFixed(2)}',
      ),
      subtitle: Text(
        '${r.requestedByName} • ${r.reason}\n${df.format(r.createdAt)} • ${r.status.value}',
      ),
      isThreeLine: true,
      trailing: r.read
          ? null
          : const Icon(Icons.brightness_1, size: 10, color: Colors.red),
      onTap: () async {
        await ref.read(voidRequestOperationsProvider.notifier).markRead(r.id);
        if (r.isPending && context.mounted) {
          _showResolveSheet(context, ref, r);
        }
      },
    );
  }

  void _showResolveSheet(
      BuildContext screenContext, WidgetRef ref, VoidRequestEntity r) {
    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => Column(
          children: [
            // Void context: requester + reason
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Void ${r.saleNumber}?',
                      style: Theme.of(screenContext).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Requested by ${r.requestedByName}'),
                  const SizedBox(height: 4),
                  Text('Reason: ${r.reason}'),
                ],
              ),
            ),
            const Divider(height: 1),
            // Receipt-style breakdown of the items being voided
            Expanded(
              child: Consumer(
                builder: (ctx, sheetRef, _) {
                  final saleAsync = sheetRef.watch(saleByIdProvider(r.saleId));
                  return saleAsync.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorStateView(message: 'Error: $e'),
                    data: (sale) => sale == null
                        ? const EmptyStateView(
                            icon: CupertinoIcons.doc_text,
                            title: 'Sale not found',
                          )
                        : ReceiptWidget(
                            sale: sale,
                            scrollController: scrollController,
                          ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _reject(screenContext, ref, r);
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _approve(screenContext, ref, r);
                        },
                        child: const Text('Approve'),
                      ),
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

  void _approve(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm with password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Your password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final pw = controller.text;
              Navigator.pop(context);
              final err = await ref
                  .read(voidRequestOperationsProvider.notifier)
                  .approve(request: r, password: pw);
              if (context.mounted) {
                err == null
                    ? context.showSuccessSnackBar('Sale voided')
                    : context.showErrorSnackBar(err);
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _reject(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final reason = controller.text;
              Navigator.pop(context);
              final err = await ref
                  .read(voidRequestOperationsProvider.notifier)
                  .reject(request: r, rejectionReason: reason);
              if (context.mounted) {
                err == null
                    ? context.showSuccessSnackBar('Request rejected')
                    : context.showErrorSnackBar(err);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
