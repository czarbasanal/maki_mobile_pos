import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
              // Success glyph — filled success-tint circle.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.success.withValues(alpha: 0.18)
                      : AppColors.successLight,
                ),
                child: const Icon(
                  LucideIcons.check,
                  color: AppColors.successDark,
                  size: 48,
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
              _buildChangeDueHero(theme, isDark),
              const SizedBox(height: AppSpacing.md),
              _buildAmountCard(theme, mutedFill, hairline),
              if (widget.warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildWarningsCard(theme),
              ],
              const SizedBox(height: AppSpacing.lg),
              // Side-by-side actions — Receipt (secondary) left, Done
              // (primary close) right. Both pinned to the same 48px height
              // and lg corner radius so the OutlinedButton.icon and the
              // FilledButton render identically.
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: widget.onPrintReceipt,
                        icon: const Icon(LucideIcons.receipt, size: 18),
                        label: const Text('Receipt'),
                        style: OutlinedButton.styleFrom(shape: _kButtonShape),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: SizedBox(
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeDueHero(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.success.withValues(alpha: 0.18)
            : AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            'CHANGE DUE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.successDark,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${AppConstants.currencySymbol}'
            '${widget.sale.changeGiven.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppColors.successDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme, Color fill, Color hairline) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hairline),
      ),
      child: Column(
        children: [
          _buildAmountRow(
            theme,
            'Total',
            '${AppConstants.currencySymbol}'
            '${widget.sale.grandTotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAmountRow(
            theme,
            'Received',
            '${AppConstants.currencySymbol}'
            '${widget.sale.amountReceived.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(ThemeData theme, String label, String value) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
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
                LucideIcons.alertTriangle,
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
