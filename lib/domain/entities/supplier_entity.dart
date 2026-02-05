import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// Represents a supplier/vendor in the system.
///
/// Suppliers are the vendors from whom products are purchased.
/// Each supplier can have different payment terms and contact information.
class SupplierEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Supplier/company name
  final String name;

  /// Business address
  final String? address;

  /// Name of the contact person
  final String? contactPerson;

  /// Contact phone number
  final String? contactNumber;

  /// Alternative contact number
  final String? alternativeNumber;

  /// Email address
  final String? email;

  /// Payment terms (cash, 30 days, 45 days, etc.)
  final TransactionType transactionType;

  /// Whether this supplier is active
  final bool isActive;

  /// Optional notes about the supplier
  final String? notes;

  /// When supplier was created
  final DateTime createdAt;

  /// When supplier was last updated
  final DateTime? updatedAt;

  /// Who created this supplier
  final String? createdBy;

  /// Who last updated this supplier
  final String? updatedBy;

  /// Total number of products from this supplier
  final int productCount;

  /// Total value of inventory from this supplier (at cost)
  final double totalInventoryValue;

  const SupplierEntity({
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
  });

  // ==================== COMPUTED PROPERTIES ====================

  /// Returns true if supplier has payment terms (not cash or N/A).
  bool get hasPaymentTerms {
    return transactionType != TransactionType.cash &&
        transactionType != TransactionType.notApplicable;
  }

  /// Returns the number of days for payment terms.
  int? get paymentTermDays => transactionType.daysUntilDue;

  /// Returns a formatted display string for payment terms.
  String get paymentTermsDisplay {
    switch (transactionType) {
      case TransactionType.cash:
        return 'Cash on Delivery';
      case TransactionType.terms30d:
        return 'Net 30 Days';
      case TransactionType.terms45d:
        return 'Net 45 Days';
      case TransactionType.terms60d:
        return 'Net 60 Days';
      case TransactionType.terms90d:
        return 'Net 90 Days';
      case TransactionType.notApplicable:
        return 'Not Applicable';
    }
  }

  /// Returns true if supplier has contact information.
  bool get hasContactInfo {
    return (contactPerson != null && contactPerson!.isNotEmpty) ||
        (contactNumber != null && contactNumber!.isNotEmpty) ||
        (email != null && email!.isNotEmpty);
  }

  /// Returns the primary contact display string.
  String get primaryContact {
    if (contactPerson != null && contactPerson!.isNotEmpty) {
      return contactPerson!;
    }
    if (contactNumber != null && contactNumber!.isNotEmpty) {
      return contactNumber!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!;
    }
    return 'No contact info';
  }

  /// Returns formatted contact number(s).
  String get formattedContactNumbers {
    final numbers = <String>[];
    if (contactNumber != null && contactNumber!.isNotEmpty) {
      numbers.add(contactNumber!);
    }
    if (alternativeNumber != null && alternativeNumber!.isNotEmpty) {
      numbers.add(alternativeNumber!);
    }
    return numbers.join(' / ');
  }

  // ==================== COPY WITH ====================

  /// Creates a copy with updated values.
  ///
  /// To explicitly set a nullable field to null, use the corresponding
  /// `clear*` parameter set to true.
  SupplierEntity copyWith({
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
    // Clear flags for nullable fields
    bool clearAddress = false,
    bool clearContactPerson = false,
    bool clearContactNumber = false,
    bool clearAlternativeNumber = false,
    bool clearEmail = false,
    bool clearNotes = false,
    bool clearUpdatedAt = false,
    bool clearCreatedBy = false,
    bool clearUpdatedBy = false,
  }) {
    return SupplierEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      address: clearAddress ? null : (address ?? this.address),
      contactPerson:
          clearContactPerson ? null : (contactPerson ?? this.contactPerson),
      contactNumber:
          clearContactNumber ? null : (contactNumber ?? this.contactNumber),
      alternativeNumber: clearAlternativeNumber
          ? null
          : (alternativeNumber ?? this.alternativeNumber),
      email: clearEmail ? null : (email ?? this.email),
      transactionType: transactionType ?? this.transactionType,
      isActive: isActive ?? this.isActive,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      createdBy: clearCreatedBy ? null : (createdBy ?? this.createdBy),
      updatedBy: clearUpdatedBy ? null : (updatedBy ?? this.updatedBy),
      productCount: productCount ?? this.productCount,
      totalInventoryValue: totalInventoryValue ?? this.totalInventoryValue,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        contactPerson,
        contactNumber,
        alternativeNumber,
        email,
        transactionType,
        isActive,
        notes,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
        productCount,
        totalInventoryValue,
      ];

  @override
  String toString() {
    return 'SupplierEntity(id: $id, name: $name, transactionType: ${transactionType.value})';
  }
}
