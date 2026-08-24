// Port of web_admin/src/domain/hr/computePayslip.test.ts — vectors verbatim.
// Exact expectations, no closeTo: the formula is plain double arithmetic on
// both surfaces, so any drift is a porting bug, not float noise. Attendance
// days never feed the computation — enforced by the signature (inputs only).
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/payslip_entity.dart';
import 'package:maki_mobile_pos/domain/hr/compute_payslip.dart';

PayslipInputs base() => const PayslipInputs(
      hoursWorked: 48,
      dailyRate: 640,
      overtimeHours: 5,
      overtimeRatePerHour: 100,
      regularHolidayDays: 1,
      specialHolidayDays: 2,
      regularHolidayPct: 100,
      specialHolidayPct: 30,
      incentives: 200,
      deductions: PayslipDeductions(
        sss: 45,
        philhealth: 50,
        pagibig: 25,
        late: 0,
        absences: 0,
        cashAdvance: 500,
        others: [OtherDeduction(label: 'Load', amount: 100)],
      ),
    );

void main() {
  test('computes the worked example end-to-end', () {
    final c = computePayslip(base());
    expect(c.hourlyRate, 80); // 640/8
    expect(c.basePay, 3840); // 48*80
    expect(c.overtimePay, 500); // 5*100
    expect(c.holidayPay, 1024); // 1*640*1.0 + 2*640*0.3
    expect(c.gross, 5564);
    expect(c.totalDeductions, 720); // 45+50+25+500+100
    expect(c.net, 4844);
  });

  test('all-zero inputs yield all-zero outputs (dailyRate 0 → hourly 0)', () {
    const zero = PayslipInputs(
      hoursWorked: 0,
      dailyRate: 0,
      overtimeHours: 0,
      overtimeRatePerHour: 0,
      regularHolidayDays: 0,
      specialHolidayDays: 0,
      regularHolidayPct: 100,
      specialHolidayPct: 30,
      incentives: 0,
      deductions: PayslipDeductions(
        sss: 0,
        philhealth: 0,
        pagibig: 0,
        late: 0,
        absences: 0,
        cashAdvance: 0,
        others: [],
      ),
    );
    final c = computePayslip(zero);
    expect(c.hourlyRate, 0);
    expect(c.basePay, 0);
    expect(c.overtimePay, 0);
    expect(c.holidayPay, 0);
    expect(c.gross, 0);
    expect(c.totalDeductions, 0);
    expect(c.net, 0);
  });

  test('net can go negative when deductions exceed gross', () {
    final c = computePayslip(base().copyWith(
      hoursWorked: 0,
      overtimeHours: 0,
      regularHolidayDays: 0,
      specialHolidayDays: 0,
      incentives: 0,
    ));
    expect(c.gross, 0);
    expect(c.net, -720);
  });
}
