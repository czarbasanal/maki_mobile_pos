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
    final picked = await _showAddDialog(mechanics);
    if (!mounted) return;
    setState(() => _rev++); // reset the dropdown display off the sentinel
    if (picked != null) widget.onChanged(picked);
  }

  Future<MechanicEntity?> _showAddDialog(List<MechanicEntity> mechanics) {
    final controller = TextEditingController();
    return showDialog<MechanicEntity>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (ctx) => AppDialog(
        title: 'Add mechanic',
        leadingIcon: LucideIcons.wrench,
        content: TextField(
          style: AppTextStyles.fieldInput,
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(LucideIcons.wrench),
          ),
        ),
        actions: [
          appDialogCancel(ctx, 'Cancel', onTap: () => Navigator.pop(ctx)),
          appDialogPrimary(ctx, 'Add', onTap: () async {
            final name = controller.text.trim();
            if (name.length < 2) return;

            // Reuse an existing active mechanic on a case-insensitive match
            // instead of creating a duplicate.
            final lower = name.toLowerCase();
            for (final m in mechanics) {
              if (m.name.toLowerCase() == lower) {
                Navigator.pop(ctx, m);
                return;
              }
            }

            final created = await ref
                .read(mechanicOperationsProvider.notifier)
                .create(
                  mechanic: MechanicEntity(
                    id: '',
                    name: name,
                    isActive: true,
                    createdAt: DateTime.now(),
                  ),
                );
            if (!ctx.mounted) return;
            Navigator.pop(ctx, created);
            if (created == null && mounted) {
              context.showErrorSnackBar('Failed to add mechanic');
            }
          }),
        ],
      ),
    );
  }
}
