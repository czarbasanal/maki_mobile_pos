import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

/// Abstract repository contract for Receiving operations.
abstract class ReceivingRepository {
  // ==================== CREATE ====================

  /// Creates a new receiving record.
  Future<ReceivingEntity> createReceiving(ReceivingEntity receiving);

  // ==================== READ ====================

  /// Gets a receiving by ID.
  Future<ReceivingEntity?> getReceivingById(String receivingId);

  /// Gets all receiving records with optional filters.
  Future<List<ReceivingEntity>> getReceivings({
    ReceivingStatus? status,
    String? supplierId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });

  /// Gets recent receiving records.
  Future<List<ReceivingEntity>> getRecentReceivings({int limit = 20});

  /// Gets draft receiving records.
  Future<List<ReceivingEntity>> getDraftReceivings();

  /// Streams receiving records for real-time updates.
  Stream<List<ReceivingEntity>> watchReceivings({
    ReceivingStatus? status,
    int limit = 50,
  });

  // ==================== UPDATE ====================

  /// Updates a receiving record.
  Future<ReceivingEntity> updateReceiving(ReceivingEntity receiving);

  /// Completes a receiving and updates inventory.
  ///
  /// This will:
  /// 1. Mark receiving as completed
  /// 2. Add stock to products
  /// 3. Create variations for different costs
  /// 4. Record price history
  Future<ReceivingEntity> completeReceiving({
    required String receivingId,
    required String completedBy,
  });

  /// Cancels a receiving record.
  Future<void> cancelReceiving({
    required String receivingId,
    required String cancelledBy,
    String? reason,
  });

  // ==================== DELETE ====================

  /// Deletes a draft receiving record.
  ///
  /// Only draft receivings can be deleted.
  Future<void> deleteReceiving(String receivingId);

  // ==================== UTILITY ====================

  /// Generates a unique reference number.
  Future<String> generateReferenceNumber();

  /// Gets receiving count by status.
  Future<Map<ReceivingStatus, int>> getReceivingCounts();
}
