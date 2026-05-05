import 'package:equatable/equatable.dart';

/// Domain entity representing an admin-managed category.
///
/// Used for both product categories and expense categories. The two are
/// stored in separate Firestore collections — see [CategoryRepositoryImpl].
class CategoryEntity extends Equatable {
  /// Unique identifier.
  final String id;

  /// Category name (display + match key).
  final String name;

  /// Whether this category is active. Soft-deleted categories stay in the
  /// collection so historical product/expense records keep matching.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  CategoryEntity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory CategoryEntity.empty() {
    return CategoryEntity(
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
