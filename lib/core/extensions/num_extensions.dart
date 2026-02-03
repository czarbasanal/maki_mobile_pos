import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';

/// Extension methods for numeric types.
///
/// Provides currency formatting and common numeric operations
/// used throughout the POS application.
extension NumExtensions on num {
  /// Formats the number as Philippine Peso currency.
  ///
  /// Example:
  /// ```dart
  /// 1234.56.toCurrency() // Returns "₱1,234.56"
  /// 1234.toCurrency()    // Returns "₱1,234.00"
  /// ```
  String toCurrency() {
    final formatter = NumberFormat.currency(
      locale: 'en_PH',
      symbol: AppConstants.currencySymbol,
      decimalDigits: AppConstants.currencyDecimalPlaces,
    );
    return formatter.format(this);
  }

  /// Formats the number as currency without the symbol.
  ///
  /// Example:
  /// ```dart
  /// 1234.56.toCurrencyWithoutSymbol() // Returns "1,234.56"
  /// ```
  String toCurrencyWithoutSymbol() {
    final formatter = NumberFormat.currency(
      locale: 'en_PH',
      symbol: '',
      decimalDigits: AppConstants.currencyDecimalPlaces,
    );
    return formatter.format(this).trim();
  }

  /// Formats the number with thousand separators.
  ///
  /// Example:
  /// ```dart
  /// 1234567.toFormattedNumber() // Returns "1,234,567"
  /// ```
  String toFormattedNumber() {
    final formatter = NumberFormat('#,##0', 'en_PH');
    return formatter.format(this);
  }

  /// Formats the number as a percentage.
  ///
  /// Example:
  /// ```dart
  /// 0.156.toPercentage()  // Returns "15.60%"
  /// 15.6.toPercentage()   // Returns "15.60%" (assumes already in percentage form)
  /// ```
  String toPercentage({int decimalPlaces = 2, bool fromDecimal = true}) {
    final value = fromDecimal ? this * 100 : this;
    return '${value.toStringAsFixed(decimalPlaces)}%';
  }

  /// Rounds the number to specified decimal places.
  ///
  /// Example:
  /// ```dart
  /// 3.14159.roundToPlaces(2) // Returns 3.14
  /// ```
  double roundToPlaces(int places) {
    final mod = _pow10(places);
    return ((this * mod).round() / mod).toDouble();
  }

  /// Helper to calculate 10^n without using dart:math
  static int _pow10(int n) {
    int result = 1;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  /// Checks if the number is within a range (inclusive).
  bool isBetween(num min, num max) {
    return this >= min && this <= max;
  }

  /// Returns the number as a positive value.
  num get absolute => this < 0 ? -this : this;
}

/// Extension methods specifically for double values.
extension DoubleExtensions on double {
  /// Safely divides by another number, returning 0 if divisor is 0.
  ///
  /// Example:
  /// ```dart
  /// 100.0.safeDivide(0)   // Returns 0.0
  /// 100.0.safeDivide(4)   // Returns 25.0
  /// ```
  double safeDivide(num divisor) {
    if (divisor == 0) return 0.0;
    return this / divisor;
  }

  /// Calculates percentage of a total.
  ///
  /// Example:
  /// ```dart
  /// 25.0.percentageOf(100) // Returns 25.0
  /// ```
  double percentageOf(num total) {
    return safeDivide(total) * 100;
  }

  /// Applies a percentage discount.
  ///
  /// Example:
  /// ```dart
  /// 100.0.applyPercentageDiscount(10) // Returns 90.0
  /// ```
  double applyPercentageDiscount(num percentage) {
    return this - (this * percentage / 100);
  }

  /// Applies a fixed amount discount.
  ///
  /// Example:
  /// ```dart
  /// 100.0.applyAmountDiscount(15) // Returns 85.0
  /// ```
  double applyAmountDiscount(num amount) {
    final result = this - amount;
    return result < 0 ? 0 : result;
  }
}

/// Extension methods for nullable num.
extension NullableNumExtensions on num? {
  /// Returns the value or a default if null.
  num orDefault([num defaultValue = 0]) => this ?? defaultValue;

  /// Formats as currency, returning empty string if null.
  String toCurrencyOrEmpty() {
    if (this == null) return '';
    return this!.toCurrency();
  }
}
