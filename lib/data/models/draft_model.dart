import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/fee_line_model.dart';
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for Draft with Firestore serialization.
///
/// This model handles:
/// - JSON/Map serialization for Firestore
/// - Conversion to/from domain entity
/// - Items stored inline (not in subcollection for simplicity)
class DraftModel {
  final String id;
  final String name;
  final List<SaleItemModel> items;
  final List<LaborLineModel> laborLines;
  final List<FeeLineModel> feeLines;
  final String? mechanicId;
  final String? mechanicName;
  final String? motorcycleModel;
  final DiscountType discountType;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final bool isConverted;
  final String? convertedToSaleId;
  final DateTime? convertedAt;
  final String? notes;

  const DraftModel({
    required this.id,
    required this.name,
    required this.items,
    this.laborLines = const [],
    this.feeLines = const [],
    this.mechanicId,
    this.mechanicName,
    this.motorcycleModel,
    this.discountType = DiscountType.amount,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.isConverted = false,
    this.convertedToSaleId,
    this.convertedAt,
    this.notes,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from a Map (Firestore data).
  factory DraftModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Parse items array
    final itemsList = <SaleItemModel>[];
    final itemsData = map['items'] as List<dynamic>? ?? [];
    for (int i = 0; i < itemsData.length; i++) {
      final itemMap = itemsData[i] as Map<String, dynamic>;
      // Use index as fallback ID if not present
      final itemId = itemMap['id'] as String? ?? 'item-$i';
      itemsList.add(SaleItemModel.fromMap(itemMap, itemId));
    }

    // Parse labor lines array (inline, like items). Legacy docs -> [].
    final laborList = <LaborLineModel>[];
    final laborData = map['laborLines'] as List<dynamic>? ?? [];
    for (int i = 0; i < laborData.length; i++) {
      final laborMap = laborData[i] as Map<String, dynamic>;
      final laborId = laborMap['id'] as String? ?? 'labor-$i';
      laborList.add(LaborLineModel.fromMap(laborMap, laborId));
    }

    // Parse fee lines array (inline, like labor). Legacy docs -> [].
    final feeList = <FeeLineModel>[];
    final feeData = map['feeLines'] as List<dynamic>? ?? [];
    for (int i = 0; i < feeData.length; i++) {
      final feeMap = feeData[i] as Map<String, dynamic>;
      final feeId = feeMap['id'] as String? ?? 'fee-$i';
      feeList.add(FeeLineModel.fromMap(feeMap, feeId));
    }

    return DraftModel(
      id: documentId,
      name: map['name'] as String? ?? 'Unnamed Draft',
      items: itemsList,
      laborLines: laborList,
      feeLines: feeList,
      mechanicId: map['mechanicId'] as String?,
      mechanicName: map['mechanicName'] as String?,
      motorcycleModel: map['motorcycleModel'] as String?,
      discountType: DiscountType.fromString(map['discountType'] as String?),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
      isConverted: map['isConverted'] as bool? ?? false,
      convertedToSaleId: map['convertedToSaleId'] as String?,
      convertedAt: _parseTimestamp(map['convertedAt']),
      notes: map['notes'] as String?,
    );
  }

  /// Creates from Firestore document.
  factory DraftModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DraftModel.fromMap(doc.data()!, doc.id);
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'name': name,
      'items': items.map((item) => item.toMap(includeId: true)).toList(),
      'laborLines':
          laborLines.map((l) => l.toMap(includeId: true)).toList(),
      'feeLines': feeLines.map((f) => f.toMap(includeId: true)).toList(),
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'motorcycleModel': motorcycleModel,
      'discountType': discountType.value,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'isConverted': isConverted,
      'convertedToSaleId': convertedToSaleId,
      'notes': notes,
    };

