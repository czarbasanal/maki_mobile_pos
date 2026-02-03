/// Extension methods for String.
///
/// Provides common string manipulations and validations
/// used throughout the POS application.
extension StringExtensions on String {
  // ==================== CASE CONVERSIONS ====================

  /// Capitalizes the first letter of the string.
  ///
  /// Example:
  /// ```dart
  /// 'hello world'.capitalize() // Returns "Hello world"
  /// ```
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalizes the first letter of each word.
  ///
  /// Example:
  /// ```dart
  /// 'hello world'.toTitleCase() // Returns "Hello World"
  /// ```
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty ? word : word.capitalize())
        .join(' ');
  }

  /// Converts to sentence case (first letter uppercase, rest lowercase).
  ///
  /// Example:
  /// ```dart
  /// 'HELLO WORLD'.toSentenceCase() // Returns "Hello world"
  /// ```
  String toSentenceCase() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  // ==================== VALIDATION ====================

  /// Checks if the string is a valid email address.
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Checks if the string contains only numeric characters.
  bool get isNumeric {
    if (isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(this);
  }

  /// Checks if the string contains only alphabetic characters.
  bool get isAlphabetic {
    if (isEmpty) return false;
    return RegExp(r'^[a-zA-Z]+$').hasMatch(this);
  }

  /// Checks if the string contains only alphanumeric characters.
  bool get isAlphanumeric {
    if (isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(this);
  }

  /// Checks if the string is a valid Philippine mobile number.
  /// Accepts formats: 09XXXXXXXXX, +639XXXXXXXXX, 639XXXXXXXXX
  bool get isValidPhilippineMobile {
    final cleaned = replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^(\+?63|0)9\d{9}$').hasMatch(cleaned);
  }

  /// Checks if the string is a valid SKU format.
  bool get isValidSku {
    if (isEmpty) return false;
    // Allows letters, numbers, and hyphens
    return RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(this);
  }

  // ==================== TRANSFORMATIONS ====================

  /// Removes all whitespace from the string.
  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Normalizes whitespace (replaces multiple spaces with single space).
  String get normalizeWhitespace {
    return replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extracts only digits from the string.
  ///
  /// Example:
  /// ```dart
  /// '+63 917 123 4567'.digitsOnly // Returns "639171234567"
  /// ```
  String get digitsOnly {
    return replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Formats as Philippine mobile number.
  ///
  /// Example:
  /// ```dart
  /// '09171234567'.toPhilippineMobileFormat() // Returns "+63 917 123 4567"
  /// ```
  String toPhilippineMobileFormat() {
    final digits = digitsOnly;
    if (digits.length < 10) return this;

    String normalized;
    if (digits.startsWith('63')) {
      normalized = digits.substring(2);
    } else if (digits.startsWith('0')) {
      normalized = digits.substring(1);
    } else {
      normalized = digits;
    }

    if (normalized.length != 10) return this;

    return '+63 ${normalized.substring(0, 3)} ${normalized.substring(3, 6)} ${normalized.substring(6)}';
  }

  /// Truncates the string to a maximum length with ellipsis.
  ///
  /// Example:
  /// ```dart
  /// 'Hello World'.truncate(8) // Returns "Hello..."
  /// ```
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  /// Masks characters except the last few.
  ///
  /// Example:
  /// ```dart
  /// '1234567890'.mask(4) // Returns "******7890"
  /// ```
  String mask(int visibleCount, {String maskChar = '*'}) {
    if (length <= visibleCount) return this;
    final maskedLength = length - visibleCount;
    return '${maskChar * maskedLength}${substring(maskedLength)}';
  }

  // ==================== SEARCH / MATCHING ====================

  /// Checks if the string contains another string (case-insensitive).
  bool containsIgnoreCase(String other) {
    return toLowerCase().contains(other.toLowerCase());
  }

  /// Checks if the string starts with another string (case-insensitive).
  bool startsWithIgnoreCase(String other) {
    return toLowerCase().startsWith(other.toLowerCase());
  }

  /// Generates search keywords from the string.
  /// Useful for Firestore array-contains queries.
  ///
  /// Example:
  /// ```dart
  /// 'Hello World'.toSearchKeywords()
  /// // Returns ['h', 'he', 'hel', 'hell', 'hello', 'w', 'wo', 'wor', 'worl', 'world']
  /// ```
  List<String> toSearchKeywords({int minLength = 1, int maxLength = 10}) {
    final keywords = <String>{};
    final words = toLowerCase().split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.isEmpty) continue;
      for (var i = minLength; i <= word.length && i <= maxLength; i++) {
        keywords.add(word.substring(0, i));
      }
    }

    return keywords.toList();
  }

  // ==================== PARSING ====================

  /// Tries to parse the string as a double.
  /// Returns null if parsing fails.
  double? tryParseDouble() {
    return double.tryParse(replaceAll(',', ''));
  }

  /// Tries to parse the string as an int.
  /// Returns null if parsing fails.
  int? tryParseInt() {
    return int.tryParse(replaceAll(',', ''));
  }

  /// Parses the string as a double or returns a default value.
  double parseDoubleOrDefault([double defaultValue = 0.0]) {
    return tryParseDouble() ?? defaultValue;
  }

  /// Parses the string as an int or returns a default value.
  int parseIntOrDefault([int defaultValue = 0]) {
    return tryParseInt() ?? defaultValue;
  }
}

/// Extension methods for nullable String.
extension NullableStringExtensions on String? {
  /// Returns true if the string is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns true if the string is null, empty, or contains only whitespace.
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;

  /// Returns the string or a default value if null/empty.
  String orDefault([String defaultValue = '']) {
    return isNullOrEmpty ? defaultValue : this!;
  }

  /// Returns the string or '-' if null/empty (for display purposes).
  String get orDash => orDefault('-');
}
