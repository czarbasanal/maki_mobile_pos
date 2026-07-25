import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Edit-amount dialog for an existing fee line. The name is fixed (it was
/// chosen from the shop-fee catalog when the line was added) — only the
/// amount is editable here, matching how the amount is entered/confirmed at
/// add time.
Future<double?> showFeeAmountDialog(
  BuildContext context, {
  required String name,
  required double initialAmount,
}) {
  return showDialog<double>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _FeeAmountDialog(name: name, initialAmount: initialAmount),
  );
}

class _FeeAmountDialog extends StatefulWidget {
  const _FeeAmountDialog({required this.name, required this.initialAmount});
  final String name;
  final double initialAmount;

  @override
  State<_FeeAmountDialog> createState() => _FeeAmountDialogState();
}

class _FeeAmountDialogState extends State<_FeeAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, double.parse(_amountCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Edit Fee Amount',
      leadingIcon: LucideIcons.receipt,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              style: AppTextStyles.fieldInput,
              key: const Key('fee-amount-field'),
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '${AppConstants.currencySymbol} ',
              ),
              validator: (v) {
                final parsed = double.tryParse(v?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Amount must be greater than 0';
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
        appDialogPrimary(context, 'Save', onTap: _submit),
      ],
    );
  }
}

/// One shop-fee row on the cart — Job Order style like [LaborLineRow]:
/// whole-card tap opens the amount-edit dialog, trailing ✕ removes.
class FeeLineRow extends StatelessWidget {
  const FeeLineRow({
    super.key,
    required this.line,
    required this.onAmountEdited,
    required this.onRemove,
  });

  final FeeLineEntity line;
  final void Function(double amount) onAmountEdited;
  final VoidCallback onRemove;

  Future<void> _edit(BuildContext context) async {
    final amount = await showFeeAmountDialog(
      context,
      name: line.name,
      initialAmount: line.amount,
    );
    if (amount == null) return;
    onAmountEdited(amount);
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
            Icon(LucideIcons.receipt, size: 14, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line.displayLabel,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              line.amount.toCurrency(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              visualDensity: VisualDensity.compact,
              color: muted,
              onPressed: onRemove,
              tooltip: 'Remove fee line',
            ),
          ],
        ),
      ),
    );
  }
}
