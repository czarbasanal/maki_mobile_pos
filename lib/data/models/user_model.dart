import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for User with Firestore serialization.
///
/// This class handles:
/// - JSON/Map serialization for Firestore
/// - Conversion to/from domain entity
/// - Timestamp handling
class UserModel {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final bool isActive;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.lastLoginAt,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates a UserModel from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel.fromMap(data, doc.id);
  }

  /// Creates a UserModel from a Map (Firestore data) with document ID.
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String?),
      isActive: map['isActive'] as bool? ?? true,
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
      lastLoginAt: _parseTimestamp(map['lastLoginAt']),
    );
  }

  /// Converts this model to a Map for Firestore.
  ///
  /// [includeId] - Whether to include the ID in the map (usually false for Firestore)
  /// [forCreate] - If true, sets createdAt to server timestamp
  /// [forUpdate] - If true, sets updatedAt to server timestamp
  Map<String, dynamic> toMap({
    bool includeId = false,
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };

    if (includeId) {
      map['id'] = id;
    }

    // Handle timestamps
    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      // Don't include createdAt on updates
    } else {
      map['createdAt'] = createdAt.toIso8601String();
      if (updatedAt != null) {
        map['updatedAt'] = updatedAt!.toIso8601String();
      }
    }

    if (lastLoginAt != null) {
      map['lastLoginAt'] = Timestamp.fromDate(lastLoginAt!);
    }

    return map;
  }

  /// Converts this model to a Map for creating a new user.
  Map<String, dynamic> toCreateMap(String createdByUserId) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      isActive: isActive,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      createdAt: createdAt,
      createdBy: createdByUserId,
      updatedBy: createdByUserId,
    ).toMap(forCreate: true);
  }

  /// Converts this model to a Map for updating a user.
  Map<String, dynamic> toUpdateMap(String updatedByUserId) {
    return {
      'displayName': displayName,
      'role': role.value,
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedByUserId,
    };
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts this model to a domain entity.
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      isActive: isActive,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      lastLoginAt: lastLoginAt,
    );
  }

  /// Creates a model from a domain entity.
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      displayName: entity.displayName,
      role: entity.role,
      isActive: entity.isActive,
      phoneNumber: entity.phoneNumber,
      photoUrl: entity.photoUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      lastLoginAt: entity.lastLoginAt,
    );
  }

  // ==================== COPY WITH ====================

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    bool? isActive,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // ==================== HELPER METHODS ====================

  /// Parses a Firestore timestamp or ISO string to DateTime.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Creates an empty user model (useful for initial states).
  factory UserModel.empty() {
    return UserModel(
      id: '',
      email: '',
      displayName: '',
      role: UserRole.cashier,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a new user model with default values.
  factory UserModel.create({
    required String id,
    required String email,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      isActive: true,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, displayName: $displayName, role: ${role.value}, isActive: $isActive)';
  }
}
