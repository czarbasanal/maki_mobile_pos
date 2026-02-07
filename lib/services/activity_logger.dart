import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/data/repositories/activity_log_repository_impl.dart';

/// Service for logging user activities.
///
/// Provides convenient methods for logging common actions.
class ActivityLogger {
  final ActivityLogRepository _repository;

  ActivityLogger(this._repository);

  /// Logs a generic activity.
  Future<void> log({
    required ActivityType type,
    required String action,
    String? details,
    required String userId,
    required String userName,
    required String userRole,
    String? entityId,
    String? entityType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _repository.logActivity(ActivityLogEntity(
        id: '',
        type: type,
        action: action,
        details: details,
        userId: userId,
        userName: userName,
        userRole: userRole,
        entityId: entityId,
        entityType: entityType,
        metadata: metadata,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      // Don't throw - logging should never break the app
      print('Failed to log activity: $e');
    }
  }

  /// Logs a login event.
  Future<void> logLogin({
    required UserEntity user,
  }) async {
    await log(
      type: ActivityType.login,
      action: 'User logged in',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
    );
  }

  /// Logs a logout event.
  Future<void> logLogout({
    required UserEntity user,
  }) async {
    await log(
      type: ActivityType.logout,
      action: 'User logged out',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
    );
  }

  /// Logs a sale completion.
  Future<void> logSale({
    required UserEntity user,
    required String saleId,
    required String saleNumber,
    required double amount,
    required int itemCount,
  }) async {
    await log(
      type: ActivityType.sale,
      action: 'Completed sale $saleNumber',
      details: '$itemCount items, total: ₱${amount.toStringAsFixed(2)}',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
      entityId: saleId,
      entityType: 'sale',
      metadata: {
        'saleNumber': saleNumber,
        'amount': amount,
        'itemCount': itemCount,
      },
    );
  }

  /// Logs a voided sale.
  Future<void> logVoidSale({
    required UserEntity user,
    required String saleId,
    required String saleNumber,
    required String reason,
    required double amount,
  }) async {
    await log(
      type: ActivityType.voidSale,
      action: 'Voided sale $saleNumber',
      details: 'Reason: $reason, Amount: ₱${amount.toStringAsFixed(2)}',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
      entityId: saleId,
      entityType: 'sale',
      metadata: {
        'saleNumber': saleNumber,
        'reason': reason,
        'amount': amount,
      },
    );
  }

  /// Logs password verification (success).
  Future<void> logPasswordVerified({
    required UserEntity user,
    required String purpose,
  }) async {
    await log(
      type: ActivityType.passwordVerified,
      action: 'Password verified for: $purpose',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
    );
  }

  /// Logs password verification failure.
  Future<void> logPasswordFailed({
    required UserEntity user,
    required String purpose,
    int? attemptNumber,
  }) async {
    await log(
      type: ActivityType.passwordFailed,
      action: 'Password verification failed for: $purpose',
      details: attemptNumber != null ? 'Attempt #$attemptNumber' : null,
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
    );
  }

  /// Logs cost visibility toggle.
  Future<void> logCostViewed({
    required UserEntity user,
  }) async {
    await log(
      type: ActivityType.costViewed,
      action: 'Viewed product costs',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
    );
  }

  /// Logs user creation.
  Future<void> logUserCreated({
    required UserEntity performedBy,
    required String newUserId,
    required String newUserName,
    required String newUserRole,
  }) async {
    await log(
      type: ActivityType.userCreated,
      action: 'Created user: $newUserName',
      details: 'Role: $newUserRole',
      userId: performedBy.id,
      userName: performedBy.displayName,
      userRole: performedBy.role.value,
      entityId: newUserId,
      entityType: 'user',
      metadata: {
        'newUserName': newUserName,
        'newUserRole': newUserRole,
      },
    );
  }

  /// Logs user update.
  Future<void> logUserUpdated({
    required UserEntity performedBy,
    required String updatedUserId,
    required String updatedUserName,
    String? changes,
  }) async {
    await log(
      type: ActivityType.userUpdated,
      action: 'Updated user: $updatedUserName',
      details: changes,
      userId: performedBy.id,
      userName: performedBy.displayName,
      userRole: performedBy.role.value,
      entityId: updatedUserId,
      entityType: 'user',
    );
  }

  /// Logs role change.
  Future<void> logRoleChanged({
    required UserEntity performedBy,
    required String targetUserId,
    required String targetUserName,
    required String oldRole,
    required String newRole,
  }) async {
    await log(
      type: ActivityType.roleChanged,
      action: 'Changed role for: $targetUserName',
      details: '$oldRole → $newRole',
      userId: performedBy.id,
      userName: performedBy.displayName,
      userRole: performedBy.role.value,
      entityId: targetUserId,
      entityType: 'user',
      metadata: {
        'targetUserName': targetUserName,
        'oldRole': oldRole,
        'newRole': newRole,
      },
    );
  }

  /// Logs stock adjustment.
  Future<void> logStockAdjustment({
    required UserEntity user,
    required String productId,
    required String productName,
    required String sku,
    required int oldQuantity,
    required int newQuantity,
    String? reason,
  }) async {
    final change = newQuantity - oldQuantity;
    final changeStr = change >= 0 ? '+$change' : '$change';

    await log(
      type: ActivityType.stockAdjustment,
      action: 'Adjusted stock for $productName',
      details:
          '$oldQuantity → $newQuantity ($changeStr)${reason != null ? ', Reason: $reason' : ''}',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
      entityId: productId,
      entityType: 'product',
      metadata: {
        'sku': sku,
        'oldQuantity': oldQuantity,
        'newQuantity': newQuantity,
        'change': change,
        'reason': reason,
      },
    );
  }

  /// Logs receiving completion.
  Future<void> logReceiving({
    required UserEntity user,
    required String receivingId,
    required String referenceNumber,
    required int itemCount,
    required double totalCost,
    String? supplierName,
  }) async {
    await log(
      type: ActivityType.receiving,
      action: 'Completed receiving $referenceNumber',
      details:
          '$itemCount items, total cost: ₱${totalCost.toStringAsFixed(2)}${supplierName != null ? ', Supplier: $supplierName' : ''}',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
      entityId: receivingId,
      entityType: 'receiving',
      metadata: {
        'referenceNumber': referenceNumber,
        'itemCount': itemCount,
        'totalCost': totalCost,
        'supplierName': supplierName,
      },
    );
  }

  /// Logs cost code mapping change.
  Future<void> logCostCodeChanged({
    required UserEntity user,
  }) async {
    await log(
      type: ActivityType.costCodeChanged,
      action: 'Modified cost code mapping',
      userId: user.id,
      userName: user.displayName,
      userRole: user.role.value,
    );
  }
}

// ==================== PROVIDER ====================

/// Provider for ActivityLogRepository.
final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepositoryImpl();
});

/// Provider for ActivityLogger service.
final activityLoggerProvider = Provider<ActivityLogger>((ref) {
  final repository = ref.watch(activityLogRepositoryProvider);
  return ActivityLogger(repository);
});
