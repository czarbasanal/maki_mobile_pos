import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Details collected when saving the register cart as a Job Order.
class SaveJobOrderInput {
  const SaveJobOrderInput({
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

/// Prompts for the ticket label + motorcycle model + mechanic when saving a
/// cart as a Job Order. [initialModel]/[initialMechanicId] prefill from the
/// cart so choices made in the Labor & Service section carry over. Returns
/// the input, or null if cancelled.
Future<SaveJobOrderInput?> showSaveJobOrderDialog(
  BuildContext context, {
  String? initialModel,
  String? initialMechanicId,
  String? initialMechanicName,
}) {
  return showDialog<SaveJobOrderInput>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _SaveJobOrderDialog(
      initialModel: initialModel,
      initialMechanicId: initialMechanicId,
      initialMechanicName: initialMechanicName,
    ),
  );
}

class _SaveJobOrderDialog extends ConsumerStatefulWidget {
  const _SaveJobOrderDialog({
    this.initialModel,
    this.initialMechanicId,
    this.initialMechanicName,
  });
  final String? initialModel;
  final String? initialMechanicId;
  final String? initialMechanicName;

  @override
  ConsumerState<_SaveJobOrderDialog> createState() =>
      _SaveJobOrderDialogState();
}

class _SaveJobOrderDialogState extends ConsumerState<_SaveJobOrderDialog> {
  final _labelController = TextEditingController();
  late String? _model = widget.initialModel;
  late String? _mechanicId = widget.initialMechanicId;
  late String? _mechanicName = widget.initialMechanicName;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Save as Job Order',
      leadingIcon: LucideIcons.clipboardPlus,
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
            nonePlaceholder: '— Optional —',
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
        appDialogPrimary(context, 'Save', onTap: () {
          final label = _labelController.text.trim();
          if (label.isEmpty) {
            context.showWarningSnackBar('Enter a customer or plate label');
            return;
          }
          Navigator.pop(
            context,
            SaveJobOrderInput(
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
