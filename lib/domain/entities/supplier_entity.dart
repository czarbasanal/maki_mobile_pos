import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// Domain entity representing a supplier.
class SupplierEntity extends Equatable {
  /// Unique identifier.
  final String id;

  /// Supplier name.
  final String name;

  /// Address.
  final String? address;

  /// Contact person name.
  final String? contactPerson;

  /// Primary contact number.
  final String? contactNumber;

  /// Alternative contact number.
  final String? alternativeNumber;

  /// Email address.
  final String? email;

  /// Transaction type (cash, credit, consignment).
  final TransactionType transactionType;

  /// Whether supplier is active.
  final bool isActive;

  /// Notes about the supplier.
  final String? notes;

  /// When the supplier was created.
  final DateTime createdAt;

  /// When the supplier was last updated.
  final DateTime? updatedAt;

  /// Who created this supplier.
  final String? createdBy;

  /// Who last updated this supplier.
  final String? updatedBy;

  /// Number of products from this supplier.
  final int productCount;

  /// Total inventory value from this supplier.
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

  /// Whether this supplier has contact information.
  bool get hasContactInfo =>
      (contactNumber != null && contactNumber!.isNotEmpty) ||
      (email != null && email!.isNotEmpty);

  /// Whether this supplier has an address.
  bool get hasAddress => address != null && address!.isNotEmpty;

  /// Display string for contact info.
  String get displayContact {
    if (contactNumber != null && contactNumber!.isNotEmpty) {
      return contactNumber!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!;
    }
    return 'No contact';
  }

  /// Whether this supplier has payment terms (not cash or N/A).
  bool get hasPaymentTerms =>
      transactionType != TransactionType.cash &&
      transactionType != TransactionType.notApplicable;

  /// Number of days for payment terms.
  int? get paymentTermDays => transactionType.daysUntilDue;

  /// Formatted display string for payment terms.
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

  /// Primary contact display string (prefers person name, then number, then email).
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
    return '';
  }

  /// Formatted contact numbers (combines primary and alternative).
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

  /// Creates an empty supplier entity.
  factory SupplierEntity.empty() {
    return SupplierEntity(
      id: '',
      name: '',
      transactionType: TransactionType.cash,
      isActive: true,
      createdAt: DateTime.now(),
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
}
