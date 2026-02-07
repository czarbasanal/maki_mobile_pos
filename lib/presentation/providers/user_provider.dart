import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/user_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the UserRepository instance.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl();
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
class UserOperationsNotifier extends StateNotifier<UserOperationsState> {
  final UserRepository _repository;
  final Ref _ref;

  UserOperationsNotifier(this._repository, this._ref)
      : super(const UserOperationsState());

  /// Creates a new user with Firebase Auth and Firestore document.
  Future<UserEntity?> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required String createdBy,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _repository.createUser(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        createdBy: createdBy,
      );

      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      return user;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Updates an existing user.
  Future<UserEntity?> updateUser({
    required UserEntity user,
    required String updatedBy,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final updated = await _repository.updateUser(
        user: user,
        updatedBy: updatedBy,
      );

      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      _ref.invalidate(userByIdProvider(user.id));
      return updated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Updates a user's role.
  Future<bool> updateUserRole({
    required String userId,
    required UserRole newRole,
    required String updatedBy,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.updateUserRole(
        userId: userId,
        newRole: newRole,
        updatedBy: updatedBy,
      );

      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      _ref.invalidate(userByIdProvider(userId));
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Deactivates a user.
  Future<bool> deactivateUser({
    required String userId,
    required String updatedBy,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.deactivateUser(
        userId: userId,
        updatedBy: updatedBy,
      );

      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      _ref.invalidate(userByIdProvider(userId));
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Reactivates a user.
  Future<bool> reactivateUser({
    required String userId,
    required String updatedBy,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.reactivateUser(
        userId: userId,
        updatedBy: updatedBy,
      );

      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      _ref.invalidate(userByIdProvider(userId));
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Checks if email exists.
  Future<bool> emailExists(String email) async {
    try {
      return await _repository.emailExists(email);
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
  final repository = ref.watch(userRepositoryProvider);
  return UserOperationsNotifier(repository, ref);
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
