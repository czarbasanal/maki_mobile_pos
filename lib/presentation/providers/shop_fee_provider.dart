import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/shop_fee_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_fee_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the [ShopFeeRepository] bound to the `shop_fees` collection.
final shopFeeRepositoryProvider = Provider<ShopFeeRepository>((ref) {
  return ShopFeeRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

// ==================== SHOP FEE QUERIES ====================

/// Streams active shop fees. Auth-gated so it does not emit a
/// permission-denied error before the user's session is warm. Used by the
/// cashier-facing shop-fee picker.
final activeShopFeesProvider = StreamProvider<List<ShopFeeEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(shopFeeRepositoryProvider).watchActive();
  });
});

/// Streams all shop fees (active + inactive) for the admin editor screen.
final allShopFeesProvider = StreamProvider<List<ShopFeeEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(shopFeeRepositoryProvider).watchAll();
  });
});

// ==================== SHOP FEE OPERATIONS ====================

/// Notifier for shop-fee mutations. Permission is checked at the route
/// layer; this notifier does not duplicate that gate.
class ShopFeeOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ShopFeeOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  ShopFeeRepository get _repository => _ref.read(shopFeeRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user.id;
  }

  Future<ShopFeeEntity?> create({required ShopFeeEntity shopFee}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final created = await _repository.createShopFee(
        shopFee: shopFee,
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<ShopFeeEntity?> update({required ShopFeeEntity shopFee}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final updated = await _repository.updateShopFee(
        shopFee: shopFee,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String shopFeeId) =>
      _setActive(shopFeeId: shopFeeId, active: false);

  Future<bool> reactivate(String shopFeeId) =>
      _setActive(shopFeeId: shopFeeId, active: true);

  Future<bool> _setActive({
    required String shopFeeId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.setActive(
        shopFeeId: shopFeeId,
        active: active,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Permanently deletes the entry. Returns true on success.
  Future<bool> delete(String shopFeeId) async {
    state = const AsyncValue.loading();
    try {
      _requireUserId();
      await _repository.deleteShopFee(shopFeeId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final shopFeeOperationsProvider =
    StateNotifierProvider<ShopFeeOperationsNotifier, AsyncValue<void>>((ref) {
  return ShopFeeOperationsNotifier(ref);
});
