import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
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
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.receiving),
        ),
        title: const Text('Draft Receivings'),
      ),
      body: draftsAsync.when(
        data: (drafts) {
          if (drafts.isEmpty) {
            return const EmptyStateView(
              icon: CupertinoIcons.square_pencil,
              title: 'No Drafts',
              subtitle: 'In-progress receivings appear here',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: drafts.length,
            itemBuilder: (context, index) =>
                _DraftItem(draft: drafts[index], dateFormat: dateFormat),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(CupertinoIcons.square_pencil, color: Colors.orange[700]),
        ),
        title: Text(
          draft.referenceNumber,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${draft.uniqueProductCount} item(s) • ${draft.totalQuantity} units',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            Text(
              dateFormat.format(draft.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: () =>
              context.push('${RoutePaths.bulkReceiving}/${draft.id}'),
          child: const Text('Resume'),
        ),
        onTap: () => context.push('${RoutePaths.bulkReceiving}/${draft.id}'),
      ),
    );
  }
}
