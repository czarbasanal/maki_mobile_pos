import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

/// Prompts for a new Job Order's motorcycle model + mechanic under the
/// auto-generated [jobOrderNo] (shown read-only — numbering is sequential
/// per day, mirroring the POS Save-as-Job-Order dialog). Returns the input
/// (label = [jobOrderNo]), or null if cancelled. Does not touch the cart.
Future<NewJobOrderInput?> showNewJobOrderDialog(
  BuildContext context, {
  required String jobOrderNo,
}) {
  return showDialog<NewJobOrderInput>(
    context: context,
    barrierColor: AppDialog.scrimColor(
        Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _NewJobOrderDialog(jobOrderNo: jobOrderNo),
  );
}

class _NewJobOrderDialog extends ConsumerStatefulWidget {
  const _NewJobOrderDialog({required this.jobOrderNo});
  final String jobOrderNo;
  @override
  ConsumerState<_NewJobOrderDialog> createState() => _NewJobOrderDialogState();
}

class _NewJobOrderDialogState extends ConsumerState<_NewJobOrderDialog> {
  String? _model;
  String? _mechanicId;
  String? _mechanicName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppDialog(
      title: 'New Job Order',
      leadingIcon: LucideIcons.clipboardList,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto-generated daily-sequential number replaces the old
          // customer/plate label — read-only by design (same row as the
          // POS Save-as-Job-Order dialog).
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
        appDialogPrimary(context, 'Create', onTap: () {
          Navigator.pop(
            context,
            NewJobOrderInput(
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
