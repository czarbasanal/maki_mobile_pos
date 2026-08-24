// HR repositories against FakeFirebaseFirestore (the repo-test convention:
// real impls, fake Firestore, no mocks). Covers the contracts the screens
// lean on: sort orders, watch emission, the sparse employee update, the
// defaults-only write, payslip round-trip, and settings overwrite/fallback.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/employee_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/hr_settings_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/payslip_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

EmployeeEntity employee({String name = 'Maybelle', double rate = 640}) =>
    EmployeeEntity(
      id: '',
      name: name,
      dailyRate: rate,
      isActive: true,
    );

PayslipEntity payslip({String name = 'Maybelle', String start = '2026-07-20'}) =>
    PayslipEntity(
      id: '',
      employeeId: 'e1',
      employeeName: name,
      periodStart: start,
      periodEnd: '2026-07-26',
      days: const [PayslipDay(date: '2026-07-20', status: DayStatus.present)],
      inputs: const PayslipInputs(
        hoursWorked: 48,
        dailyRate: 640,
        overtimeHours: 0,
        overtimeRatePerHour: 0,
        regularHolidayDays: 0,
        specialHolidayDays: 0,
        regularHolidayPct: 100,
        specialHolidayPct: 30,
        incentives: 0,
        deductions: PayslipDeductions.empty,
      ),
      computed: const PayslipComputed(
        hourlyRate: 80,
        basePay: 3840,
        overtimePay: 0,
        holidayPay: 0,
        gross: 3840,
        totalDeductions: 0,
        net: 3840,
      ),
      createdBy: 'u1',
      createdByName: 'Owner',
    );

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('EmployeeRepositoryImpl', () {
    test('create → watchAll round-trips and sorts A→Z', () async {
      final repo = EmployeeRepositoryImpl(firestore: firestore);
      await repo.create(employee(name: 'Zeny'));
      await repo.create(employee(name: 'Ana'));

      final all = await repo.watchAll().first;
      expect(all.map((e) => e.name).toList(), ['Ana', 'Zeny']);
      expect(all.first.dailyRate, 640);
    });

    test('create writes NO payslipDefaults key', () async {
      final repo = EmployeeRepositoryImpl(firestore: firestore);
      final created = await repo.create(employee());
      final doc = await firestore.collection('employees').doc(created.id).get();
      expect(doc.data()!.containsKey('payslipDefaults'), isFalse);
    });

    test('watchActive excludes deactivated employees', () async {
      final repo = EmployeeRepositoryImpl(firestore: firestore);
      final a = await repo.create(employee(name: 'Ana'));
      await repo.create(employee(name: 'Ben'));
      await repo.update(a.copyWith(isActive: false));

      final active = await repo.watchActive().first;
      expect(active.map((e) => e.name).toList(), ['Ben']);
      final all = await repo.watchAll().first;
      expect(all, hasLength(2));
    });

    test('saveDefaults writes only the profile + updatedAt', () async {
      final repo = EmployeeRepositoryImpl(firestore: firestore);
      final created = await repo.create(employee());
      const defaults = PayslipDefaults(
        hoursWorked: 48,
        overtimeHours: 0,
        overtimeRatePerHour: 0,
        regularHolidayDays: 0,
        specialHolidayDays: 0,
        incentives: 200,
        deductions: PayslipDeductions.empty,
        dayPattern: [DayStatus.present, DayStatus.dayOff],
      );

      await repo.saveDefaults(created.id, defaults);

      final back = await repo.getById(created.id);
      expect(back!.payslipDefaults, defaults);
      expect(back.name, 'Maybelle'); // untouched
    });

    test('delete removes the doc', () async {
      final repo = EmployeeRepositoryImpl(firestore: firestore);
      final created = await repo.create(employee());
      await repo.delete(created.id);
      expect(await repo.getById(created.id), isNull);
    });
  });

  group('PayslipRepositoryImpl', () {
    test('create → getById round-trips the frozen snapshot', () async {
      final repo = PayslipRepositoryImpl(firestore: firestore);
      final id = await repo.create(payslip());
      final back = await repo.getById(id);
      expect(back!.employeeName, 'Maybelle');
      expect(back.computed.net, 3840);
      expect(back.days.single.status, DayStatus.present);
      expect(back.createdAt, isNotNull); // serverTimestamp resolved
    });

    test('watchAll sorts periodStart DESC then employeeName ASC', () async {
      final repo = PayslipRepositoryImpl(firestore: firestore);
      await repo.create(payslip(name: 'Ben', start: '2026-07-13'));
      await repo.create(payslip(name: 'Zeny', start: '2026-07-20'));
      await repo.create(payslip(name: 'Ana', start: '2026-07-20'));

      final all = await repo.watchAll().first;
      expect(
        all.map((p) => '${p.periodStart}/${p.employeeName}').toList(),
        ['2026-07-20/Ana', '2026-07-20/Zeny', '2026-07-13/Ben'],
      );
    });

    test('delete removes the slip', () async {
      final repo = PayslipRepositoryImpl(firestore: firestore);
      final id = await repo.create(payslip());
      await repo.delete(id);
      expect(await repo.getById(id), isNull);
    });
  });

  group('HrSettingsRepositoryImpl', () {
    test('missing doc reads as the 1/100/30 defaults', () async {
      final repo = HrSettingsRepositoryImpl(firestore: firestore);
      expect(await repo.get(), HrSettingsEntity.defaults);
    });

    test('save is a full overwrite of exactly three fields', () async {
      final repo = HrSettingsRepositoryImpl(firestore: firestore);
      // A stray key some old write left behind must not survive a save.
      await firestore
          .collection('settings')
          .doc('hr')
          .set({'weekStartDay': 5, 'stray': true});

      const next = HrSettingsEntity(
        weekStartDay: 7,
        regularHolidayPct: 200,
        specialHolidayPct: 50,
      );
      await repo.save(next);

      expect(await repo.get(), next);
      final doc = await firestore.collection('settings').doc('hr').get();
      expect(doc.data()!.keys.toSet(),
          {'weekStartDay', 'regularHolidayPct', 'specialHolidayPct'});
    });
  });
}
