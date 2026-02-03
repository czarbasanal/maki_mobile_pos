import 'package:flutter/material.dart';

/// Application color palette.
///
/// Contains all colors used throughout the app, organized by theme
/// and semantic purpose.
abstract class AppColors {
  // ==================== BRAND COLORS ====================

  /// Primary dark color - used as dark theme background and light theme accent
  static const Color primaryDark = Color(0xFF121C1D);

  /// Primary accent color - used as dark theme accent
  static const Color primaryAccent = Color(0xFFFCAC18);

  // ==================== LIGHT THEME COLORS ====================

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightTextHint = Color(0xFF999999);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightBorder = Color(0xFFD0D0D0);
  static const Color lightAccent = primaryDark;
  static const Color lightAccentText = Color(0xFFFFFFFF);

  // ==================== DARK THEME COLORS ====================

  static const Color darkBackground = primaryDark;
  static const Color darkSurface = Color(0xFF1E2A2B);
  static const Color darkCard = Color(0xFF243334);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextHint = Color(0xFF808080);
  static const Color darkDivider = Color(0xFF3A4A4B);
  static const Color darkBorder = Color(0xFF4A5A5B);
  static const Color darkAccent = primaryAccent;
  static const Color darkAccentText = Color(0xFF000000);

  // ==================== SEMANTIC COLORS ====================

  /// Success color (green) - for successful operations
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF2E7D32);

  /// Warning color (amber) - for warnings and cautions
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color warningDark = Color(0xFFF57C00);

  /// Error color (red) - for errors and destructive actions
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorDark = Color(0xFFC62828);

  /// Info color (blue) - for informational messages
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color infoDark = Color(0xFF1565C0);

  // ==================== POS SPECIFIC COLORS ====================

  /// Color for cash payments
  static const Color cashPayment = Color(0xFF4CAF50);

  /// Color for GCash payments
  static const Color gcashPayment = Color(0xFF007DFE);

  /// Color for voided transactions
  static const Color voided = Color(0xFF9E9E9E);

  /// Color for draft sales
  static const Color draft = Color(0xFFFF9800);

  /// Color for low stock warning
  static const Color lowStock = Color(0xFFFF5722);

  /// Color for out of stock
  static const Color outOfStock = Color(0xFFF44336);

  /// Color for in stock
  static const Color inStock = Color(0xFF4CAF50);

  // ==================== ROLE COLORS ====================

  /// Color for admin role badge
  static const Color roleAdmin = Color(0xFF9C27B0);

  /// Color for staff role badge
  static const Color roleStaff = Color(0xFF2196F3);

  /// Color for cashier role badge
  static const Color roleCashier = Color(0xFF4CAF50);

  // ==================== UTILITY METHODS ====================

  /// Returns the appropriate text color for a given background color.
  static Color getTextColorForBackground(Color background) {
    // Calculate luminance to determine if text should be light or dark
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? lightText : darkText;
  }

  /// Returns a color with modified opacity.
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}
