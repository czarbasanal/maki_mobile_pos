import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

/// Pick-or-add mechanic dropdown (canonical "C1" signature).
///
/// Watches [activeMechanicsProvider] and reports the picked mechanic (or null
/// for "— None —") via [onChanged]. "➕ Add mechanic…" creates a mechanic
/// inline (reusing an existing one on a case-insensitive name match) and
/// selects it. The PARENT owns where the selection goes (the cart in POS, a
/// draft working-copy in the draft editor), so the same widget is reused
/// verbatim in both places.
class MechanicPicker extends ConsumerStatefulWidget {
  const MechanicPicker({
    super.key,
    this.selectedMechanicId,
    required this.onChanged,
    this.nonePlaceholder = '— None —',
  });

  /// Currently-assigned mechanic id (null = none).
  final String? selectedMechanicId;

  /// Reports the chosen mechanic; null means the placeholder was picked.
  final void Function(MechanicEntity? mechanic) onChanged;

  /// Label for the no-mechanic option (e.g. "— Optional —" at create).
  final String nonePlaceholder;

  @override
  ConsumerState<MechanicPicker> createState() => _MechanicPickerState();
}

class _MechanicPickerState extends ConsumerState<MechanicPicker> {
  static const _addNew = '__add_mechanic__';

  /// Bumped after the "Add mechanic…" flow so the underlying [AppDropdown]
  /// rebuilds fresh — resetting its display off the sentinel whether or not
  /// a mechanic was actually added (handles cancel).
  int _rev = 0;

  @override
  Widget build(BuildContext context) {
    final mechanicsAsync = ref.watch(activeMechanicsProvider);

    return mechanicsAsync.when(
      data: (mechanics) {
        // If the assigned mechanic was deactivated (no longer in the active
        // list), fall back to no selection so the dropdown value stays valid.
        final hasSelected = widget.selectedMechanicId != null &&
            mechanics.any((m) => m.id == widget.selectedMechanicId);

        return AppDropdown<String>(
          key: ValueKey('$_rev|${widget.selectedMechanicId}'),
          initialValue: hasSelected ? widget.selectedMechanicId : null,
          decoration: const InputDecoration(
            labelText: 'Mechanic',
            prefixIcon: Icon(LucideIcons.wrench),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(widget.nonePlaceholder),
            ),
            for (final m in mechanics)
              DropdownMenuItem<String>(value: m.id, child: Text(m.name)),
            const DropdownMenuItem<String>(
              value: _addNew,
              child: Text('➕ Add mechanic…'),
            ),
          ],
          onChanged: (id) {
            if (id == _addNew) {
              _onAddNew(mechanics);
            } else {
              widget.onChanged(
                id == null ? null : mechanics.firstWhere((m) => m.id == id),
              );
            }
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Failed to load mechanics: $e'),
    );
  }

  Future<void> _onAddNew(List<MechanicEntity> mechanics) async {
    final picked = await showDialog<MechanicEntity>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (ctx) => _AddMechanicDialog(activeMechanics: mechanics),
    );
    if (!mounted) return;
    setState(() => _rev++); // reset the dropdown display off the sentinel
    if (picked != null) widget.onChanged(picked);
  }
}

/// Inline "Add mechanic" dialog. Reuses an existing ACTIVE mechanic on a
/// case-insensitive name match; otherwise checks for an ARCHIVED twin (via
/// [MechanicRepository.nameExists], which sees active + inactive rows) and
/// refuses to create a duplicate, since only staff can reactivate one from
/// Settings. Guards double-tap with an [_isSaving] busy state, matching the
/// pattern in `mechanic_editor_screen.dart`'s form dialog.
class _AddMechanicDialog extends ConsumerStatefulWidget {
  const _AddMechanicDialog({required this.activeMechanics});

  final List<MechanicEntity> activeMechanics;

  @override
  ConsumerState<_AddMechanicDialog> createState() =>
      _AddMechanicDialogState();
}

class _AddMechanicDialogState extends ConsumerState<_AddMechanicDialog> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Add mechanic',
      leadingIcon: LucideIcons.wrench,
      content: TextField(
        style: AppTextStyles.fieldInput,
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          prefixIcon: Icon(LucideIcons.wrench),
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: _isSaving ? () {} : () => Navigator.pop(context)),
        appDialogPrimary(context, 'Add', onTap: _onAdd, loading: _isSaving),
      ],
    );
  }

  Future<void> _onAdd() async {
    if (_isSaving) return;
    final name = _controller.text.trim();
    if (name.length < 2) return;

    // Reuse an existing active mechanic on a case-insensitive match instead
    // of creating a duplicate.
    final lower = name.toLowerCase();
    for (final m in widget.activeMechanics) {
      if (m.name.toLowerCase() == lower) {
        Navigator.pop(context, m);
        return;
      }
    }

    setState(() => _isSaving = true);

    // No active twin above — an exact-name hit here must be an archived one
    // (the active scan is already case-insensitive, so it would have caught
    // any active match regardless of case).
    final archived =
        await ref.read(mechanicRepositoryProvider).nameExists(name: name);
    if (archived) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showErrorSnackBar(
        'A mechanic with this name is archived — ask staff to reactivate '
        'them in Settings',
      );
      return;
    }

    final created =
        await ref.read(mechanicOperationsProvider.notifier).create(
              mechanic: MechanicEntity(
                id: '',
                name: name,
                isActive: true,
                createdAt: DateTime.now(),
              ),
            );
    if (!mounted) return;
    if (created == null) {
      setState(() => _isSaving = false);
      context.showErrorSnackBar('Failed to add mechanic');
      return;
    }
    Navigator.pop(context, created);
  }
}
