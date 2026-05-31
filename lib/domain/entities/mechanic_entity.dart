import 'package:equatable/equatable.dart';

/// Domain entity representing an admin-managed mechanic.
///
/// Mechanics are assigned to a service draft/sale. Inactive mechanics drop
/// off the picker but stay valid on historical records via the snapshotted
/// name on the draft/sale.
class MechanicEntity extends Equatable {
  /// Unique identifier.
  final String id;

  /// Mechanic name (display + match key).
  final String name;

  /// Whether this mechanic is active. Soft-deleted mechanics stay in the
  /// collection so historical records keep matching.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MechanicEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  MechanicEntity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MechanicEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory MechanicEntity.empty() {
    return MechanicEntity(
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
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
      ];
}
