// Pure stock-adjustment helpers — mirrors web_admin's
// `resolveStockChange.ts` (resolveStockChange / adjustmentValidity) exactly,
// same messages, same rule order. Kept pure (no Firestore) so the repo's
// transaction body (see ProductRepositoryImpl.adjustStockAudited) is thin
// glue over logic that's fully covered here.

/// How a stock adjustment changes the on-hand quantity.
///
/// `set` is a legal enum member name in Dart (it's only a contextual
/// keyword inside class member declarations), and `AdjustmentMode.set.name`
/// is `'set'` — matching the web's wire string exactly.
enum AdjustmentMode { add, remove, set }

/// Resulting before/after/delta for a stock adjustment.
class AdjustmentResult {
  final int before;
  final int after;
  final int delta;

  const AdjustmentResult({
    required this.before,
    required this.after,
    required this.delta,
  });
}

/// Resolves the before/after/delta for a stock adjustment. Pure — the
/// caller validates first (see [adjustmentValidity]).
AdjustmentResult resolveAdjustment(AdjustmentMode mode, int onHand, int qty) {
  final after = switch (mode) {
    AdjustmentMode.add => onHand + qty,
    AdjustmentMode.remove => onHand - qty,
    AdjustmentMode.set => qty,
  };
  return AdjustmentResult(before: onHand, after: after, delta: after - onHand);
}

/// Validation message for an adjustment, or null when it can be applied.
/// `qty` is the parsed quantity (null = not entered / not a whole number).
///
/// Rule order mirrors the web's `adjustmentValidity` exactly:
/// 1. qty present
/// 2. add/remove qty > 0
/// 3. resulting after >= 0 (remove gets the guide's sentence)
/// 4. a reason is picked
/// 5. a note is present when the reason requires one
String? adjustmentValidity({
  required AdjustmentMode mode,
  required int? qty,
  required int onHand,
  required String? reasonId,
  required bool requiresNote,
  required String note,
}) {
  if (qty == null) return 'Enter a quantity';

  if ((mode == AdjustmentMode.add || mode == AdjustmentMode.remove) &&
      qty <= 0) {
    return 'Quantity must be greater than 0';
  }

  final after = resolveAdjustment(mode, onHand, qty).after;

  if (after < 0) {
    if (mode == AdjustmentMode.remove) {
      return 'Removing $qty would leave $after. Stock cannot go negative.';
    }
    return 'Stock cannot go negative.';
  }

  if (reasonId == null) return 'Pick a reason';

  if (requiresNote && note.trim().isEmpty) {
    return 'A note is required for this reason';
  }

  return null;
}
