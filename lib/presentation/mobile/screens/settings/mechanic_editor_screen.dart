import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

/// Admin CRUD editor for the mechanics list.
///
/// Lists active + inactive mechanics; supports add / edit / deactivate /
/// reactivate with name-exists validation. Inactive entries stay (greyed) so
/// admin can reactivate them; deactivating never breaks historical records,
/// which carry a snapshotted mechanic name.
class MechanicEditorScreen extends ConsumerStatefulWidget {
  const MechanicEditorScreen({super.key});

  @override
  ConsumerState<MechanicEditorScreen> createState() =>
      _MechanicEditorScreenState();
}

class _MechanicEditorScreenState extends ConsumerState<MechanicEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final mechanicsAsync = ref.watch(allMechanicsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Mechanics'),
      ),
      body: mechanicsAsync.when(
        data: (mechanics) => _buildList(context, mechanics),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load mechanics: $e')),
      ),
      floatingActionButton: SettingsAddFab(
        onPressed: () => _showMechanicDialog(context),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<MechanicEntity> mechanics) {
    if (mechanics.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: mechanics.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final mechanic = mechanics[index];
        return SettingsCrudRow(
          name: mechanic.name,
          isActive: mechanic.isActive,
          leadingIcon: LucideIcons.wrench,
          onEdit: () => _showMechanicDialog(context, existing: mechanic),
          onToggleActive: () => _toggleActive(mechanic),
        );
      },
    );
  }

  Future<void> _toggleActive(MechanicEntity mechanic) async {
    final ops = ref.read(mechanicOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      () => mechanic.isActive
          ? ops.deactivate(mechanic.id)
          : ops.reactivate(mechanic.id),
      message: 'Updating…',
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        mechanic.isActive ? 'Mechanic deactivated' : 'Mechanic reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _showMechanicDialog(
    BuildContext context, {
    MechanicEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (dialogContext) => _MechanicFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Mechanic created' : 'Mechanic updated',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              LucideIcons.wrench,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No mechanics yet',
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

class _MechanicFormDialog extends ConsumerStatefulWidget {
  const _MechanicFormDialog({this.existing});

  final MechanicEntity? existing;

  @override
  ConsumerState<_MechanicFormDialog> createState() =>
      _MechanicFormDialogState();
}

class _MechanicFormDialogState extends ConsumerState<_MechanicFormDialog> {
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
    return AppDialog(
      title: _isEdit ? 'Edit Mechanic' : 'New Mechanic',
      leadingIcon: LucideIcons.wrench,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(LucideIcons.wrench),
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
                      ? 'Visible in the mechanic picker'
                      : 'Hidden from the picker (existing records keep matching)',
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
    final ops = ref.read(mechanicOperationsProvider.notifier);

    // Capture the navigator before any await: pop must not reach for
    // BuildContext after an async gap.
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final existing = widget.existing;
    final result = await context.runWithWaiting(
      () async {
        if (existing == null) {
          return ops.create(
            mechanic: MechanicEntity(
              id: '',
              name: name,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          );
        }
        return ops.update(
          mechanic: existing.copyWith(name: name, isActive: _isActive),
        );
      },
      message: existing == null ? 'Saving…' : 'Updating…',
    );

    if (!mounted) return;

    if (result != null) {
      navigator.pop(true);
    } else {
      setState(() => _isSaving = false);
      final err = ref.read(mechanicOperationsProvider).error;
      context.showErrorSnackBar(
        err == null ? 'Failed to save mechanic' : 'Failed: $err',
      );
    }
  }
}
