import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_fee_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/fee_line_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

const _uuid = Uuid();

/// Add-flow dialog: pick an active catalog shop fee, then confirm (and edit,
/// if needed) the amount. A default amount pre-fills an editable field; a
/// fee with no default requires the cashier to type one. Returns a fully
/// formed [FeeLineEntity] (id minted here, like cart items/labor lines) or
/// null if cancelled.
Future<FeeLineEntity?> showAddFeeLineDialog(
  BuildContext context, {
  required List<ShopFeeEntity> activeFees,
}) {
  return showDialog<FeeLineEntity>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _AddFeeLineDialog(activeFees: activeFees),
  );
}

class _AddFeeLineDialog extends StatefulWidget {
  const _AddFeeLineDialog({required this.activeFees});
  final List<ShopFeeEntity> activeFees;

  @override
  State<_AddFeeLineDialog> createState() => _AddFeeLineDialogState();
}

/// Fee name that requires a cashier-entered description of what's being
/// charged (an outside-item charge with no fixed catalog meaning).
const _chargeItemFeeName = 'Charge Item';

class _AddFeeLineDialogState extends State<_AddFeeLineDialog> {
  final _formKey = GlobalKey<FormState>();
  ShopFeeEntity? _selected;
  late TextEditingController _amountCtrl;
  late TextEditingController _descriptionCtrl;

  bool get _requiresDescription => _selected?.name == _chargeItemFeeName;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _pick(ShopFeeEntity fee) {
    setState(() {
      _selected = fee;
      final defaultAmount = fee.defaultAmount;
      _amountCtrl.text =
          (defaultAmount != null && defaultAmount > 0)
              ? defaultAmount.toStringAsFixed(2)
              : '';
      _descriptionCtrl.text = '';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final fee = _selected;
    if (fee == null) return;
    Navigator.pop(
      context,
      FeeLineEntity(
        id: _uuid.v4(),
        name: fee.name,
        amount: double.parse(_amountCtrl.text.trim()),
        description: _requiresDescription
            ? _descriptionCtrl.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected == null) {
      return AppDialog(
        title: 'Add Shop Fee',
        leadingIcon: LucideIcons.receipt,
        content: widget.activeFees.isEmpty
            ? Text(
                'No shop fees configured. Add one in Settings first.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final fee in widget.activeFees)
                    _FeeChoiceTile(fee: fee, onTap: () => _pick(fee)),
                ],
              ),
        actions: [
          appDialogCancel(context, 'Cancel',
              onTap: () => Navigator.pop(context)),
        ],
      );
    }

    return AppDialog(
      title: 'Add Shop Fee',
      leadingIcon: LucideIcons.receipt,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selected.name, style: Theme.of(context).textTheme.bodyMedium),
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
            if (_requiresDescription) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                style: AppTextStyles.fieldInput,
                key: const Key('fee-description-field'),
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is being charged?',
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancel(context, 'Back', onTap: () {
          setState(() => _selected = null);
        }),
        appDialogPrimary(context, 'Add', onTap: _submit),
      ],
    );
  }
}

class _FeeChoiceTile extends StatelessWidget {
  const _FeeChoiceTile({required this.fee, required this.onTap});
  final ShopFeeEntity fee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final defaultAmount = fee.defaultAmount;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(fee.name, style: theme.textTheme.bodyMedium),
            ),
            Text(
              defaultAmount != null && defaultAmount > 0
                  ? defaultAmount.toCurrency()
                  : 'Enter amount',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible "Shop Fees" block — mirrors the Labor & Service section's
/// pattern: hidden-or-empty subtitle, add affordance, editable rows. Belongs
/// beside Labor & Service on the POS cart (and, per Task 5b, reused wherever
/// Labor is reused).
class FeeSection extends ConsumerWidget {
  const FeeSection({super.key, required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Watched (not just read) so the stream is warmed up well before the Add
    // button is tapped — by the time the cashier expands this section and
    // taps Add, activeFees below already has data instead of racing the
    // first emission.
    final activeFees =
        ref.watch(activeShopFeesProvider).valueOrNull ?? const [];

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: cart.feeLines.isNotEmpty,
        iconColor: muted,
        collapsedIconColor: muted,
        leading: const Icon(LucideIcons.receipt, size: 19),
        title: Text(
          'Shop Fees',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: cart.feeLines.isEmpty
            ? Text(
                'Optional — add shop fees',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: muted, fontSize: 12),
              )
            : Text(
                '${cart.feeLines.length} fee(s) · ${cart.feesTotal.toCurrency()}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: muted, fontSize: 12),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: cart.feeLines
                  .map(
                    (line) => FeeLineRow(
                      line: line,
                      onAmountEdited: (amount) => ref
                          .read(cartProvider.notifier)
                          .updateFeeLine(line.copyWith(amount: amount)),
                      onRemove: () => ref
                          .read(cartProvider.notifier)
                          .removeFeeLine(line.id),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddFeeDialog(context, ref, activeFees),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Add fee line'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFeeDialog(
    BuildContext context,
    WidgetRef ref,
    List<ShopFeeEntity> activeFees,
  ) async {
    final result =
        await showAddFeeLineDialog(context, activeFees: activeFees);
    if (result == null) return;
    ref.read(cartProvider.notifier).addFeeLine(result);
  }
}
