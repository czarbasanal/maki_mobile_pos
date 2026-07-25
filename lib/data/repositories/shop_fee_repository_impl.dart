import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_fee_repository.dart';

/// Firestore implementation of [ShopFeeRepository], bound to the single
/// `shop_fees` collection.
class ShopFeeRepositoryImpl implements ShopFeeRepository {
  final FirebaseFirestore _firestore;

  ShopFeeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.shopFees);

  @override
  Stream<List<ShopFeeEntity>> watchActive() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_snapshotToSorted);
  }

  @override
  Stream<List<ShopFeeEntity>> watchAll() {
    return _ref.snapshots().map(_snapshotToSorted);
  }

  @override
  Future<ShopFeeEntity?> getShopFeeById(String shopFeeId) async {
    try {
      final doc = await _ref.doc(shopFeeId).get();
      if (!doc.exists) return null;
      return ShopFeeModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get shop fee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ShopFeeEntity> createShopFee({
    required ShopFeeEntity shopFee,
    required String createdBy,
  }) async {
    try {
      if (await nameExists(name: shopFee.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: shopFee.name,
          message: 'A shop fee with this name already exists',
        );
      }

      final model = ShopFeeModel.fromEntity(shopFee);
      final docRef = await _ref.add(model.toCreateMap(createdBy));
      return shopFee.copyWith(id: docRef.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create shop fee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ShopFeeEntity> updateShopFee({
    required ShopFeeEntity shopFee,
    required String updatedBy,
  }) async {
    try {
      if (await nameExists(
        name: shopFee.name,
        excludeShopFeeId: shopFee.id,
      )) {
        throw DuplicateEntryException(
          field: 'name',
          value: shopFee.name,
          message: 'A shop fee with this name already exists',
        );
      }

      final model = ShopFeeModel.fromEntity(shopFee);
      await _ref.doc(shopFee.id).update(model.toUpdateMap(updatedBy));

      final updated = await getShopFeeById(shopFee.id);
      if (updated == null) {
        throw const DatabaseException(
          message: 'Shop fee not found after update',
        );
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update shop fee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setActive({
    required String shopFeeId,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(shopFeeId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to ${active ? 'activate' : 'deactivate'} shop fee: '
            '${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> nameExists({
    required String name,
    String? excludeShopFeeId,
  }) async {
    try {
      // Firestore has no case-insensitive query operator; the catalog is
      // small (mirrors mechanics' client-side sort), so fetch and compare
      // client-side instead of maintaining a normalized-name field.
      final normalized = name.toLowerCase();
      final snapshot = await _ref.get();
      final matches = snapshot.docs.where(
        (doc) => (doc.data()['name'] as String? ?? '').toLowerCase() ==
            normalized,
      );
      if (excludeShopFeeId == null) {
        return matches.isNotEmpty;
      }
      return matches.any((doc) => doc.id != excludeShopFeeId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check shop fee name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // Sort client-side A→Z (case-insensitive). Avoids a Firestore index and the
  // dataset is small.
  List<ShopFeeEntity> _snapshotToSorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => ShopFeeModel.fromFirestore(doc).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
