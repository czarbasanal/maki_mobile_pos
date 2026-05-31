import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for Sale with Firestore serialization.
///
/// This model handles:
/// - JSON/Map serialization for Firestore
/// - Conversion to/from domain entity
/// - Sale number generation
/// - Timestamp handling
class SaleModel {
  final String id;
  final String saleNumber;
  final List<SaleItemModel> items;
  final List<LaborLineModel> laborLines;
  final String? mechanicId;
  final String? mechanicName;
  final DiscountType discountType;
  final PaymentMethod paymentMethod;
  final Map<PaymentMethod, double> tenders;
  final double amountReceived;
  final double changeGiven;
  final SaleStatus status;
  final String cashierId;
  final String cashierName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? draftId;
  final String? notes;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidedByName;
  final String? voidReason;

  const SaleModel({
    required this.id,
    required this.saleNumber,
    required this.items,
    this.laborLines = const [],
    this.mechanicId,
    this.mechanicName,
    this.discountType = DiscountType.amount,
    required this.paymentMethod,
    this.tenders = const {},
    required this.amountReceived,
    required this.changeGiven,
    this.status = SaleStatus.completed,
    required this.cashierId,
    required this.cashierName,
    required this.createdAt,
    this.updatedAt,
    this.draftId,
    this.notes,
    this.voidedAt,
    this.voidedBy,
    this.voidedByName,
    this.voidReason,
  });

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Creates from a Map (Firestore data).
  /// Note: Items are loaded separately from subcollection
  factory SaleModel.fromMap(
    Map<String, dynamic> map,
    String documentId, {
    List<SaleItemModel>? items,
  }) {
    // Labor lines are stored INLINE on the sale doc (unlike items, which live
    // in the subcollection). Parse them directly off the map. Legacy -> [].
    final laborList = <LaborLineModel>[];
    final laborData = map['laborLines'] as List<dynamic>? ?? [];
    for (int i = 0; i < laborData.length; i++) {
      final laborMap = laborData[i] as Map<String, dynamic>;
      final laborId = laborMap['id'] as String? ?? 'labor-$i';
      laborList.add(LaborLineModel.fromMap(laborMap, laborId));
    }

    return SaleModel(
      id: documentId,
      saleNumber: map['saleNumber'] as String? ?? '',
      items: items ?? [],
      laborLines: laborList,
      mechanicId: map['mechanicId'] as String?,
      mechanicName: map['mechanicName'] as String?,
      discountType: DiscountType.fromString(map['discountType'] as String?),
      paymentMethod: PaymentMethod.fromString(map['paymentMethod'] as String?),
      tenders: _parseTenders(map['tenders']),
      amountReceived: (map['amountReceived'] as num?)?.toDouble() ?? 0.0,
      changeGiven: (map['changeGiven'] as num?)?.toDouble() ?? 0.0,
      status: SaleStatus.fromString(map['status'] as String?),
      cashierId: map['cashierId'] as String? ?? '',
      cashierName: map['cashierName'] as String? ?? '',
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      draftId: map['draftId'] as String?,
      notes: map['notes'] as String?,
      voidedAt: _parseTimestamp(map['voidedAt']),
      voidedBy: map['voidedBy'] as String?,
      voidedByName: map['voidedByName'] as String?,
      voidReason: map['voidReason'] as String?,
    );
  }

