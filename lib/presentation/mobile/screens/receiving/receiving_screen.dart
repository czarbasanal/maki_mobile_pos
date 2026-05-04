import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/receiving_widgets.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Main receiving screen showing history and entry point for new receivings.
class ReceivingScreen extends ConsumerWidget {
  const ReceivingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The screen surfaces only this week's receivings; "View all"
    // navigates to the full grouped history.
    final weeklyAsync = ref.watch(currentWeekReceivingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Receiving'),
      ),
      body: Column(
        children: [
          // Summary cards
          ReceivingSummaryCardsRow(
            onTapDrafts: () => context.push(RoutePaths.receivingDrafts),
            onTapCompleted: () => context.push(RoutePaths.receivingHistory),
          ),

          // Section header — Recent Receivings (this week) + View all.
          _SectionHeader(
            title: 'Recent Receivings',
            onViewAll: () => context.push(RoutePaths.receivingHistory),
          ),

          // This-week list
          Expanded(
            child: weeklyAsync.when(
              data: (receivings) =>
                  _buildReceivingsList(context, ref, receivings),
              loading: () => const LoadingView(),
              error: (error, _) => ErrorStateView(
                message: 'Error: $error',
                onRetry: () => ref.invalidate(recentReceivingsProvider),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _startNewReceiving(context, ref),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('New Receiving'),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivingsList(
    BuildContext context,
    WidgetRef ref,
    List<ReceivingEntity> receivings,
  ) {
    if (receivings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.cube_box, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nothing yet this week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "View all" to see earlier records',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, y • h:mm a');
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;

    return ListView.builder(
      itemCount: receivings.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final receiving = receivings[index];
        return _buildReceivingItem(context, receiving, dateFormat, isAdmin);
      },
    );
  }

  Widget _buildReceivingItem(
    BuildContext context,
    ReceivingEntity receiving,
    DateFormat dateFormat,
    bool isAdmin,
  ) {
    final theme = Theme.of(context);
    final (bg, fg, icon) = _statusVisuals(receiving.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: fg),
        ),
        title: Text(
          receiving.referenceNumber,
          style: AppTextStyles.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateFormat.format(receiving.completedAt ?? receiving.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (receiving.supplierName != null)
              Text(
                receiving.supplierName!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                receiving.status.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${receiving.totalQuantity} items',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (isAdmin)
              Text(
                '${AppConstants.currencySymbol}${receiving.totalCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        onTap: () =>
            context.push('${RoutePaths.bulkReceiving}/${receiving.id}'),
      ),
    );
  }

  (Color, Color, IconData) _statusVisuals(ReceivingStatus status) {
    switch (status) {
      case ReceivingStatus.completed:
        return (Colors.green[50]!, Colors.green[700]!,
            CupertinoIcons.checkmark_circle);
      case ReceivingStatus.draft:
        return (Colors.orange[50]!, Colors.orange[700]!,
            CupertinoIcons.square_pencil);
      case ReceivingStatus.cancelled:
        return (Colors.grey[200]!, Colors.grey[700]!, CupertinoIcons.xmark);
    }
  }

  Future<void> _startNewReceiving(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(currentReceivingProvider.notifier).initNewReceiving();
    } catch (e) {
      // Surface failures (e.g. Firestore can't generate the reference
      // number) instead of swallowing them — without this the button
      // looks broken because navigation never runs.
      if (context.mounted) {
        context.showErrorSnackBar('Could not start a new receiving: $e');
      }
      return;
    }

    if (context.mounted) {
      context.push(RoutePaths.bulkReceiving);
    }
  }
}

/// Inline section header with a "View all" trailing TextButton on the
/// right. Kept private to this screen — if other screens need the same
/// shape we can promote it later.
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View all'),
          ),
        ],
      ),
    );
  }
}
