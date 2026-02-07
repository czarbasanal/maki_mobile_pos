import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Firestore implementation of [UserRepository].
class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

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

      // Create Firebase Auth user
      // Note: This creates the user under the admin's session
      // In production, you might want to use Cloud Functions for this
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

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
