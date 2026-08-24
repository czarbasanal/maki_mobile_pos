// Port of web_admin/src/domain/hr/computePayslip.ts — the single source of
// payslip arithmetic on this surface. No rounding anywhere: raw doubles in,
// raw doubles stored; display formatting is the only place values round
// (matches web and the payslip docs already in production).
//
// Attendance days deliberately do NOT appear in this signature — they are a
// recorded snapshot, never an input to pay.
import 'package:maki_mobile_pos/domain/entities/payslip_entity.dart';

PayslipComputed computePayslip(PayslipInputs i) {
  final hourlyRate = i.dailyRate == 0 ? 0.0 : i.dailyRate / 8;
  final basePay = i.hoursWorked * hourlyRate;
  final overtimePay = i.overtimeHours * i.overtimeRatePerHour;
  final holidayPay = i.regularHolidayDays * i.dailyRate * (i.regularHolidayPct / 100) +
      i.specialHolidayDays * i.dailyRate * (i.specialHolidayPct / 100);
  final gross = basePay + overtimePay + holidayPay + i.incentives;
  final d = i.deductions;
  final totalDeductions = d.sss +
      d.philhealth +
      d.pagibig +
      d.late +
      d.absences +
      d.cashAdvance +
      d.others.fold<double>(0, (sum, o) => sum + o.amount);
  return PayslipComputed(
    hourlyRate: hourlyRate,
    basePay: basePay,
    overtimePay: overtimePay,
    holidayPay: holidayPay,
    gross: gross,
    totalDeductions: totalDeductions,
    net: gross - totalDeductions,
  );
}
