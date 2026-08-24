// Payslip value types + entity — port of web_admin/src/domain/hr/types.ts.
// Wire values are shared with the web admin, so string enums and field names
// must match exactly. A stored payslip is a FROZEN snapshot (firestore.rules:
// payslips update:false) — the entity carries the computed figures as written
// and nothing recomputes them on read.
import 'package:equatable/equatable.dart';

/// One day's recorded attendance status. Wire values match web exactly.
enum DayStatus {
  present('present'),
  absent('absent'),
  dayOff('dayOff');

  final String value;
  const DayStatus(this.value);

  static DayStatus fromString(String? value) => DayStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => DayStatus.present,
      );
}

/// One cell of the pay-period attendance grid.
class PayslipDay extends Equatable {
  final String date; // 'YYYY-MM-DD', local calendar date
  final DayStatus status;

  const PayslipDay({required this.date, required this.status});

  @override
  List<Object?> get props => [date, status];
}

/// A free-form deduction line ("Load", "Uniform", …).
class OtherDeduction extends Equatable {
  final String label;
  final double amount;

  const OtherDeduction({required this.label, required this.amount});

  @override
  List<Object?> get props => [label, amount];
}

class PayslipDeductions extends Equatable {
  final double sss;
  final double philhealth;
  final double pagibig;
  final double late;
  final double absences;
  final double cashAdvance;
  final List<OtherDeduction> others;

  const PayslipDeductions({
    required this.sss,
    required this.philhealth,
    required this.pagibig,
    required this.late,
    required this.absences,
    required this.cashAdvance,
    required this.others,
  });

  static const empty = PayslipDeductions(
    sss: 0,
    philhealth: 0,
    pagibig: 0,
    late: 0,
    absences: 0,
    cashAdvance: 0,
    others: [],
  );

  @override
  List<Object?> get props =>
      [sss, philhealth, pagibig, late, absences, cashAdvance, others];
}

/// Everything the generator was told. Attendance days are NOT part of the
/// inputs — they are a recorded snapshot that never feeds the computation
/// (absences are entered as a peso amount by hand).
class PayslipInputs extends Equatable {
  final double hoursWorked;
  final double dailyRate;
  final double overtimeHours;
  final double overtimeRatePerHour;
  final double regularHolidayDays;
  final double specialHolidayDays;
  final double regularHolidayPct;
  final double specialHolidayPct;
  final double incentives;
  final PayslipDeductions deductions;

  const PayslipInputs({
    required this.hoursWorked,
    required this.dailyRate,
    required this.overtimeHours,
    required this.overtimeRatePerHour,
    required this.regularHolidayDays,
    required this.specialHolidayDays,
    required this.regularHolidayPct,
    required this.specialHolidayPct,
    required this.incentives,
    required this.deductions,
  });

  PayslipInputs copyWith({
    double? hoursWorked,
    double? dailyRate,
    double? overtimeHours,
    double? overtimeRatePerHour,
    double? regularHolidayDays,
    double? specialHolidayDays,
    double? regularHolidayPct,
    double? specialHolidayPct,
    double? incentives,
    PayslipDeductions? deductions,
  }) {
    return PayslipInputs(
      hoursWorked: hoursWorked ?? this.hoursWorked,
      dailyRate: dailyRate ?? this.dailyRate,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      overtimeRatePerHour: overtimeRatePerHour ?? this.overtimeRatePerHour,
      regularHolidayDays: regularHolidayDays ?? this.regularHolidayDays,
      specialHolidayDays: specialHolidayDays ?? this.specialHolidayDays,
      regularHolidayPct: regularHolidayPct ?? this.regularHolidayPct,
      specialHolidayPct: specialHolidayPct ?? this.specialHolidayPct,
      incentives: incentives ?? this.incentives,
      deductions: deductions ?? this.deductions,
    );
  }

  @override
  List<Object?> get props => [
        hoursWorked,
        dailyRate,
        overtimeHours,
        overtimeRatePerHour,
        regularHolidayDays,
        specialHolidayDays,
        regularHolidayPct,
        specialHolidayPct,
        incentives,
        deductions,
      ];
}

/// The derived figures, stored alongside the inputs. Raw doubles with NO
/// rounding anywhere — display formatting rounds, the data never does
/// (matches web and the docs already in production).
class PayslipComputed extends Equatable {
  final double hourlyRate;
  final double basePay;
  final double overtimePay;
  final double holidayPay;
  final double gross;
  final double totalDeductions;
  final double net;

  const PayslipComputed({
    required this.hourlyRate,
    required this.basePay,
    required this.overtimePay,
    required this.holidayPay,
    required this.gross,
    required this.totalDeductions,
    required this.net,
  });

  @override
  List<Object?> get props =>
      [hourlyRate, basePay, overtimePay, holidayPay, gross, totalDeductions, net];
}

/// A generated payslip — a frozen full snapshot of days + inputs + computed.
class PayslipEntity extends Equatable {
  final String id;
  final String employeeId;
  final String employeeName;
  final String periodStart; // 'YYYY-MM-DD'
  final String periodEnd; // 'YYYY-MM-DD'
  final List<PayslipDay> days;
  final PayslipInputs inputs;
  final PayslipComputed computed;
  final DateTime? createdAt;
  final String? createdBy;
  final String? createdByName;

  const PayslipEntity({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.periodStart,
    required this.periodEnd,
    required this.days,
    required this.inputs,
    required this.computed,
    this.createdAt,
    this.createdBy,
    this.createdByName,
  });

  @override
  List<Object?> get props => [
        id,
        employeeId,
        employeeName,
        periodStart,
        periodEnd,
        days,
        inputs,
        computed,
        createdAt,
        createdBy,
        createdByName,
      ];
}
