import 'package:flutter/material.dart';

/// Application color palette.
///
/// Contains all colors used throughout the app, organized by theme
/// and semantic purpose.
abstract class AppColors {
  // ==================== BRAND COLORS ====================

  /// Primary dark color — dark-theme background. Stays near-black so the
  /// dark surface keeps its identity.
  static const Color primaryDark = Color(0xFF121C1D);

  /// Primary accent — gold used as the dark-theme accent. Softened from the
  /// older fully-saturated 0xFFFCAC18 to read less harsh on screen.
  static const Color primaryAccent = Color(0xFFE8B84C);

  /// Slate used for the light-theme primary (buttons, FAB, focus). Darkened
  /// (was 0xFF334E58) for the refreshed theme so the filled primary reads with
  /// more authority against the warm canvas.
  static const Color brandSlate = Color(0xFF283E46);

  // ==================== LIGHT THEME COLORS ====================

  static const Color lightBackground = Color(0xFFFFFFFF);

  /// Warm off-white canvas the cards sit on (refreshed theme). The scaffold
  /// uses this; cards/app bar stay [lightCard] white so they lift off it.
  static const Color lightCanvas = Color(0xFFF6F5F3);
  static const Color lightSurface = Color(0xFFF5F5F5);

  /// Near-white surface used for inputs and quiet panels — lighter than
  /// [lightSurface] so the airy theme keeps a hint of fill without feeling
  /// boxed in.
  static const Color lightSurfaceMuted = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF16201F);
  static const Color lightTextSecondary = Color(0xFF6A7378);

  /// Quietest text — card labels, captions, the lightest muted copy.
  static const Color lightTextMuted = Color(0xFF8A9296);
  static const Color lightTextHint = Color(0xFF9AA0A3);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightBorder = Color(0xFFD0D0D0);

  /// Resting border for input fields on the white card surface.
  static const Color lightInputBorder = Color(0xFFE2E2E2);

  /// Hairline border used for outlined cards and quiet separators in the
  /// airy/minimal theme. Lighter than [lightBorder] so flat surfaces still
  /// read as discrete panels without any shadow.
  static const Color lightHairline = Color(0xFFECECEC);
  static const Color lightAccent = brandSlate;
  static const Color lightAccentText = Color(0xFFFFFFFF);

  // ==================== DARK THEME COLORS ====================

  static const Color darkBackground = primaryDark;

  /// Deepest dark surface — the scaffold canvas behind cards (refreshed
  /// theme). The app bar / status bar stay [darkBackground] so they read as a
  /// distinct surface above the canvas.
  static const Color darkCanvas = Color(0xFF0C1415);
  static const Color darkSurface = Color(0xFF1E2A2B);

  /// Quiet near-background surface for inputs and muted panels in dark mode.
  /// Slightly lifted from [darkBackground] so input fields read as fields
  /// without leaning on a heavy fill.
  static const Color darkSurfaceMuted = Color(0xFF182425);

  /// Dark-theme card / elevated surface — lifts off [darkCanvas].
  static const Color darkCard = Color(0xFF18262A);
  static const Color darkText = Color(0xFFECEFEF);
  static const Color darkTextSecondary = Color(0xFF93A0A3);
  static const Color darkTextHint = Color(0xFF6C797C);
  static const Color darkDivider = Color(0xFF3A4A4B);
  static const Color darkBorder = Color(0xFF4A5A5B);

  /// Hairline / card border for dark-theme surfaces (refreshed).
  static const Color darkHairline = Color(0xFF243234);

  /// Resting border for input fields in dark mode.
  static const Color darkInputBorder = Color(0xFF2C3C3E);
  static const Color darkAccent = primaryAccent;
  static const Color darkAccentText = Color(0xFF000000);

  // ==================== SEMANTIC COLORS ====================

  /// Success color (green) - for successful operations
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF2E7D32);

  /// Brighter green for success text/values painted on a dark surface — the
  /// `successDark` (#2E7D32) used in light mode reads almost black on the dark
  /// canvas, so dark mode uses this lighter green for parity with the handoff.
  static const Color successOnDark = Color(0xFF8FE39A);

  /// Green text/value color appropriate for the current brightness.
  static Color successText(bool dark) => dark ? successOnDark : successDark;

  /// Filled success-tint surface (e.g. Change box, applied-discount chip)
  /// appropriate for the current brightness.
  static Color successFill(bool dark) =>
      dark ? success.withValues(alpha: 0.18) : successLight;

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

  // ── Status dark-parity variants (Receiving bundle 05) ──
  // The light-mode status hues read poorly on the dark canvas; these lighter
  // variants give icon/badge parity with the handoff prototype.
  static const Color successOnDarkIcon = Color(0xFF5FC86A);
  static Color successIcon(bool dark) => dark ? successOnDarkIcon : success;

  static const Color warningOnDark = Color(0xFFF5B547);
  static const Color warningTextLight = Color(0xFF9A6300);
  static Color warningIcon(bool dark) => dark ? warningOnDark : warningDark;
  static Color warningBadgeText(bool dark) =>
      dark ? warningOnDark : warningTextLight;

  static const Color infoOnDarkIcon = Color(0xFF5AA9F0);
  static const Color infoTextLight = Color(0xFF1976D2);
  static const Color infoOnDarkText = Color(0xFF7FB6FF);
  static Color infoIcon(bool dark) => dark ? infoOnDarkIcon : info;
  static Color infoBadgeText(bool dark) => dark ? infoOnDarkText : infoTextLight;

  static const Color errorOnDark = Color(0xFFFF6B5E);
  static Color costUp(bool dark) => dark ? errorOnDark : errorDark;
  static Color costDown(bool dark) => dark ? successOnDark : successDark;

  /// Error text/value color appropriate for the current brightness — used
  /// for the import skipped-rows box and the Errors chip.
  static Color errorText(bool dark) =>
      dark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F);

  /// Lightly brand-tinted secondary text (e.g. the receiving line pricing
  /// subtitle): brand slate in light, a readable slate-grey on the dark canvas.
  static Color brandMutedText(bool dark) =>
      dark ? const Color(0xFFB8C4C6) : brandSlate;

  /// Hairline border / progress-track color for the current brightness — the
  /// card outline + metric/rank borders used across the reports surfaces.
  static Color hairline(bool dark) => dark ? darkHairline : lightHairline;

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
    return color.withValues(alpha: opacity);
  }
}
