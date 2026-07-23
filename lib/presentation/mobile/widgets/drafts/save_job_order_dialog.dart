import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

/// Confirms saving the cart as a Job Order under the auto-generated
/// [jobOrderNo] (shown read-only — numbering is sequential per day) and
/// collects motorcycle model + mechanic. [initialModel]/[initialMechanicId]
/// prefill from the cart so choices made in the Labor & Service section
/// carry over. Returns the input (label = [jobOrderNo]), or null if
/// cancelled.
Future<SaveJobOrderInput?> showSaveJobOrderDialog(
  BuildContext context, {
  required String jobOrderNo,
  String? initialModel,
  String? initialMechanicId,
  String? initialMechanicName,
}) {
  return showDialog<SaveJobOrderInput>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _SaveJobOrderDialog(
      jobOrderNo: jobOrderNo,
      initialModel: initialModel,
      initialMechanicId: initialMechanicId,
      initialMechanicName: initialMechanicName,
    ),
  );
}

class _SaveJobOrderDialog extends ConsumerStatefulWidget {
  const _SaveJobOrderDialog({
    required this.jobOrderNo,
    this.initialModel,
    this.initialMechanicId,
    this.initialMechanicName,
  });
  final String jobOrderNo;
  final String? initialModel;
  final String? initialMechanicId;
  final String? initialMechanicName;

  @override
  ConsumerState<_SaveJobOrderDialog> createState() =>
      _SaveJobOrderDialogState();
}

class _SaveJobOrderDialogState extends ConsumerState<_SaveJobOrderDialog> {
  late String? _model = widget.initialModel;
  late String? _mechanicId = widget.initialMechanicId;
  late String? _mechanicName = widget.initialMechanicName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppDialog(
      title: 'Save as Job Order',
      leadingIcon: LucideIcons.clipboardPlus,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto-generated daily-sequential number replaces the old
          // customer/plate label — read-only by design.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.hash, size: 15, color: muted),
                const SizedBox(width: 8),
                Text(
                  'Job Order No.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  widget.jobOrderNo,
                  style: AppTextStyles.fieldInput
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
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
          Navigator.pop(
            context,
            SaveJobOrderInput(
              label: widget.jobOrderNo,
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
