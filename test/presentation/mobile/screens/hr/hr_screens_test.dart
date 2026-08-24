// Screen-level wiring for the HR slice, against FakeFirebaseFirestore + real
// repositories (the mechanic-test convention). Semantics live in
// PayslipDraftController and the use-cases — these tests only prove the
// screens are wired to them: the hub hosts the three tabs (gear -> HR
// Settings), rows render from the stream, the generator writes the frozen
// doc + log, and the detail screen renders STORED figures and survives a
// deleted doc.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/activity_log_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/employee_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/hr_settings_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/payslip_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/hr_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/employees_tab.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/hr_hub_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/payroll_tab.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/payslip_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/payslips_tab.dart';
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

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    // A minimal real router: screens navigate after success (generate pushes
    // the new payslip's detail), so a bare MaterialApp would throw
    // "No GoRouter found in context" at exactly the moment the test passes.
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(
        path: '/hr/payslips/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/hr/settings',
        builder: (_, __) => const Scaffold(body: Text('HR SETTINGS STUB')),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
          employeeRepositoryProvider
              .overrideWithValue(EmployeeRepositoryImpl(firestore: firestore)),
          payslipRepositoryProvider
              .overrideWithValue(PayslipRepositoryImpl(firestore: firestore)),
          hrSettingsRepositoryProvider.overrideWithValue(
              HrSettingsRepositoryImpl(firestore: firestore)),
          activityLoggerProvider.overrideWithValue(
            ActivityLogger(ActivityLogRepositoryImpl(firestore: firestore)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> seedEmployee({
    String name = 'Maybelle Tampos',
    bool isActive = true,
  }) async {
    final ref = await firestore.collection('employees').add({
      'name': name,
      'dailyRate': 640,
      'isActive': isActive,
      'weekStartDay': null,
    });
    return ref.id;
  }

  Future<String> seedPayslip() async {
    final ref = await firestore.collection('payslips').add({
      'employeeId': 'e1',
      'employeeName': 'Maybelle Tampos',
      'periodStart': '2026-07-20',
      'periodEnd': '2026-07-26',
      'days': [
        {'date': '2026-07-20', 'status': 'present'},
      ],
      'inputs': {
        'hoursWorked': 48, 'dailyRate': 640, 'overtimeHours': 0,
        'overtimeRatePerHour': 0, 'regularHolidayDays': 0,
        'specialHolidayDays': 0, 'regularHolidayPct': 100,
        'specialHolidayPct': 30, 'incentives': 0,
        'deductions': {
          'sss': 0, 'philhealth': 0, 'pagibig': 0, 'late': 0,
          'absences': 0, 'cashAdvance': 0, 'others': [],
        },
      },
      // Stored figures deliberately differ from recomputation (base would be
      // 3840) — the detail must show these.
      'computed': {
        'hourlyRate': 80, 'basePay': 9999, 'overtimePay': 0, 'holidayPay': 0,
        'gross': 8888, 'totalDeductions': 0, 'net': 7777,
      },
    });
    return ref.id;
  }

  group('HrHubScreen', () {
    testWidgets('hosts the three tabs and switches between them',
        (tester) async {
      await seedPayslip();
      await pump(tester, const HrHubScreen());

      // Employees tab first (its empty state showing).
      expect(find.text('No employees yet'), findsOneWidget);

      await tester.tap(find.text('Payslips'));
      await tester.pumpAndSettle();
      expect(find.text('Maybelle Tampos'), findsOneWidget);
    });

    testWidgets('the gear opens HR Settings', (tester) async {
      await pump(tester, const HrHubScreen());
      await tester.tap(find.byTooltip('HR Settings'));
      await tester.pumpAndSettle();
      expect(find.text('HR SETTINGS STUB'), findsOneWidget);
    });
  });

  group('EmployeesTab', () {
    testWidgets('lists employees from the stream, inactive rows greyed in',
        (tester) async {
      await seedEmployee(name: 'Ana');
      await seedEmployee(name: 'Ben', isActive: false);
      await pump(tester, const EmployeesTab());

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
    });

    testWidgets('the add dialog refuses a zero daily rate', (tester) async {
      await pump(tester, const EmployeesTab());
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'New Hire');
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Daily rate must be more than 0'), findsOneWidget);
      expect(
          (await firestore.collection('employees').get()).docs, isEmpty);
    });
  });

  group('PayslipsTab', () {
    testWidgets('renders the seeded payslip with its stored net',
        (tester) async {
      await seedPayslip();
      await pump(tester, const PayslipsTab());

      expect(find.text('Maybelle Tampos'), findsOneWidget);
      expect(find.text('₱7,777.00'), findsOneWidget);
    });

    testWidgets('empty state points at Payroll', (tester) async {
      await pump(tester, const PayslipsTab());
      expect(find.text('No payslips yet'), findsOneWidget);
    });
  });

  group('PayslipDetailScreen', () {
    testWidgets('renders the receipt from STORED figures', (tester) async {
      final id = await seedPayslip();
      await pump(tester, PayslipDetailScreen(payslipId: id));

      expect(find.text('₱7,777.00'), findsOneWidget); // stored net
      expect(find.text('₱3,840.00'), findsNothing); // recomputation absent
      expect(find.text('NET PAY'), findsOneWidget);
    });

    testWidgets('a missing doc shows not-found instead of crashing',
        (tester) async {
      await pump(tester, const PayslipDetailScreen(payslipId: 'gone'));
      expect(find.text('Payslip not found'), findsOneWidget);
    });
  });

  group('PayrollTab', () {
    testWidgets(
        'pick → rate populates; generate writes the frozen doc AND a log',
        (tester) async {
      await seedEmployee();
      await pump(tester, const PayrollTab());

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maybelle Tampos').last);
      await tester.pumpAndSettle();

      // Rate populated from the employee.
      expect(find.widgetWithText(TextField, '640.0'), findsOneWidget);

      // Enter hours, generate.
      final hours = find.byType(TextField).first;
      await tester.enterText(hours, '48');
      await tester.ensureVisible(find.text('Generate payslip'));
      await tester.tap(find.text('Generate payslip'));
      await tester.pumpAndSettle();

      final slips = (await firestore.collection('payslips').get()).docs;
      expect(slips, hasLength(1));
      final data = slips.single.data();
      expect(data['employeeName'], 'Maybelle Tampos');
      expect((data['computed'] as Map)['basePay'], 3840); // 48h × 80
      expect((data['days'] as List), hasLength(7));

      final logs = (await firestore.collection('user_logs').get()).docs;
      expect(
        logs.map((d) => d.data()['action']),
        contains('Generated payslip: Maybelle Tampos'),
      );
    });
  });
}
