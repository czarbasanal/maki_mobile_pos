import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Firestore (de)serialization for [VoidRequestEntity].
class VoidRequestModel {
  static VoidRequestEntity fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return VoidRequestEntity(
      id: doc.id,
      saleId: map['saleId'] as String? ?? '',
      saleNumber: map['saleNumber'] as String? ?? '',
      saleGrandTotal: (map['saleGrandTotal'] as num?)?.toDouble() ?? 0.0,
      requestedBy: map['requestedBy'] as String? ?? '',
      requestedByName: map['requestedByName'] as String? ?? '',
      requestedByRole: map['requestedByRole'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: VoidRequestStatus.fromValue(map['status'] as String? ?? 'pending'),
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedBy: map['resolvedBy'] as String?,
      resolvedByName: map['resolvedByName'] as String?,
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  /// Map for creating a new request (server timestamp for createdAt).
  static Map<String, dynamic> toCreateMap(VoidRequestEntity e) {
    return {
      'saleId': e.saleId,
      'saleNumber': e.saleNumber,
      'saleGrandTotal': e.saleGrandTotal,
      'requestedBy': e.requestedBy,
      'requestedByName': e.requestedByName,
      'requestedByRole': e.requestedByRole,
      'reason': e.reason,
      'status': VoidRequestStatus.pending.value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
