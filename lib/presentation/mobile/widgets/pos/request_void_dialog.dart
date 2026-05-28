import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Collects a reason from a cashier/staff and submits a void request for an
/// admin to approve. No password — that gate lives on the admin's approval.
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
    return showDialog(
      context: context,
      builder: (_) => RequestVoidDialog(sale: sale, onRequested: onRequested),
    );
  }

  @override
  ConsumerState<RequestVoidDialog> createState() => _RequestVoidDialogState();
}

class _RequestVoidDialogState extends ConsumerState<RequestVoidDialog> {
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 5) {
      setState(() =>
          _error = 'Please provide a more detailed reason (min 5 characters)');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await ref
        .read(voidRequestOperationsProvider.notifier)
        .requestVoid(sale: widget.sale, reason: reason);
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
    return AlertDialog(
      title: const Text('Request Void'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sale ${widget.sale.saleNumber} will be sent to an admin for approval.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'Why should this sale be voided?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Sending…' : 'Send Request'),
        ),
      ],
    );
  }
}
