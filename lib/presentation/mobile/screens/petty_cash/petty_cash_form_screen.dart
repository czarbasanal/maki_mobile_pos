import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/providers/petty_cash_provider.dart';

enum _Direction { cashIn, cashOut }

/// Form for recording a cash in or cash out petty-cash entry.
class PettyCashFormScreen extends ConsumerStatefulWidget {
  const PettyCashFormScreen({super.key});

  @override
  ConsumerState<PettyCashFormScreen> createState() =>
      _PettyCashFormScreenState();
}

class _PettyCashFormScreenState extends ConsumerState<PettyCashFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  _Direction _direction = _Direction.cashOut;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);

    final amount = double.parse(_amountController.text);
    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();
    final notifier = ref.read(pettyCashOperationsProvider.notifier);

    final result = _direction == _Direction.cashIn
        ? await notifier.cashIn(
            amount: amount,
            description: description,
            notes: notes.isEmpty ? null : notes,
          )
        : await notifier.cashOut(
            amount: amount,
            description: description,
            notes: notes.isEmpty ? null : notes,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result == null) {
      final state = ref.read(pettyCashOperationsProvider);
      final message = state.hasError
          ? state.error?.toString() ?? 'Operation failed'
          : 'Operation failed';
      context.showErrorSnackBar(message);
      return;
    }

    context.showSuccessSnackBar(
      _direction == _Direction.cashIn ? 'Cash in recorded' : 'Cash out recorded',
    );
    context.go(RoutePaths.pettyCash);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petty Cash Entry'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.pettyCash),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Direction>(
                segments: const [
                  ButtonSegment(
                    value: _Direction.cashOut,
                    label: Text('Cash out'),
                    icon: Icon(CupertinoIcons.arrow_down),
                  ),
                  ButtonSegment(
                    value: _Direction.cashIn,
                    label: Text('Cash in'),
                    icon: Icon(CupertinoIcons.arrow_up),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                enabled: !_busy,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '₱ ',
                  prefixIcon: Icon(CupertinoIcons.money_dollar),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  prefixIcon: Icon(CupertinoIcons.doc_text),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(CupertinoIcons.list_bullet),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_direction == _Direction.cashIn
                        ? 'Record Cash In'
                        : 'Record Cash Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
