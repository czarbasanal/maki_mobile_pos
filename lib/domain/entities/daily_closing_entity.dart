import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

/// The raw inputs of a day's closing — the sales summary plus the itemized
/// expense list. The EOD screen derives [DailyClosingDraft]s from this via
/// [draftExcluding], so removing/restoring an expense recomputes instantly
/// without refetching (fetch/derive split).
class DailyClosingData extends Equatable {
  final DateTime businessDate;
  final SalesSummary summary;
  final List<ExpenseEntity> expenses;

  const DailyClosingData({
    required this.businessDate,
    required this.summary,
    required this.expenses,
  });

  /// Draft computed over the expenses NOT in [excludedExpenseIds]. An
  /// excluded expense stays recorded in the ledger — it just doesn't count
  /// against this closing's totals or drawer math.
  DailyClosingDraft draftExcluding(Set<String> excludedExpenseIds) {
    return DailyClosingDraft.fromData(
      businessDate: businessDate,
      summary: summary,
      expenses: excludedExpenseIds.isEmpty
          ? expenses
          : expenses
              .where((e) => !excludedExpenseIds.contains(e.id))
              .toList(),
    );
  }

  @override
  List<Object?> get props => [businessDate, summary, expenses];
}

/// Live, unsaved end-of-day figures computed from the day's sales + expenses.
///
/// The manual inputs (opening float, counted cash) are layered on top by the
/// UI / [CloseDayUseCase]; [expectedCashFor] and [varianceFor] derive the
/// reconciliation once a float / count is known.
class DailyClosingDraft extends Equatable {
  final DateTime businessDate;
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double cashSales;
  final double nonCashSales;
  final double gcashSales;
  final double mayaSales;
  final double totalExpenses;
  final double cashExpenses;
  final double salmonReceivable;

  /// Labor (service) revenue for the day. A separate track from merchandise:
  /// [grossSales]/[netSales] stay PARTS-ONLY. Labor cash is already folded into
  /// [cashSales]/[expectedCashFor] (the drawer physically holds it), so this
  /// field is a reporting line, not a reconciliation input.
  final double laborRevenue;

  final int salesCount;
  final int voidedCount;

  const DailyClosingDraft({
    required this.businessDate,
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.cashSales,
    required this.nonCashSales,
    required this.gcashSales,
    required this.mayaSales,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.salmonReceivable,
    this.laborRevenue = 0,
    required this.salesCount,
    required this.voidedCount,
  });

  /// Builds a draft from a [SalesSummary] and the day's [expenses].
  ///
  /// Cash sales come from the cash payment-method bucket (net cash received).
  /// Non-cash sales are every other payment method summed. Cash expenses are
  /// only those with `paidVia == cash`.
  factory DailyClosingDraft.fromData({
    required DateTime businessDate,
    required SalesSummary summary,
    required List<ExpenseEntity> expenses,
  }) {
    final cashSales = summary.byPaymentMethod[PaymentMethod.cash] ?? 0;
    final gcashSales = summary.byPaymentMethod[PaymentMethod.gcash] ?? 0;
    final mayaSales = summary.byPaymentMethod[PaymentMethod.maya] ?? 0;
    final salmonReceivable =
        summary.byPaymentMethod[PaymentMethod.salmon] ?? 0;
    double nonCashSales = 0;
    for (final entry in summary.byPaymentMethod.entries) {
      if (entry.key != PaymentMethod.cash &&
          entry.key != PaymentMethod.salmon) {
        nonCashSales += entry.value;
      }
    }

    double totalExpenses = 0;
    double cashExpenses = 0;
    for (final e in expenses) {
      totalExpenses += e.amount;
      if (e.paidVia == PaymentMethod.cash) cashExpenses += e.amount;
    }

    return DailyClosingDraft(
      businessDate: businessDate,
      grossSales: summary.grossAmount,
      netSales: summary.netAmount,
      totalDiscounts: summary.totalDiscounts,
      cashSales: cashSales,
      nonCashSales: nonCashSales,
      gcashSales: gcashSales,
      mayaSales: mayaSales,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: salmonReceivable,
      laborRevenue: summary.laborRevenue,
      salesCount: summary.totalSalesCount,
      voidedCount: summary.voidedSalesCount,
    );
  }

  /// Expected drawer cash given an [openingFloat].
  ///
  /// Plate-number orders are settled in cash: the downpayment ([plateNoDp]) is
  /// collected into the drawer, while the delivery fee ([plateNoDelivery]) is
  /// paid out of it.
  double expectedCashFor(
    double openingFloat, {
    double plateNoDp = 0,
    double plateNoDelivery = 0,
  }) =>
      openingFloat + cashSales - cashExpenses + plateNoDp - plateNoDelivery;

  /// Variance given an [openingFloat] and a physical [countedCash].
  double varianceFor(double openingFloat, double countedCash) =>
      countedCash - expectedCashFor(openingFloat);

