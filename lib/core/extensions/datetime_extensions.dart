import 'package:intl/intl.dart';

/// Extension methods for DateTime.
///
/// Provides formatting and manipulation methods commonly used
/// in reports, logs, and timestamps throughout the POS app.
extension DateTimeExtensions on DateTime {
  // ==================== FORMATTING ====================

  /// Formats as full date and time.
  ///
  /// Example: "January 15, 2025 3:30 PM"
  String toFullDateTime() {
    return DateFormat('MMMM d, y h:mm a').format(this);
  }

  /// Formats as short date and time.
  ///
  /// Example: "Jan 15, 2025 3:30 PM"
  String toShortDateTime() {
    return DateFormat('MMM d, y h:mm a').format(this);
  }

  /// Formats as date only (full month).
  ///
  /// Example: "January 15, 2025"
  String toFullDate() {
    return DateFormat('MMMM d, y').format(this);
  }

  /// Formats as date only (short month).
  ///
  /// Example: "Jan 15, 2025"
  String toShortDate() {
    return DateFormat('MMM d, y').format(this);
  }

  /// Formats as numeric date.
  ///
  /// Example: "01/15/2025"
  String toNumericDate() {
    return DateFormat('MM/dd/yyyy').format(this);
  }

  /// Formats as ISO date (for Firestore queries).
  ///
  /// Example: "2025-01-15"
  String toIsoDate() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  /// Formats as time only.
  ///
  /// Example: "3:30 PM"
  String toTime() {
    return DateFormat('h:mm a').format(this);
  }

  /// Formats as time with seconds.
  ///
  /// Example: "3:30:45 PM"
  String toTimeWithSeconds() {
    return DateFormat('h:mm:ss a').format(this);
  }

  /// Formats as 24-hour time.
  ///
  /// Example: "15:30"
  String toTime24() {
    return DateFormat('HH:mm').format(this);
  }

  /// Formats for display in receipts.
  ///
  /// Example: "01/15/2025 03:30 PM"
  String toReceiptFormat() {
    return DateFormat('MM/dd/yyyy hh:mm a').format(this);
  }

  /// Formats for file names (no special characters).
  ///
  /// Example: "20250115_153045"
  String toFileNameFormat() {
    return DateFormat('yyyyMMdd_HHmmss').format(this);
  }

  // ==================== RELATIVE TIME ====================

  /// Returns a human-readable relative time string.
  ///
  /// Examples:
  /// - "Just now"
  /// - "5 minutes ago"
  /// - "2 hours ago"
  /// - "Yesterday"
  /// - "Jan 15, 2025"
  String toRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return toShortDate();
    }
  }

  // ==================== DATE CALCULATIONS ====================

  /// Returns the start of the day (00:00:00.000).
  DateTime get startOfDay {
    return DateTime(year, month, day);
  }

  /// Returns the end of the day (23:59:59.999).
  DateTime get endOfDay {
    return DateTime(year, month, day, 23, 59, 59, 999);
  }

  /// Returns the start of the week (Monday).
  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1;
    return DateTime(year, month, day - daysFromMonday);
  }

  /// Returns the end of the week (Sunday).
  DateTime get endOfWeek {
    final daysUntilSunday = 7 - weekday;
    return DateTime(year, month, day + daysUntilSunday, 23, 59, 59, 999);
  }

  /// Returns the start of the month.
  DateTime get startOfMonth {
    return DateTime(year, month, 1);
  }

  /// Returns the end of the month.
  DateTime get endOfMonth {
    return DateTime(year, month + 1, 0, 23, 59, 59, 999);
  }

  /// Returns the start of the year.
  DateTime get startOfYear {
    return DateTime(year, 1, 1);
  }

  /// Returns the end of the year.
  DateTime get endOfYear {
    return DateTime(year, 12, 31, 23, 59, 59, 999);
  }

  // ==================== COMPARISONS ====================

  /// Checks if this date is the same day as another date.
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Checks if this date is today.
  bool get isToday {
    return isSameDay(DateTime.now());
  }

  /// Checks if this date is yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(yesterday);
  }

  /// Checks if this date is within the current week.
  bool get isThisWeek {
    final now = DateTime.now();
    return isAfter(now.startOfWeek.subtract(const Duration(seconds: 1))) &&
        isBefore(now.endOfWeek.add(const Duration(seconds: 1)));
  }

  /// Checks if this date is within the current month.
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Checks if this date is within the current year.
  bool get isThisYear {
    return year == DateTime.now().year;
  }

  // ==================== UTILITIES ====================

  /// Returns the name of the month.
  String get monthName {
    return DateFormat('MMMM').format(this);
  }

  /// Returns the short name of the month.
  String get monthNameShort {
    return DateFormat('MMM').format(this);
  }

  /// Returns the name of the day of the week.
  String get dayName {
    return DateFormat('EEEE').format(this);
  }

  /// Returns the short name of the day of the week.
  String get dayNameShort {
    return DateFormat('EEE').format(this);
  }

  /// Returns the number of days in the current month.
  int get daysInMonth {
    return DateTime(year, month + 1, 0).day;
  }

  /// Adds business days (excluding weekends).
  DateTime addBusinessDays(int days) {
    var result = this;
    var remaining = days;

    while (remaining > 0) {
      result = result.add(const Duration(days: 1));
      if (result.weekday != DateTime.saturday &&
          result.weekday != DateTime.sunday) {
        remaining--;
      }
    }

    return result;
  }
}

/// Extension methods for nullable DateTime.
extension NullableDateTimeExtensions on DateTime? {
  /// Returns formatted string or default if null.
  String toShortDateOrDefault([String defaultValue = '-']) {
    return this?.toShortDate() ?? defaultValue;
  }

  /// Returns formatted string or empty if null.
  String toShortDateTimeOrEmpty() {
    return this?.toShortDateTime() ?? '';
  }
}
