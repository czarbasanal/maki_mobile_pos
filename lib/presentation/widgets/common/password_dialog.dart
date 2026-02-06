import 'package:flutter/material.dart';

/// Reusable password verification dialog.
///
/// Used for sensitive operations like voiding sales or viewing costs.
class PasswordDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmButtonText;
  final Color? confirmButtonColor;
  final Future<bool> Function(String password) onVerify;

  const PasswordDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.confirmButtonText = 'Confirm',
    this.confirmButtonColor,
    required this.onVerify,
  });

  /// Shows the password dialog and returns true if verified successfully.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String confirmButtonText = 'Confirm',
    Color? confirmButtonColor,
    required Future<bool> Function(String password) onVerify,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordDialog(
        title: title,
        subtitle: subtitle,
        confirmButtonText: confirmButtonText,
        confirmButtonColor: confirmButtonColor,
        onVerify: onVerify,
      ),
    );
    return result ?? false;
  }

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isObscured = true;
  bool _isVerifying = false;
  String? _errorMessage;
  int _attempts = 0;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    // Auto-focus password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await widget.onVerify(password);

      if (isValid) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _attempts++;
        setState(() {
          _isVerifying = false;
          if (_attempts >= _maxAttempts) {
            _errorMessage = 'Maximum attempts reached. Please try again later.';
          } else {
            _errorMessage =
                'Incorrect password. ${_maxAttempts - _attempts} attempts remaining.';
          }
          _passwordController.clear();
        });

        if (_attempts >= _maxAttempts && mounted) {
          // Close dialog after max attempts
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context, false);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline,
              color: Colors.amber[800],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Password field
          TextField(
            controller: _passwordController,
            focusNode: _focusNode,
            obscureText: _isObscured,
            enabled: !_isVerifying && _attempts < _maxAttempts,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.password),
              suffixIcon: IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
              ),
              errorText: _errorMessage,
            ),
            onSubmitted: (_) => _verify(),
          ),

          // Security notice
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This action requires authentication for security.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying || _attempts >= _maxAttempts ? null : _verify,
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmButtonColor,
          ),
          child: _isVerifying
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.confirmButtonText),
        ),
      ],
    );
  }
}
