// Employee model round-trips — the payslipDefaults nested map is the risk:
// Firestore hands back int for whole numbers, so every numeric must normalize
// through (v as num?)?.toDouble(), and a missing/null defaults map must stay
// null (web writes no payslipDefaults key on create at all).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/employee_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  test('reads a full doc, normalizing ints to doubles', () {
    final model = EmployeeModel.fromMap({
      'name': 'Maybelle Tampos',
      'dailyRate': 640, // int, as Firestore stores whole numbers
      'isActive': true,
      'weekStartDay': 3,
      'payslipDefaults': {
        'hoursWorked': 48,
        'overtimeHours': 0,
        'overtimeRatePerHour': 0,
        'regularHolidayDays': 0,
        'specialHolidayDays': 0,
        'incentives': 200,
        'deductions': {
          'sss': 45,
          'philhealth': 50,
          'pagibig': 25,
          'late': 0,
          'absences': 0,
          'cashAdvance': 500,
          'others': [
            {'label': 'Load', 'amount': 100},
          ],
        },
        'dayPattern': [
          'present',
          'present',
          'present',
          'present',
          'present',
          'present',
          'dayOff',
        ],
      },
    }, 'e1');

    final e = model.toEntity();
    expect(e.dailyRate, 640.0);
    expect(e.weekStartDay, 3);
    final d = e.payslipDefaults!;
    expect(d.hoursWorked, 48.0);
    expect(d.deductions.cashAdvance, 500.0);
    expect(d.deductions.others.single,
        const OtherDeduction(label: 'Load', amount: 100));
    expect(d.dayPattern.last, DayStatus.dayOff);
    expect(d.dayPattern, hasLength(7));
  });

  test('missing weekStartDay and payslipDefaults stay null; lenient defaults',
      () {
    final e = EmployeeModel.fromMap({'name': 'X'}, 'e2').toEntity();
    expect(e.name, 'X');
    expect(e.dailyRate, 0);
    expect(e.isActive, isTrue);
    expect(e.weekStartDay, isNull);
    expect(e.payslipDefaults, isNull);
  });

  test('entity → map → entity round-trips the defaults exactly', () {
    const entity = EmployeeEntity(
      id: 'e1',
      name: 'Maybelle',
      dailyRate: 640,
      isActive: true,
      weekStartDay: null,
      payslipDefaults: PayslipDefaults(
        hoursWorked: 48,
        overtimeHours: 5,
        overtimeRatePerHour: 100,
        regularHolidayDays: 1,
        specialHolidayDays: 2,
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
        dayPattern: [DayStatus.present, DayStatus.absent, DayStatus.dayOff],
      ),
    );
    final map = EmployeeModel.fromEntity(entity).toMap();
    final back = EmployeeModel.fromMap(map, 'e1').toEntity();
    expect(back, entity);
  });

  test('create map writes serverTimestamps, isActive true, and NO defaults key',
      () {
    const entity = EmployeeEntity(
      id: '',
      name: 'New Hire',
      dailyRate: 500,
      isActive: true,
      weekStartDay: null,
    );
    final map = EmployeeModel.fromEntity(entity).toMap(forCreate: true);
    expect(map['createdAt'], isA<FieldValue>());
    expect(map['updatedAt'], isA<FieldValue>());
    expect(map['isActive'], isTrue);
    expect(map['weekStartDay'], isNull);
    // Web's create never writes the key; a sparse doc must not gain a null
    // defaults field on create.
    expect(map.containsKey('payslipDefaults'), isFalse);
  });
}
