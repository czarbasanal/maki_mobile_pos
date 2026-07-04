import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:maki_mobile_pos/services/firebase_service.dart';

/// Thin wrapper around [FirebaseStorage] for expense receipt photos.
///
/// Storage layout: `expenses/{expenseId}/receipt.jpg` (single receipt per
/// expense, overwritten on re-upload). The download URL is what we persist
/// on `ExpenseEntity.receiptImageUrl`.
class ExpenseReceiptStorageService {
  ExpenseReceiptStorageService(this._storage);

  final FirebaseStorage _storage;

  Reference _ref(String expenseId) =>
      _storage.ref().child('expenses').child(expenseId).child('receipt.jpg');

  /// Uploads [bytes] (already compressed JPEG) and returns the public
  /// download URL. Caller persists the URL onto the expense document.
  Future<String> upload({
    required String expenseId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(expenseId);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  /// Deletes the expense's receipt (if any). No-ops on `object-not-found`.
  Future<void> delete({required String expenseId}) async {
    try {
      await _ref(expenseId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}

final expenseReceiptStorageServiceProvider =
    Provider<ExpenseReceiptStorageService>((ref) {
  return ExpenseReceiptStorageService(ref.watch(firebaseStorageProvider));
});
