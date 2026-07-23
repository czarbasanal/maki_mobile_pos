import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Result of the shared add/edit labor dialog — plain values so each call
/// site reconciles into its own mutation shape (CartNotifier id-based
/// updates vs DraftEntity whole-line updates).
class LaborLineInput {
  const LaborLineInput({required this.description, required this.fee});
  final String description;
  final double fee;
}

/// The ONE add/edit dialog for labor lines (POS register + Job Order
/// editor). Title flips Add/Edit on [line]; validators: description
/// required, fee > 0. Returns the entered values, or null if cancelled.
Future<LaborLineInput?> showLaborLineDialog(
  BuildContext context, {
  LaborLineEntity? line,
}) {
  return showDialog<LaborLineInput>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _LaborLineDialog(line: line),
  );
}

class _LaborLineDialog extends StatefulWidget {
  const _LaborLineDialog({this.line});
  final LaborLineEntity? line;

  @override
  State<_LaborLineDialog> createState() => _LaborLineDialogState();
}

class _LaborLineDialogState extends State<_LaborLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  late final TextEditingController _feeCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.line?.description ?? '');
    _feeCtrl = TextEditingController(
      text: (widget.line?.fee ?? 0) > 0
          ? widget.line!.fee.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      LaborLineInput(
        description: _descCtrl.text.trim(),
        fee: double.parse(_feeCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.line == null ? 'Add Labor' : 'Edit Labor',
      leadingIcon: LucideIcons.wrench,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              style: AppTextStyles.fieldInput,
              key: const Key('labor-desc-field'),
              controller: _descCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Engine tune-up',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              style: AppTextStyles.fieldInput,
              key: const Key('labor-fee-field'),
              controller: _feeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Fee',
                prefixText: '${AppConstants.currencySymbol} ',
              ),
              validator: (v) {
                final parsed = double.tryParse(v?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Fee must be greater than 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: () => Navigator.pop(context)),
        appDialogPrimary(context, widget.line == null ? 'Add' : 'Save',
            onTap: _submit),
      ],
    );
  }
}

/// The ONE labor row (POS register + Job Order editor) — the Job Order
/// style: whole-card tap opens the shared edit dialog, trailing ✕ removes.
/// No swipe-to-dismiss, no pencil.
class LaborLineRow extends StatelessWidget {
  const LaborLineRow({
    super.key,
    required this.line,
    required this.onEdited,
    required this.onRemove,
  });

  final LaborLineEntity line;
  final void Function(String description, double fee) onEdited;
  final VoidCallback onRemove;

  Future<void> _edit(BuildContext context) async {
    final result = await showLaborLineDialog(context, line: line);
    if (result == null) return;
    onEdited(result.description, result.fee);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        radius: AppRadius.md,
        onTap: () => _edit(context),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 4, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Icon(LucideIcons.wrench, size: 14, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line.description.isEmpty ? 'Service' : line.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              line.fee.toCurrency(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              visualDensity: VisualDensity.compact,
              color: muted,
              onPressed: onRemove,
              tooltip: 'Remove labor line',
            ),
          ],
        ),
      ),
    );
  }
}
