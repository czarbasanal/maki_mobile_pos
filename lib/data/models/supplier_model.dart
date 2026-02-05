import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for Supplier with Firestore serialization.
class SupplierModel {
  final String id;
  final String name;
  final String? address;
  final String? contactPerson;
  final String? contactNumber;
  final String? alternativeNumber;
  final String? email;
  final TransactionType transactionType;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int productCount;
  final double totalInventoryValue;
  final List<String> searchKeywords;

  const SupplierModel({
    required this.id,
    required this.name,
    this.address,
    this.contactPerson,
    this.contactNumber,
    this.alternativeNumber,
    this.email,
    required this.transactionType,
    required this.isActive,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.productCount = 0,
    this.totalInventoryValue = 0,
    this.searchKeywords = const [],
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from Firestore document.
  factory SupplierModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return SupplierModel.fromMap(data, doc.id);
  }

  /// Creates from a Map.
  factory SupplierModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SupplierModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      address: map['address'] as String?,
      contactPerson: map['contactPerson'] as String?,
      contactNumber: map['contactNumber'] as String?,
      alternativeNumber: map['alternativeNumber'] as String?,
      email: map['email'] as String?,
      transactionType:
          TransactionType.fromString(map['transactionType'] as String?),
      isActive: map['isActive'] as bool? ?? true,
      notes: map['notes'] as String?,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
      productCount: (map['productCount'] as num?)?.toInt() ?? 0,
      totalInventoryValue:
          (map['totalInventoryValue'] as num?)?.toDouble() ?? 0,
      searchKeywords: _parseStringList(map['searchKeywords']),
    );
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'name': name,
      'address': address,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'alternativeNumber': alternativeNumber,
      'email': email,
      'transactionType': transactionType.value,
      'isActive': isActive,
      'notes': notes,
      'productCount': productCount,
      'totalInventoryValue': totalInventoryValue,
      'searchKeywords': searchKeywords,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['createdBy'] = createdBy;
      map['updatedBy'] = createdBy;
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['updatedBy'] = updatedBy;
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
      if (updatedAt != null) {
        map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      }
      map['createdBy'] = createdBy;
      map['updatedBy'] = updatedBy;
    }

    return map;
  }

  /// Converts to a Map for creating a new supplier.
  Map<String, dynamic> toCreateMap(String createdByUserId) {
    return copyWith(
      createdBy: createdByUserId,
      searchKeywords: _generateSearchKeywords(),
    ).toMap(forCreate: true);
  }

  /// Converts to a Map for updating a supplier.
  Map<String, dynamic> toUpdateMap(String updatedByUserId) {
    return copyWith(
      updatedBy: updatedByUserId,
      searchKeywords: _generateSearchKeywords(),
    ).toMap(forUpdate: true);
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  SupplierEntity toEntity() {
    return SupplierEntity(
      id: id,
      name: name,
      address: address,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      alternativeNumber: alternativeNumber,
      email: email,
      transactionType: transactionType,
      isActive: isActive,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      productCount: productCount,
      totalInventoryValue: totalInventoryValue,
    );
  }

  /// Creates from domain entity.
  factory SupplierModel.fromEntity(SupplierEntity entity) {
    final model = SupplierModel(
      id: entity.id,
      name: entity.name,
      address: entity.address,
      contactPerson: entity.contactPerson,
      contactNumber: entity.contactNumber,
      alternativeNumber: entity.alternativeNumber,
      email: entity.email,
      transactionType: entity.transactionType,
      isActive: entity.isActive,
      notes: entity.notes,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      productCount: entity.productCount,
      totalInventoryValue: entity.totalInventoryValue,
    );

    return model.copyWith(
      searchKeywords: model._generateSearchKeywords(),
    );
  }

  // ==================== FACTORY METHODS ====================

  /// Creates an empty supplier model.
  factory SupplierModel.empty() {
    return SupplierModel(
      id: '',
      name: '',
      transactionType: TransactionType.cash,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a new supplier with default values.
  factory SupplierModel.create({
    required String name,
    String? address,
    String? contactPerson,
    String? contactNumber,
    String? alternativeNumber,
    String? email,
    TransactionType transactionType = TransactionType.cash,
    String? notes,
  }) {
    final model = SupplierModel(
      id: '',
      name: name,
      address: address,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      alternativeNumber: alternativeNumber,
      email: email,
      transactionType: transactionType,
      isActive: true,
      notes: notes,
      createdAt: DateTime.now(),
    );

    return model.copyWith(
      searchKeywords: model._generateSearchKeywords(),
    );
  }

  // ==================== HELPER METHODS ====================

  /// Generates search keywords from name and contact info.
  List<String> _generateSearchKeywords() {
    final keywords = <String>{};

    // Add name keywords
    keywords.addAll(name.toLowerCase().toSearchKeywords());

    // Add contact person keywords
    if (contactPerson != null && contactPerson!.isNotEmpty) {
      keywords.addAll(contactPerson!.toLowerCase().toSearchKeywords());
    }

    // Add address keywords (first few words)
    if (address != null && address!.isNotEmpty) {
      final addressWords = address!.toLowerCase().split(' ').take(3);
      for (final word in addressWords) {
        if (word.length > 2) {
          keywords.addAll(word.toSearchKeywords());
        }
      }
    }

    return keywords.toList();
  }

  /// Helper to parse Firestore timestamps.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Helper to parse string lists.
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  // ==================== COPY WITH ====================

  SupplierModel copyWith({
    String? id,
    String? name,
    String? address,
    String? contactPerson,
    String? contactNumber,
    String? alternativeNumber,
    String? email,
    TransactionType? transactionType,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? productCount,
    double? totalInventoryValue,
    List<String>? searchKeywords,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      contactNumber: contactNumber ?? this.contactNumber,
      alternativeNumber: alternativeNumber ?? this.alternativeNumber,
      email: email ?? this.email,
      transactionType: transactionType ?? this.transactionType,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      productCount: productCount ?? this.productCount,
      totalInventoryValue: totalInventoryValue ?? this.totalInventoryValue,
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }

  @override
  String toString() {
    return 'SupplierModel(id: $id, name: $name, transactionType: ${transactionType.value})';
  }
}
