// HR use-cases: manageHr gating + activity-log parity with web. The action
// strings are copied from the web source verbatim (EmployeesPage /
// PayrollPage / PayslipDetailPage) so the /logs screen reads identically no
// matter which surface did the work. Save-as-defaults is deliberately NOT a
// use-case and NOT logged — web parity; asserted by the provider test.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/employee_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/payslip_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/create_employee_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/delete_employee_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/delete_payslip_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/generate_payslip_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/update_employee_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockEmployeeRepository extends Mock implements EmployeeRepository {}

class _MockPayslipRepository extends Mock implements PayslipRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

class _FakeEmployee extends Fake implements EmployeeEntity {}

class _FakePayslip extends Fake implements PayslipEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

EmployeeEntity _employee() => const EmployeeEntity(
      id: 'e1',
      name: 'Maybelle Tampos',
      dailyRate: 640,
      isActive: true,
    );

PayslipEntity _payslip() => const PayslipEntity(
      id: '',
      employeeId: 'e1',
      employeeName: 'Maybelle Tampos',
      periodStart: '2026-07-20',
      periodEnd: '2026-07-26',
      days: [],
      inputs: PayslipInputs(
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
      computed: PayslipComputed(
        hourlyRate: 80,
        basePay: 3840,
        overtimePay: 0,
        holidayPay: 0,
        gross: 3840,
        totalDeductions: 0,
        net: 3840,
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
    registerFallbackValue(_FakeEmployee());
    registerFallbackValue(_FakePayslip());
  });

  late _MockEmployeeRepository employees;
  late _MockPayslipRepository payslips;
  late _MockActivityLogRepository logRepo;
  late ActivityLogger logger;

  setUp(() {
    employees = _MockEmployeeRepository();
    payslips = _MockPayslipRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    logger = ActivityLogger(logRepo);
  });

  List<ActivityLogEntity> logged() =>
      verify(() => logRepo.logActivity(captureAny()))
          .captured
          .cast<ActivityLogEntity>()
          .toList();

  group('CreateEmployeeUseCase', () {
    test('creates and logs the web-parity string', () async {
      when(() => employees.create(any()))
          .thenAnswer((_) async => _employee());
      final useCase =
          CreateEmployeeUseCase(repository: employees, logger: logger);

      final result = await useCase.execute(
          actor: _user(UserRole.admin), employee: _employee());

      expect(result.success, isTrue);
      final entry = logged().single;
      expect(entry.type, ActivityType.userManagement);
      expect(entry.action, 'Created employee: Maybelle Tampos');
      expect(entry.entityType, 'employee');
    });

    test('staff are denied — payroll is admin-only', () async {
      final useCase =
          CreateEmployeeUseCase(repository: employees, logger: logger);
      final result = await useCase.execute(
          actor: _user(UserRole.staff), employee: _employee());
      expect(result.success, isFalse);
      verifyNever(() => employees.create(any()));
    });
  });

  group('UpdateEmployeeUseCase', () {
    test('updates and logs, noting deactivation in details', () async {
      when(() => employees.update(any())).thenAnswer((_) async {});
      final useCase =
          UpdateEmployeeUseCase(repository: employees, logger: logger);

      await useCase.execute(
        actor: _user(UserRole.admin),
        employee: _employee().copyWith(isActive: false),
        activeChanged: true,
      );

      final entry = logged().single;
      expect(entry.action, 'Updated employee: Maybelle Tampos');
      expect(entry.details, 'Deactivated');
    });

    test('reactivation is noted too; a plain edit carries no details',
        () async {
      when(() => employees.update(any())).thenAnswer((_) async {});
      final useCase =
          UpdateEmployeeUseCase(repository: employees, logger: logger);

      await useCase.execute(
        actor: _user(UserRole.admin),
        employee: _employee(),
        activeChanged: true,
      );
      await useCase.execute(
        actor: _user(UserRole.admin),
        employee: _employee(),
      );

      final entries = logged();
      expect(entries[0].details, 'Reactivated');
      expect(entries[1].details, isNull);
    });
  });

  group('DeleteEmployeeUseCase', () {
    test('deletes and logs with the name', () async {
      when(() => employees.delete(any())).thenAnswer((_) async {});
      final useCase =
          DeleteEmployeeUseCase(repository: employees, logger: logger);

      await useCase.execute(
        actor: _user(UserRole.admin),
        employeeId: 'e1',
        employeeName: 'Maybelle Tampos',
      );

      expect(logged().single.action, 'Deleted employee: Maybelle Tampos');
    });
  });

  group('GeneratePayslipUseCase', () {
    test('creates the frozen snapshot and logs the web-parity string',
        () async {
      when(() => payslips.create(any())).thenAnswer((_) async => 'ps-1');
      final useCase =
          GeneratePayslipUseCase(repository: payslips, logger: logger);

      final result = await useCase.execute(
          actor: _user(UserRole.admin), payslip: _payslip());

      expect(result.success, isTrue);
      expect(result.data, 'ps-1');
      final entry = logged().single;
      expect(entry.action, 'Generated payslip: Maybelle Tampos');
      expect(entry.details, '2026-07-20 – 2026-07-26');
      expect(entry.entityId, 'ps-1');
      expect(entry.entityType, 'payslip');
    });

    test('cashier is denied', () async {
      final useCase =
          GeneratePayslipUseCase(repository: payslips, logger: logger);
      final result = await useCase.execute(
          actor: _user(UserRole.cashier), payslip: _payslip());
      expect(result.success, isFalse);
      verifyNever(() => payslips.create(any()));
    });
  });

  group('DeletePayslipUseCase', () {
    test('deletes and logs with the employee name', () async {
      when(() => payslips.delete(any())).thenAnswer((_) async {});
      final useCase =
          DeletePayslipUseCase(repository: payslips, logger: logger);

      await useCase.execute(
        actor: _user(UserRole.admin),
        payslipId: 'ps-1',
        employeeName: 'Maybelle Tampos',
      );

      expect(logged().single.action, 'Deleted payslip: Maybelle Tampos');
    });
  });
}
