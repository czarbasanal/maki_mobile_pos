import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Button variants available in the app.
enum AppButtonVariant {
  /// Primary filled button with accent color
  primary,

  /// Secondary outlined button
  secondary,

  /// Text-only button
  text,

  /// Danger/destructive action button
  danger,
}

/// A customized button widget for the POS app.
///
/// Features:
/// - Multiple variants (primary, secondary, text, danger)
/// - Loading state with spinner
/// - Icon support (leading and trailing)
/// - Full width option
/// - Disabled state
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final bool enabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.enabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.height = 52,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: _buildButton(context, isDisabled),
    );
  }

  Widget _buildButton(BuildContext context, bool isDisabled) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _buildPrimaryButton(context, isDisabled);
      case AppButtonVariant.secondary:
        return _buildSecondaryButton(context, isDisabled);
      case AppButtonVariant.text:
        return _buildTextButton(context, isDisabled);
      case AppButtonVariant.danger:
        return _buildDangerButton(context, isDisabled);
    }
  }

  Widget _buildPrimaryButton(BuildContext context, bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: padding,
        disabledBackgroundColor: AppColors.lightAccent.withOpacity(0.5),
        disabledForegroundColor: AppColors.lightAccentText.withOpacity(0.7),
      ),
      child: _buildChild(AppColors.lightAccentText),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, bool isDisabled) {
    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: padding,
      ),
      child: _buildChild(Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildTextButton(BuildContext context, bool isDisabled) {
    return TextButton(
      onPressed: isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        padding: padding,
      ),
      child: _buildChild(Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildDangerButton(BuildContext context, bool isDisabled) {
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        padding: padding,
        disabledBackgroundColor: AppColors.error.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.7),
      ),
      child: _buildChild(Colors.white),
    );
  }

  Widget _buildChild(Color contentColor) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(contentColor),
        ),
      );
    }

    final List<Widget> children = [];

    if (leadingIcon != null) {
      children.add(Icon(leadingIcon, size: 20));
      children.add(const SizedBox(width: 8));
    }

    children.add(
      Text(
        text,
        style: AppTextStyles.button,
      ),
    );

    if (trailingIcon != null) {
      children.add(const SizedBox(width: 8));
      children.add(Icon(trailingIcon, size: 20));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}
