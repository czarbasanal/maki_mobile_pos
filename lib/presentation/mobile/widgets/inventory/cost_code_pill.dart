import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Outlined pill rendering a cost-code chip for a given `cost`.
///
/// Encoding happens at display time via [encodeCostProvider], which
/// watches [costCodeMappingProvider]. As a result every place that
/// uses this widget refreshes immediately when admin saves a new
/// mapping — without rewriting stored `costCode` fields on each
/// product or sale line.
///
/// The widget is intentionally stateless aside from the provider read
/// so it can be embedded in inventory tiles, POS cart lines, and any
/// other surface that wants the same "encoded cost" affordance.
class CostCodePill extends ConsumerWidget {
  const CostCodePill({
    super.key,
    required this.cost,
    this.compact = false,
  });

  /// Cost (in currency units) that should be encoded.
  final double cost;

  /// When true, renders with the smaller font/icon used inside dense
  /// list rows. Default (false) is the standard size suitable for
  /// detail screens and roomier surfaces.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(encodeCostProvider(cost));
    final iconSize = compact ? 12.0 : 16.0;
    final textSize = compact ? 12.0 : 13.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: 6,
          );

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.lock,
            size: iconSize,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 4),
          Text(
            code,
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: AppColors.warningDark,
            ),
          ),
        ],
      ),
    );
  }
}
