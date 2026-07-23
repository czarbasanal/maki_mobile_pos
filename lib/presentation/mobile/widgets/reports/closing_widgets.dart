import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/variance_style.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

String _signedPeso(double v) =>
    '${v < 0 ? '-' : '+'}${AppConstants.currencySymbol}${v.abs().toCurrencyWithoutSymbol()}';

/// `AppCard` section with a Lucide icon header — the closing-flow card shell.
/// [trailing] (optional) renders right-aligned in the header row, e.g. the
/// Expenses card's compact Add Expense button.
class ClosingSectionCard extends StatelessWidget {
  const ClosingSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: iconColor ?? theme.colorScheme.primary),
              const SizedBox(width: 9),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Label/value row used in every closing section. [indented] = a sub-row
/// (e.g. GCash/Maya under Non-cash sales); [dense] = the tighter history-detail
/// variant (13px / weight 500).
class ClosingKvRow extends StatelessWidget {
  const ClosingKvRow({
    super.key,
    required this.label,
    required this.value,
    this.indented = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool indented;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final subValue = isDark ? const Color(0xFFAEC0C6) : const Color(0xFF5A6468);
    final labelColor = indented ? theme.colorScheme.outline : muted;
    final valueColor = indented ? subValue : theme.colorScheme.onSurface;
    final fontSize = (dense || indented) ? 13.0 : 14.0;
    final vPad = dense ? 3.0 : (indented ? 4.0 : 5.0);

    return Padding(
      padding: EdgeInsets.only(
        top: vPad,
        bottom: vPad,
        left: indented ? (dense ? 14 : 16) : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(fontSize: fontSize, color: labelColor)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: dense ? FontWeight.w500 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Variance shown as a tinted panel (End-of-Day form + closed view).
class VariancePanel extends StatelessWidget {
  const VariancePanel({super.key, required this.variance});
  final double variance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final s = VarianceStyle.of(variance, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.panelTint,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Variance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                _VarianceChip(style: s),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _signedPeso(variance),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: s.text,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _VarianceChip extends StatelessWidget {
  const _VarianceChip({required this.style});
  final VarianceStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.pillTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 11, color: style.text),
          const SizedBox(width: 3),
          Text(
            style.word,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: style.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Variance shown as a tinted pill (Closing-History row trailing).
class VariancePill extends StatelessWidget {
  const VariancePill({super.key, required this.variance});
  final double variance;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = VarianceStyle.of(variance, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.pillTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: s.text),
          const SizedBox(width: 4),
          Text(
            _signedPeso(variance),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: s.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labeled, filled ₱ input used across the closing form (label above the box).
class ClosingField extends StatelessWidget {
  const ClosingField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.enabled = true,
    this.pesoPrefix = true,
    this.hintText,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final bool enabled;
  final bool pesoPrefix;
  final String? hintText;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted;
    final border = isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder;

    OutlineInputBorder outline(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text.rich(
            TextSpan(
              text: label,
              style: TextStyle(fontSize: 12, color: muted),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: pesoPrefix
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: fill,
            hintText: hintText,
            prefixText: pesoPrefix ? '₱ ' : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: outline(border, 1),
            enabledBorder: outline(border, 1),
            focusedBorder: outline(theme.colorScheme.primary, 1.5),
          ),
        ),
      ],
    );
  }
}

/// Soft-amber banner shown when sales/voids landed after the day was closed.
class PostCloseWarningBanner extends StatelessWidget {
  const PostCloseWarningBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.warningBannerFill(dark);
    final borderC = AppColors.warningBannerBorder(dark);
    final textC = AppColors.warningBannerText(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderC),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle,
              size: 19, color: AppColors.warningIcon(dark)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: textC),
            ),
          ),
        ],
      ),
    );
  }
}

/// Success banner naming who closed the day and when.
class ClosedByBanner extends StatelessWidget {
  const ClosedByBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0x244CAF50) : AppColors.successLight;
    final fg = AppColors.successText(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.badgeCheck, size: 20, color: fg),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _plainPeso(double v) =>
    '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';

/// Add-a-row peso amount list (Plate No DP / Delivery on the EOD form).
/// The amount input + Add appends to [amounts]; each row is removable while
/// the day is open; a live sum line totals the entries. The parent owns the
/// list state — only ADDED rows count toward the sums.
///
/// [controller] is owned by the caller (same pattern as every other
/// `ClosingField` on the EOD form), not created internally — the caller
/// needs to read the pending (not-yet-Added) text off it, e.g. to
/// auto-commit or block on Close Day so a typed-but-not-Added amount is
/// never silently dropped.
class ClosingAmountList extends StatelessWidget {
  const ClosingAmountList({
    super.key,
    required this.label,
    required this.amounts,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<double> amounts;
  final TextEditingController controller;
  final ValueChanged<List<double>> onChanged;
  final bool enabled;

  void _add() {
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null || parsed <= 0) return;
    onChanged([...amounts, parsed]);
    controller.clear();
  }

  void _removeAt(int index) {
    final next = List<double>.of(amounts)..removeAt(index);
    onChanged(next);
  }

  double get _sum => amounts.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ClosingField(
                label: label,
                controller: controller,
                enabled: enabled,
                hintText: '0',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: Key('add-amount-$label'),
                onPressed: enabled ? _add : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Add'),
              ),
            ),
          ],
        ),
        for (var i = 0; i < amounts.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Entry ${i + 1}',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
                Text(
                  _plainPeso(amounts[i]),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 15, color: muted),
                  visualDensity: VisualDensity.compact,
                  onPressed: enabled ? () => _removeAt(i) : null,
                  tooltip: 'Remove amount',
                ),
              ],
            ),
          ),
        if (amounts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClosingKvRow(
              label: '$label total (${amounts.length} '
                  '${amounts.length == 1 ? 'entry' : 'entries'})',
              value: _plainPeso(_sum),
            ),
          ),
      ],
    );
  }
}
