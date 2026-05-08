import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';

/// Per-kind CRUD editor for an admin-managed name list.
///
/// One screen per [CategoryKind]; the hub at `/settings/categories` lists the
/// kinds as tiles and pushes this screen for the chosen one. Inactive items
/// stay (greyed) so admin can reactivate. A "Seed defaults" overflow action
/// is shown when [CategoryKind] has a known starter set.
class CategoryEditorScreen extends ConsumerStatefulWidget {
  const CategoryEditorScreen({super.key, required this.kind});

  final CategoryKind kind;

  @override
  ConsumerState<CategoryEditorScreen> createState() =>
      _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  CategoryKind get _kind => widget.kind;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider(_kind));
    final defaults = _defaultsFor(_kind);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.categorySettings),
        ),
        title: Text(_kind.pluralLabel.toTitleCase()),
        actions: [
          if (defaults != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'seed') _seedDefaults(_kind, defaults);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'seed',
                  child: Text('Seed default ${_kind.pluralLabel}'),
                ),
              ],
            ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) => _buildList(context, categories),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load ${_kind.pluralLabel}: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context),
        icon: const Icon(CupertinoIcons.add),
        label: const Text('Add'),
      ),
    );
  }

  static const _expenseDefaults = [
    'General',
    'Utilities',
    'Rent',
    'Supplies',
    'Transportation',
    'Food',
    'Maintenance',
    'Other',
  ];

  static const _unitDefaults = [
    'pcs',
    'kg',
    'g',
    'box',
    'l',
    'ml',
    'm',
    'pack',
  ];

  static const _voidReasonDefaults = [
    'Customer changed mind',
    'Wrong items entered',
    'Payment issue',
    'Duplicate transaction',
    'Price error',
    'Other',
  ];

  List<String>? _defaultsFor(CategoryKind kind) {
    switch (kind) {
      case CategoryKind.product:
        return null;
      case CategoryKind.expense:
        return _expenseDefaults;
      case CategoryKind.unit:
        return _unitDefaults;
      case CategoryKind.voidReason:
        return _voidReasonDefaults;
    }
  }

  Widget _buildList(BuildContext context, List<CategoryEntity> categories) {
    if (categories.isEmpty) {
      return _EmptyState(kind: _kind);
    }

    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl * 2,
      ),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryRow(
          category: category,
          theme: theme,
          onEdit: () => _showCategoryDialog(context, existing: category),
          onToggleActive: () => _toggleActive(category),
        );
      },
    );
  }

  Future<void> _toggleActive(CategoryEntity category) async {
    final ops = ref.read(categoryOperationsProvider(_kind).notifier);
    final ok = category.isActive
        ? await ops.deactivate(category.id)
        : await ops.reactivate(category.id);
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        category.isActive ? 'Category deactivated' : 'Category reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext context, {
    CategoryEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CategoryFormDialog(
        kind: _kind,
        existing: existing,
      ),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null
          ? '${_kind.singularLabel} created'
          : '${_kind.singularLabel} updated',
    );
  }

  /// Inserts a starter set for the given [kind]. Idempotent — anything that
  /// already exists by name (active or inactive) is left alone.
  Future<void> _seedDefaults(CategoryKind kind, List<String> defaults) async {
    final ops = ref.read(categoryOperationsProvider(kind).notifier);
    final existing = ref.read(allCategoriesProvider(kind)).valueOrNull;
    if (existing == null) {
      // Stream hasn't emitted yet — bail rather than risk duplicates.
      if (mounted) {
        context.showErrorSnackBar(
          '${kind.pluralLabel.toCapitalizedFirst()} are still loading; try again.',
        );
      }
      return;
    }
    final existingNames = existing.map((c) => c.name).toSet();
    final toInsert = defaults.where((d) => !existingNames.contains(d)).toList();

    if (toInsert.isEmpty) {
      if (mounted) {
        context.showSuccessSnackBar('Defaults already present.');
      }
      return;
    }

    var added = 0;
    var failed = 0;
    for (final name in toInsert) {
      final created = await ops.create(
        category: CategoryEntity(
          id: '',
          name: name,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );
      if (created == null) {
        failed++;
      } else {
        added++;
      }
    }

    if (!mounted) return;
    if (failed == 0) {
      context.showSuccessSnackBar('Added $added default ${kind.pluralLabel}.');
    } else {
      context.showErrorSnackBar(
        'Added $added, $failed failed. Check connection and retry.',
      );
    }
  }
}

extension on String {
  String toCapitalizedFirst() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String toTitleCase() => isEmpty
      ? this
      : split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.theme,
    required this.onEdit,
    required this.onToggleActive,
  });

  final CategoryEntity category;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final muted = !category.isActive;
    final nameStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: muted ? theme.colorScheme.onSurfaceVariant : null,
      decoration: muted ? TextDecoration.lineThrough : null,
    );

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
        title: Text(category.name, style: nameStyle),
        subtitle: muted
            ? Text(
                'Inactive',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(CupertinoIcons.pencil),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: muted ? 'Reactivate' : 'Deactivate',
              icon: Icon(
                muted ? CupertinoIcons.arrow_clockwise : CupertinoIcons.archivebox,
              ),
              onPressed: onToggleActive,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.tag,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No ${kind.pluralLabel} yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap Add to create one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog({required this.kind, this.existing});

  final CategoryKind kind;
  final CategoryEntity? existing;

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit ${widget.kind.singularLabel}' : 'New ${widget.kind.singularLabel}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(CupertinoIcons.tag),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Name is required';
                if (trimmed.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'Visible in dropdowns'
                      : 'Hidden from dropdowns (existing records keep matching)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final ops = ref.read(categoryOperationsProvider(widget.kind).notifier);

    // Capture the navigator before any await: pop must not reach for
    // BuildContext after an async gap.
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final existing = widget.existing;
    CategoryEntity? result;
    if (existing == null) {
      result = await ops.create(
        category: CategoryEntity(
          id: '',
          name: name,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      result = await ops.update(
        category: existing.copyWith(name: name, isActive: _isActive),
      );
    }

    if (!mounted) return;

    if (result != null) {
      navigator.pop(true);
    } else {
      setState(() => _isSaving = false);
      final err = ref.read(categoryOperationsProvider(widget.kind)).error;
      context.showErrorSnackBar(
        err == null
            ? 'Failed to save ${widget.kind.singularLabel.toLowerCase()}'
            : 'Failed: $err',
      );
    }
  }
}
