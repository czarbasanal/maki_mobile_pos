// The payroll generator's state machine — a pure port of the web admin's
// usePayslipDraft hook plus PayrollPage's pick-employee ordering. Zero
// Flutter/Firestore imports so every parity rule unit-tests fast; the screen
// only wires this controller to widgets.
//
// Parity rules carried over (see the web sources for their rationale):
// - Numeric fields are TEXT; the numeric value is `double.tryParse ?? 0`, so
//   blanks and junk read as 0 while '-5' stays negative and trips isValid.
// - isValid = every derived numeric ≥ 0. That is the only validation.
// - Seeded day grid: all present except the last day = dayOff (6-day week).
// - Picking an employee: rate text ← employee, effective week start =
//   employee.weekStartDay ?? settings, and when that CHANGES the period
//   re-anchors from the displayed period's END (guarantees overlap; anchoring
//   from the start or "today" can jump to a non-overlapping week).
// - applyDefaults(null) blanks everything EXCEPT dailyRate and the two pcts;
//   non-null defaults render `String(value)` per field (a saved 0 shows "0",
//   not blank) and overwrite the seeded grid POSITIONALLY by dayPattern.
// - snapshotDefaults excludes dailyRate and the pcts.
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';

enum DraftField {
  hoursWorked,
  dailyRate,
  overtimeHours,
  overtimeRatePerHour,
  regularHolidayDays,
  specialHolidayDays,
  regularHolidayPct,
  specialHolidayPct,
  incentives,
  sss,
  philhealth,
  pagibig,
  late,
  absences,
  cashAdvance,
}

class OtherRow {
  final int id;
  final String label;
  final String amountText;

  const OtherRow({required this.id, required this.label, required this.amountText});

  OtherRow copyWith({String? label, String? amountText}) => OtherRow(
        id: id,
        label: label ?? this.label,
        amountText: amountText ?? this.amountText,
      );
}

class PayslipDraftState {
  final PayPeriod period;
  final int weekStartDay;
  final List<PayslipDay> days;
  final List<OtherRow> others;
  final Map<DraftField, String> fields;

  const PayslipDraftState({
    required this.period,
    required this.weekStartDay,
    required this.days,
    required this.others,
    required this.fields,
  });

  String text(DraftField f) => fields[f] ?? '';

  String get hoursWorkedText => text(DraftField.hoursWorked);
  String get dailyRateText => text(DraftField.dailyRate);
  String get overtimeHoursText => text(DraftField.overtimeHours);
  String get incentivesText => text(DraftField.incentives);
  String get sssText => text(DraftField.sss);
  String get regularHolidayPctText => text(DraftField.regularHolidayPct);
}

/// Plain mutable controller (no framework classes) — the screen listens via
/// [addListener], the tests poke it directly.
class PayslipDraftController {
  PayslipDraftState _state;
  int _nextOtherId = 1;
  final List<void Function()> _listeners = [];

  PayslipDraftController({
    required HrSettingsEntity settings,
    required DateTime now,
  }) : _state = _seed(
          payPeriodFor(now, settings.weekStartDay),
          settings.weekStartDay,
          {
            DraftField.regularHolidayPct: settings.regularHolidayPct.toString(),
            DraftField.specialHolidayPct: settings.specialHolidayPct.toString(),
          },
        );

  PayslipDraftState get state => _state;

  void addListener(void Function() fn) => _listeners.add(fn);

  void _emit(PayslipDraftState next) {
    _state = next;
    for (final fn in _listeners) {
      fn();
    }
  }

  static List<PayslipDay> _seedDays(PayPeriod period) => [
        for (var i = 0; i < period.dates.length; i++)
          PayslipDay(
            date: period.dates[i],
            status: i == period.dates.length - 1
                ? DayStatus.dayOff
                : DayStatus.present,
          ),
      ];

