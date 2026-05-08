import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';

/// Hub for the admin-managed name lists. One tile per [CategoryKind] —
/// tapping pushes the per-kind editor at `/settings/categories/<kind.name>`.
class CategorySettingsScreen extends ConsumerWidget {
  const CategorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Manage Lists'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: CategoryKind.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final kind = CategoryKind.values[index];
          return _ManageListTile(
            kind: kind,
            theme: theme,
            onTap: () => context.push('${RoutePaths.categorySettings}/${kind.name}'),
          );
        },
      ),
    );
  }
}

class _ManageListTile extends StatelessWidget {
  const _ManageListTile({
    required this.kind,
    required this.theme,
    required this.onTap,
  });

  final CategoryKind kind;
  final ThemeData theme;
  final VoidCallback onTap;

  IconData get _leadingIcon {
    switch (kind) {
      case CategoryKind.product:
        return CupertinoIcons.cube_box;
      case CategoryKind.expense:
        return CupertinoIcons.money_dollar_circle;
      case CategoryKind.unit:
        return Icons.straighten;
      case CategoryKind.voidReason:
        return CupertinoIcons.xmark_circle;
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Icon(_leadingIcon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          _title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          CupertinoIcons.chevron_right,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
