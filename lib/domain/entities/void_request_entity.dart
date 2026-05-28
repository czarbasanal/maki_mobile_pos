import 'package:equatable/equatable.dart';

/// Lifecycle status of a void request.
enum VoidRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VoidRequestStatus(this.value);
  final String value;

  static VoidRequestStatus fromValue(String value) =>
      VoidRequestStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => VoidRequestStatus.pending,
      );
}

/// A cashier/staff request to void a sale, awaiting admin approval.
class VoidRequestEntity extends Equatable {
  final String id;
  final String saleId;
  final String saleNumber;
  final double saleGrandTotal;
  final String requestedBy;
  final String requestedByName;
  final String requestedByRole;
  final String reason;
  final VoidRequestStatus status;
  final bool read;
  final DateTime createdAt;
  final String? resolvedBy;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? rejectionReason;

  const VoidRequestEntity({
    required this.id,
    required this.saleId,
    required this.saleNumber,
    required this.saleGrandTotal,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedByRole,
    required this.reason,
    this.status = VoidRequestStatus.pending,
    this.read = false,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.rejectionReason,
  });

  bool get isPending => status == VoidRequestStatus.pending;

  VoidRequestEntity copyWith({
    String? id,
    VoidRequestStatus? status,
    bool? read,
    String? resolvedBy,
    String? resolvedByName,
    DateTime? resolvedAt,
    String? rejectionReason,
  }) {
    return VoidRequestEntity(
      id: id ?? this.id,
      saleId: saleId,
      saleNumber: saleNumber,
      saleGrandTotal: saleGrandTotal,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      requestedByRole: requestedByRole,
      reason: reason,
      status: status ?? this.status,
      read: read ?? this.read,
      createdAt: createdAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedByName: resolvedByName ?? this.resolvedByName,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        saleId,
        saleNumber,
        saleGrandTotal,
        requestedBy,
        requestedByName,
        requestedByRole,
        reason,
        status,
        read,
        createdAt,
        resolvedBy,
        resolvedByName,
        resolvedAt,
        rejectionReason,
      ];
}
