import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/user_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/user/create_user_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/user/update_user_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the UserRepository instance.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl();
});

// ==================== USE CASE PROVIDERS ====================

final createUserUseCaseProvider = Provider<CreateUserUseCase>((ref) {
  return CreateUserUseCase(
    repository: ref.watch(userRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final updateUserUseCaseProvider = Provider<UpdateUserUseCase>((ref) {
  return UpdateUserUseCase(
    repository: ref.watch(userRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== USER QUERIES ====================

// Note: currentUserProvider is provided by auth_provider.dart
// It streams the current authenticated user from Firebase Auth.

/// Provides all users (for admin user management).
final allUsersProvider = FutureProvider<List<UserEntity>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getAllUsers(includeInactive: true);
});

/// Provides all active users.
final activeUsersProvider = FutureProvider<List<UserEntity>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getAllUsers(includeInactive: false);
});

/// Provides a user by ID.
final userByIdProvider = FutureProvider.family<UserEntity?, String>(
  (ref, userId) async {
    final repository = ref.watch(userRepositoryProvider);
    return repository.getUserById(userId);
  },
);

/// Provides users filtered by role.
final usersByRoleProvider = FutureProvider.family<List<UserEntity>, UserRole>(
  (ref, role) async {
    final repository = ref.watch(userRepositoryProvider);
    return repository.getUsersByRole(role);
  },
);

/// Provides user count.
final userCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserCount();
});

// ==================== USER OPERATIONS ====================

/// State for user operations.
class UserOperationsState {
  final bool isLoading;
  final String? errorMessage;

  const UserOperationsState({
    this.isLoading = false,
    this.errorMessage,
  });

  UserOperationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserOperationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier for user operations.
///
/// All mutations route through use-cases that own permission gating, business
/// guards (last-admin, self-demote, self-deactivate), and activity logging.
/// The notifier just owns transient UI state (loading + error message).
class UserOperationsNotifier extends StateNotifier<UserOperationsState> {
  final CreateUserUseCase _createUseCase;
  final UpdateUserUseCase _updateUseCase;
  final Ref _ref;

  UserOperationsNotifier({
    required CreateUserUseCase createUseCase,
    required UpdateUserUseCase updateUseCase,
    required Ref ref,
  })  : _createUseCase = createUseCase,
        _updateUseCase = updateUseCase,
        _ref = ref,
        super(const UserOperationsState());

  /// Creates a new user. Returns null on failure (errorMessage is set).
  Future<UserEntity?> createUser({
    required UserEntity actor,
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _createUseCase.execute(
      actor: actor,
      email: email,
      password: password,
      displayName: displayName,
      role: role,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      return result.data;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return null;
    }
  }

  /// Updates an existing user (handles role + active changes too).
  Future<UserEntity?> updateUser({
    required UserEntity actor,
    required UserEntity user,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _updateUseCase.execute(actor: actor, user: user);

    if (result.success) {
      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      _ref.invalidate(userByIdProvider(user.id));
      return result.data;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return null;
    }
  }

  /// Convenience: deactivate (route through updateUser so all guards apply).
  Future<bool> deactivateUser({
    required UserEntity actor,
    required UserEntity user,
  }) async {
    final updated = await updateUser(
      actor: actor,
      user: user.copyWith(isActive: false),
    );
    return updated != null;
  }

  /// Convenience: reactivate.
  Future<bool> reactivateUser({
    required UserEntity actor,
    required UserEntity user,
  }) async {
    final updated = await updateUser(
      actor: actor,
      user: user.copyWith(isActive: true),
    );
    return updated != null;
  }

  /// Checks if email exists.
  Future<bool> emailExists(String email) async {
    try {
      return await _ref.read(userRepositoryProvider).emailExists(email);
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _invalidateProviders() {
    _ref.invalidate(allUsersProvider);
    _ref.invalidate(activeUsersProvider);
    _ref.invalidate(userCountProvider);
  }
}

/// Provider for user operations.
final userOperationsProvider =
    StateNotifierProvider<UserOperationsNotifier, UserOperationsState>((ref) {
  return UserOperationsNotifier(
    createUseCase: ref.watch(createUserUseCaseProvider),
    updateUseCase: ref.watch(updateUserUseCaseProvider),
    ref: ref,
  );
});

// ==================== ROLE HELPERS ====================

/// Provides whether the current user is an admin.
final isAdminProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  return currentUser?.role == UserRole.admin;
});

/// Provides whether the current user is staff or admin.
final isStaffOrAdminProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return false;
  return currentUser.role == UserRole.admin ||
      currentUser.role == UserRole.staff;
});

/// Provides whether the current user can view costs.
final canViewCostProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  return currentUser?.role == UserRole.admin;
});

/// Provides whether the current user can manage users.
final canManageUsersProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  return currentUser?.role == UserRole.admin;
});

/// Provides whether the current user can void sales.
final canVoidSalesProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  return currentUser?.role == UserRole.admin;
});

/// Provides whether the current user can access inventory.
final canAccessInventoryProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return false;
  return currentUser.role == UserRole.admin ||
      currentUser.role == UserRole.staff;
});

/// Provides whether the current user can access receiving.
final canAccessReceivingProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return false;
  return currentUser.role == UserRole.admin ||
      currentUser.role == UserRole.staff;
});

/// Provides whether the current user can access reports.
final canAccessReportsProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return false;
  return currentUser.role == UserRole.admin ||
      currentUser.role == UserRole.staff;
});
