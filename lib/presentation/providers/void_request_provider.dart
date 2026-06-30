import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/void_request_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/approve_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/reject_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY ====================

final voidRequestRepositoryProvider = Provider<VoidRequestRepository>((ref) {
  return VoidRequestRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE CASES ====================

final requestVoidSaleUseCaseProvider = Provider<RequestVoidSaleUseCase>((ref) {
  return RequestVoidSaleUseCase(
      repository: ref.watch(voidRequestRepositoryProvider));
});

final rejectVoidRequestUseCaseProvider =
    Provider<RejectVoidRequestUseCase>((ref) {
  return RejectVoidRequestUseCase(
      repository: ref.watch(voidRequestRepositoryProvider));
});

final approveVoidRequestUseCaseProvider =
    Provider<ApproveVoidRequestUseCase>((ref) {
  return ApproveVoidRequestUseCase(
    repository: ref.watch(voidRequestRepositoryProvider),
    voidSaleUseCase: VoidSaleUseCase(
      saleRepository: ref.watch(saleRepositoryProvider),
      productRepository: ref.watch(productRepositoryProvider),
      authRepository: ref.watch(authRepositoryProvider),
    ),
  );
});

// ==================== STREAMS ====================

/// All void requests, newest first (admin queue).
final voidRequestsProvider = StreamProvider<List<VoidRequestEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(voidRequestRepositoryProvider).watchRequests();
  });
});

/// Unread void-request count (notification badge).
final unreadVoidRequestCountProvider = Provider<int>((ref) {
  final async = ref.watch(voidRequestsProvider);
  return async.maybeWhen(
    data: (list) => list.where((r) => !r.read).length,
    orElse: () => 0,
  );
});

/// Pending requests for a sale (sale-detail indicator).
final pendingVoidRequestForSaleProvider =
    StreamProvider.autoDispose.family<List<VoidRequestEntity>, String>(
        (ref, saleId) {
  return authGatedStream(ref, (_) {
    return ref
        .watch(voidRequestRepositoryProvider)
        .watchPendingForSale(saleId);
  });
});

// ==================== OPERATIONS ====================

class VoidRequestOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  VoidRequestOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) throw const UnauthenticatedException();
    return user;
  }

  String _messageFor(Object error) =>
      error is AppException ? error.message : error.toString();

  /// Returns null on success, or an error message.
  ///
  /// `_requireUser()` throws on an auth-transition race (null user); each
  /// method catches so the failure comes back through the returned
  /// message rather than as a rejected Future the dialog never observes.
  Future<String?> requestVoid({
    required SaleEntity sale,
    required String reason,
  }) async {
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(requestVoidSaleUseCaseProvider)
          .execute(actor: actor, sale: sale, reason: reason);
      _ref.invalidate(voidRequestsProvider);
      return result.success ? null : (result.errorMessage ?? 'Failed');
    } catch (e) {
      return _messageFor(e);
    }
  }

  Future<String?> approve({
    required VoidRequestEntity request,
    required String password,
  }) async {
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(approveVoidRequestUseCaseProvider)
          .execute(actor: actor, request: request, password: password);
      _ref.invalidate(voidRequestsProvider);
      _ref.invalidate(todaysSalesProvider);
      return result.success ? null : (result.errorMessage ?? 'Failed');
    } catch (e) {
      return _messageFor(e);
    }
  }

  Future<String?> reject({
    required VoidRequestEntity request,
    required String rejectionReason,
  }) async {
    try {
      final actor = _requireUser();
      final result = await _ref.read(rejectVoidRequestUseCaseProvider).execute(
          actor: actor,
          request: request,
          rejectionReason: rejectionReason);
      _ref.invalidate(voidRequestsProvider);
      return result.success ? null : (result.errorMessage ?? 'Failed');
    } catch (e) {
      return _messageFor(e);
    }
  }

  Future<void> markAllRead() async {
    await _ref.read(voidRequestRepositoryProvider).markAllRead();
    _ref.invalidate(voidRequestsProvider);
  }

  Future<void> markRead(String requestId) async {
    await _ref.read(voidRequestRepositoryProvider).markRead(requestId);
    _ref.invalidate(voidRequestsProvider);
  }
}

final voidRequestOperationsProvider =
    StateNotifierProvider<VoidRequestOperationsNotifier, AsyncValue<void>>(
        (ref) => VoidRequestOperationsNotifier(ref));
