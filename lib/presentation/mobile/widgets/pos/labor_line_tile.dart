import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// A single labor/service line in the cart. Mirrors [CartItemTile] but with
/// no quantity stepper and — deliberately — no discount control: labor is
/// full price by construction (decision #4 in the spec).
///
/// Tapping the pencil opens an edit dialog that reports the new
/// `(description, fee)` via [onEdited]; swipe-to-dismiss reports [onRemove].
class LaborLineTile extends StatelessWidget {
  final LaborLineEntity line;
  final void Function(String description, double fee) onEdited;
  final VoidCallback onRemove;

  const LaborLineTile({
    super.key,
    required this.line,
    required this.onEdited,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: Key('labor-${line.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg - 4),
        color: AppColors.error,
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: AppCard(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              Icon(LucideIcons.wrench, size: 18, color: muted),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Text(
                  line.description.isEmpty ? 'Service' : line.description,
                  style: AppTextStyles.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit labor line',
                onPressed: () => _showEditDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final descController = TextEditingController(text: line.description);
    final feeController = TextEditingController(
      text: line.fee > 0 ? line.fee.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Labor / Service'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('labor-desc-field'),
                controller: descController,
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
                key: const Key('labor-fee-field'),
                controller: feeController,
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      onEdited(
        descController.text.trim(),
        double.parse(feeController.text.trim()),
      );
    }
    // Controllers are dialog-local (not StatefulWidget-owned); they hold no
    // external listeners and will be GC'd when this async frame exits.
    // Calling dispose() here races with the dialog's close animation and
    // causes a "used after disposed" assertion in tests, so we omit it.
  }
}
