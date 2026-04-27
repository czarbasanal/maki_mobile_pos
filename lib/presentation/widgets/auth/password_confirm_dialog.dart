import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Modal that re-authenticates the current user before allowing a sensitive
/// operation (e.g. voiding a sale, viewing product cost, editing cost-code map).
///
/// Returns `true` only after the user enters a correct password. Audit-logs
/// every attempt via [ActivityLogger].
///
/// Usage:
/// ```dart
/// final ok = await PasswordConfirmDialog.show(
///   context,
///   purpose: 'Void sale',
/// );
/// if (ok) { /* proceed */ }
/// ```
class PasswordConfirmDialog extends ConsumerStatefulWidget {
  final String purpose;
  final String? message;

  const PasswordConfirmDialog({
    super.key,
    required this.purpose,
    this.message,
  });

  static Future<bool> show(
    BuildContext context, {
    required String purpose,
    String? message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PasswordConfirmDialog(purpose: purpose, message: message),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PasswordConfirmDialog> createState() =>
      _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends ConsumerState<PasswordConfirmDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _errorText;
  int _attempts = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });

    final auth = ref.read(authActionsProvider);
    final logger = ref.read(activityLoggerProvider);
    final user = ref.read(currentUserProvider).valueOrNull;

    bool ok = false;
    Object? error;
    try {
      ok = await auth.verifyPassword(_controller.text);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      if (user != null) {
        unawaited(_logVerified(logger, user));
      }
      return;
    }

    _attempts += 1;
    if (user != null) {
      unawaited(_logFailed(logger, user));
    }
    setState(() {
      _busy = false;
      _errorText =
          error == null ? 'Incorrect password' : 'Verification failed: $error';
    });
  }

  Future<void> _logVerified(ActivityLogger logger, UserEntity user) async {
    await logger.logPasswordVerified(user: user, purpose: widget.purpose);
  }

  Future<void> _logFailed(ActivityLogger logger, UserEntity user) async {
    await logger.logPasswordFailed(
      user: user,
      purpose: widget.purpose,
      attemptNumber: _attempts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.purpose),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.message ??
                  'Confirm your password to continue with this action.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              obscureText: _obscure,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
              onFieldSubmitted: (_) => _submit(),
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
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
