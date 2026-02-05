import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/errors/errors.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Implementation of [AuthRepository] using Firebase Auth and Firestore.
///
/// This class:
/// - Handles Firebase Auth operations
/// - Fetches user profile from Firestore
/// - Converts Firebase errors to app exceptions
/// - Manages auth state streams
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to the users collection
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(FirestoreCollections.users);

  // ==================== SIGN IN ====================

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('AuthRepository: Attempting sign in for $email');

      // Authenticate with Firebase Auth
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException(
          message: 'Sign in failed: No user returned',
          code: 'no-user',
        );
      }

      debugPrint(
          'AuthRepository: Firebase auth successful, fetching user profile');

      // Fetch user profile from Firestore
      final userEntity = await _getUserProfile(firebaseUser.uid);

      // Check if user is active
      if (!userEntity.isActive) {
        await _firebaseAuth.signOut();
        throw const AccountDisabledException();
      }

      // Update last login timestamp
      await _updateLastLogin(firebaseUser.uid);

      debugPrint(
          'AuthRepository: Sign in complete for ${userEntity.displayName}');
      return userEntity;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'AuthRepository: Firebase auth error - ${e.code}: ${e.message}');
      throw _mapFirebaseAuthException(e);
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('AuthRepository: Unexpected error - $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException(
        message: 'An unexpected error occurred during sign in',
        code: 'unknown',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== SIGN OUT ====================

  @override
  Future<void> signOut() async {
    try {
      debugPrint('AuthRepository: Signing out');
      await _firebaseAuth.signOut();
      debugPrint('AuthRepository: Sign out complete');
    } catch (e, stackTrace) {
      debugPrint('AuthRepository: Sign out error - $e');
      throw AuthException(
        message: 'Failed to sign out',
        code: 'sign-out-failed',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== GET CURRENT USER ====================

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        debugPrint('AuthRepository: No current user');
        return null;
      }

      debugPrint('AuthRepository: Getting current user profile');
      return await _getUserProfile(firebaseUser.uid);
    } catch (e) {
      debugPrint('AuthRepository: Error getting current user - $e');
      return null;
    }
  }

  // ==================== AUTH STATE STREAM ====================

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        debugPrint('AuthRepository: Auth state changed - signed out');
        return null;
      }

      try {
        debugPrint(
            'AuthRepository: Auth state changed - fetching user profile');
        final user = await _getUserProfile(firebaseUser.uid);

        if (!user.isActive) {
          debugPrint('AuthRepository: User is inactive, signing out');
          await _firebaseAuth.signOut();
          return null;
        }

        return user;
      } catch (e) {
        debugPrint('AuthRepository: Error in auth state stream - $e');
        return null;
      }
    });
  }

  // ==================== PASSWORD VERIFICATION ====================

  @override
  Future<bool> verifyPassword(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const UnauthenticatedException();
      }

      debugPrint('AuthRepository: Verifying password');

      // Re-authenticate with current credentials
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('AuthRepository: Password verified successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthRepository: Password verification failed - ${e.code}');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return false;
      }
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      debugPrint('AuthRepository: Password verification error - $e');
      return false;
    }
  }

  // ==================== PASSWORD RESET ====================

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('AuthRepository: Sending password reset email to $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      debugPrint('AuthRepository: Password reset email sent');
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthRepository: Password reset error - ${e.code}');
      throw _mapFirebaseAuthException(e);
    }
  }

  // ==================== UPDATE PASSWORD ====================

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw const UnauthenticatedException();
      }

      debugPrint('AuthRepository: Updating password');

      // Re-authenticate first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      debugPrint('AuthRepository: Password updated successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthRepository: Update password error - ${e.code}');
      throw _mapFirebaseAuthException(e);
    }
  }

  // ==================== HELPER GETTERS ====================

  @override
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  // ==================== PRIVATE HELPERS ====================

  /// Fetches user profile from Firestore.
  Future<UserEntity> _getUserProfile(String uid) async {
    final doc = await _usersCollection.doc(uid).get();

    if (!doc.exists) {
      debugPrint('AuthRepository: User profile not found for $uid');
      throw NotFoundException(
        message: 'User profile not found',
        entityType: 'User',
        entityId: uid,
      );
    }

    final userModel = UserModel.fromFirestore(doc);
    return userModel.toEntity();
  }

  /// Updates the last login timestamp for a user.
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't fail sign in if this update fails
      debugPrint('AuthRepository: Failed to update last login - $e');
    }
  }

  /// Maps Firebase Auth exceptions to app exceptions.
  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const InvalidCredentialsException(
          message: 'No account found with this email',
          code: 'user-not-found',
        );
      case 'wrong-password':
        return const InvalidCredentialsException(
          message: 'Incorrect password',
          code: 'wrong-password',
        );
      case 'invalid-credential':
        return const InvalidCredentialsException(
          message: 'Invalid email or password',
          code: 'invalid-credential',
        );
      case 'invalid-email':
        return const AuthException(
          message: 'Invalid email address',
          code: 'invalid-email',
        );
      case 'user-disabled':
        return const AccountDisabledException();
      case 'too-many-requests':
        return const AuthException(
          message: 'Too many failed attempts. Please try again later.',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return AuthException(
          message: 'Network error. Please check your connection.',
          code: 'network-error',
          originalError: e,
        );
      case 'weak-password':
        return const AuthException(
          message: 'Password is too weak',
          code: 'weak-password',
        );
      case 'email-already-in-use':
        return const AuthException(
          message: 'An account already exists with this email',
          code: 'email-already-in-use',
        );
      case 'requires-recent-login':
        return const AuthException(
          message: 'Please sign in again to perform this action',
          code: 'requires-recent-login',
        );
      default:
        return AuthException(
          message: e.message ?? 'Authentication failed',
          code: e.code,
          originalError: e,
        );
    }
  }
}
