// Payslip model — a FROZEN snapshot (rules: update:false). The model is
// create-only by design: no forUpdate path exists, and `computed` is stored
// verbatim, never recomputed. Reads are defensive because web's converter has
// no computed fallback and malformed docs must not crash the phone.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/payslip_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

PayslipEntity entity() => const PayslipEntity(
      id: 'p1',
      employeeId: 'e1',
      employeeName: 'Maybelle Tampos',
      periodStart: '2026-07-20',
      periodEnd: '2026-07-26',
      days: [
        PayslipDay(date: '2026-07-20', status: DayStatus.present),
        PayslipDay(date: '2026-07-21', status: DayStatus.absent),
        PayslipDay(date: '2026-07-22', status: DayStatus.dayOff),
      ],
      inputs: PayslipInputs(
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
      ),
      computed: PayslipComputed(
        hourlyRate: 80,
        basePay: 3840,
        overtimePay: 500,
        holidayPay: 1024,
        gross: 5564,
        totalDeductions: 720,
        net: 4844,
      ),
      createdBy: 'u1',
      createdByName: 'Owner',
    );

void main() {
  test('entity → map → entity round-trips the whole snapshot', () {
    final map = PayslipModel.fromEntity(entity()).toMap();
    final back = PayslipModel.fromMap(map, 'p1').toEntity();
    expect(back, entity());
  });

  test('create map stamps a serverTimestamp and carries the STORED computed',
      () {
    final map = PayslipModel.fromEntity(entity()).toMap(forCreate: true);
    expect(map['createdAt'], isA<FieldValue>());
    expect((map['computed'] as Map)['net'], 4844);
    expect((map['inputs'] as Map)['deductions'], isA<Map>());
  });

  test('a malformed doc reads with zeroed computed instead of crashing', () {
    final e = PayslipModel.fromMap({
      'employeeId': 'e1',
      'employeeName': 'X',
      'periodStart': '2026-07-20',
      'periodEnd': '2026-07-26',
      // no days, no inputs, no computed
    }, 'p9').toEntity();
    expect(e.days, isEmpty);
    expect(e.computed.net, 0);
    expect(e.inputs.deductions.others, isEmpty);
  });
}