  static PayslipDraftState _seed(
    PayPeriod period,
    int weekStartDay,
    Map<DraftField, String> keepFields,
  ) {
    return PayslipDraftState(
      period: period,
      weekStartDay: weekStartDay,
      days: _seedDays(period),
      others: const [],
      fields: Map.unmodifiable(keepFields),
    );
  }

  double _num(String t) => double.tryParse(t) ?? 0;

  // ---------- field edits ----------

  void setField(DraftField field, String text) {
    _emit(PayslipDraftState(
      period: _state.period,
      weekStartDay: _state.weekStartDay,
      days: _state.days,
      others: _state.others,
      fields: Map.unmodifiable({..._state.fields, field: text}),
    ));
  }

  void addOther() {
    _emit(_withOthers([
      ..._state.others,
      OtherRow(id: _nextOtherId++, label: '', amountText: ''),
    ]));
  }

  void setOther(int id, {String? label, String? amountText}) {
    _emit(_withOthers([
      for (final o in _state.others)
        o.id == id ? o.copyWith(label: label, amountText: amountText) : o,
    ]));
  }

  void removeOther(int id) {
    _emit(_withOthers(
        [..._state.others.where((o) => o.id != id)]));
  }

  PayslipDraftState _withOthers(List<OtherRow> others) => PayslipDraftState(
        period: _state.period,
        weekStartDay: _state.weekStartDay,
        days: _state.days,
        others: others,
        fields: _state.fields,
      );

  // ---------- grid ----------

  static DayStatus nextDayStatus(DayStatus s) => switch (s) {
        DayStatus.present => DayStatus.absent,
        DayStatus.absent => DayStatus.dayOff,
        DayStatus.dayOff => DayStatus.present,
      };

  void cycleDay(int index) {
    final days = [..._state.days];
    days[index] =
        PayslipDay(date: days[index].date, status: nextDayStatus(days[index].status));
    _emit(PayslipDraftState(
      period: _state.period,
      weekStartDay: _state.weekStartDay,
      days: days,
      others: _state.others,
      fields: _state.fields,
    ));
  }

  // ---------- period navigation ----------

  void shift(int weeks) {
    final period = shiftPeriod(_state.period, weeks);
    _emit(PayslipDraftState(
      period: period,
      weekStartDay: _state.weekStartDay,
      days: _seedDays(period),
      others: _state.others,
      fields: _state.fields,
    ));
  }

  // ---------- employee pick ----------

  void pickEmployee(EmployeeEntity employee, {HrSettingsEntity? settings}) {
    final settingsDay =
        settings?.weekStartDay ?? HrSettingsEntity.defaults.weekStartDay;
    final day = employee.weekStartDay ??
        (settings != null ? settingsDay : _fallbackSettingsDay);
    // Re-anchor from the displayed period's END only when the effective start
    // day actually changes — the overlap guarantee (see header comment).
    final period = day == _state.weekStartDay
        ? _state.period
        : payPeriodFor(parseIsoLocalDate(_state.period.end), day);

    final rateText = employee.dailyRate.toString();
    _applyDefaults(employee.payslipDefaults, period, day, rateText);
  }

  // The controller was seeded with the settings' start day; keep it as the
  // fallback when pickEmployee is called without a fresh settings object.
  int get _fallbackSettingsDay => _seededSettingsDay;
  late final int _seededSettingsDay = _state.weekStartDay;

