import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Name of the throwaway FirebaseApp used only to mint new accounts. See
/// [UserRepositoryImpl._defaultProvisioningAuth].
const String _provisioningAppName = 'maki-admin-provisioning';

/// Firestore implementation of [UserRepository].
class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _firestore;

  /// Deliberately the ONLY auth this repository can reach. It never holds the
  /// primary [FirebaseAuth], so account creation cannot replace the signed-in
  /// admin's session even by accident.
  final Future<FirebaseAuth> Function() _provisioningAuth;

  /// The `deleteUserAccount` Cloud Function (functions/src/index.ts): removes
  /// the Auth login AND the users/{uid} doc together. Only the Admin SDK can
  /// delete another person's credential, so the client never does the doc
  /// delete itself any more. Injectable for tests.
  final Future<void> Function(Map<String, dynamic> data) _deleteAccount;

  UserRepositoryImpl({
    FirebaseFirestore? firestore,
    Future<FirebaseAuth> Function()? provisioningAuth,
    Future<void> Function(Map<String, dynamic> data)? deleteAccount,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _provisioningAuth = provisioningAuth ?? _defaultProvisioningAuth,
        _deleteAccount = deleteAccount ?? _defaultDeleteAccount;

  /// Same region as Firestore and the web client.
  static Future<void> _defaultDeleteAccount(Map<String, dynamic> data) async {
    await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('deleteUserAccount')
        .call<Map<String, dynamic>>(data);
  }

  /// Auth bound to a SECONDARY FirebaseApp, used solely to create accounts.
  ///
  /// `createUserWithEmailAndPassword` signs the new account in as a side
  /// effect. On the primary app that replaces the admin's own session, so the
  /// profile write that follows is evaluated as the brand-new user (who has
  /// no profile doc yet, so the rules' `isAdmin()` is false) and gets denied —
  /// leaving a login credential with no profile, and the admin logged out.
  /// Doing it on a separate app keeps the admin's session untouched. Mirrors
  /// the web admin (web_admin/src/data/repositories/FirestoreUserRepository.ts).
  /// Note: this app is NOT pointed at the Auth emulator by FirebaseService,
  /// so if emulator use is ever switched on, wire it here too — otherwise
  /// creates would mint real accounts while the rest of the app is local.
  static Future<FirebaseAuth> _defaultProvisioningAuth() async {
    FirebaseApp app;
    try {
      app = Firebase.app(_provisioningAppName);
    } catch (_) {
      // Reuse the primary app's options — same project, separate session.
      app = await Firebase.initializeApp(
        name: _provisioningAppName,
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestoreCollections.users);

  // ==================== CREATE ====================

  @override
  Future<UserEntity> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required String createdBy,
  }) async {
    try {
      // Check if email already exists
      if (await emailExists(email)) {
        throw const DuplicateEntryException(
          field: 'email',
          value: '',
          message: 'A user with this email already exists',
        );
      }

      // Mint the credential on the provisioning app, NOT on `_auth` — see
      // [_defaultProvisioningAuth]. The new account is signed into that
      // throwaway instance as a side effect; sign it back out so nothing is
      // left holding a session, then write the profile below with the
      // admin's own (untouched) session so the rules see an admin.
      // Residual (accepted, matches the web admin): between minting the
      // credential and writing the profile below there is a window where the
      // credential exists with no profile. If that write fails, recovery
      // needs a service account (scripts/delete-auth-user.mjs). Closing it
      // would mean deleting the just-minted account on failure instead of
      // signing out here.
      final provisioningAuth = await _provisioningAuth();
      final String userId;
      try {
        final userCredential =
            await provisioningAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        userId = userCredential.user!.uid;
      } finally {
        try {
          await provisioningAuth.signOut();
        } catch (_) {
          // Never let cleanup mask the real outcome of the create.
        }
      }

      // Create Firestore document
      final user = UserEntity(
        id: userId,
        email: email,
        displayName: displayName,
        role: role,
        isActive: true,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      final model = UserModel.fromEntity(user);
      await _usersRef.doc(userId).set(model.toCreateMap(createdBy));

      return user;
    } on FirebaseAuthException catch (e) {
      // No profile doc exists (emailExists ran above), yet Auth already has
      // the credential. Deliberately does NOT guess which cause it is —
      // deleting a user removes users/{uid} but leaves the Auth credential
      // behind on purpose (see firestore.rules), so re-adding someone who
      // was deleted is the most common trigger, not a failed setup. A
      // capitalisation difference lands here too, since this check is an
      // exact-match Firestore query while Auth is case-insensitive.
      // Reporting the raw "email already in use" sends admins hunting for a
      // user that isn't in the list.
      if (e.code == 'email-already-in-use') {
        throw DuplicateEntryException(
          field: 'email',
          value: email,
          message: 'This email already has a login — it may be from a deleted '
              'user, an earlier failed setup, or the same address typed with '
              'different capitalisation. Ask your developer to check it, then '
              'try again.',
        );
      }
      throw AuthException(
        message: 'Failed to create user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<UserEntity?> getUserById(String userId) async {
    try {
      final doc = await _usersRef.doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<UserEntity?> getUserByEmail(String email) async {
    try {
      final snapshot =
          await _usersRef.where('email', isEqualTo: email).limit(1).get();

      if (snapshot.docs.isEmpty) return null;
      return UserModel.fromFirestore(snapshot.docs.first).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get user by email: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<UserEntity>> getAllUsers({bool includeInactive = false}) async {
    try {
      Query<Map<String, dynamic>> query = _usersRef.orderBy('displayName');

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get users: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<UserEntity>> getUsersByRole(UserRole role) async {
    try {
      final snapshot = await _usersRef
          .where('role', isEqualTo: role.value)
          .where('isActive', isEqualTo: true)
          .orderBy('displayName')
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get users by role: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<UserEntity?> watchUser(String userId) {
    return _usersRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc).toEntity();
    });
  }

  @override
  Stream<List<UserEntity>> watchAllUsers({bool includeInactive = false}) {
    Query<Map<String, dynamic>> query = _usersRef.orderBy('displayName');

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc).toEntity())
        .toList());
  }

  // ==================== UPDATE ====================

  @override
  Future<UserEntity> updateUser({
    required UserEntity user,
    required String updatedBy,
  }) async {
    try {
      final model = UserModel.fromEntity(user);
      await _usersRef.doc(user.id).update(model.toUpdateMap(updatedBy));

      final updated = await getUserById(user.id);
      if (updated == null) {
        throw const DatabaseException(message: 'User not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateUserRole({
    required String userId,
    required UserRole newRole,
    required String updatedBy,
  }) async {
    try {
      await _usersRef.doc(userId).update({
        'role': newRole.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update user role: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateLastLogin(String userId) async {
    try {
      await _usersRef.doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update last login: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deactivateUser({
    required String userId,
    required String updatedBy,
  }) async {
    try {
      await _usersRef.doc(userId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to deactivate user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> reactivateUser({
    required String userId,
    required String updatedBy,
  }) async {
    try {
      await _usersRef.doc(userId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to reactivate user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== DELETE ====================

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _deleteAccount({'uid': userId});
    } on FirebaseFunctionsException catch (e) {
      // The function's own messages ("Deactivate this user before deleting
      // them") are the ones the admin should read — pass them through.
      throw DatabaseException(
        message: e.message ?? 'Failed to delete user',
        code: e.code,
        originalError: e,
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== UTILITY ====================

  @override
  Future<bool> emailExists(String email) async {
    try {
      final snapshot =
          await _usersRef.where('email', isEqualTo: email).limit(1).get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check email existence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> getUserCount({bool activeOnly = true}) async {
    try {
      Query<Map<String, dynamic>> query = _usersRef;

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get user count: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
