import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('SupplierEntity', () {
    late SupplierEntity supplier;

    setUp(() {
      supplier = SupplierEntity(
        id: 'supplier-001',
        name: 'ABC Distributors',
        address: '123 Main Street, Manila',
        contactPerson: 'Juan Dela Cruz',
        contactNumber: '+639171234567',
        alternativeNumber: '+639181234567',
        email: 'juan@abcdist.com',
        transactionType: TransactionType.terms30d,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
      );
    });

    test('should create a valid supplier entity', () {
      expect(supplier.id, 'supplier-001');
      expect(supplier.name, 'ABC Distributors');
      expect(supplier.transactionType, TransactionType.terms30d);
      expect(supplier.isActive, true);
    });

    test('hasPaymentTerms should return correct value', () {
      expect(supplier.hasPaymentTerms, true);

      final cashSupplier = supplier.copyWith(
        transactionType: TransactionType.cash,
      );
      expect(cashSupplier.hasPaymentTerms, false);

      final naSupplier = supplier.copyWith(
        transactionType: TransactionType.notApplicable,
      );
      expect(naSupplier.hasPaymentTerms, false);
    });

    test('paymentTermDays should return correct days', () {
      // paymentTermDays returns int? from transactionType.daysUntilDue
      expect(supplier.paymentTermDays, 30);

      final terms45 = supplier.copyWith(
        transactionType: TransactionType.terms45d,
      );
      expect(terms45.paymentTermDays, 45);

      final terms60 = supplier.copyWith(
        transactionType: TransactionType.terms60d,
      );
      expect(terms60.paymentTermDays, 60);

      final terms90 = supplier.copyWith(
        transactionType: TransactionType.terms90d,
      );
      expect(terms90.paymentTermDays, 90);

      final cash = supplier.copyWith(
        transactionType: TransactionType.cash,
      );
      expect(cash.paymentTermDays, 0);

      final na = supplier.copyWith(
        transactionType: TransactionType.notApplicable,
      );
      expect(na.paymentTermDays, isNull);
    });

    test('paymentTermsDisplay should return formatted string', () {
      expect(supplier.paymentTermsDisplay, 'Net 30 Days');

      final cashSupplier = supplier.copyWith(
        transactionType: TransactionType.cash,
      );
      expect(cashSupplier.paymentTermsDisplay, 'Cash on Delivery');

      final naSupplier = supplier.copyWith(
        transactionType: TransactionType.notApplicable,
      );
      expect(naSupplier.paymentTermsDisplay, 'Not Applicable');
    });

    test('hasContactInfo should return correct value', () {
      expect(supplier.hasContactInfo, true);

      final noContact = SupplierEntity(
        id: 'test',
        name: 'Test',
        transactionType: TransactionType.cash,
        isActive: true,
        createdAt: DateTime.now(),
      );
      expect(noContact.hasContactInfo, false);
    });

    test('primaryContact should return best available contact', () {
      expect(supplier.primaryContact, 'Juan Dela Cruz');

      // Use clearContactPerson to set it to null
      final noPersonContact = supplier.copyWith(clearContactPerson: true);
      expect(noPersonContact.primaryContact, '+639171234567');

      final emailOnly = SupplierEntity(
        id: 'test',
        name: 'Test',
        email: 'test@example.com',
        transactionType: TransactionType.cash,
        isActive: true,
        createdAt: DateTime.now(),
      );
      expect(emailOnly.primaryContact, 'test@example.com');

      final noAnyContact = SupplierEntity(
        id: 'test',
        name: 'Test',
        transactionType: TransactionType.cash,
        isActive: true,
        createdAt: DateTime.now(),
      );
      expect(noAnyContact.primaryContact, '');
    });

    test('formattedContactNumbers should combine numbers', () {
      expect(supplier.formattedContactNumbers, '+639171234567 / +639181234567');

      // Use clearAlternativeNumber to set it to null
      final singleNumber = supplier.copyWith(clearAlternativeNumber: true);
      expect(singleNumber.formattedContactNumbers, '+639171234567');

      // Test with no numbers
      final noNumbers = SupplierEntity(
        id: 'test',
        name: 'Test',
        transactionType: TransactionType.cash,
        isActive: true,
        createdAt: DateTime.now(),
      );
      expect(noNumbers.formattedContactNumbers, '');
    });

    test('hasAddress should return correct value', () {
      expect(supplier.hasAddress, true);

      final noAddress = supplier.copyWith(clearAddress: true);
      expect(noAddress.hasAddress, false);
    });

    test('displayContact should return best available contact info', () {
      expect(supplier.displayContact, '+639171234567');

      final emailOnlyContact = supplier.copyWith(clearContactNumber: true);
      expect(emailOnlyContact.displayContact, 'juan@abcdist.com');

      final noContact = SupplierEntity(
        id: 'test',
        name: 'Test',
        transactionType: TransactionType.cash,
        isActive: true,
        createdAt: DateTime.now(),
      );
      expect(noContact.displayContact, 'No contact');
    });

    test('copyWith should create new instance with updated values', () {
      final updated = supplier.copyWith(
        name: 'XYZ Distributors',
        transactionType: TransactionType.terms60d,
      );

      expect(updated.id, supplier.id);
      expect(updated.name, 'XYZ Distributors');
      expect(updated.transactionType, TransactionType.terms60d);
      expect(updated.contactPerson, supplier.contactPerson);
    });

    test('copyWith with clear flags should set fields to null', () {
      final cleared = supplier.copyWith(
        clearAddress: true,
        clearContactPerson: true,
        clearAlternativeNumber: true,
      );

      expect(cleared.address, isNull);
      expect(cleared.contactPerson, isNull);
      expect(cleared.alternativeNumber, isNull);
      // These should remain unchanged
      expect(cleared.contactNumber, supplier.contactNumber);
      expect(cleared.email, supplier.email);
    });

    test('productCount and totalInventoryValue should have default values', () {
      expect(supplier.productCount, 0);
      expect(supplier.totalInventoryValue, 0);

      final withValues = supplier.copyWith(
        productCount: 10,
        totalInventoryValue: 5000.0,
      );
      expect(withValues.productCount, 10);
      expect(withValues.totalInventoryValue, 5000.0);
    });
  });

  group('SupplierModel', () {
    late SupplierModel model;

    setUp(() {
      model = SupplierModel.create(
        name: 'Test Supplier',
        address: '456 Test Street',
        contactPerson: 'Test Person',
        contactNumber: '+639991234567',
        email: 'test@supplier.com',
        transactionType: TransactionType.terms45d,
      );
    });

    test('should create supplier with correct values', () {
      expect(model.name, 'Test Supplier');
      expect(model.transactionType, TransactionType.terms45d);
      expect(model.isActive, true);
      expect(model.searchKeywords, isNotEmpty);
    });

    test('toEntity should convert to SupplierEntity', () {
      final entity = model.toEntity();

      expect(entity, isA<SupplierEntity>());
      expect(entity.name, model.name);
      expect(entity.transactionType, model.transactionType);
      expect(entity.contactPerson, model.contactPerson);
    });

    test('fromEntity should convert from SupplierEntity', () {
      final entity = model.toEntity();
      final fromEntity = SupplierModel.fromEntity(entity);

      expect(fromEntity.name, entity.name);
      expect(fromEntity.transactionType, entity.transactionType);
      expect(fromEntity.searchKeywords, isNotEmpty);
    });

    test('toMap should serialize correctly', () {
      final map = model.toMap();

      expect(map['name'], 'Test Supplier');
      expect(map['transactionType'], 'terms_45d');
      expect(map['isActive'], true);
      expect(map['contactPerson'], 'Test Person');
      expect(map['searchKeywords'], isNotEmpty);
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'name': 'Map Supplier',
        'address': '789 Map Street',
        'contactPerson': 'Map Person',
        'contactNumber': '+639881234567',
        'email': 'map@supplier.com',
        'transactionType': 'terms_60d',
        'isActive': true,
        'notes': 'Test notes',
        'productCount': 5,
        'totalInventoryValue': 1000.0,
        'searchKeywords': ['map', 'supplier'],
      };

      final fromMap = SupplierModel.fromMap(map, 'map-id');

      expect(fromMap.id, 'map-id');
      expect(fromMap.name, 'Map Supplier');
      expect(fromMap.transactionType, TransactionType.terms60d);
      expect(fromMap.notes, 'Test notes');
      expect(fromMap.productCount, 5);
      expect(fromMap.totalInventoryValue, 1000.0);
    });

    test('fromMap should handle missing optional fields', () {
      final minimalMap = {
        'name': 'Minimal Supplier',
      };

      final fromMap = SupplierModel.fromMap(minimalMap, 'minimal-id');

      expect(fromMap.id, 'minimal-id');
      expect(fromMap.name, 'Minimal Supplier');
      expect(fromMap.transactionType, TransactionType.notApplicable);
      expect(fromMap.isActive, true);
      expect(fromMap.address, isNull);
      expect(fromMap.contactPerson, isNull);
      expect(fromMap.productCount, 0);
      expect(fromMap.totalInventoryValue, 0);
    });

    test('empty factory should create empty model', () {
      final empty = SupplierModel.empty();

      expect(empty.id, '');
      expect(empty.name, '');
      expect(empty.transactionType, TransactionType.cash);
      expect(empty.isActive, true);
    });

    test('searchKeywords should contain name parts', () {
      expect(model.searchKeywords.any((k) => k.contains('test')), true);
      expect(model.searchKeywords.any((k) => k.contains('supp')), true);
    });

    test('toCreateMap should include createdBy and generate keywords', () {
      final createMap = model.toCreateMap('user-123');

      expect(createMap['createdBy'], 'user-123');
      expect(createMap['searchKeywords'], isNotEmpty);
    });

    test('toUpdateMap should include updatedBy', () {
      final updateMap = model.toUpdateMap('user-456');

      expect(updateMap['updatedBy'], 'user-456');
    });

    test('copyWith should create new instance with updated values', () {
      final updated = model.copyWith(
        name: 'Updated Supplier',
        transactionType: TransactionType.terms90d,
      );

      expect(updated.name, 'Updated Supplier');
      expect(updated.transactionType, TransactionType.terms90d);
      expect(updated.contactPerson, model.contactPerson);
    });
  });

  group('TransactionType', () {
    test('fromString should parse correctly', () {
      expect(TransactionType.fromString('cash'), TransactionType.cash);
      expect(TransactionType.fromString('terms_30d'), TransactionType.terms30d);
      expect(TransactionType.fromString('terms_45d'), TransactionType.terms45d);
      expect(TransactionType.fromString('terms_60d'), TransactionType.terms60d);
      expect(TransactionType.fromString('terms_90d'), TransactionType.terms90d);
      expect(TransactionType.fromString('na'), TransactionType.notApplicable);
    });

    test('fromString should return notApplicable for invalid values', () {
      expect(
          TransactionType.fromString('invalid'), TransactionType.notApplicable);
      expect(TransactionType.fromString(null), TransactionType.notApplicable);
      expect(TransactionType.fromString(''), TransactionType.notApplicable);
    });

    test('daysUntilDue should return correct values', () {
      expect(TransactionType.cash.daysUntilDue, 0);
      expect(TransactionType.terms30d.daysUntilDue, 30);
      expect(TransactionType.terms45d.daysUntilDue, 45);
      expect(TransactionType.terms60d.daysUntilDue, 60);
      expect(TransactionType.terms90d.daysUntilDue, 90);
      expect(TransactionType.notApplicable.daysUntilDue, isNull);
    });

    test('displayName should return readable names', () {
      expect(TransactionType.cash.displayName, 'Cash');
      expect(TransactionType.terms30d.displayName, '30 Days');
      expect(TransactionType.terms45d.displayName, '45 Days');
      expect(TransactionType.terms60d.displayName, '60 Days');
      expect(TransactionType.terms90d.displayName, '90 Days');
      expect(TransactionType.notApplicable.displayName, 'N/A');
    });

    test('value should return correct Firestore values', () {
      expect(TransactionType.cash.value, 'cash');
      expect(TransactionType.terms30d.value, 'terms_30d');
      expect(TransactionType.terms45d.value, 'terms_45d');
      expect(TransactionType.terms60d.value, 'terms_60d');
      expect(TransactionType.terms90d.value, 'terms_90d');
      expect(TransactionType.notApplicable.value, 'na');
    });
  });
}
