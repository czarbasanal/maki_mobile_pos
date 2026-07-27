import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Job Order operations.
///
/// This interface defines all data access methods for job orders.
/// Implementations handle the actual data source (Firestore, etc.)
///
/// Key responsibilities:
/// - CRUD operations for job orders
/// - Converting job orders to sales
/// - Querying job orders by various criteria
abstract class JobOrderRepository {
  // ==================== CREATE ====================

  /// Creates a new job order and returns it with the generated ID.
  ///
  /// [job order] - The job order entity to create (id will be ignored/replaced)
  ///
  /// Returns the created job order with populated ID and server timestamps.
  /// Throws [DatabaseException] if creation fails.
  Future<JobOrderEntity> createJobOrder(JobOrderEntity jobOrder);

  // ==================== READ ====================

  /// Retrieves a job order by its ID.
  ///
  /// [jobOrderId] - The unique identifier of the job order
  ///
  /// Returns the job order entity.
  /// Returns null if not found.
  Future<JobOrderEntity?> getJobOrderById(String jobOrderId);

  /// Retrieves all active (non-converted) job orders.
  ///
  /// [createdBy] - Optional filter by creator
  /// [limit] - Maximum number of results (default: 50)
  ///
  /// Returns list of job orders ordered by updatedAt descending.
  Future<List<JobOrderEntity>> getActiveJobOrders({
    String? createdBy,
    int limit = 50,
  });

  /// Retrieves all job orders including converted ones.
  ///
  /// [createdBy] - Optional filter by creator
  /// [includeConverted] - Whether to include converted job orders
  /// [limit] - Maximum number of results
  ///
  /// Returns list of all job orders.
  Future<List<JobOrderEntity>> getAllJobOrders({
    String? createdBy,
    bool includeConverted = false,
    int limit = 100,
  });

  /// Retrieves job orders created within a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  /// [includeConverted] - Whether to include converted job orders
  ///
  /// Returns list of job orders in that date range.
  Future<List<JobOrderEntity>> getJobOrdersByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    bool includeConverted = false,
  });

  /// Searches job orders by name.
  ///
  /// [query] - Search query string
  /// [includeConverted] - Whether to include converted job orders
  ///
  /// Returns list of matching job orders.
  Future<List<JobOrderEntity>> searchJobOrdersByName({
    required String query,
    bool includeConverted = false,
  });

  /// Streams active job orders for real-time updates.
  ///
  /// [createdBy] - Optional filter by creator
  ///
  /// Returns a stream of job order lists.
  Stream<List<JobOrderEntity>> watchActiveJobOrders({String? createdBy});

  /// Streams a specific job order for real-time updates.
  ///
  /// [jobOrderId] - The job order ID to watch
  ///
  /// Returns a stream of the job order (null if deleted).
  Stream<JobOrderEntity?> watchJobOrder(String jobOrderId);

  // ==================== UPDATE ====================

  /// Updates an existing job order.
  ///
  /// [job order] - The job order entity with updated values
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated job order entity.
  /// Throws [DatabaseException] if update fails.
  Future<JobOrderEntity> updateJobOrder({
    required JobOrderEntity jobOrder,
    required String updatedBy,
  });

  /// Updates only the items in a job order.
  ///
  /// [jobOrderId] - The job order ID
  /// [items] - The new list of items
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated job order entity.
  Future<JobOrderEntity> updateJobOrderItems({
    required String jobOrderId,
    required List<SaleItemEntity> items,
    required String updatedBy,
  });

  /// Updates the job order name.
  ///
  /// [jobOrderId] - The job order ID
  /// [name] - The new name
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated job order entity.
  Future<JobOrderEntity> updateJobOrderName({
    required String jobOrderId,
    required String name,
    required String updatedBy,
  });

  /// Updates job order notes.
  ///
  /// [jobOrderId] - The job order ID
  /// [notes] - The new notes
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated job order entity.
  Future<JobOrderEntity> updateJobOrderNotes({
    required String jobOrderId,
    required String? notes,
    required String updatedBy,
  });

  /// Marks a job order as converted to a sale.
  ///
  /// [jobOrderId] - The job order ID
  /// [saleId] - The ID of the created sale
  ///
  /// Returns the updated job order entity.
  /// This is typically called after successfully creating a sale from a job order.
  Future<JobOrderEntity> markJobOrderAsConverted({
    required String jobOrderId,
    required String saleId,
  });

  // ==================== DELETE ====================

  /// Deletes a job order.
  ///
  /// [jobOrderId] - The job order ID to delete
  ///
  /// Throws [DatabaseException] if deletion fails.
  /// Note: Consider soft delete or archiving for audit purposes.
  Future<void> deleteJobOrder(String jobOrderId);

  /// Deletes all converted job orders older than a specified date.
  ///
  /// [olderThan] - Delete job orders converted before this date
  ///
  /// Returns the number of job orders deleted.
  /// Use for cleanup of old converted job orders.
  Future<int> deleteOldConvertedJobOrders(DateTime olderThan);
}
