import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/adjustment_reason_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Admin CRUD editor for stock adjustment reasons.
///
/// Lists active + inactive reasons; supports add / edit / deactivate /
/// reactivate. Inactive entries stay (greyed) so admin can reactivate them —
/// deactivating never breaks historical adjustments, which keep the reason
/// id even after its entry stops rendering in the picker.
class AdjustmentReasonEditorScreen extends ConsumerStatefulWidget {
  const AdjustmentReasonEditorScreen({super.key});

  @override
  ConsumerState<AdjustmentReasonEditorScreen> createState() =>
      _AdjustmentReasonEditorScreenState();
}

class _AdjustmentReasonEditorScreenState
    extends ConsumerState<AdjustmentReasonEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final reasonsAsync = ref.watch(allAdjustmentReasonsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Adjustment Reasons'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(LucideIcons.moreVertical),
            onSelected: (value) {
              if (value == 'seed') _seedDefaults();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'seed',
                child: Text('Seed default reasons'),
              ),
            ],
          ),
        ],
      ),
      body: reasonsAsync.when(
        data: (reasons) => _buildList(context, reasons),
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorStateView(
          message: 'Failed to load adjustment reasons: $e',
          onRetry: () => ref.invalidate(allAdjustmentReasonsProvider),
        ),
      ),
      floatingActionButton: SettingsAddFab(
        onPressed: () => _showReasonDialog(context),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, List<AdjustmentReasonEntity> reasons) {
    if (reasons.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.clipboardList,
        title: 'No adjustment reasons yet',
        subtitle: 'Tap Add to create one.',
      );
    }

    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: reasons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final reason = reasons[index];
        return SettingsCrudRow(
          name: reason.name,
          isActive: reason.isActive,
          subtitle: reason.requiresNote ? 'Note required' : null,
          leadingIcon: LucideIcons.clipboardList,
          onEdit: () => _showReasonDialog(context, existing: reason),
          onToggleActive: canManage ? () => _toggleActive(reason) : null,
          onDelete: canManage ? () => _confirmDelete(reason) : null,
        );
      },
    );
  }

  Future<void> _toggleActive(AdjustmentReasonEntity reason) async {
    final ops = ref.read(adjustmentReasonOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      () => reason.isActive
          ? ops.deactivate(reason.id)
          : ops.reactivate(reason.id),
      message: 'Updating…',
    );
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        reason.isActive ? 'Reason deactivated' : 'Reason reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _confirmDelete(AdjustmentReasonEntity reason) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this entry?',
      message: '"${reason.name}" will be permanently deleted. '
          'Past adjustments keep the reason name. '
          'Use Deactivate instead to just hide it.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(adjustmentReasonOperationsProvider.notifier)
        .delete(reason.id);
    if (!mounted) return;
    ok
        ? context.showSuccessSnackBar('Deleted')
        : context.showErrorSnackBar('Failed to delete');
  }

  Future<void> _showReasonDialog(
    BuildContext context, {
    AdjustmentReasonEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (dialogContext) => _ReasonFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Reason created' : 'Reason updated',
    );
  }

  /// Inserts the default reason set. Idempotent — the repository skips
  /// anything that already exists by name.
  Future<void> _seedDefaults() async {
    final ops = ref.read(adjustmentReasonOperationsProvider.notifier);
    final ok = await context.runWithWaiting(
      ops.seedDefaults,
      message: 'Seeding…',
    );
    if (!mounted) return;
    ok
        ? context.showSuccessSnackBar('Default reasons added.')
        : context.showErrorSnackBar('Failed to seed defaults.');
  }
}

class _ReasonFormDialog extends ConsumerStatefulWidget {
  const _ReasonFormDialog({this.existing});

  final AdjustmentReasonEntity? existing;

  @override
  ConsumerState<_ReasonFormDialog> createState() => _ReasonFormDialogState();
}

class _ReasonFormDialogState extends ConsumerState<_ReasonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _requiresNote;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _requiresNote = existing?.requiresNote ?? false;
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
    final canManage = ref.watch(currentUserProvider).valueOrNull
            ?.hasPermission(Permission.manageCategories) ??
        false;
    // Note-required is editable by everyone on create; on edit it's
    // rules-parity gated to manageCategories holders same as Active.
    final showNoteRequiredSwitch = !_isEdit || canManage;
    return AppDialog(
      title: _isEdit ? 'Edit Reason' : 'New Reason',
      leadingIcon: LucideIcons.clipboardList,
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
                prefixIcon: Icon(LucideIcons.clipboardList),
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
            if (showNoteRequiredSwitch) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Note required'),
                subtitle: Text(
                  'Cashier must type a note when using this reason',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _requiresNote,
                onChanged: (v) => setState(() => _requiresNote = v),
              ),
            ],
            if (_isEdit && canManage) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'Shows in the adjustment reason picker'
                      : 'Hidden from the picker (existing records keep the reason id)',
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
    final ops = ref.read(adjustmentReasonOperationsProvider.notifier);

    // Capture the navigator before any await: pop must not reach for
    // BuildContext after an async gap.
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final existing = widget.existing;
    final result = await context.runWithWaiting(
      () async {
        if (existing == null) {
          return ops.create(
            reason: AdjustmentReasonEntity(
              id: '',
              name: name,
              requiresNote: _requiresNote,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          );
        }
        return ops.update(
          reason: existing.copyWith(
            name: name,
            requiresNote: _requiresNote,
            isActive: _isActive,
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
      final err = ref.read(adjustmentReasonOperationsProvider).error;
      context.showErrorSnackBar(
        err == null ? 'Failed to save reason' : 'Failed: $err',
      );
    }
  }
}
