import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

/// Presentation-only mechanic dropdown (canonical "C1" signature).
///
/// Watches [activeMechanicsProvider] and reports the picked mechanic (or null
/// for "— None —") via [onChanged]. The PARENT owns where the selection goes
/// (the cart in POS, a draft working-copy in the draft editor), so the same
/// widget is reused verbatim in both places.
class MechanicPicker extends ConsumerWidget {
  const MechanicPicker({
    super.key,
    this.selectedMechanicId,
    required this.onChanged,
  });

  /// Currently-assigned mechanic id (null = none).
  final String? selectedMechanicId;

  /// Reports the chosen mechanic; null means "— None —" was picked.
  final void Function(MechanicEntity? mechanic) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mechanicsAsync = ref.watch(activeMechanicsProvider);

    return mechanicsAsync.when(
      data: (mechanics) {
        // If the assigned mechanic was deactivated (no longer in the active
        // list), fall back to no selection so the dropdown value stays valid.
        final hasSelected = selectedMechanicId != null &&
            mechanics.any((m) => m.id == selectedMechanicId);

        return AppDropdown<String>(
          initialValue: hasSelected ? selectedMechanicId : null,
          decoration: const InputDecoration(
            labelText: 'Mechanic',
            prefixIcon: Icon(CupertinoIcons.wrench),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('— None —'),
            ),
            for (final m in mechanics)
              DropdownMenuItem<String>(value: m.id, child: Text(m.name)),
          ],
          onChanged: (id) => onChanged(
            id == null ? null : mechanics.firstWhere((m) => m.id == id),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Failed to load mechanics: $e'),
    );
  }
}
