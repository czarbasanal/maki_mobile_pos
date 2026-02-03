import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
///
/// Failures are returned (not thrown) from repositories and use cases
/// to represent expected error states. They use Equatable for easy comparison.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'Failure: $message (code: $code)';
}

// ==================== AUTH FAILURES ====================

/// Failure when authentication fails.
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
  });
}

/// Failure when user is not authenticated.
class UnauthenticatedFailure extends AuthFailure {
  const UnauthenticatedFailure({
    super.message = 'User is not authenticated',
    super.code = 'unauthenticated',
  });
}

/// Failure when credentials are invalid.
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password',
    super.code = 'invalid-credentials',
  });
}

/// Failure when account is disabled.
class AccountDisabledFailure extends AuthFailure {
  const AccountDisabledFailure({
    super.message = 'This account has been disabled',
    super.code = 'account-disabled',
  });
}

/// Failure when password verification fails.
class PasswordVerificationFailure extends AuthFailure {
  const PasswordVerificationFailure({
    super.message = 'Incorrect password',
    super.code = 'password-verification-failed',
  });
}

// ==================== PERMISSION FAILURES ====================

/// Failure when user lacks required permission.
class PermissionDeniedFailure extends Failure {
  final String? requiredPermission;

  const PermissionDeniedFailure({
    super.message = 'You do not have permission to perform this action',
    super.code = 'permission-denied',
    this.requiredPermission,
  });

  @override
  List<Object?> get props => [...super.props, requiredPermission];
}

/// Failure when user role is insufficient.
class InsufficientRoleFailure extends PermissionDeniedFailure {
  final String? requiredRole;

  const InsufficientRoleFailure({
    super.message = 'Your role does not have access to this feature',
    super.code = 'insufficient-role',
    this.requiredRole,
  });

  @override
  List<Object?> get props => [...super.props, requiredRole];
}

// ==================== DATA FAILURES ====================

/// Failure when requested data is not found.
class NotFoundFailure extends Failure {
  final String? entityType;
  final String? entityId;

  const NotFoundFailure({
    super.message = 'The requested resource was not found',
    super.code = 'not-found',
    this.entityType,
    this.entityId,
  });

  @override
  List<Object?> get props => [...super.props, entityType, entityId];
}

/// Failure when data validation fails.
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code = 'validation-error',
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// Failure when a duplicate entry is detected.
class DuplicateEntryFailure extends Failure {
  final String? field;
  final String? value;

  const DuplicateEntryFailure({
    super.message = 'A record with this value already exists',
    super.code = 'duplicate-entry',
    this.field,
    this.value,
  });

  @override
  List<Object?> get props => [...super.props, field, value];
}

// ==================== NETWORK FAILURES ====================

/// Failure when a network error occurs.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'A network error occurred. Please check your connection.',
    super.code = 'network-error',
  });
}

/// Failure when a server error occurs.
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    super.message = 'A server error occurred. Please try again later.',
    super.code = 'server-error',
    this.statusCode,
  });

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Failure when request times out.
class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure({
    super.message = 'The request timed out. Please try again.',
    super.code = 'timeout',
  });
}

// ==================== CACHE FAILURES ====================

/// Failure when cache operation fails.
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to access local storage',
    super.code = 'cache-error',
  });
}

// ==================== POS FAILURES ====================

/// Failure when a POS operation fails.
class POSFailure extends Failure {
  const POSFailure({
    required super.message,
    super.code = 'pos-error',
  });
}

/// Failure when cart is empty during checkout.
class EmptyCartFailure extends POSFailure {
  const EmptyCartFailure({
    super.message = 'Cannot checkout with an empty cart',
    super.code = 'empty-cart',
  });
}

/// Failure when insufficient payment is provided.
class InsufficientPaymentFailure extends POSFailure {
  final double amountDue;
  final double amountReceived;

  const InsufficientPaymentFailure({
    super.message = 'Payment amount is less than the total due',
    super.code = 'insufficient-payment',
    required this.amountDue,
    required this.amountReceived,
  });

  @override
  List<Object?> get props => [...super.props, amountDue, amountReceived];
}

/// Failure when product stock is insufficient.
class InsufficientStockFailure extends POSFailure {
  final String productId;
  final String productName;
  final int requestedQty;
  final int availableQty;

  const InsufficientStockFailure({
    super.message = 'Insufficient stock for this product',
    super.code = 'insufficient-stock',
    required this.productId,
    required this.productName,
    required this.requestedQty,
    required this.availableQty,
  });

  @override
  List<Object?> get props => [
        ...super.props,
        productId,
        productName,
        requestedQty,
        availableQty,
      ];
}

/// Failure when void operation fails.
class VoidSaleFailure extends POSFailure {
  const VoidSaleFailure({
    super.message = 'Failed to void the sale',
    super.code = 'void-sale-error',
  });
}

// ==================== INVENTORY FAILURES ====================

/// Failure when SKU already exists.
class DuplicateSkuFailure extends DuplicateEntryFailure {
  const DuplicateSkuFailure({
    required String sku,
    super.message = 'A product with this SKU already exists',
    super.code = 'duplicate-sku',
  }) : super(field: 'sku', value: sku);
}

// ==================== UNKNOWN FAILURE ====================

/// Failure for unexpected/unknown errors.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code = 'unknown-error',
  });
}
