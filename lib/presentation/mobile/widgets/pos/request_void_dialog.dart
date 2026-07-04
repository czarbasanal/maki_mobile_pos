import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/void_reason_field.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Collects a reason from a cashier/staff and submits a void request for an
/// admin to approve. No password — that gate lives on the admin's approval.
/// Uses the same admin-managed reason dropdown (+ "Other" detail) as the
/// admin Void Sale dialog.
class RequestVoidDialog extends ConsumerStatefulWidget {
  final SaleEntity sale;
  final VoidCallback onRequested;

  const RequestVoidDialog({
    super.key,
    required this.sale,
    required this.onRequested,
  });

  static Future<void> show({
    required BuildContext context,
    required SaleEntity sale,
    required VoidCallback onRequested,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      barrierColor: AppDialog.scrimColor(dark),
      builder: (_) => RequestVoidDialog(sale: sale, onRequested: onRequested),
    );
  }

  @override
  ConsumerState<RequestVoidDialog> createState() => _RequestVoidDialogState();
}

class _RequestVoidDialogState extends ConsumerState<RequestVoidDialog> {
  final _detailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;
  String? _selectedReason;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final reason =
        VoidReasonField.resolveReason(_selectedReason, _detailController.text);
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await context.runWithWaiting(
      () => ref
          .read(voidRequestOperationsProvider.notifier)
          .requestVoid(sale: widget.sale, reason: reason),
      message: 'Submitting…',
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      widget.onRequested();
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AppDialog(
      title: 'Request Void',
      leadingIcon: LucideIcons.send,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sale ${widget.sale.saleNumber} will be sent to an admin for approval.',
              style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: appDialogBodyColor(dark)),
            ),
            const SizedBox(height: 12),
            VoidReasonField(
              selectedReason: _selectedReason,
              detailController: _detailController,
              onChanged: (value) => setState(() => _selectedReason = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                    color: dark ? AppColors.errorOnDark : AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        appDialogCancel(
          context,
          'Cancel',
          onTap: _submitting ? () {} : () => Navigator.pop(context),
        ),
        appDialogPrimary(
          context,
          _submitting ? 'Sending…' : 'Send Request',
          onTap: _submitting ? () {} : _submit,
        ),
      ],
    );
  }
}
