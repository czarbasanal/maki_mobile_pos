import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Full list of draft receivings with a Resume action on each row.
class ReceivingDraftsScreen extends ConsumerWidget {
  const ReceivingDraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftReceivingsProvider);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.receiving),
        ),
        title: const Text('Draft Receivings'),
      ),
      body: draftsAsync.when(
        data: (drafts) {
          if (drafts.isEmpty) {
            return const EmptyStateView(
              icon: LucideIcons.edit,
              title: 'No Drafts',
              subtitle: 'In-progress receivings appear here',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: drafts.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DraftItem(draft: drafts[index], dateFormat: dateFormat),
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(draftReceivingsProvider),
        ),
      ),
    );
  }
}

class _DraftItem extends StatelessWidget {
  final ReceivingEntity draft;
  final DateFormat dateFormat;

  const _DraftItem({required this.draft, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final warn = AppColors.warningIcon(isDark);
    final accent = isDark ? AppColors.primaryAccent : AppColors.brandSlate;

    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.all(13),
      onTap: () => context.push('${RoutePaths.bulkReceiving}/${draft.id}'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: warn.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(LucideIcons.edit, color: warn, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.referenceNumber,
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${draft.uniqueProductCount} item(s) · ${draft.totalQuantity} units · ${dateFormat.format(draft.createdAt)}',
                  style: TextStyle(fontSize: 12, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () =>
                context.push('${RoutePaths.bulkReceiving}/${draft.id}'),
            style: TextButton.styleFrom(
              foregroundColor: accent,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}
