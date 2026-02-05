import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single entry in a product's price/cost history.
///
/// Recorded whenever price or cost changes during:
/// - Product creation
/// - Product editing
/// - Receiving with different cost (creates variation)
class PriceHistoryModel {
  final String id;
  final double price;
  final double cost;
  final DateTime changedAt;
  final String changedBy;
  final String? reason;
  final String? note;

  const PriceHistoryModel({
    required this.id,
    required this.price,
    required this.cost,
    required this.changedAt,
    required this.changedBy,
    this.reason,
    this.note,
  });

  /// Creates from Firestore document.
  factory PriceHistoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PriceHistoryModel.fromMap(data, doc.id);
  }

  /// Creates from a Map.
  factory PriceHistoryModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return PriceHistoryModel(
      id: documentId,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      changedAt: _parseTimestamp(map['changedAt']) ?? DateTime.now(),
      changedBy: map['changedBy'] as String? ?? '',
      reason: map['reason'] as String?,
      note: map['note'] as String?,
    );
  }

  /// Converts to a Map for Firestore.
  Map<String, dynamic> toMap({bool forCreate = false}) {
    return {
      'price': price,
      'cost': cost,
      'changedAt': forCreate
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(changedAt),
      'changedBy': changedBy,
      'reason': reason,
      'note': note,
    };
  }

  /// Helper to parse Firestore timestamps.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Creates a new history entry for a price/cost change.
  factory PriceHistoryModel.create({
    required double price,
    required double cost,
    required String changedBy,
    String? reason,
    String? note,
  }) {
    return PriceHistoryModel(
      id: '', // Will be set by Firestore
      price: price,
      cost: cost,
      changedAt: DateTime.now(),
      changedBy: changedBy,
      reason: reason,
      note: note,
    );
  }

  @override
  String toString() {
    return 'PriceHistoryModel(id: $id, price: $price, cost: $cost, changedAt: $changedAt)';
  }
}

/// Reasons for price/cost changes.
abstract class PriceChangeReason {
  static const String initial = 'Initial price';
  static const String priceUpdate = 'Price update';
  static const String costUpdate = 'Cost update';
  static const String receiving = 'Stock receiving';
  static const String promotion = 'Promotion';
  static const String supplierChange = 'Supplier change';
  static const String marketAdjustment = 'Market adjustment';
  static const String correction = 'Correction';
}
