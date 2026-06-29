import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// The single password / single-input dialog variant, built on [AppDialog].
/// Absorbs both legacy password dialogs: pass [maxAttempts] for the lockout
/// behavior, and supply an [onVerify] that audit-logs for the audited path.
/// Returns true only on a successful verification.
Future<bool> showAppPasswordDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String confirmLabel = 'Confirm',
  required Future<bool> Function(String password) onVerify,
  int? maxAttempts,
  String infoNote = 'Re-authentication is required for this action.',
  Color? confirmColor,
}) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (_) => _AppPasswordDialog(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      onVerify: onVerify,
      maxAttempts: maxAttempts,
      infoNote: infoNote,
      confirmColor: confirmColor,
    ),
  );
  return result ?? false;
}

class _AppPasswordDialog extends StatefulWidget {
  const _AppPasswordDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.onVerify,
    required this.maxAttempts,
    required this.infoNote,
    required this.confirmColor,
  });

  final String title;
  final String? subtitle;
  final String confirmLabel;
  final Future<bool> Function(String password) onVerify;
  final int? maxAttempts;
  final String infoNote;
  final Color? confirmColor;

  @override
  State<_AppPasswordDialog> createState() => _AppPasswordDialogState();
}

class _AppPasswordDialogState extends State<_AppPasswordDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  int _attempts = 0;

  bool get _lockedOut =>
      widget.maxAttempts != null && _attempts >= widget.maxAttempts!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _lockedOut) return;
    if (_controller.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    bool ok = false;
    Object? err;
    try {
      ok = await widget.onVerify(_controller.text);
    } catch (e) {
      err = e;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    // A thrown verification (e.g. flaky network) is surfaced but does NOT
    // consume a lockout attempt — only a genuine wrong password does.
    if (err != null) {
      setState(() {
        _busy = false;
        _error = 'Verification failed: $err';
      });
      return;
    }
    _attempts++;
    setState(() {
      _busy = false;
      if (_lockedOut) {
        _error = 'Maximum attempts reached. Please try again later.';
      } else if (widget.maxAttempts != null) {
        _error =
            'Incorrect password. ${widget.maxAttempts! - _attempts} attempts remaining.';
      } else {
        _error = 'Incorrect password';
      }
      _controller.clear();
    });
    if (_lockedOut) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppDialog(
      title: widget.title,
      leadingIcon: LucideIcons.lock,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(widget.subtitle!,
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: appDialogBodyColor(dark))),
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 7),
            child: Text('Password',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary)),
          ),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            obscureText: _obscure,
            enabled: !_busy && !_lockedOut,
            onSubmitted: (_) => _verify(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              prefixIcon: Icon(LucideIcons.lock,
                  size: 19, color: theme.colorScheme.primary),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 19, color: muted),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              errorText: _error,
              border: _border(theme, false),
              enabledBorder: _border(theme, false),
              focusedBorder: _border(theme, true),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dark ? const Color(0x0DFFFFFF) : const Color(0x0F283E46),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 16, color: appDialogBodyColor(dark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.infoNote,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: appDialogBodyColor(dark))),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: _busy ? null : () => Navigator.of(context).pop(false)),
        FilledButton(
          onPressed: (_busy || _lockedOut) ? null : _verify,
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor ?? theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            textStyle:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }

  OutlineInputBorder _border(ThemeData theme, bool focused) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: focused
              ? theme.colorScheme.primary
              : (theme.brightness == Brightness.dark
                  ? AppColors.darkInputBorder
                  : AppColors.lightInputBorder),
          width: focused ? 1.5 : 1,
        ),
      );
}
