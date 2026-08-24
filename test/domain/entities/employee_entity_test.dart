// Employee entity semantics that the data layer leans on: nullable fields
// clear via explicit flags (copyWith(x: null) is indistinguishable from "keep"
// in Dart), and PayslipDefaults compares by value through nested lists.
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

EmployeeEntity employee() => const EmployeeEntity(
      id: 'e1',
      name: 'Maybelle Tampos',
      dailyRate: 640,
      isActive: true,
      weekStartDay: 3,
      payslipDefaults: PayslipDefaults(
        hoursWorked: 48,
        overtimeHours: 0,
        overtimeRatePerHour: 0,
        regularHolidayDays: 0,
        specialHolidayDays: 0,
        incentives: 200,
        deductions: PayslipDeductions.empty,
        dayPattern: [
          DayStatus.present,
          DayStatus.present,
          DayStatus.present,
          DayStatus.present,
          DayStatus.present,
          DayStatus.present,
          DayStatus.dayOff,
        ],
      ),
    );

void main() {
  test('copyWith keeps nullable fields unless explicitly cleared', () {
    final renamed = employee().copyWith(name: 'M. Tampos');
    expect(renamed.weekStartDay, 3);
    expect(renamed.payslipDefaults, isNotNull);
  });

  test('clearWeekStartDay / clearPayslipDefaults null the fields', () {
    final cleared = employee()
        .copyWith(clearWeekStartDay: true, clearPayslipDefaults: true);
    expect(cleared.weekStartDay, isNull);
    expect(cleared.payslipDefaults, isNull);
  });

  test('PayslipDefaults compares by value, nested lists included', () {
    expect(employee().payslipDefaults, employee().payslipDefaults);
    final other = employee().payslipDefaults!;
    expect(
      other ==
          const PayslipDefaults(
            hoursWorked: 40, // differs
            overtimeHours: 0,
            overtimeRatePerHour: 0,
            regularHolidayDays: 0,
            specialHolidayDays: 0,
            incentives: 200,
            deductions: PayslipDeductions.empty,
            dayPattern: [],
          ),
      isFalse,
    );
  });
}
