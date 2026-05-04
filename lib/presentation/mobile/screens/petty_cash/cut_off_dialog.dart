import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/petty_cash_provider.dart';

/// Dialog for the end-of-day petty cash cut-off.
///
/// Shows the system balance, captures the cashier's counted balance,
/// surfaces the variance, and triggers [PerformCutOffUseCase] on confirm.
class CutOffDialog extends ConsumerStatefulWidget {
  final double currentBalance;

  const CutOffDialog({super.key, required this.currentBalance});

  @override
  ConsumerState<CutOffDialog> createState() => _CutOffDialogState();
}

class _CutOffDialogState extends ConsumerState<CutOffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _countedController = TextEditingController();
  final _notesController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _countedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? get _counted => double.tryParse(_countedController.text);
  double? get _variance =>
      _counted == null ? null : _counted! - widget.currentBalance;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);

    final notes = _notesController.text.trim();
    final composedNotes = _variance == null
        ? (notes.isEmpty ? null : notes)
        : 'Counted: ${AppConstants.currencySymbol}${_counted!.toStringAsFixed(2)} '
            '(variance ${_variance! >= 0 ? '+' : ''}${_variance!.toStringAsFixed(2)})'
            '${notes.isEmpty ? '' : ' • $notes'}';

    final record = await ref
        .read(pettyCashOperationsProvider.notifier)
        .performCutOff(notes: composedNotes);

    if (!mounted) return;
    setState(() => _busy = false);

    if (record == null) {
      context.showErrorSnackBar('Cut-off failed. Check permissions.');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variance = _variance;

    return AlertDialog(
      title: const Text('End-of-day cut-off'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kv(
              context,
              'System balance',
              '${AppConstants.currencySymbol}${widget.currentBalance.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countedController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Counted cash *',
                prefixText: '₱ ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Counted cash is required';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed < 0) return 'Enter a valid amount';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            if (variance != null) ...[
              const SizedBox(height: 12),
              _kv(
                context,
                'Variance',
                '${variance >= 0 ? '+' : ''}${AppConstants.currencySymbol}${variance.toStringAsFixed(2)}',
                color: variance == 0
                    ? AppColors.successDark
                    : (variance < 0 ? AppColors.error : AppColors.warningDark),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This zeroes out the fund. The closing balance will be saved '
              'as a cut-off entry.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Perform cut-off'),
        ),
      ],
    );
  }

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
