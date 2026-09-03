import 'package:equatable/equatable.dart';

/// Domain entity for a custom product tag (spec 2026-09-03).
///
/// Tags are attached to products via [ProductEntity.tagIds] and rendered as
/// colored chips on inventory rows. Built for the physical-count sweep
/// ("Intact" markers) but general-purpose. Inactive tags stop rendering but
/// their ids stay on products, so reactivation restores the chips.
class TagEntity extends Equatable {
  final String id;

  /// Tag name (display + match key).
  final String name;

  /// Named color token — one of [TagColors.tokens]; unknown renders as gray.
  final String color;

  /// Optional description, shown only in the tag editor.
  final String? description;

  /// Soft-delete flag.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const TagEntity({
    required this.id,
    required this.name,
    required this.color,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  TagEntity copyWith({
    String? id,
    String? name,
    String? color,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool clearDescription = false,
  }) {
    return TagEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: clearDescription ? null : (description ?? this.description),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory TagEntity.empty() {
    return TagEntity(
      id: '',
      name: '',
      color: 'gray',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, color, description, isActive, createdAt, updatedAt, createdBy, updatedBy];
}
