import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Contract for void-request persistence.
abstract class VoidRequestRepository {
  /// Creates a new pending request. Returns it with id populated.
  Future<VoidRequestEntity> createRequest(VoidRequestEntity request);

  /// Streams all requests, newest first (admin queue + unread count).
  Stream<List<VoidRequestEntity>> watchRequests({int limit = 50});

  /// Streams pending requests for a given sale (sale-detail indicator).
  Stream<List<VoidRequestEntity>> watchPendingForSale(String saleId);

  /// True if a pending request already exists for the sale (dedupe).
  Future<bool> hasPendingForSale(String saleId);

  /// Resolves a request (approve/reject) — admin only at the rules layer.
  /// [saleId] is the resolved request's sale — used to delete the matching
  /// `void_request_pending/{saleId}` claim in the same operation as the
  /// status update. Deleting a claim that doesn't exist (a legacy request
  /// created before the claim collection existed) is a no-op.
  Future<void> resolve({
    required String requestId,
    required String saleId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  });

  /// Marks a single request read.
  Future<void> markRead(String requestId);

  /// Marks all requests read.
  Future<void> markAllRead();

  /// One page of requests with timestamps from `start` to `end`, inclusive
  /// (>= `start`, <= `end`), newest first. [status] null = all statuses.
  /// Callers must pass an end-of-day `end` (e.g. 23:59:59.999) to cover a full day.
  /// Pass the last item's id as `startAfterId` for the next page; it must be an id
  /// from a prior page of the SAME status/window query — a cursor from a different
  /// filter silently shifts the page, and an id that no longer exists is treated as
  /// no cursor.
  Future<List<VoidRequestEntity>> getRequestsPage({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
    int limit = 20,
    String? startAfterId,
  });

  /// Count of requests with [status] with timestamps from `start` to `end`,
  /// inclusive (>= `start`, <= `end`). Callers must pass an end-of-day `end`
  /// (e.g. 23:59:59.999) to cover a full day. (Aggregate query.)
  Future<int> countByStatus({
    required VoidRequestStatus status,
    required DateTime start,
    required DateTime end,
  });
}
