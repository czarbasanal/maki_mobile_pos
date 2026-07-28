import 'package:equatable/equatable.dart';

/// Domain entity representing an admin-managed shop fee.
///
/// Shop fees are attachable to a sale/job order (e.g. environmental fee,
/// disposal fee). [defaultAmount] is the amount pre-filled when the fee is
/// picked; when null, the cashier enters the amount at the register.
/// Inactive shop fees drop off the picker but stay valid on historical
/// records via the snapshotted name/amount on the job order/sale.
class ShopFeeEntity extends Equatable {
  /// Unique identifier.
  final String id;

  /// Shop fee name (display + match key).
  final String name;

  /// Default amount pre-filled when this fee is picked. Null means no
  /// default — the amount is entered at the register.
  final double? defaultAmount;

  /// Whether this shop fee is active. Soft-deleted shop fees stay in the
  /// collection so historical records keep matching.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ShopFeeEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.defaultAmount,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  ShopFeeEntity copyWith({
    String? id,
    String? name,
    double? defaultAmount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool clearDefaultAmount = false,
  }) {
    return ShopFeeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultAmount:
          clearDefaultAmount ? null : (defaultAmount ?? this.defaultAmount),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory ShopFeeEntity.empty() {
    return ShopFeeEntity(
      id: '',
      name: '',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        defaultAmount,
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
      ];
}
