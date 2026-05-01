import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/petty_cash/cash_in_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/petty_cash/cash_out_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/petty_cash/perform_cutoff_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

final pettyCashRepositoryProvider = Provider<PettyCashRepository>((ref) {
  return PettyCashRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// ==================== USE-CASE PROVIDERS ====================

final cashInUseCaseProvider = Provider<CashInUseCase>((ref) {
  return CashInUseCase(
    repository: ref.watch(pettyCashRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final cashOutUseCaseProvider = Provider<CashOutUseCase>((ref) {
  return CashOutUseCase(
    repository: ref.watch(pettyCashRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final performCutOffUseCaseProvider = Provider<PerformCutOffUseCase>((ref) {
  return PerformCutOffUseCase(
    repository: ref.watch(pettyCashRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== PETTY CASH QUERIES ====================

/// Provides petty cash records as a real-time stream.
final pettyCashRecordsProvider = StreamProvider<List<PettyCashEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(pettyCashRepositoryProvider).watchRecords();
  });
});

/// Provides the current petty cash balance.
final pettyCashBalanceProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(pettyCashRepositoryProvider);
  return repository.getCurrentBalance();
});

/// Provides a single petty cash record by ID.
final pettyCashRecordByIdProvider =
    FutureProvider.family<PettyCashEntity?, String>((ref, recordId) async {
  final repository = ref.watch(pettyCashRepositoryProvider);
  return repository.getRecordById(recordId);
});

// ==================== PETTY CASH OPERATIONS ====================

/// Notifier for petty cash operations.
///
/// All mutations route through use-cases. The current user is read from
/// [currentUserProvider]; callers no longer pass createdBy/createdByName.
class PettyCashOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  PettyCashOperationsNotifier(this._ref) : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user;
  }

  Future<PettyCashEntity?> cashIn({
    required double amount,
    required String description,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref.read(cashInUseCaseProvider).execute(
            actor: actor,
            amount: amount,
            description: description,
            notes: notes,
          );
      if (result.success) {
        state = const AsyncValue.data(null);
        _invalidate();
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Cash in failed',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<PettyCashEntity?> cashOut({
    required double amount,
    required String description,
    String? referenceId,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref.read(cashOutUseCaseProvider).execute(
            actor: actor,
            amount: amount,
            description: description,
            referenceId: referenceId,
            notes: notes,
          );
      if (result.success) {
        state = const AsyncValue.data(null);
        _invalidate();
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Cash out failed',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<PettyCashEntity?> performCutOff({String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final actor = _requireUser();
      final result = await _ref
          .read(performCutOffUseCaseProvider)
          .execute(actor: actor, notes: notes);
      if (result.success) {
        state = const AsyncValue.data(null);
        _invalidate();
        return result.data;
      }
      state = AsyncValue.error(
        result.errorMessage ?? 'Cut-off failed',
        StackTrace.current,
      );
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void _invalidate() {
    _ref.invalidate(pettyCashRecordsProvider);
    _ref.invalidate(pettyCashBalanceProvider);
  }
}

/// Provider for petty cash operations.
final pettyCashOperationsProvider =
    StateNotifierProvider<PettyCashOperationsNotifier, AsyncValue<void>>((ref) {
  return PettyCashOperationsNotifier(ref);
});
