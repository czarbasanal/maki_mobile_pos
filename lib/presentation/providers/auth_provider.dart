import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/auth/sign_in_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/auth/sign_out_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/auth/verify_password_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Provider for the AuthRepository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// Provider for the current authenticated user.
///
/// Returns null if no user is signed in.
/// Automatically updates when auth state changes.
final currentUserProvider = StreamProvider<UserEntity?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Provider to check if user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user != null) ?? false;
});

/// Provider for the current user's ID.
final currentUserIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.id);
});

/// Provider for the current user's role.
final currentUserRoleProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.whenOrNull(data: (user) => user?.role.value);
});

/// Auth state notifier for handling sign in/out actions.
///
/// State-changing auth operations route through use cases that own the
/// activity-log writes (logLogin / logLogout / logPasswordVerified).
class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository _authRepository;
  final SignInUseCase _signInUseCase;
  final SignOutUseCase _signOutUseCase;
  final VerifyPasswordUseCase _verifyPasswordUseCase;

  AuthNotifier({
    required AuthRepository authRepository,
    required SignInUseCase signInUseCase,
    required SignOutUseCase signOutUseCase,
    required VerifyPasswordUseCase verifyPasswordUseCase,
  })  : _authRepository = authRepository,
        _signInUseCase = signInUseCase,
        _signOutUseCase = signOutUseCase,
        _verifyPasswordUseCase = verifyPasswordUseCase,
        super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _authRepository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserEntity?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await _signInUseCase.execute(email: email, password: password);
    if (result.success) {
      state = AsyncValue.data(result.data);
      return result.data;
    }
    final err = AuthException(
      message: result.errorMessage ?? 'Sign-in failed',
      code: result.errorCode,
    );
    state = AsyncValue.error(err, StackTrace.current);
    throw err;
  }

  Future<void> signOut() async {
    final actor = state.valueOrNull;
    final result = await _signOutUseCase.execute(actor: actor);
    if (result.success) {
      state = const AsyncValue.data(null);
    } else {
      final err = AuthException(
        message: result.errorMessage ?? 'Auth operation failed',
        code: result.errorCode);
      state = AsyncValue.error(err, StackTrace.current);
      throw err;
    }
  }

  /// Verifies the current user's password.
  Future<bool> verifyPassword(String password, {String purpose = 'sensitive action'}) async {
    final actor = state.valueOrNull;
    if (actor == null) return false;
    final result = await _verifyPasswordUseCase.execute(
      actor: actor,
      password: password,
      purpose: purpose,
    );
    return result.data ?? false;
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _authRepository.sendPasswordResetEmail(email);
  }

  /// Updates the current user's password.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authRepository.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}

// ==================== AUTH USE CASE PROVIDERS ====================

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(
    repository: ref.watch(authRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(
    repository: ref.watch(authRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final verifyPasswordUseCaseProvider = Provider<VerifyPasswordUseCase>((ref) {
  return VerifyPasswordUseCase(
    repository: ref.watch(authRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

/// Provider for the AuthNotifier.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  return AuthNotifier(
    authRepository: ref.watch(authRepositoryProvider),
    signInUseCase: ref.watch(signInUseCaseProvider),
    signOutUseCase: ref.watch(signOutUseCaseProvider),
    verifyPasswordUseCase: ref.watch(verifyPasswordUseCaseProvider),
  );
});

/// Provider for easy access to auth actions.
final authActionsProvider = Provider<AuthNotifier>((ref) {
  return ref.watch(authNotifierProvider.notifier);
});
