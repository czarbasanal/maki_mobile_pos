import 'package:equatable/equatable.dart';

/// Domain entity for a stock adjustment reason (spec 2026-09-04).
///
/// Adjustment reasons categorize stock corrections (loss, gain, physical count,
/// damage, etc.) and optionally require notes for audit trail. Inactive reasons
/// stop rendering in dropdowns but their ids stay on adjustments.
class AdjustmentReasonEntity extends Equatable {
  final String id;

  /// Reason name (display + match key).
  final String name;

  /// Whether a note is required when recording this adjustment.
  final bool requiresNote;

  /// Soft-delete flag.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const AdjustmentReasonEntity({
    required this.id,
    required this.name,
    required this.requiresNote,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  AdjustmentReasonEntity copyWith({
    String? id,
    String? name,
    bool? requiresNote,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return AdjustmentReasonEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      requiresNote: requiresNote ?? this.requiresNote,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory AdjustmentReasonEntity.empty() {
    return AdjustmentReasonEntity(
      id: '',
      name: '',
      requiresNote: false,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, requiresNote, isActive, createdAt, updatedAt, createdBy, updatedBy];
}
