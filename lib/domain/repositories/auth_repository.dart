import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository defining authentication operations.
///
/// This is a domain-layer contract that defines what auth operations
/// are available without specifying how they're implemented.
abstract class AuthRepository {
  /// Signs in a user with email and password.
  ///
  /// Returns the authenticated [UserEntity] on success.
  /// Throws [AuthException] on failure.
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs out the current user.
  ///
  /// Clears local session data and Firebase auth state.
  Future<void> signOut();

  /// Gets the currently authenticated user.
  ///
  /// Returns null if no user is signed in.
  Future<UserEntity?> getCurrentUser();

  /// Stream of authentication state changes.
  ///
  /// Emits the current user when auth state changes (sign in/out).
  /// Emits null when user signs out.
  Stream<UserEntity?> get authStateChanges;

  /// Verifies the current user's password.
  ///
  /// Used for protected actions like voiding sales or viewing costs.
  /// Returns true if password is correct, false otherwise.
  Future<bool> verifyPassword(String password);

  /// Sends a password reset email to the specified address.
  Future<void> sendPasswordResetEmail(String email);

  /// Updates the current user's password.
  ///
  /// Requires the current password for re-authentication.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Checks if a user is currently signed in.
  bool get isSignedIn;

  /// Gets the current user's ID, or null if not signed in.
  String? get currentUserId;
}
