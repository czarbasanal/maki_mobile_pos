import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Generated payslips — frozen snapshots (firestore.rules: update:false).
/// Deliberately no update method: a slip is created, read, or deleted.
abstract class PayslipRepository {
  /// Streams all payslips, periodStart DESC then employeeName ASC
  /// (web's fixed sort).
  Stream<List<PayslipEntity>> watchAll();

  Future<PayslipEntity?> getById(String id);

  /// Creates the frozen snapshot; returns the new doc id.
  Future<String> create(PayslipEntity payslip);

  Future<void> delete(String id);
}
