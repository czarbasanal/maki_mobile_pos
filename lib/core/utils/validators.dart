import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/extensions/extensions.dart';

/// Centralized input validation for the POS application.
///
/// Returns null if valid, or an error message string if invalid.
/// Compatible with Flutter's Form validation.
abstract class Validators {
  // ==================== GENERAL ====================

  /// Validates that a field is not empty.
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates minimum length.
  static String? minLength(String? value, int min,
      [String fieldName = 'This field']) {
    if (value == null || value.length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  /// Validates maximum length.
  static String? maxLength(String? value, int max,
      [String fieldName = 'This field']) {
    if (value != null && value.length > max) {
      return '$fieldName must be at most $max characters';
    }
    return null;
  }

  // ==================== AUTH ====================

  /// Validates email format.
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.isValidEmail) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password requirements.
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  /// Validates password confirmation matches.
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ==================== PRODUCT ====================

  /// Validates product name.
  static String? productName(String? value) {
    final requiredError = required(value, 'Product name');
    if (requiredError != null) return requiredError;

    final maxError =
        maxLength(value, AppConstants.maxProductNameLength, 'Product name');
    if (maxError != null) return maxError;

    return null;
  }

  /// Validates SKU format.
  static String? sku(String? value) {
    if (value == null || value.isEmpty) {
      return null; // SKU can be auto-generated
    }
    if (!value.isValidSku) {
      return 'SKU can only contain letters, numbers, and hyphens';
    }
    return null;
  }

  /// Validates price (must be positive).
  static String? price(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }

    final price = value.tryParseDouble();
    if (price == null) {
      return 'Please enter a valid price';
    }
    if (price < 0) {
      return 'Price cannot be negative';
    }
    return null;
  }

  /// Validates cost (must be non-negative).
  static String? cost(String? value) {
    if (value == null || value.isEmpty) {
      return 'Cost is required';
    }

    final cost = value.tryParseDouble();
    if (cost == null) {
      return 'Please enter a valid cost';
    }
    if (cost < 0) {
      return 'Cost cannot be negative';
    }
    return null;
  }

  /// Validates quantity (must be non-negative integer).
  static String? quantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }

    final qty = value.tryParseInt();
    if (qty == null) {
      return 'Please enter a valid whole number';
    }
    if (qty < 0) {
      return 'Quantity cannot be negative';
    }
    return null;
  }

  /// Validates reorder level.
  static String? reorderLevel(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final level = value.tryParseInt();
    if (level == null) {
      return 'Please enter a valid whole number';
    }
    if (level < 0) {
      return 'Reorder level cannot be negative';
    }
    return null;
  }

  // ==================== CONTACT ====================

  /// Validates Philippine mobile number.
  static String? philippineMobile(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (!value.isValidPhilippineMobile) {
      return 'Please enter a valid Philippine mobile number';
    }
    return null;
  }

  /// Validates any phone number (basic check).
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final digits = value.digitsOnly;
    if (digits.length < 7 || digits.length > 15) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // ==================== POS ====================

  /// Validates discount amount.
  static String? discountAmount(String? value, double subtotal) {
    if (value == null || value.isEmpty) {
      return null; // No discount
    }

    final discount = value.tryParseDouble();
    if (discount == null) {
      return 'Please enter a valid amount';
    }
    if (discount < 0) {
      return 'Discount cannot be negative';
    }
    if (discount > subtotal) {
      return 'Discount cannot exceed subtotal';
    }
    return null;
  }

  /// Validates discount percentage.
  static String? discountPercentage(String? value) {
    if (value == null || value.isEmpty) {
      return null; // No discount
    }

    final percentage = value.tryParseDouble();
    if (percentage == null) {
      return 'Please enter a valid percentage';
    }
    if (percentage < 0) {
      return 'Percentage cannot be negative';
    }
    if (percentage > 100) {
      return 'Percentage cannot exceed 100%';
    }
    return null;
  }

  /// Validates payment amount.
  static String? paymentAmount(String? value, double amountDue) {
    if (value == null || value.isEmpty) {
      return 'Payment amount is required';
    }

    final payment = value.tryParseDouble();
    if (payment == null) {
      return 'Please enter a valid amount';
    }
    if (payment < 0) {
      return 'Payment cannot be negative';
    }
    if (payment < amountDue) {
      return 'Payment must be at least ${amountDue.toStringAsFixed(2)}';
    }
    return null;
  }

  // ==================== DRAFT ====================

  /// Validates draft description.
  static String? draftDescription(String? value) {
    final maxError = maxLength(
      value,
      AppConstants.maxDraftDescriptionLength,
      'Description',
    );
    if (maxError != null) return maxError;

    return null;
  }

  // ==================== COMPOSITE VALIDATORS ====================

  /// Combines multiple validators. Returns first error found.
  static String? combine(List<String? Function()> validators) {
    for (final validator in validators) {
      final error = validator();
      if (error != null) return error;
    }
    return null;
  }
}
