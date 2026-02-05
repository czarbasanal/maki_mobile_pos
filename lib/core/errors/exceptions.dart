/// Base class for all custom exceptions in the application.
///
/// Exceptions are thrown when something unexpected happens
/// that may need to be caught and handled.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

// ==================== AUTH EXCEPTIONS ====================

/// Exception thrown when authentication fails.
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when user is not authenticated.
class UnauthenticatedException extends AuthException {
  const UnauthenticatedException({
    super.message = 'User is not authenticated',
    super.code = 'unauthenticated',
  });
}

/// Exception thrown when credentials are invalid.
class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException({
    super.message = 'Invalid email or password',
    super.code = 'invalid-credentials',
  });
}

/// Exception thrown when user account is disabled.
class AccountDisabledException extends AuthException {
  const AccountDisabledException({
    super.message = 'This account has been disabled',
    super.code = 'account-disabled',
  });
}

/// Exception thrown when password verification fails.
class PasswordVerificationException extends AuthException {
  const PasswordVerificationException({
    super.message = 'Incorrect password',
    super.code = 'password-verification-failed',
  });
}

// ==================== PERMISSION EXCEPTIONS ====================

/// Exception thrown when user lacks required permission.
class PermissionDeniedException extends AppException {
  final String? requiredPermission;

  const PermissionDeniedException({
    super.message = 'You do not have permission to perform this action',
    super.code = 'permission-denied',
    this.requiredPermission,
  });
}

/// Exception thrown when user role is insufficient.
class InsufficientRoleException extends PermissionDeniedException {
  final String? requiredRole;

  const InsufficientRoleException({
    super.message = 'Your role does not have access to this feature',
    super.code = 'insufficient-role',
    this.requiredRole,
  });
}

// ==================== DATA EXCEPTIONS ====================

/// Exception thrown when requested data is not found.
class NotFoundException extends AppException {
  final String? entityType;
  final String? entityId;

  const NotFoundException({
    super.message = 'The requested resource was not found',
    super.code = 'not-found',
    this.entityType,
    this.entityId,
  });
}

/// Exception thrown when data validation fails.
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code = 'validation-error',
    this.fieldErrors,
  });
}

/// Exception thrown when a duplicate entry is detected.
class DuplicateEntryException extends AppException {
  final String? field;
  final String? value;

  const DuplicateEntryException({
    super.message = 'A record with this value already exists',
    super.code = 'duplicate-entry',
    this.field,
    this.value,
  });
}

/// Exception thrown when a database operation fails (e.g. Firestore).
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code = 'database-error',
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when a Firestore-specific operation fails.
class FirestoreException extends DatabaseException {
  const FirestoreException({
    required super.message,
    super.code = 'firestore-error',
    super.originalError,
    super.stackTrace,
  });
}

// ==================== NETWORK EXCEPTIONS ====================

/// Exception thrown when a network error occurs.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'A network error occurred. Please check your connection.',
    super.code = 'network-error',
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when a server error occurs.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    super.message = 'A server error occurred. Please try again later.',
    super.code = 'server-error',
    this.statusCode,
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when request times out.
class TimeoutException extends NetworkException {
  const TimeoutException({
    super.message = 'The request timed out. Please try again.',
    super.code = 'timeout',
  });
}

// ==================== CACHE EXCEPTIONS ====================

/// Exception thrown when cache operation fails.
class CacheException extends AppException {
  const CacheException({
    super.message = 'Failed to access local storage',
    super.code = 'cache-error',
    super.originalError,
    super.stackTrace,
  });
}

// ==================== POS EXCEPTIONS ====================

/// Exception thrown when a POS operation fails.
class POSException extends AppException {
  const POSException({
    required super.message,
    super.code = 'pos-error',
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when cart is empty during checkout.
class EmptyCartException extends POSException {
  const EmptyCartException({
    super.message = 'Cannot checkout with an empty cart',
    super.code = 'empty-cart',
  });
}

/// Exception thrown when insufficient payment is provided.
class InsufficientPaymentException extends POSException {
  final double amountDue;
  final double amountReceived;

  const InsufficientPaymentException({
    super.message = 'Payment amount is less than the total due',
    super.code = 'insufficient-payment',
    required this.amountDue,
    required this.amountReceived,
  });
}

/// Exception thrown when product stock is insufficient.
class InsufficientStockException extends POSException {
  final String productId;
  final String productName;
  final int requestedQty;
  final int availableQty;

  const InsufficientStockException({
    super.message = 'Insufficient stock for this product',
    super.code = 'insufficient-stock',
    required this.productId,
    required this.productName,
    required this.requestedQty,
    required this.availableQty,
  });
}

/// Exception thrown when void operation fails.
class VoidSaleException extends POSException {
  const VoidSaleException({
    super.message = 'Failed to void the sale',
    super.code = 'void-sale-error',
    super.originalError,
  });
}

// ==================== INVENTORY EXCEPTIONS ====================

/// Exception thrown when SKU already exists.
class DuplicateSkuException extends DuplicateEntryException {
  const DuplicateSkuException({
    required String sku,
    super.message = 'A product with this SKU already exists',
    super.code = 'duplicate-sku',
  }) : super(field: 'sku', value: sku);
}

/// Exception thrown when barcode scanning fails.
class BarcodeScanException extends AppException {
  const BarcodeScanException({
    super.message = 'Failed to scan barcode',
    super.code = 'barcode-scan-error',
    super.originalError,
  });
}
