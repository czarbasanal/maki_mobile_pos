import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:maki_mobile_pos/services/firebase_service.dart';

/// Thin wrapper around [FirebaseStorage] for product imagery.
///
/// Storage layout: `products/{productId}/main.jpg` (single image per
/// product, overwritten on re-upload). The download URL is what we
/// persist on `ProductEntity.imageUrl`.
class ProductImageStorageService {
  ProductImageStorageService(this._storage);

  final FirebaseStorage _storage;

  Reference _ref(String productId) =>
      _storage.ref().child('products').child(productId).child('main.jpg');

  /// Uploads [bytes] (already compressed JPEG) and returns the public
  /// download URL. Caller is responsible for persisting the URL onto
  /// the product document.
  Future<String> upload({
    required String productId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(productId);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  /// Deletes the product's image (if any). No-ops on `object-not-found`
  /// so callers can call this freely on a product that never had one.
  Future<void> delete({required String productId}) async {
    try {
      await _ref(productId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}

final productImageStorageServiceProvider =
    Provider<ProductImageStorageService>((ref) {
  return ProductImageStorageService(ref.watch(firebaseStorageProvider));
});
