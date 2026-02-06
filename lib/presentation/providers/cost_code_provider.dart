import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/data/repositories/cost_code_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/cost_code_repository.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the CostCodeRepository instance.
final costCodeRepositoryProvider = Provider<CostCodeRepository>((ref) {
  return CostCodeRepositoryImpl();
});

// ==================== COST CODE QUERIES ====================

/// Provides the current cost code mapping.
final costCodeMappingProvider = FutureProvider<CostCodeEntity>((ref) async {
  final repository = ref.watch(costCodeRepositoryProvider);
  return repository.getCostCodeMapping();
});

/// Provides the cost code mapping as a stream for real-time updates.
final costCodeMappingStreamProvider = StreamProvider<CostCodeEntity>((ref) {
  final repository = ref.watch(costCodeRepositoryProvider);
  return repository.watchCostCodeMapping();
});

// ==================== COST CODE OPERATIONS ====================

/// Notifier for cost code operations.
class CostCodeOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final CostCodeRepository _repository;
  final Ref _ref;

  CostCodeOperationsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Updates the cost code mapping.
  Future<bool> updateMapping({
    required CostCodeEntity mapping,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updatedMapping = mapping.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: updatedBy,
      );
      await _repository.updateCostCodeMapping(updatedMapping);
      state = const AsyncValue.data(null);
      _ref.invalidate(costCodeMappingProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Resets to default mapping.
  Future<bool> resetToDefault() async {
    state = const AsyncValue.loading();
    try {
      await _repository.resetToDefaultMapping();
      state = const AsyncValue.data(null);
      _ref.invalidate(costCodeMappingProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider for cost code operations.
final costCodeOperationsProvider =
    StateNotifierProvider<CostCodeOperationsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(costCodeRepositoryProvider);
  return CostCodeOperationsNotifier(repository, ref);
});

// ==================== UTILITY PROVIDERS ====================

/// Encodes a cost value using the current mapping.
final encodeCostProvider = Provider.family<String, double>((ref, cost) {
  final mappingAsync = ref.watch(costCodeMappingProvider);
  return mappingAsync.when(
    data: (mapping) => mapping.encode(cost),
    loading: () => '',
    error: (_, __) => CostCodeEntity.defaultMapping().encode(cost),
  );
});

/// Decodes a cost code using the current mapping.
final decodeCostProvider = Provider.family<double?, String>((ref, code) {
  final mappingAsync = ref.watch(costCodeMappingProvider);
  return mappingAsync.when(
    data: (mapping) => mapping.decode(code),
    loading: () => null,
    error: (_, __) => CostCodeEntity.defaultMapping().decode(code),
  );
});

/// Validates if a code is valid using the current mapping.
final isValidCodeProvider = Provider.family<bool, String>((ref, code) {
  final mappingAsync = ref.watch(costCodeMappingProvider);
  return mappingAsync.when(
    data: (mapping) => mapping.isValidCode(code),
    loading: () => false,
    error: (_, __) => CostCodeEntity.defaultMapping().isValidCode(code),
  );
});