  @override
  List<Object?> get props => [
        businessDate,
        grossSales,
        netSales,
        totalDiscounts,
        cashSales,
        nonCashSales,
        gcashSales,
        mayaSales,
        totalExpenses,
        cashExpenses,
        salmonReceivable,
        laborRevenue,
        salesCount,
        voidedCount,
      ];
}

/// A persisted end-of-day closing for a single business day.
///
/// Document id is the business date as `YYYY-MM-DD`, which enforces one
/// closing per day. Immutable once saved (audit record).
class DailyClosingEntity extends Equatable {
  final String id;
  final DateTime businessDate;
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double cashSales;
  final double nonCashSales;
  final double gcashSales;
  final double mayaSales;
  final double totalExpenses;
  final double cashExpenses;
  final double salmonReceivable;
  final double laborRevenue;
  final double plateNoDp;
  final double plateNoDelivery;
  final double openingFloat;
  final double expectedCash;
  final double countedCash;
  final double variance;
  final int salesCount;
  final int voidedCount;

  /// Ids of same-day expenses the closer removed from the reconciliation —
  /// still recorded in the expenses ledger, just not deducted from the
  /// drawer in this closing. Needed so post-close drift math can filter
  /// them when recomputing the current draft.
  final List<String> excludedExpenseIds;
  final String? notes;
  final String closedBy;
  final String closedByName;
  final DateTime closedAt;

  const DailyClosingEntity({
    required this.id,
    required this.businessDate,
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.cashSales,
    required this.nonCashSales,
    required this.gcashSales,
    required this.mayaSales,
    required this.totalExpenses,
    required this.cashExpenses,
    required this.salmonReceivable,
    this.laborRevenue = 0,
    this.plateNoDp = 0,
    this.plateNoDelivery = 0,
    required this.openingFloat,
    required this.expectedCash,
    required this.countedCash,
    required this.variance,
    required this.salesCount,
    required this.voidedCount,
    this.excludedExpenseIds = const [],
    this.notes,
    required this.closedBy,
    required this.closedByName,
    required this.closedAt,
  });

  @override
  List<Object?> get props => [
        id,
        businessDate,
        grossSales,
        netSales,
        totalDiscounts,
        cashSales,
        nonCashSales,
        gcashSales,
        mayaSales,
        totalExpenses,
        cashExpenses,
        salmonReceivable,
        laborRevenue,
        plateNoDp,
        plateNoDelivery,
        openingFloat,
        expectedCash,
        countedCash,
        variance,
        salesCount,
        voidedCount,
        excludedExpenseIds,
        notes,
        closedBy,
        closedByName,
        closedAt,
      ];
}

/// Difference between a saved closing's snapshot and the current figures.
///
/// A closing is an immutable point-in-time snapshot. If sales are recorded (or
/// voided) after the day is closed, the snapshot no longer matches reality;
/// this surfaces that drift — including the **updated cash on hand** the drawer
/// should physically hold once post-close cash sales/expenses are applied.
class PostCloseActivity extends Equatable {
  /// Completed sales beyond the snapshot (negative if a sale was voided).
  final int extraSales;

  /// Current gross minus the snapshot gross.
  final double grossDelta;

  /// Cash sales recorded after close (negative if a cash sale was voided).
  final double cashSalesDelta;

  /// Cash expenses recorded after close.
  final double cashExpensesDelta;

  /// What the drawer should now hold: the counted cash at close plus the cash
  /// collected after close, minus any cash expenses after close.
  final double updatedCashOnHand;

  const PostCloseActivity({
    required this.extraSales,
    required this.grossDelta,
    required this.cashSalesDelta,
    required this.cashExpensesDelta,
    required this.updatedCashOnHand,
  });

  factory PostCloseActivity.between({
    required DailyClosingEntity closing,
    required DailyClosingDraft current,
  }) {
    final cashSalesDelta = current.cashSales - closing.cashSales;
    final cashExpensesDelta = current.cashExpenses - closing.cashExpenses;
    return PostCloseActivity(
      extraSales: current.salesCount - closing.salesCount,
      grossDelta: current.grossSales - closing.grossSales,
      cashSalesDelta: cashSalesDelta,
      cashExpensesDelta: cashExpensesDelta,
      updatedCashOnHand:
          closing.countedCash + cashSalesDelta - cashExpensesDelta,
    );
  }

  /// True when current figures differ from the snapshot (sub-cent noise ignored).
  bool get hasChanged =>
      extraSales != 0 ||
      grossDelta.abs() > 0.005 ||
      cashSalesDelta.abs() > 0.005 ||
      cashExpensesDelta.abs() > 0.005;

  /// True when the drift is additional sales (vs a void/refund reducing totals).
  bool get isAdditional => extraSales > 0 || grossDelta > 0.005;

  @override
  List<Object?> get props => [
        extraSales,
        grossDelta,
        cashSalesDelta,
        cashExpensesDelta,
        updatedCashOnHand,
      ];
}
