import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/tag_colors.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

/// Bottom sheet for quick tag attach/detach on one product (the sweep
/// gesture: long-press a tile → tap a tag → done). Every tap writes the
/// composed tagIds list immediately via [ProductTagOperationsNotifier.setTags]
/// — only tagIds + audit fields, so it can never clobber a concurrent edit.
Future<void> showProductTagSheet(
  BuildContext context, {
  required ProductEntity product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ProductTagSheet(product: product),
  );
}

class _ProductTagSheet extends ConsumerStatefulWidget {
  const _ProductTagSheet({required this.product});
  final ProductEntity product;

  @override
  ConsumerState<_ProductTagSheet> createState() => _ProductTagSheetState();
}

class _ProductTagSheetState extends ConsumerState<_ProductTagSheet> {
  late final Set<String> _selected = Set.of(widget.product.tagIds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tagsAsync = ref.watch(activeTagsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No tags yet — create tags in Settings → Product Tags.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: tags.map((tag) {
                      final style = TagColors.styleFor(tag.color, isDark);
                      final selected = _selected.contains(tag.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: style.bg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child:
                              Icon(LucideIcons.tag, size: 15, color: style.fg),
                        ),
                        title: Text(tag.name),
                        trailing: selected
                            ? Icon(LucideIcons.check, color: style.fg)
                            : null,
                        onTap: () => _toggle(tag.id),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load tags: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(String tagId) async {
    setState(() {
      if (!_selected.remove(tagId)) _selected.add(tagId);
    });
    // Preserve the original attach order for ids that stay selected.
    final ordered = <String>[
      ...widget.product.tagIds.where(_selected.contains),
      ..._selected.where((id) => !widget.product.tagIds.contains(id)),
    ];
    final ok = await ref
        .read(productTagOperationsProvider.notifier)
        .setTags(productId: widget.product.id, tagIds: ordered);
    if (!ok && mounted) {
      setState(() {
        if (!_selected.remove(tagId)) _selected.add(tagId); // roll back
      });
    }
  }
}
