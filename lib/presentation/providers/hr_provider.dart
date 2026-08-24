// HR providers — employees registry, payslips, HR settings, and the ops
// notifier the screens drive. Mirrors supplier_provider's shape: repository
// providers → authGatedStream queries → use-case providers → a
// StateNotifier<AsyncValue<void>> whose methods resolve the actor themselves.
//
// Save-as-defaults and save-settings are plain repository ops with NO
// activity log — web parity: only employee CRUD and payslip generate/delete
// appear in /logs.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/employee_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/hr_settings_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/payslip_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/employee_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/hr_settings_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/payslip_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/create_employee_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/delete_employee_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/delete_payslip_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/generate_payslip_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/hr/update_employee_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

// ==================== REPOSITORIES ====================

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl();
});

final payslipRepositoryProvider = Provider<PayslipRepository>((ref) {
  return PayslipRepositoryImpl();
});

final hrSettingsRepositoryProvider = Provider<HrSettingsRepository>((ref) {
  return HrSettingsRepositoryImpl();
});

// ==================== QUERIES ====================

/// Active employees A→Z — the payroll picker.
final activeEmployeesProvider = StreamProvider<List<EmployeeEntity>>((ref) {
  return authGatedStream(
      ref, (_) => ref.watch(employeeRepositoryProvider).watchActive());
});

/// All employees (active + inactive) — the registry editor.
final allEmployeesProvider = StreamProvider<List<EmployeeEntity>>((ref) {
  return authGatedStream(
      ref, (_) => ref.watch(employeeRepositoryProvider).watchAll());
});

/// All payslips, newest period first.
final payslipsProvider = StreamProvider<List<PayslipEntity>>((ref) {
  return authGatedStream(
      ref, (_) => ref.watch(payslipRepositoryProvider).watchAll());
});

/// One payslip by id (detail screen).
final payslipByIdProvider =
    FutureProvider.family<PayslipEntity?, String>((ref, id) {
  return ref.watch(payslipRepositoryProvider).getById(id);
});

/// The settings/hr doc; a missing doc reads as the 1/100/30 defaults.
final hrSettingsProvider = FutureProvider<HrSettingsEntity>((ref) {
  return ref.watch(hrSettingsRepositoryProvider).get();
});

// ==================== USE-CASE PROVIDERS ====================

final createEmployeeUseCaseProvider = Provider<CreateEmployeeUseCase>((ref) {
  return CreateEmployeeUseCase(
    repository: ref.watch(employeeRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final updateEmployeeUseCaseProvider = Provider<UpdateEmployeeUseCase>((ref) {
  return UpdateEmployeeUseCase(
    repository: ref.watch(employeeRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final deleteEmployeeUseCaseProvider = Provider<DeleteEmployeeUseCase>((ref) {
  return DeleteEmployeeUseCase(
    repository: ref.watch(employeeRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final generatePayslipUseCaseProvider = Provider<GeneratePayslipUseCase>((ref) {
  return GeneratePayslipUseCase(
    repository: ref.watch(payslipRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final deletePayslipUseCaseProvider = Provider<DeletePayslipUseCase>((ref) {
  return DeletePayslipUseCase(
    repository: ref.watch(payslipRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== OPERATIONS ====================

class HrOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  HrOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) throw const UnauthenticatedException();
    return user;
  }

  Future<EmployeeEntity?> createEmployee(EmployeeEntity employee) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref
          .read(createEmployeeUseCaseProvider)
          .execute(actor: _requireUser(), employee: employee);
      if (result.success) {
        state = const AsyncValue.data(null);
        return result.data;
      }
      state = AsyncValue.error(
          result.errorMessage ?? 'Create employee failed', StackTrace.current);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateEmployee(EmployeeEntity employee,
      {bool activeChanged = false}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(updateEmployeeUseCaseProvider).execute(
          actor: _requireUser(),
          employee: employee,
          activeChanged: activeChanged);
      if (result.success) {
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(
          result.errorMessage ?? 'Update employee failed', StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteEmployee(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(deleteEmployeeUseCaseProvider).execute(
          actor: _requireUser(), employeeId: id, employeeName: name);
      if (result.success) {
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(
          result.errorMessage ?? 'Delete employee failed', StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Persists the generator profile onto the employee. Deliberately NOT
  /// logged (web parity) and deliberately not a use-case — it is a
  /// preference save, not an audited action.
  Future<bool> saveDefaults(String employeeId, PayslipDefaults defaults) async {
    state = const AsyncValue.loading();
    try {
      _requireUser();
      await _ref
          .read(employeeRepositoryProvider)
          .saveDefaults(employeeId, defaults);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<String?> generatePayslip(PayslipEntity payslip) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref
          .read(generatePayslipUseCaseProvider)
          .execute(actor: _requireUser(), payslip: payslip);
      if (result.success) {
        state = const AsyncValue.data(null);
        return result.data;
      }
      state = AsyncValue.error(
          result.errorMessage ?? 'Generate payslip failed', StackTrace.current);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deletePayslip(String id, String employeeName) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(deletePayslipUseCaseProvider).execute(
          actor: _requireUser(), payslipId: id, employeeName: employeeName);
      if (result.success) {
        state = const AsyncValue.data(null);
        return true;
      }
      state = AsyncValue.error(
          result.errorMessage ?? 'Delete payslip failed', StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> saveSettings(HrSettingsEntity settings) async {
    state = const AsyncValue.loading();
    try {
      _requireUser();
      await _ref.read(hrSettingsRepositoryProvider).save(settings);
      _ref.invalidate(hrSettingsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final hrOperationsProvider =
    StateNotifierProvider<HrOperationsNotifier, AsyncValue<void>>((ref) {
  return HrOperationsNotifier(ref);
});
