// Employee registry entity + per-employee payslip defaults — port of the
// Employee/PayslipDefaults shapes in web_admin/src/domain/hr/types.ts.
// Employees are their own registry (NOT users or mechanics): payroll staff
// need no login, and mechanics are the labor-commission list.
import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/domain/entities/payslip_entity.dart';

/// Saved generator profile for one employee, applied when they're picked on
/// the payroll form. Deliberately EXCLUDES dailyRate (lives on the employee)
/// and the holiday percentages (settings-seeded). `dayPattern` is positional
/// against the employee's effective week-start day, index 0 = day 1 of the
/// period — NOT calendar weekdays (web parity; changing the week start
/// silently rotates a saved pattern).
class PayslipDefaults extends Equatable {
  final double hoursWorked;
  final double overtimeHours;
  final double overtimeRatePerHour;
  final double regularHolidayDays;
  final double specialHolidayDays;
  final double incentives;
  final PayslipDeductions deductions;
  final List<DayStatus> dayPattern;

  const PayslipDefaults({
    required this.hoursWorked,
    required this.overtimeHours,
    required this.overtimeRatePerHour,
    required this.regularHolidayDays,
    required this.specialHolidayDays,
    required this.incentives,
    required this.deductions,
    required this.dayPattern,
  });

  @override
  List<Object?> get props => [
        hoursWorked,
        overtimeHours,
        overtimeRatePerHour,
        regularHolidayDays,
        specialHolidayDays,
        incentives,
        deductions,
        dayPattern,
      ];
}

class EmployeeEntity extends Equatable {
  final String id;
  final String name;
  final double dailyRate;
  final bool isActive;

  /// ISO weekday 1–7 anchoring this employee's pay week; null = use the
  /// shop-wide HR setting.
  final int? weekStartDay;

  /// Saved generator profile; null = none saved yet.
  final PayslipDefaults? payslipDefaults;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EmployeeEntity({
    required this.id,
    required this.name,
    required this.dailyRate,
    required this.isActive,
    this.weekStartDay,
    this.payslipDefaults,
    this.createdAt,
    this.updatedAt,
  });

  EmployeeEntity copyWith({
    String? id,
    String? name,
    double? dailyRate,
    bool? isActive,
    int? weekStartDay,
    PayslipDefaults? payslipDefaults,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearWeekStartDay = false,
    bool clearPayslipDefaults = false,
  }) {
    return EmployeeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyRate: dailyRate ?? this.dailyRate,
      isActive: isActive ?? this.isActive,
      weekStartDay: clearWeekStartDay ? null : (weekStartDay ?? this.weekStartDay),
      payslipDefaults:
          clearPayslipDefaults ? null : (payslipDefaults ?? this.payslipDefaults),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        dailyRate,
        isActive,
        weekStartDay,
        payslipDefaults,
        createdAt,
        updatedAt,
      ];
}
