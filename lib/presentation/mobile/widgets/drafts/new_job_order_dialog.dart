import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Details collected when opening a new Job Order (cart-independent).
class NewJobOrderInput {
  const NewJobOrderInput({
    required this.label,
    this.model,
    this.mechanicId,
    this.mechanicName,
  });
  final String label;
  final String? model;
  final String? mechanicId;
  final String? mechanicName;
}

/// Prompts for a new Job Order's label + motorcycle model + mechanic. Returns
/// the input, or null if cancelled. Does not touch the register cart.
Future<NewJobOrderInput?> showNewJobOrderDialog(BuildContext context) {
  return showDialog<NewJobOrderInput>(
    context: context,
    barrierColor: AppDialog.scrimColor(
        Theme.of(context).brightness == Brightness.dark),
    builder: (_) => const _NewJobOrderDialog(),
  );
}

class _NewJobOrderDialog extends ConsumerStatefulWidget {
  const _NewJobOrderDialog();
  @override
  ConsumerState<_NewJobOrderDialog> createState() => _NewJobOrderDialogState();
}

class _NewJobOrderDialogState extends ConsumerState<_NewJobOrderDialog> {
  final _labelController = TextEditingController();
  String? _model;
  String? _mechanicId;
  String? _mechanicName;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'New Job Order',
      leadingIcon: LucideIcons.clipboardList,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer / plate',
              hintText: 'e.g. Juan / ABC-123',
            ),
          ),
          const SizedBox(height: 12),
          MotorcycleModelPicker(
            selectedModel: _model,
            onChanged: (m) => setState(() => _model = m),
          ),
          const SizedBox(height: 12),
          MechanicPicker(
            selectedMechanicId: _mechanicId,
            onChanged: (m) => setState(() {
              _mechanicId = m?.id;
              _mechanicName = m?.name;
            }),
          ),
        ],
      ),
      actions: [
        appDialogCancel(context, 'Cancel', onTap: () => Navigator.pop(context)),
        appDialogPrimary(context, 'Create', onTap: () {
          final label = _labelController.text.trim();
          if (label.isEmpty) {
            context.showWarningSnackBar('Enter a customer or plate label');
            return;
          }
          Navigator.pop(
            context,
            NewJobOrderInput(
              label: label,
              model: _model,
              mechanicId: _mechanicId,
              mechanicName: _mechanicName,
            ),
          );
        }),
      ],
    );
  }
}
