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
  Future<void> resolve({
    required String requestId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  });

  /// Marks a single request read.
  Future<void> markRead(String requestId);

  /// Marks all requests read.
  Future<void> markAllRead();
}
