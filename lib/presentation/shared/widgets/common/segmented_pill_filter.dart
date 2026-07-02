import 'package:flutter/material.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// Segmented filter pill on an [AppCard]: equal-width segments, the selected
/// one filled slate (light) / gold (dark), per the report/price-history
/// handoff. [segmentKeyPrefix] gives each segment a `Key('<prefix>-<name>')`
/// for widget tests (enum `name`, else `toString`).
class SegmentedPillFilter<T> extends StatelessWidget {
  const SegmentedPillFilter({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.segmentKeyPrefix,
  });

  final List<T> values;
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? segmentKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final v in values) Expanded(child: _segment(context, v)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, T v) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSel = v == selected;
    final name = v is Enum ? v.name : v.toString();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(v),
      child: Container(
        key: segmentKeyPrefix == null ? null : Key('$segmentKeyPrefix-$name'),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? AppColors.primaryAccent : AppColors.brandSlate)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          labels[v]!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
            color: isSel
                ? (isDark ? AppColors.primaryDark : Colors.white)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
