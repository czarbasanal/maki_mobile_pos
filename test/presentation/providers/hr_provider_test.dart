// HR ops through the provider layer against FakeFirebaseFirestore. The
// load-bearing negative: Save-as-defaults writes the profile but NO activity
// log (web parity) — while an employee create does log. Both asserted against
// the same fake user_logs collection so the negative can't pass vacuously.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/activity_log_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/employee_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

UserEntity _admin() => UserEntity(
      id: 'admin-1',
      email: 'a@test',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
      employeeRepositoryProvider
          .overrideWithValue(EmployeeRepositoryImpl(firestore: firestore)),
      activityLoggerProvider.overrideWithValue(
        ActivityLogger(ActivityLogRepositoryImpl(firestore: firestore)),
      ),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(currentUserProvider, (_, __) {});
    addTearDown(sub.close);
  });

  Future<int> logCount() async =>
      (await firestore.collection('user_logs').get()).docs.length;

  test('createEmployee writes the doc AND one log entry', () async {
    await container.read(currentUserProvider.future);
    final ops = container.read(hrOperationsProvider.notifier);

    final created = await ops.createEmployee(const EmployeeEntity(
      id: '',
      name: 'Maybelle',
      dailyRate: 640,
      isActive: true,
    ));

    expect(created, isNotNull);
    expect(await logCount(), 1);
  });

  test('saveDefaults writes the profile and NO log entry', () async {
    await container.read(currentUserProvider.future);
    final ops = container.read(hrOperationsProvider.notifier);
    final created = await ops.createEmployee(const EmployeeEntity(
      id: '',
      name: 'Maybelle',
      dailyRate: 640,
      isActive: true,
    ));
    final logsAfterCreate = await logCount();

    const defaults = PayslipDefaults(
      hoursWorked: 48,
      overtimeHours: 0,
      overtimeRatePerHour: 0,
      regularHolidayDays: 0,
      specialHolidayDays: 0,
      incentives: 0,
      deductions: PayslipDeductions.empty,
      dayPattern: [DayStatus.present],
    );
    final ok = await ops.saveDefaults(created!.id, defaults);

    expect(ok, isTrue);
    final doc =
        await firestore.collection('employees').doc(created.id).get();
    expect(doc.data()!['payslipDefaults'], isNotNull);
    // The parity rule: a preference save is not an audited action.
    expect(await logCount(), logsAfterCreate);
  });
}