  /// Creates from Firestore document.
  factory SaleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<SaleItemModel>? items,
  }) {
    return SaleModel.fromMap(doc.data()!, doc.id, items: items);
  }

  /// Converts to a Map for Firestore.
  /// Note: Items are stored in a subcollection, not in this map
  Map<String, dynamic> toMap({
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'saleNumber': saleNumber,
      'laborLines':
          laborLines.map((l) => l.toMap(includeId: true)).toList(),
      'mechanicId': mechanicId,
      'mechanicName': mechanicName,
      'discountType': discountType.value,
      'paymentMethod': paymentMethod.value,
      'amountReceived': amountReceived,
      'changeGiven': changeGiven,
      'status': status.value,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'draftId': draftId,
      'notes': notes,
      'voidedBy': voidedBy,
      'voidedByName': voidedByName,
      'voidReason': voidReason,
    };

    if (tenders.isNotEmpty) {
      map['tenders'] = {
        for (final e in tenders.entries) e.key.value: e.value,
      };
    }

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

    // Handle void timestamp
    if (voidedAt != null) {
      map['voidedAt'] = Timestamp.fromDate(voidedAt!);
    } else if (forUpdate && status == SaleStatus.voided) {
      map['voidedAt'] = FieldValue.serverTimestamp();
    }

    return map;
  }

  /// Converts to a Map for creating a new sale.
  Map<String, dynamic> toCreateMap() {
    return toMap(forCreate: true);
  }

  /// Converts to a Map for voiding a sale.
  Map<String, dynamic> toVoidMap({
    required String voidedById,
    required String voidedByUserName,
    required String reason,
  }) {
    return {
      'status': SaleStatus.voided.value,
      'updatedAt': FieldValue.serverTimestamp(),
      'voidedAt': FieldValue.serverTimestamp(),
      'voidedBy': voidedById,
      'voidedByName': voidedByUserName,
      'voidReason': reason,
    };
  }

  // ==================== ENTITY CONVERSION ====================

  /// Converts to domain entity.
  SaleEntity toEntity() {
    return SaleEntity(
      id: id,
      saleNumber: saleNumber,
      items: items.map((item) => item.toEntity()).toList(),
      laborLines: laborLines.map((l) => l.toEntity()).toList(),
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      discountType: discountType,
      paymentMethod: paymentMethod,
      tenders: tenders,
      amountReceived: amountReceived,
      changeGiven: changeGiven,
      status: status,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      draftId: draftId,
      notes: notes,
      voidedAt: voidedAt,
      voidedBy: voidedBy,
      voidedByName: voidedByName,
      voidReason: voidReason,
    );
  }

  /// Creates from domain entity.
  factory SaleModel.fromEntity(SaleEntity entity) {
    return SaleModel(
      id: entity.id,
      saleNumber: entity.saleNumber,
      items:
          entity.items.map((item) => SaleItemModel.fromEntity(item)).toList(),
      laborLines: entity.laborLines
          .map((l) => LaborLineModel.fromEntity(l))
          .toList(),
      mechanicId: entity.mechanicId,
      mechanicName: entity.mechanicName,
      discountType: entity.discountType,
      paymentMethod: entity.paymentMethod,
      tenders: entity.tenders,
      amountReceived: entity.amountReceived,
      changeGiven: entity.changeGiven,
      status: entity.status,
      cashierId: entity.cashierId,
      cashierName: entity.cashierName,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      draftId: entity.draftId,
      notes: entity.notes,
      voidedAt: entity.voidedAt,
      voidedBy: entity.voidedBy,
      voidedByName: entity.voidedByName,
      voidReason: entity.voidReason,
    );
  }

  // ==================== FACTORY METHODS ====================

  /// Creates an empty sale model.
  factory SaleModel.empty() {
    return SaleModel(
      id: '',
      saleNumber: '',
      items: [],
      paymentMethod: PaymentMethod.cash,
      amountReceived: 0,
      changeGiven: 0,
      cashierId: '',
      cashierName: '',
      createdAt: DateTime.now(),
    );
  }

  /// Creates a new sale with default values.
  factory SaleModel.create({
    required String saleNumber,
    required List<SaleItemModel> items,
    List<LaborLineModel> laborLines = const [],
    String? mechanicId,
    String? mechanicName,
    DiscountType discountType = DiscountType.amount,
    required PaymentMethod paymentMethod,
    Map<PaymentMethod, double> tenders = const {},
    required double amountReceived,
    required double changeGiven,
    required String cashierId,
    required String cashierName,
    String? draftId,
    String? notes,
  }) {
    return SaleModel(
      id: '', // Will be set by Firestore
      saleNumber: saleNumber,
      items: items,
      laborLines: laborLines,
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      discountType: discountType,
      paymentMethod: paymentMethod,
      tenders: tenders,
      amountReceived: amountReceived,
      changeGiven: changeGiven,
      status: SaleStatus.completed,
      cashierId: cashierId,
      cashierName: cashierName,
      createdAt: DateTime.now(),
      draftId: draftId,
      notes: notes,
    );
  }

  /// Generates a sale number based on current date and sequence.
  ///
  /// Format: SALE-YYYYMMDD-NNN
  /// Example: SALE-20250205-001
  static String generateSaleNumber(DateTime date, int sequenceNumber) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final seqStr = sequenceNumber.toString().padLeft(3, '0');
    return 'SALE-$dateStr-$seqStr';
  }

  // ==================== COMPUTED PROPERTIES ====================

  /// Whether discount type is percentage
  bool get isPercentageDiscount => discountType == DiscountType.percentage;

  /// Subtotal before discounts
  double get subtotal {
    return items.fold(
      0.0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );
  }

  /// Total discount amount
  double get totalDiscount {
    return items.fold(0.0, (sum, item) {
      final entity = item.toEntity();
      return sum +
          entity.calculateDiscountAmount(isPercentage: isPercentageDiscount);
    });
  }

  /// Labor subtotal (sum of labor fees; never discounted)
  double get laborSubtotal => laborLines.fold(0.0, (s, l) => s + l.fee);

  /// Grand total: net parts (after discount) + labor
  double get grandTotal => (subtotal - totalDiscount) + laborSubtotal;

  // ==================== COPY WITH ====================

  SaleModel copyWith({
    String? id,
    String? saleNumber,
    List<SaleItemModel>? items,
    List<LaborLineModel>? laborLines,
    String? mechanicId,
    String? mechanicName,
    bool clearMechanic = false,
    DiscountType? discountType,
    PaymentMethod? paymentMethod,
    Map<PaymentMethod, double>? tenders,
    double? amountReceived,
    double? changeGiven,
    SaleStatus? status,
    String? cashierId,
    String? cashierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? draftId,
    String? notes,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidedByName,
    String? voidReason,
  }) {
    return SaleModel(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      items: items ?? this.items,
      laborLines: laborLines ?? this.laborLines,
      mechanicId: clearMechanic ? null : (mechanicId ?? this.mechanicId),
      mechanicName:
          clearMechanic ? null : (mechanicName ?? this.mechanicName),
      discountType: discountType ?? this.discountType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenders: tenders ?? this.tenders,
      amountReceived: amountReceived ?? this.amountReceived,
      changeGiven: changeGiven ?? this.changeGiven,
      status: status ?? this.status,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      draftId: draftId ?? this.draftId,
      notes: notes ?? this.notes,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      voidedByName: voidedByName ?? this.voidedByName,
      voidReason: voidReason ?? this.voidReason,
    );
  }

  // ==================== HELPER METHODS ====================

  /// Parses a Firestore `tenders` map ({ '<method>': amount }) into a typed
  /// map. Returns an empty map when absent (legacy sales).
  static Map<PaymentMethod, double> _parseTenders(dynamic value) {
    if (value is! Map) return const {};
    final result = <PaymentMethod, double>{};
    value.forEach((key, amount) {
      if (key is String && amount is num) {
        result[PaymentMethod.fromString(key)] = amount.toDouble();
      }
    });
    return result;
  }

  /// Parses a Firestore timestamp or ISO string to DateTime.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  String toString() {
    return 'SaleModel(id: $id, saleNumber: $saleNumber, total: $grandTotal, status: ${status.displayName})';
  }
}
