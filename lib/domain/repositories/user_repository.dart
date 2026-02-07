import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for User operations.
abstract class UserRepository {
  // ==================== CREATE ====================

  /// Creates a new user with Firebase Auth and Firestore document.
  Future<UserEntity> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required String createdBy,
  });

  // ==================== READ ====================

  /// Gets a user by ID.
  Future<UserEntity?> getUserById(String userId);

  /// Gets a user by email.
  Future<UserEntity?> getUserByEmail(String email);

  /// Gets all users.
  Future<List<UserEntity>> getAllUsers({bool includeInactive = false});

  /// Gets users by role.
  Future<List<UserEntity>> getUsersByRole(UserRole role);

  /// Streams a user by ID.
  Stream<UserEntity?> watchUser(String userId);

  /// Streams all users.
  Stream<List<UserEntity>> watchAllUsers({bool includeInactive = false});

  // ==================== UPDATE ====================

  /// Updates a user.
  Future<UserEntity> updateUser({
    required UserEntity user,
    required String updatedBy,
  });

  /// Updates a user's role.
  Future<void> updateUserRole({
    required String userId,
    required UserRole newRole,
    required String updatedBy,
  });

  /// Updates a user's last login time.
  Future<void> updateLastLogin(String userId);

  /// Deactivates a user.
  Future<void> deactivateUser({
    required String userId,
    required String updatedBy,
  });

  /// Reactivates a user.
  Future<void> reactivateUser({
    required String userId,
    required String updatedBy,
  });

  // ==================== UTILITY ====================

  /// Checks if an email exists.
  Future<bool> emailExists(String email);

  /// Gets user count.
  Future<int> getUserCount({bool activeOnly = true});
}
