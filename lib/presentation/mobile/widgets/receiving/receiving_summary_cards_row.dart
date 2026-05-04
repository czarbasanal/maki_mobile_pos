import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';

/// Three summary cards on the receiving screen — Drafts (open, any
/// age), Completed (this month), Total Received (this month, peso).
/// Each card resolves its own loading state independently so a
/// fast-arriving count doesn't have to wait on a slower peso-total
/// query.
class ReceivingSummaryCardsRow extends ConsumerWidget {
  /// Tap handler for the Drafts card. Null disables the tap affordance.
  final VoidCallback? onTapDrafts;

  /// Tap handler for the Completed card. Null disables the tap affordance.
  final VoidCallback? onTapCompleted;

  const ReceivingSummaryCardsRow({
    super.key,
    this.onTapDrafts,
    this.onTapCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(receivingCountsProvider);
    final mtdTotal = ref.watch(monthToDateReceivingTotalProvider);

    // Surface a visible error chip rather than collapsing the row —
    // the previous SizedBox.shrink path silently hid all three cards
    // when the counts query failed.
    if (countsAsync.hasError) {
      return _ErrorRow(message: '${countsAsync.error}');
    }

    final draftValue = countsAsync.isLoading
        ? null
        : '${countsAsync.value?[ReceivingStatus.draft] ?? 0}';
    // Completed is the all-time count, not month-to-date — operators
    // want the full lifetime tally on this card.
    final completedValue = countsAsync.isLoading
        ? null
        : '${countsAsync.value?[ReceivingStatus.completed] ?? 0}';
    final totalValue = mtdTotal.isLoading
        ? null
        : _formatPesoCompact(mtdTotal.valueOrNull ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _CountCard(
              label: 'Drafts',
              value: draftValue,
              icon: CupertinoIcons.square_pencil,
              color: Colors.orange,
              onTap: onTapDrafts,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CountCard(
              label: 'Completed',
              value: completedValue,
              icon: CupertinoIcons.checkmark_circle,
              color: Colors.green,
              onTap: onTapCompleted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CountCard(
              label: 'Total Received',
              value: totalValue,
              icon: CupertinoIcons.calendar,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact peso formatter for the count card — keeps a 3-up row
  /// readable even when month totals run into six figures.
  String _formatPesoCompact(double value) {
    final symbol = AppConstants.currencySymbol;
    if (value >= 1000000) return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '$symbol${(value / 1000).toStringAsFixed(1)}K';
    return '$symbol${value.toStringAsFixed(0)}';
  }
}

/// Renders one count card. Pass `null` for [value] to show a loading
/// spinner — keeps the label and icon visible so the user can see
/// which card is still populating. The 32 px reservation on the value
/// slot keeps the row's height identical loading vs loaded so cards
/// don't shift as data arrives.
class _CountCard extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CountCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: Center(
              child: value == null
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    )
                  : Text(
                      value!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

/// Inline error chip for the summary row — replaces the previous
/// SizedBox.shrink so a counts-provider failure stays visible.
class _ErrorRow extends StatelessWidget {
  final String message;

  const _ErrorRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.error, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: theme.colorScheme.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Couldn't load receiving stats: $message",
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
