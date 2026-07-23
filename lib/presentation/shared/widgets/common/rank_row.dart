import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// One ranked product line — medal circle + name/subtitle + "N sold"/revenue,
/// then a share bar scaled to [maxQuantity] and an optional profit pill.
/// Extracted from the reports TopProductsCard so the dashboard's Top Selling
/// list shares the exact visual.
class RankRow extends StatelessWidget {
  const RankRow({
    super.key,
    required this.index,
    required this.name,
    required this.subtitle,
    required this.quantitySold,
    required this.revenue,
    required this.maxQuantity,
    this.onTap,
    this.profit,
  });

  /// 0-based rank (0 = gold, 1 = silver, 2 = bronze, 3+ = neutral).
  final int index;
  final String name;

  /// Second line under the name — the SKU on every current call site
  /// (mono-styled).
  final String subtitle;
  final int quantitySold;
  final double revenue;

  /// Quantity of the rank-1 row — scales the share bar.
  final int maxQuantity;
  final VoidCallback? onTap;

  /// When non-null, renders the green profit pill (admin-gated surfaces
  /// pass it; the dashboard never does).
  final double? profit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final progress = maxQuantity > 0 ? quantitySold / maxQuantity : 0.0;
    final medal = _rankColors(index, isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank medal.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: medal.ring,
                    width: index < 3 ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: medal.number,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style:
                          AppTextStyles.productName.copyWith(fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontSize: 11.5,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$quantitySold sold',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  Text(
                    revenue.toCurrency(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const SizedBox(width: 28),
              const SizedBox(width: 11),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: hairline,
                    valueColor: AlwaysStoppedAnimation<Color>(medal.bar),
                    minHeight: 6,
                  ),
                ),
              ),
              if (profit != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: AppColors.successFill(isDark),
                  ),
                  child: Text(
                    '+${AppConstants.currencySymbol}${profit!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successText(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Medal palette per 0-based rank — amber / silver / bronze for the top
  /// three, neutral after. Rank-1 leads gold in dark to match the primary
  /// flip.
  _RankColors _rankColors(int index, bool dark) {
    switch (index) {
      case 0:
        return _RankColors(
          ring: const Color(0xFFE8B84C),
          number: dark ? const Color(0xFFE8B84C) : const Color(0xFFB07A12),
          bar: const Color(0xFFE8B84C),
        );
      case 1:
        return _RankColors(
          ring: const Color(0xFF90A4AE),
          number: dark ? const Color(0xFFAEC0C6) : const Color(0xFF5E7079),
          bar: const Color(0xFF90A4AE),
        );
      case 2:
        return _RankColors(
          ring: const Color(0xFFB08D6F),
          number: dark ? const Color(0xFFCBA890) : const Color(0xFF8A6244),
          bar: const Color(0xFFB08D6F),
        );
      default:
        return _RankColors(
          ring: dark ? AppColors.darkInputBorder : AppColors.lightHairline,
          number:
              dark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
          bar: dark ? const Color(0xFF5E7A84) : const Color(0xFF283E46),
        );
    }
  }
}

class _RankColors {
  const _RankColors({
    required this.ring,
    required this.number,
    required this.bar,
  });
  final Color ring;
  final Color number;
  final Color bar;
}
