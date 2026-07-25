import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Caps how many recent void requests the notification sheet shows.
const _maxEntries = 20;

/// Opens the void-request notification sheet (from the dashboard bell).
///
/// Rounded-top modal bottom sheet mirroring the app's other sheet chrome
/// (see the resolve sheet in `void_requests_screen.dart`).
Future<void> showVoidRequestNotificationSheet(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (_) => const _VoidRequestNotificationSheet(),
  );
}

class _VoidRequestNotificationSheet extends ConsumerWidget {
  const _VoidRequestNotificationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final hairline = dark ? AppColors.darkHairline : AppColors.lightDivider;
    final requests = (ref.watch(voidRequestsProvider).valueOrNull ??
            const <VoidRequestEntity>[])
        .take(_maxEntries)
        .toList();
    final unread = ref.watch(unreadVoidRequestCountProvider);

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: dark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x80000000) : const Color(0x29111C1D),
            blurRadius: 34,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            decoration: BoxDecoration(
              color:
                  dark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(
              children: [
                Text(
                  'Void requests',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 18, height: 1.2),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  _UnreadChip(count: unread),
                ],
              ],
            ),
          ),
          Flexible(
            child: requests.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: EmptyStateView(
                      icon: LucideIcons.bell,
                      title: 'No void requests',
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemCount: requests.length,
                    itemBuilder: (context, i) => _Entry(request: requests[i]),
                  ),
          ),
          Container(
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: hairline))),
            width: double.infinity,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.voidRequests);
                  },
                  child: const Text('View all'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadChip extends StatelessWidget {
  const _UnreadChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Entry extends ConsumerWidget {
  const _Entry({required this.request});
  final VoidRequestEntity request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final unread = !request.read;

    final detail = [
      request.saleNumber,
      '₱${request.saleGrandTotal.toCurrencyWithoutSymbol()}',
      if (request.itemsSummary != null && request.itemsSummary!.isNotEmpty)
        request.itemsSummary!,
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pop(context);
        // Fire-and-forget: the sheet has already popped, so the caller
        // doesn't need to await this before navigating.
        ref.read(voidRequestOperationsProvider.notifier).markRead(request.id);
        context.push(RoutePaths.voidRequests);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          '${request.requestedByName} sent a void request',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 12.5, color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _relativeTime(request.createdAt),
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `<60m` → `Xm ago`; `<24h` → `Xh ago`; else the calendar date (`MMM d`).
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes < 0 ? 0 : diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('MMM d').format(dt);
}
