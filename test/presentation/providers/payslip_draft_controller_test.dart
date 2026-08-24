// The payroll form's state machine — a pure port of web's usePayslipDraft +
// PayrollPage pick-employee semantics. These tests are the workhorse of the
// parity contract; the generator screen itself only wires this controller.
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';
import 'package:maki_mobile_pos/presentation/providers/payslip_draft_controller.dart';

EmployeeEntity employee({
  int? weekStartDay,
  PayslipDefaults? defaults,
  double rate = 640,
}) =>
    EmployeeEntity(
      id: 'e1',
      name: 'Maybelle',
      dailyRate: rate,
      isActive: true,
      weekStartDay: weekStartDay,
      payslipDefaults: defaults,
    );

const settings = HrSettingsEntity(
  weekStartDay: 1,
  regularHolidayPct: 100,
  specialHolidayPct: 30,
);

PayslipDraftController controller({DateTime? now}) => PayslipDraftController(
      settings: settings,
      now: now ?? DateTime(2026, 7, 22), // a Wednesday
    );

void main() {
  test('seeds: Monday period around now, pcts from settings, days 6+1', () {
    final c = controller();
    expect(c.state.period.start, '2026-07-20');
    expect(c.state.regularHolidayPctText, '100.0');
    expect(c.state.days.take(6).every((d) => d.status == DayStatus.present),
        isTrue);
    expect(c.state.days.last.status, DayStatus.dayOff);
    expect(c.state.hoursWorkedText, '');
  });

  test('numerics parse as tryParse??0; isValid rejects only negatives', () {
    final c = controller();
    c.setField(DraftField.hoursWorked, 'abc');
    expect(c.inputs.hoursWorked, 0);
    expect(c.isValid, isTrue);

    c.setField(DraftField.sss, '-5');
    expect(c.isValid, isFalse);

    c.setField(DraftField.sss, '45');
    expect(c.isValid, isTrue);
  });

  test('cycleDay walks present → absent → dayOff → present', () {
    final c = controller();
    expect(c.state.days[0].status, DayStatus.present);
    c.cycleDay(0);
    expect(c.state.days[0].status, DayStatus.absent);
    c.cycleDay(0);
    expect(c.state.days[0].status, DayStatus.dayOff);
    c.cycleDay(0);
    expect(c.state.days[0].status, DayStatus.present);
  });

  test('shiftPeriod reseeds the day grid', () {
    final c = controller();
    c.cycleDay(0); // dirty the grid
    c.shift(1);
    expect(c.state.period.start, '2026-07-27');
    expect(c.state.days[0].status, DayStatus.present); // reseeded
    expect(c.state.days[0].date, '2026-07-27');
  });

  test(
      'pick-employee with a different weekStartDay re-anchors from period END, '
      'not start — an explicit vector where the two disagree', () {
    final c = controller();
    // Current period Mon 2026-07-20 → Sun 2026-07-26. Picking a Wednesday
    // starter (weekStartDay=3):
    //   anchored from END (Sun 26)  → Wed 2026-07-22 .. Tue 2026-07-28 (overlaps)
    //   anchored from START (Mon 20) → Wed 2026-07-15 .. Tue 2026-07-21 (wrong)
    c.pickEmployee(employee(weekStartDay: 3));
    expect(c.state.period.start, '2026-07-22');
    expect(c.state.period.end, '2026-07-28');
    expect(c.state.dailyRateText, '640.0');
  });

  test('pick-employee with the SAME start day keeps the displayed period', () {
    final c = controller();
    c.shift(-1); // navigate away from the current week deliberately
    c.pickEmployee(employee(weekStartDay: null)); // settings day = 1, same
    expect(c.state.period.start, '2026-07-13');
  });

  test('null defaults blank the form but keep dailyRate and pcts', () {
    final c = controller();
    c.setField(DraftField.hoursWorked, '48');
    c.setField(DraftField.regularHolidayPct, '150');
    c.pickEmployee(employee(defaults: null));

    expect(c.state.hoursWorkedText, '');
    expect(c.state.dailyRateText, '640.0'); // set by the pick, not blanked
    expect(c.state.regularHolidayPctText, '150'); // pcts untouched
    expect(c.state.others, isEmpty);
  });

  test('non-null defaults apply positionally, String(value) per field', () {
    const defaults = PayslipDefaults(
      hoursWorked: 48,
      overtimeHours: 0,
      overtimeRatePerHour: 0,
      regularHolidayDays: 0,
      specialHolidayDays: 0,
      incentives: 200,
      deductions: PayslipDeductions(
        sss: 45,
        philhealth: 0,
        pagibig: 0,
        late: 0,
        absences: 0,
        cashAdvance: 0,
        others: [OtherDeduction(label: 'Load', amount: 100)],
      ),
      // Positional: index 1 of the PERIOD is absent regardless of weekday.
      dayPattern: [DayStatus.present, DayStatus.absent],
    );
    final c = controller();
    c.pickEmployee(employee(defaults: defaults));

    expect(c.state.hoursWorkedText, '48.0');
    expect(c.state.overtimeHoursText, '0.0'); // zero renders, not blank
    expect(c.state.incentivesText, '200.0');
    expect(c.state.sssText, '45.0');
    expect(c.state.others.single.label, 'Load');
    expect(c.state.days[1].status, DayStatus.absent);
    // Indices beyond the pattern keep the seed.
    expect(c.state.days[5].status, DayStatus.present);
    expect(c.state.days.last.status, DayStatus.dayOff);
  });

  test('snapshotDefaults excludes dailyRate and pcts, dayPattern positional',
      () {
    final c = controller();
    c.pickEmployee(employee());
    c.setField(DraftField.hoursWorked, '40');
    c.cycleDay(1); // absent

    final snap = c.snapshotDefaults();
    expect(snap.hoursWorked, 40);
    expect(snap.dayPattern[1], DayStatus.absent);
    expect(snap.dayPattern, hasLength(7));
  });

  test('others rows add and remove by id; a negative amount trips isValid',
      () {
    final c = controller();
    c.addOther();
    c.addOther();
    final first = c.state.others.first.id;
    c.setOther(first, label: 'Uniform', amountText: '-1');
    expect(c.isValid, isFalse);
    c.removeOther(first);
    expect(c.isValid, isTrue);
    expect(c.state.others, hasLength(1));
  });

  test('inputs assemble the full PayslipInputs for compute', () {
    final c = controller();
    c.pickEmployee(employee());
    c.setField(DraftField.hoursWorked, '48');
    c.setField(DraftField.sss, '45');
    c.addOther();
    c.setOther(c.state.others.single.id, label: 'Load', amountText: '100');

    final i = c.inputs;
    expect(i.dailyRate, 640);
    expect(i.hoursWorked, 48);
    expect(i.regularHolidayPct, 100);
    expect(i.deductions.sss, 45);
    expect(i.deductions.others.single.amount, 100);
  });

  test('effective week start prefers the employee override', () {
    final c = controller();
    c.pickEmployee(employee(weekStartDay: 3));
    // A later shift stays on the Wednesday-anchored grid.
    c.shift(1);
    expect(parseIsoLocalDate(c.state.period.start).weekday, 3);
  });
}