  void _applyDefaults(
    PayslipDefaults? defaults,
    PayPeriod period,
    int weekStartDay,
    String rateText,
  ) {
    final keep = <DraftField, String>{
      DraftField.dailyRate: rateText,
      DraftField.regularHolidayPct: _state.text(DraftField.regularHolidayPct),
      DraftField.specialHolidayPct: _state.text(DraftField.specialHolidayPct),
    };

    if (defaults == null) {
      _emit(PayslipDraftState(
        period: period,
        weekStartDay: weekStartDay,
        days: _seedDays(period),
        others: const [],
        fields: Map.unmodifiable(keep),
      ));
      return;
    }

    final days = _seedDays(period);
    for (var i = 0; i < days.length && i < defaults.dayPattern.length; i++) {
      days[i] = PayslipDay(date: days[i].date, status: defaults.dayPattern[i]);
    }

    final d = defaults.deductions;
    _emit(PayslipDraftState(
      period: period,
      weekStartDay: weekStartDay,
      days: days,
      others: [
        for (final o in d.others)
          OtherRow(
            id: _nextOtherId++,
            label: o.label,
            amountText: o.amount.toString(),
          ),
      ],
      fields: Map.unmodifiable({
        ...keep,
        DraftField.hoursWorked: defaults.hoursWorked.toString(),
        DraftField.overtimeHours: defaults.overtimeHours.toString(),
        DraftField.overtimeRatePerHour: defaults.overtimeRatePerHour.toString(),
        DraftField.regularHolidayDays: defaults.regularHolidayDays.toString(),
        DraftField.specialHolidayDays: defaults.specialHolidayDays.toString(),
        DraftField.incentives: defaults.incentives.toString(),
        DraftField.sss: d.sss.toString(),
        DraftField.philhealth: d.philhealth.toString(),
        DraftField.pagibig: d.pagibig.toString(),
        DraftField.late: d.late.toString(),
        DraftField.absences: d.absences.toString(),
        DraftField.cashAdvance: d.cashAdvance.toString(),
      }),
    ));
  }

  // ---------- derived ----------

  PayslipInputs get inputs => PayslipInputs(
        hoursWorked: _num(_state.text(DraftField.hoursWorked)),
        dailyRate: _num(_state.text(DraftField.dailyRate)),
        overtimeHours: _num(_state.text(DraftField.overtimeHours)),
        overtimeRatePerHour: _num(_state.text(DraftField.overtimeRatePerHour)),
        regularHolidayDays: _num(_state.text(DraftField.regularHolidayDays)),
        specialHolidayDays: _num(_state.text(DraftField.specialHolidayDays)),
        regularHolidayPct: _num(_state.text(DraftField.regularHolidayPct)),
        specialHolidayPct: _num(_state.text(DraftField.specialHolidayPct)),
        incentives: _num(_state.text(DraftField.incentives)),
        deductions: PayslipDeductions(
          sss: _num(_state.text(DraftField.sss)),
          philhealth: _num(_state.text(DraftField.philhealth)),
          pagibig: _num(_state.text(DraftField.pagibig)),
          late: _num(_state.text(DraftField.late)),
          absences: _num(_state.text(DraftField.absences)),
          cashAdvance: _num(_state.text(DraftField.cashAdvance)),
          others: [
            for (final o in _state.others)
              OtherDeduction(label: o.label, amount: _num(o.amountText)),
          ],
        ),
      );

  bool get isValid {
    final i = inputs;
    final values = [
      i.hoursWorked,
      i.dailyRate,
      i.overtimeHours,
      i.overtimeRatePerHour,
      i.regularHolidayDays,
      i.specialHolidayDays,
      i.regularHolidayPct,
      i.specialHolidayPct,
      i.incentives,
      i.deductions.sss,
      i.deductions.philhealth,
      i.deductions.pagibig,
      i.deductions.late,
      i.deductions.absences,
      i.deductions.cashAdvance,
      ...i.deductions.others.map((o) => o.amount),
    ];
    return values.every((v) => v >= 0);
  }

  PayslipDefaults snapshotDefaults() {
    final i = inputs;
    return PayslipDefaults(
      hoursWorked: i.hoursWorked,
      overtimeHours: i.overtimeHours,
      overtimeRatePerHour: i.overtimeRatePerHour,
      regularHolidayDays: i.regularHolidayDays,
      specialHolidayDays: i.specialHolidayDays,
      incentives: i.incentives,
      deductions: i.deductions,
      dayPattern: [for (final d in _state.days) d.status],
    );
  }
}
