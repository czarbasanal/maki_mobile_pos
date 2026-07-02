import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Admin CRUD editor for the motorcycle models list.
///
/// Lists active + inactive models; add / edit / deactivate / reactivate with a
/// case-insensitive duplicate guard. Inactive entries stay (greyed) so admin
/// can reactivate; deactivating never breaks history (the model is snapshotted
/// by name on the draft/sale).
class MotorcycleModelEditorScreen extends ConsumerStatefulWidget {
  const MotorcycleModelEditorScreen({super.key});

  @override
  ConsumerState<MotorcycleModelEditorScreen> createState() =>
      _MotorcycleModelEditorScreenState();
}

class _MotorcycleModelEditorScreenState
    extends ConsumerState<MotorcycleModelEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allMotorcycleModelsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Motorcycle Models'),
      ),
      body: async.when(
        data: (models) => _buildList(context, models),
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load models: $e',
          onRetry: () => ref.invalidate(allMotorcycleModelsProvider),
        ),
      ),
      floatingActionButton: SettingsAddFab(
        onPressed: () => _showModelDialog(context),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<MotorcycleModelEntity> models) {
    if (models.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.bike,
        title: 'No motorcycle models yet',
        subtitle: 'Tap Add to create one.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: models.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = models[index];
        return SettingsCrudRow(
          name: m.name,
          isActive: m.isActive,
          leadingIcon: LucideIcons.bike,
          onEdit: () => _showModelDialog(context, existing: m),
          onToggleActive: () => _toggleActive(m),
        );
      },
    );
  }

  Future<void> _toggleActive(MotorcycleModelEntity m) async {
    final ops = ref.read(motorcycleModelOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      () => m.isActive ? ops.deactivate(m.id) : ops.reactivate(m.id),
      message: 'Updating…',
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        m.isActive ? 'Model deactivated' : 'Model reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _showModelDialog(
    BuildContext context, {
    MotorcycleModelEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (_) => _ModelFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Model created' : 'Model updated',
    );
  }
}

class _ModelFormDialog extends ConsumerStatefulWidget {
  const _ModelFormDialog({this.existing});

  final MotorcycleModelEntity? existing;

  @override
  ConsumerState<_ModelFormDialog> createState() => _ModelFormDialogState();
}

class _ModelFormDialogState extends ConsumerState<_ModelFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
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
      title: _isEdit ? 'Edit Model' : 'New Model',
      leadingIcon: LucideIcons.bike,
      content: Form(
        key: _formKey,
        child: TextFormField(
          style: AppTextStyles.fieldInput,
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Model',
            prefixIcon: Icon(LucideIcons.bike),
            hintText: 'e.g. Nmax, Click 125i',
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) return 'Model is required';
            if (trimmed.length < 2) return 'Model must be at least 2 characters';
            return null;
          },
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
    final name = canonicalModelName(_nameController.text);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    // Duplicate guard — the repo create is a plain add (no server-side unique
    // constraint), so reject a case-insensitive collision here.
    final repo = ref.read(motorcycleModelRepositoryProvider);
    final match = await repo.findByNormalizedKey(normalizedModelKey(name));
    if (!mounted) return;
    final existing = widget.existing;
    final isDuplicate =
        match != null && (existing == null || match.id != existing.id);
    if (isDuplicate) {
      setState(() => _isSaving = false);
      context.showErrorSnackBar('A model with this name already exists');
      return;
    }

    final ops = ref.read(motorcycleModelOperationsProvider.notifier);
    final result = await context.runWithWaiting(
      () async {
        if (existing == null) {
          return ops.create(
            model: MotorcycleModelEntity(
              id: '',
              name: name,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          );
        }
        return ops.update(model: existing.copyWith(name: name));
      },
      message: existing == null ? 'Saving…' : 'Updating…',
    );

    if (!mounted) return;
    if (result != null) {
      navigator.pop(true);
    } else {
      setState(() => _isSaving = false);
      context.showErrorSnackBar('Failed to save model');
    }
  }
}
