import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Shared button shape so the stacked Receipt + Done actions render
/// with identical corners (theme defaults differ between Outlined and
/// Filled buttons; we pin both to AppRadius.lg).
final RoundedRectangleBorder _kButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadius.lg),
);

/// Dialog shown after successful checkout.
class CheckoutSuccessDialog extends StatefulWidget {
  final SaleEntity sale;
  final List<String> warnings;
  final VoidCallback onDone;
  final VoidCallback onPrintReceipt;

  const CheckoutSuccessDialog({
    super.key,
    required this.sale,
    this.warnings = const [],
    required this.onDone,
    required this.onPrintReceipt,
  });

  @override
  State<CheckoutSuccessDialog> createState() => _CheckoutSuccessDialogState();
}

class _CheckoutSuccessDialogState extends State<CheckoutSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;

    return Dialog(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success glyph — outlined success-colored circle (no fill)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_circle,
                  color: AppColors.successDark,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Payment Successful!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Sale number — hairline-bordered pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: mutedFill,
                  border: Border.all(color: hairline),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  widget.sale.saleNumber,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAmountCard(theme),
              if (widget.warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildWarningsCard(theme),
              ],
              const SizedBox(height: AppSpacing.lg),
              // Stacked actions — Receipt on top, Done at the bottom
              // (Done is the primary close action, so it anchors the
              // dialog's bottom edge). Both pinned to the same 48px
              // height and lg corner radius so the secondary
              // OutlinedButton.icon and the primary FilledButton
              // render identically.
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: widget.onPrintReceipt,
                  icon: const Icon(CupertinoIcons.doc_text),
                  label: const Text('Receipt'),
                  style: OutlinedButton.styleFrom(shape: _kButtonShape),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: widget.onDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: _kButtonShape,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        children: [
          _buildAmountRow(
            theme,
            'Total',
            '${AppConstants.currencySymbol}${widget.sale.grandTotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAmountRow(
            theme,
            'Received',
            '${AppConstants.currencySymbol}${widget.sale.amountReceived.toStringAsFixed(2)}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          _buildAmountRow(
            theme,
            'Change',
            '${AppConstants.currencySymbol}${widget.sale.changeGiven.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
    ThemeData theme,
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            fontSize: isHighlighted ? 18 : 14,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w600,
            fontSize: isHighlighted ? 24 : 14,
            color: isHighlighted ? AppColors.successDark : null,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningsCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 16,
                color: AppColors.warningDark,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Warnings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...widget.warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $warning',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.warningDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