    // Handle timestamps
    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
      if (updatedAt != null) {
        map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      }
    }

    // Handle updatedBy
    if (forUpdate && updatedBy != null) {
      map['updatedBy'] = updatedBy;
    }

    // Handle conversion timestamp
    if (convertedAt != null) {
      map['convertedAt'] = Timestamp.fromDate(convertedAt!);
    } else if (isConverted && forUpdate) {
      map['convertedAt'] = FieldValue.serverTimestamp();
    }

    return map;
  }

  /// Converts to a Map for creating a new draft.
  Map<String, dynamic> toCreateMap() {
    return toMap(forCreate: true);
  }

  /// Converts to a Map for updating a draft.
  Map<String, dynamic> toUpdateMap(String updatedByUserId) {
    return copyWith(updatedBy: updatedByUserId).toMap(forUpdate: true);
  }

  /// Converts to a Map for marking as converted.
  Map<String, dynamic> toConvertedMap(String saleId) {
    return {
      'isConverted': true,
      'convertedToSaleId': saleId,
      'convertedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  DraftEntity toEntity() {
    return DraftEntity(
      id: id,
      name: name,
      items: items.map((item) => item.toEntity()).toList(),
      laborLines: laborLines.map((l) => l.toEntity()).toList(),
      feeLines: feeLines.map((f) => f.toEntity()).toList(),
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      motorcycleModel: motorcycleModel,
      discountType: discountType,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      isConverted: isConverted,
      convertedToSaleId: convertedToSaleId,
      convertedAt: convertedAt,
      notes: notes,
    );
  }

  /// Creates from domain entity.
  factory DraftModel.fromEntity(DraftEntity entity) {
    return DraftModel(
      id: entity.id,
      name: entity.name,
      items:
          entity.items.map((item) => SaleItemModel.fromEntity(item)).toList(),
      laborLines: entity.laborLines
          .map((l) => LaborLineModel.fromEntity(l))
          .toList(),
      feeLines:
          entity.feeLines.map((f) => FeeLineModel.fromEntity(f)).toList(),
      mechanicId: entity.mechanicId,
      mechanicName: entity.mechanicName,
      motorcycleModel: entity.motorcycleModel,
      discountType: entity.discountType,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      updatedBy: entity.updatedBy,
      isConverted: entity.isConverted,
      convertedToSaleId: entity.convertedToSaleId,
      convertedAt: entity.convertedAt,
      notes: entity.notes,
    );
  }

  // ==================== FACTORY METHODS ====================

  /// Creates an empty draft model.
  factory DraftModel.empty() {
    return DraftModel(
      id: '',
      name: '',
      items: [],
      createdBy: '',
      createdByName: '',
      createdAt: DateTime.now(),
    );
  }

  /// Creates a new draft with default values.
  factory DraftModel.create({
    required String name,
    required List<SaleItemModel> items,
    List<LaborLineModel> laborLines = const [],
    List<FeeLineModel> feeLines = const [],
    String? mechanicId,
    String? mechanicName,
    DiscountType discountType = DiscountType.amount,
    required String createdBy,
    required String createdByName,
    String? notes,
  }) {
    return DraftModel(
      id: '', // Will be set by Firestore
      name: name,
      items: items,
      laborLines: laborLines,
      feeLines: feeLines,
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      discountType: discountType,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  // ==================== COMPUTED PROPERTIES ====================

  /// Whether discount type is percentage
  bool get isPercentageDiscount => discountType == DiscountType.percentage;

  /// Subtotal before discounts
  double get subtotal {
    return items.fold(
      0.0,
      (acc, item) => acc + (item.unitPrice * item.quantity),
    );
  }

  /// Total discount amount
  double get totalDiscount {
    return items.fold(0.0, (acc, item) {
      final entity = item.toEntity();
      return acc +
          entity.calculateDiscountAmount(isPercentage: isPercentageDiscount);
    });
  }

  /// Labor subtotal (sum of labor fees; never discounted)
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Fees total (sum of shop-fee amounts; never discounted)
  double get feesTotal => feeLines.fold(0.0, (s, f) => s + f.amount);

  /// Grand total: net parts (after discount) + labor + fees
  double get grandTotal =>
      (subtotal - totalDiscount) + laborSubtotal + feesTotal;

  /// Total item count
  int get totalItemCount => items.fold(0, (acc, item) => acc + item.quantity);

  // ==================== COPY WITH ====================

  DraftModel copyWith({
    String? id,
    String? name,
    List<SaleItemModel>? items,
    List<LaborLineModel>? laborLines,
    List<FeeLineModel>? feeLines,
    String? mechanicId,
    String? mechanicName,
    String? motorcycleModel,
    DiscountType? discountType,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isConverted,
    String? convertedToSaleId,
    DateTime? convertedAt,
    String? notes,
    bool clearMechanic = false,
  }) {
    return DraftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      feeLines: feeLines ?? this.feeLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName:
          clearMechanic ? null : (mechanicName ?? this.mechanicName),
      motorcycleModel: motorcycleModel ?? this.motorcycleModel,
      discountType: discountType ?? this.discountType,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isConverted: isConverted ?? this.isConverted,
      convertedToSaleId: convertedToSaleId ?? this.convertedToSaleId,
      convertedAt: convertedAt ?? this.convertedAt,
      notes: notes ?? this.notes,
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

  @override
  String toString() {
    return 'DraftModel(id: $id, name: $name, items: ${items.length}, total: $grandTotal)';
  }
}
