import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/void_request_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/sales/void_status_style.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Three status summary cards (Pending / Approved / Rejected) for the admin
/// void-requests queue — mirrors the Inventory stock-filter summary cards
/// (`inventory_screen.dart`'s `_buildSummaryCard`). Tapping a card toggles it
/// as the active status filter; tapping the already-selected card clears it.
///
/// Counts are nullable: pass `null` for a card whose underlying query
/// errored (e.g. FAILED_PRECONDITION from a missing composite index, or a
/// permission error) so it renders a dash ('—') instead of a misleading
/// '0' — a real zero and a broken query must never look the same. The
/// caller (VoidRequestsScreen) is expected to pass `null` on `AsyncError`
/// and `0` while loading.
class VoidStatusSummaryCards extends StatelessWidget {
  const VoidStatusSummaryCards({
    super.key,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.selected,
    required this.onSelect,
  });

  final int? pendingCount;
  final int? approvedCount;
  final int? rejectedCount;
  final VoidRequestStatus? selected;
  final ValueChanged<VoidRequestStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _card(context, VoidRequestStatus.pending, pendingCount),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _card(context, VoidRequestStatus.approved, approvedCount),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _card(context, VoidRequestStatus.rejected, rejectedCount),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, VoidRequestStatus status, int? count) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = VoidStatusStyle.of(status, dark: dark);
    final isSelected = selected == status;

    final card = AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      onTap: () => onSelect(isSelected ? null : status),
      child: Column(
        children: [
          Icon(style.squareIcon, color: style.iconColor, size: 19),
          const SizedBox(height: 4),
          Text(
            count == null ? '—' : '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1,
              color: style.iconColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            style.label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: muted,
            ),
          ),
        ],
      ),
    );

    if (!isSelected) return card;

    // Paint the selected ring over the card edge without re-deriving the
    // AppCard surface (light shadow / dark hairline) — mirrors the
    // Inventory summary-card selection treatment.
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: style.iconColor, width: 1.5),
      ),
      child: card,
    );
  }
}
