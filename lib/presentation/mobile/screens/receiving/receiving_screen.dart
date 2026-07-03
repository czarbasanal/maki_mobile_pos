import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/receiving/receiving_widgets.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
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
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Receiving'),
        actions: [
          IconButton(
            tooltip: 'Purchase Orders',
            icon: const Icon(LucideIcons.clipboardList),
            onPressed: () => context.push(RoutePaths.purchaseOrders),
          ),
          IconButton(
            tooltip: 'Batch import (CSV)',
            icon: const Icon(LucideIcons.uploadCloud),
            onPressed: () => context.push(RoutePaths.batchImport),
          ),
        ],
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
              loading: () => const ListSkeleton(),
              error: (error, _) => ErrorStateView(
                message: 'Error: $error',
                onRetry: () => ref.invalidate(recentReceivingsProvider),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _NewReceivingFooter(
        onPressed: () => _startNewReceiving(context, ref),
      ),
    );
  }

  Widget _buildReceivingsList(
    BuildContext context,
    WidgetRef ref,
    List<ReceivingEntity> receivings,
  ) {
    if (receivings.isEmpty) {
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.package, size: 64, color: muted),
            const SizedBox(height: 16),
            Text(
              'Nothing yet this week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "View all" to see earlier records',
              style: TextStyle(color: muted),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemBuilder: (context, index) {
        final receiving = receivings[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildReceivingItem(context, receiving, dateFormat, isAdmin),
        );
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
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final s = _statusStyle(receiving.status, theme, isDark);

    final subtitle = receiving.supplierName != null
        ? '${dateFormat.format(receiving.completedAt ?? receiving.createdAt)} · ${receiving.supplierName}'
        : dateFormat.format(receiving.completedAt ?? receiving.createdAt);

    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('${RoutePaths.bulkReceiving}/${receiving.id}'),
      child: Row(
        children: [
          // Status leading circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: s.circleFill,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(s.icon, color: s.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Ref # + date · supplier
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiving.referenceNumber,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge + item count + ₱ total (admin)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: s.badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  receiving.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: s.badgeText,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${receiving.totalQuantity} items',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (isAdmin)
                Text(
                  receiving.totalCost.toCurrency(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Theme-aware status visuals for a receiving row: the leading-circle
  /// icon + tint, and the trailing status badge fill + text.
  _StatusStyle _statusStyle(
    ReceivingStatus status,
    ThemeData theme,
    bool isDark,
  ) {
    switch (status) {
      case ReceivingStatus.completed:
        return _StatusStyle(
          icon: LucideIcons.checkCircle,
          iconColor: AppColors.successIcon(isDark),
          circleFill: AppColors.success.withValues(alpha: isDark ? 0.16 : 0.10),
          badgeBg: AppColors.successFill(isDark),
          badgeText: AppColors.successText(isDark),
        );
      case ReceivingStatus.draft:
        final warn = AppColors.warningIcon(isDark);
        return _StatusStyle(
          icon: LucideIcons.edit,
          iconColor: warn,
          circleFill: warn.withValues(alpha: isDark ? 0.16 : 0.12),
          badgeBg: warn.withValues(alpha: isDark ? 0.18 : 0.14),
          badgeText: AppColors.warningBadgeText(isDark),
        );
      case ReceivingStatus.cancelled:
        final m = theme.colorScheme.onSurfaceVariant;
        return _StatusStyle(
          icon: LucideIcons.x,
          iconColor: m,
          circleFill: m.withValues(alpha: isDark ? 0.16 : 0.10),
          badgeBg: m.withValues(alpha: isDark ? 0.18 : 0.12),
          badgeText: m,
        );
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

/// Status visuals bundle for a receiving row.
class _StatusStyle {
  final IconData icon;
  final Color iconColor;
  final Color circleFill;
  final Color badgeBg;
  final Color badgeText;

  const _StatusStyle({
    required this.icon,
    required this.iconColor,
    required this.circleFill,
    required this.badgeBg,
    required this.badgeText,
  });
}

/// Pinned "New Receiving" footer — soft top shadow + primary button,
/// mirroring the inventory / sale-detail pinned action bars.
class _NewReceivingFooter extends StatelessWidget {
  final VoidCallback onPressed;

  const _NewReceivingFooter({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            boxShadow:
                isDark ? AppShadows.primaryButtonGold : AppShadows.primaryButton,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('New Receiving'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline section header with a "View all" trailing button on the
/// right. Kept private to this screen — if other screens need the same
/// shape we can promote it later.
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? AppColors.primaryAccent : AppColors.brandSlate,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View all'),
          ),
        ],
      ),
    );
  }
}
