import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// Hub for the admin-managed name lists. One tile per [CategoryKind] —
/// tapping pushes the per-kind editor at `/settings/categories/<kind.name>`.
class CategorySettingsScreen extends ConsumerWidget {
  const CategorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Manage Lists'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: CategoryKind.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final kind = CategoryKind.values[index];
          return _ManageListTile(
            kind: kind,
            onTap: () =>
                context.push('${RoutePaths.categorySettings}/${kind.name}'),
          );
        },
      ),
    );
  }
}

/// Soft-shadow nav row: neutral 40×40 glyph tile + title + "Used in …"
/// subtitle + muted chevron.
class _ManageListTile extends StatelessWidget {
  const _ManageListTile({required this.kind, required this.onTap});

  final CategoryKind kind;
  final VoidCallback onTap;

  IconData get _leadingIcon {
    switch (kind) {
      case CategoryKind.product:
        return LucideIcons.package;
      case CategoryKind.expense:
        return LucideIcons.circleDollarSign;
      case CategoryKind.unit:
        return LucideIcons.ruler;
      case CategoryKind.voidReason:
        return LucideIcons.xCircle;
    }
  }

  String get _title {
    switch (kind) {
      case CategoryKind.product:
        return 'Product Categories';
      case CategoryKind.expense:
        return 'Expense Categories';
      case CategoryKind.unit:
        return 'Units';
      case CategoryKind.voidReason:
        return 'Void Reasons';
    }
  }

  String get _subtitle {
    switch (kind) {
      case CategoryKind.product:
        return 'Used in product form and inventory filter';
      case CategoryKind.expense:
        return 'Used in expense form';
      case CategoryKind.unit:
        return 'Used in product unit field';
      case CategoryKind.voidReason:
        return 'Used in void-sale dialog';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final tileBg = dark ? const Color(0x1F93A0A3) : const Color(0x0F283E46);

    return AppCard(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_leadingIcon, size: 20, color: muted),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: Color(0xFFB4B8BA),
          ),
        ],
      ),
    );
  }
}
