import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Employees registry (HR payroll). Same collection as the web admin.
abstract class EmployeeRepository {
  /// Streams active employees, A→Z by name (the payroll picker).
  Stream<List<EmployeeEntity>> watchActive();

  /// Streams all employees (active + inactive) for the registry editor.
  Stream<List<EmployeeEntity>> watchAll();

  Future<EmployeeEntity?> getById(String id);

  Future<EmployeeEntity> create(EmployeeEntity employee);

  /// Sparse update: only name/dailyRate/isActive/weekStartDay/payslipDefaults
  /// plus an updatedAt serverTimestamp — mirrors web's patch semantics.
  Future<void> update(EmployeeEntity employee);

  /// Persists the "Save as defaults" profile alone (web parity: this is the
  /// only writer of the payslipDefaults key).
  Future<void> saveDefaults(String id, PayslipDefaults defaults);

  /// Hard delete — only offered on inactive rows by the UI.
  Future<void> delete(String id);
}
