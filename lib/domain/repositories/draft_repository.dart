import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Draft operations.
///
/// This interface defines all data access methods for drafts.
/// Implementations handle the actual data source (Firestore, etc.)
///
/// Key responsibilities:
/// - CRUD operations for drafts
/// - Converting drafts to sales
/// - Querying drafts by various criteria
abstract class DraftRepository {
  // ==================== CREATE ====================

  /// Creates a new draft and returns it with the generated ID.
  ///
  /// [draft] - The draft entity to create (id will be ignored/replaced)
  ///
  /// Returns the created draft with populated ID and server timestamps.
  /// Throws [DraftException] if creation fails.
  Future<DraftEntity> createDraft(DraftEntity draft);

  // ==================== READ ====================

  /// Retrieves a draft by its ID.
  ///
  /// [draftId] - The unique identifier of the draft
  ///
  /// Returns the draft entity.
  /// Returns null if not found.
  Future<DraftEntity?> getDraftById(String draftId);

  /// Retrieves all active (non-converted) drafts.
  ///
  /// [createdBy] - Optional filter by creator
  /// [limit] - Maximum number of results (default: 50)
  ///
  /// Returns list of drafts ordered by updatedAt descending.
  Future<List<DraftEntity>> getActiveDrafts({
    String? createdBy,
    int limit = 50,
  });

  /// Retrieves all drafts including converted ones.
  ///
  /// [createdBy] - Optional filter by creator
  /// [includeConverted] - Whether to include converted drafts
  /// [limit] - Maximum number of results
  ///
  /// Returns list of all drafts.
  Future<List<DraftEntity>> getAllDrafts({
    String? createdBy,
    bool includeConverted = false,
    int limit = 100,
  });

  /// Retrieves drafts created within a date range.
  ///
  /// [startDate] - Start of the date range
  /// [endDate] - End of the date range
  /// [includeConverted] - Whether to include converted drafts
  ///
  /// Returns list of drafts in that date range.
  Future<List<DraftEntity>> getDraftsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    bool includeConverted = false,
  });

  /// Searches drafts by name.
  ///
  /// [query] - Search query string
  /// [includeConverted] - Whether to include converted drafts
  ///
  /// Returns list of matching drafts.
  Future<List<DraftEntity>> searchDraftsByName({
    required String query,
    bool includeConverted = false,
  });

  /// Streams active drafts for real-time updates.
  ///
  /// [createdBy] - Optional filter by creator
  ///
  /// Returns a stream of draft lists.
  Stream<List<DraftEntity>> watchActiveDrafts({String? createdBy});

  /// Streams a specific draft for real-time updates.
  ///
  /// [draftId] - The draft ID to watch
  ///
  /// Returns a stream of the draft (null if deleted).
  Stream<DraftEntity?> watchDraft(String draftId);

  // ==================== UPDATE ====================

  /// Updates an existing draft.
  ///
  /// [draft] - The draft entity with updated values
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated draft entity.
  /// Throws [DraftException] if update fails.
  Future<DraftEntity> updateDraft({
    required DraftEntity draft,
    required String updatedBy,
  });

  /// Updates only the items in a draft.
  ///
  /// [draftId] - The draft ID
  /// [items] - The new list of items
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated draft entity.
  Future<DraftEntity> updateDraftItems({
    required String draftId,
    required List<SaleItemEntity> items,
    required String updatedBy,
  });

  /// Updates the draft name.
  ///
  /// [draftId] - The draft ID
  /// [name] - The new name
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated draft entity.
  Future<DraftEntity> updateDraftName({
    required String draftId,
    required String name,
    required String updatedBy,
  });

  /// Updates draft notes.
  ///
  /// [draftId] - The draft ID
  /// [notes] - The new notes
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated draft entity.
  Future<DraftEntity> updateDraftNotes({
    required String draftId,
    required String? notes,
    required String updatedBy,
  });

  /// Marks a draft as converted to a sale.
  ///
  /// [draftId] - The draft ID
  /// [saleId] - The ID of the created sale
  ///
  /// Returns the updated draft entity.
  /// This is typically called after successfully creating a sale from a draft.
  Future<DraftEntity> markDraftAsConverted({
    required String draftId,
    required String saleId,
  });

  // ==================== DELETE ====================

  /// Deletes a draft.
  ///
  /// [draftId] - The draft ID to delete
  ///
  /// Throws [DraftException] if deletion fails.
  /// Note: Consider soft delete or archiving for audit purposes.
  Future<void> deleteDraft(String draftId);

  /// Deletes all converted drafts older than a specified date.
  ///
  /// [olderThan] - Delete drafts converted before this date
  ///
  /// Returns the number of drafts deleted.
  /// Use for cleanup of old converted drafts.
  Future<int> deleteOldConvertedDrafts(DateTime olderThan);

  // ==================== UTILITY ====================

  /// Checks if a draft with the given name already exists.
  ///
  /// [name] - The draft name to check
  /// [excludeDraftId] - Optional draft ID to exclude from check (for updates)
  ///
  /// Returns true if a draft with that name exists.
  Future<bool> draftNameExists({
    required String name,
    String? excludeDraftId,
  });

  /// Gets the count of active (non-converted) drafts.
  ///
  /// [createdBy] - Optional filter by creator
  ///
  /// Returns the count of active drafts.
  Future<int> getActiveDraftCount({String? createdBy});

  /// Gets the count of all drafts.
  ///
  /// [includeConverted] - Whether to include converted drafts
  ///
  /// Returns the total draft count.
  Future<int> getTotalDraftCount({bool includeConverted = false});
}
