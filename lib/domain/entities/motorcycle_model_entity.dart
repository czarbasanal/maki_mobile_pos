import 'package:equatable/equatable.dart';

/// Admin-managed + cashier-addable motorcycle model, picked on a Job Order.
///
/// Inactive models drop off the picker but stay valid on history — the model
/// is snapshotted by *name* onto the draft/sale, never referenced by id.
class MotorcycleModelEntity extends Equatable {
  final String id;
  final String name; // canonical display, e.g. "Nmax"
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MotorcycleModelEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  MotorcycleModelEntity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MotorcycleModelEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory MotorcycleModelEntity.empty() => MotorcycleModelEntity(
        id: '',
        name: '',
        isActive: true,
        createdAt: DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [id, name, isActive, createdAt, updatedAt, createdBy, updatedBy];
}
