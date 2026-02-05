import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/widgets.dart';

/// A dialog that prompts for password verification.
///
/// Used for protected actions like:
/// - Viewing product costs
/// - Voiding sales
/// - Changing cost code settings
class PasswordDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmButtonText;
  final Future<bool> Function(String password) onVerify;

  const PasswordDialog({
    super.key,
    this.title = 'Password Required',
    this.message = 'Please enter your password to continue.',
    this.confirmButtonText = 'Confirm',
    required this.onVerify,
  });

  /// Shows the password dialog and returns true if verification succeeded.
  static Future<bool> show({
    required BuildContext context,
    String title = 'Password Required',
    String message = 'Please enter your password to continue.',
    String confirmButtonText = 'Confirm',
    required Future<bool> Function(String password) onVerify,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordDialog(
        title: title,
        message: message,
        confirmButtonText: confirmButtonText,
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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await widget.onVerify(_passwordController.text);

      if (!mounted) return;

      if (isValid) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Incorrect password. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: AppColors.primaryDark,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _passwordController,
              labelText: 'Password',
              hintText: 'Enter your password',
              obscureText: true,
              prefixIcon: Icons.lock_outline,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleVerify(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.errorDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          text: widget.confirmButtonText,
          onPressed: _handleVerify,
          isLoading: _isLoading,
          width: 120,
          height: 44,
        ),
      ],
    );
  }
}
