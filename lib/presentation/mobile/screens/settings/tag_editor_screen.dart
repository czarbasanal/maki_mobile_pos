import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/constants/tag_colors.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Admin CRUD editor for the product tags list.
///
/// Lists active + inactive tags; supports add / edit / deactivate /
/// reactivate with a picked color token. Inactive entries stay (greyed) so
/// admin can reactivate them; deactivating never breaks historical records,
/// which keep the tag id even while its chip stops rendering.
class TagEditorScreen extends ConsumerStatefulWidget {
  const TagEditorScreen({super.key});

  @override
  ConsumerState<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends ConsumerState<TagEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Product Tags'),
      ),
      body: tagsAsync.when(
        data: (tags) => _buildList(context, tags),
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load tags: $e',
          onRetry: () => ref.invalidate(allTagsProvider),
        ),
      ),
      floatingActionButton: SettingsAddFab(
        onPressed: () => _showTagDialog(context),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<TagEntity> tags) {
    if (tags.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.tag,
        title: 'No tags yet',
        subtitle: 'Tap Add to create one.',
      );
    }

    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tag = tags[index];
        final style = TagColors.styleFor(
            tag.color, Theme.of(context).brightness == Brightness.dark);
        return SettingsCrudRow(
          name: tag.name,
          isActive: tag.isActive,
          subtitle: tag.description,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.tag, size: 18, color: style.fg),
          ),
          onEdit: () => _showTagDialog(context, existing: tag),
          onToggleActive: canManage ? () => _toggleActive(tag) : null,
          onDelete: canManage ? () => _confirmDelete(tag) : null,
        );
      },
    );
  }

  Future<void> _toggleActive(TagEntity tag) async {
    final ops = ref.read(tagOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      () => tag.isActive ? ops.deactivate(tag.id) : ops.reactivate(tag.id),
      message: 'Updating…',
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        tag.isActive ? 'Tag deactivated' : 'Tag reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _confirmDelete(TagEntity tag) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this entry?',
      message: '"${tag.name}" will be permanently deleted. '
          'Products keep the tag but the chip disappears everywhere. '
          'Use Deactivate instead to just hide it.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(tagOperationsProvider.notifier).delete(tag.id);
    if (!mounted) return;
    ok
        ? context.showSuccessSnackBar('Deleted')
        : context.showErrorSnackBar('Failed to delete');
  }

  Future<void> _showTagDialog(
    BuildContext context, {
    TagEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (dialogContext) => _TagFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Tag created' : 'Tag updated',
    );
  }
}

class _TagFormDialog extends ConsumerStatefulWidget {
  const _TagFormDialog({this.existing});

  final TagEntity? existing;

  @override
  ConsumerState<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends ConsumerState<_TagFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _color;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _color = existing?.color ?? 'gray';
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppDialog(
      title: _isEdit ? 'Edit Tag' : 'New Tag',
      leadingIcon: LucideIcons.tag,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              style: AppTextStyles.fieldInput,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(LucideIcons.tag),
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
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: TagColors.tokens.map((token) {
                  final style = TagColors.styleFor(token, isDark);
                  final selected = _color == token;
                  return InkWell(
                    key: ValueKey('tag-color-$token'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _color = token),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: style.bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? style.fg : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration:
                              BoxDecoration(color: style.fg, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              style: AppTextStyles.fieldInput,
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(LucideIcons.text),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            if (_isEdit && canManage) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'Chip shows on inventory rows'
                      : 'Hidden from products (existing records keep the tag id)',
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
        appDialogCancel(context, 'Cancel',
            onTap: _isSaving ? () {} : () => Navigator.pop(context)),
        appDialogPrimary(context, _isEdit ? 'Save' : 'Create',
            onTap: _save, loading: _isSaving),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    // Optional field: blank collapses to null so we don't persist empty
    // strings (and clearing a previously-set value nulls it out).
    final desc = _descriptionController.text.trim();
    final ops = ref.read(tagOperationsProvider.notifier);

    // Capture the navigator before any await: pop must not reach for
    // BuildContext after an async gap.
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final existing = widget.existing;
    final result = await context.runWithWaiting(
      () async {
        if (existing == null) {
          return ops.create(
            tag: TagEntity(
              id: '',
              name: name,
              color: _color,
              description: desc.isEmpty ? null : desc,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          );
        }
        return ops.update(
          tag: existing.copyWith(
            name: name,
            color: _color,
            isActive: _isActive,
            description: desc.isEmpty ? null : desc,
            clearDescription: desc.isEmpty,
          ),
        );
      },
      message: existing == null ? 'Saving…' : 'Updating…',
    );

    if (!mounted) return;

    if (result != null) {
      navigator.pop(true);
    } else {
      setState(() => _isSaving = false);
      final err = ref.read(tagOperationsProvider).error;
      context.showErrorSnackBar(
        err == null ? 'Failed to save tag' : 'Failed: $err',
      );
    }
  }
}
