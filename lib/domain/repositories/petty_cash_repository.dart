import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Petty Cash operations.
abstract class PettyCashRepository {
  /// Creates a new petty cash record.
  Future<PettyCashEntity> createRecord(PettyCashEntity record);

  /// Gets a record by ID.
  Future<PettyCashEntity?> getRecordById(String recordId);

  /// Gets petty cash records with optional filters.
  Future<List<PettyCashEntity>> getRecords({
    PettyCashType? type,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });

  /// Streams petty cash records for real-time updates.
  Stream<List<PettyCashEntity>> watchRecords({int limit = 50});

  /// Gets the current petty cash balance.
  Future<double> getCurrentBalance();

  /// Performs a cash-in transaction.
  Future<PettyCashEntity> cashIn({
    required double amount,
    required String description,
    required String createdBy,
    required String createdByName,
    String? notes,
  });

  /// Performs a cash-out transaction.
  Future<PettyCashEntity> cashOut({
    required double amount,
    required String description,
    required String createdBy,
    required String createdByName,
    String? referenceId,
    String? notes,
  });

  /// Performs end-of-day cut-off.
  Future<PettyCashEntity> performCutOff({
    required String createdBy,
    required String createdByName,
    String? notes,
  });
}
