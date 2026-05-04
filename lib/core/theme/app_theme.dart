import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Application theme configuration.
///
/// Provides light and dark themes with consistent styling
/// throughout the application.
abstract class AppTheme {
  // ==================== LIGHT THEME ====================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Roboto is bundled by Material on Android. To get Roboto on iOS/web
      // too, drop Roboto-Regular/Medium/Bold.ttf into assets/fonts/ and
      // declare them under flutter.fonts in pubspec.yaml.
      fontFamily: AppTextStyles.fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightAccent,
        onPrimary: AppColors.lightAccentText,
        secondary: AppColors.primaryAccent,
        onSecondary: AppColors.darkAccentText,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        error: AppColors.error,
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.lightBackground,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.lightText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.lightText,
        ),
      ),

      // Card — flat surface with a hairline border. Cards no longer cast a
      // shadow; the border carries the visual separation.
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.lightHairline),
        ),
      ),

      // Elevated Button — flat fill, 48 px target height, no shadow.
      // Vertical padding 12 + 16 px text leaves room within the 48 px
      // floor enforced by minimumSize; shrinkWrap drops Material's
      // default invisible 48-dp tap padding so the visual matches the
      // tap rect.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightAccent,
          foregroundColor: AppColors.lightAccentText,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Filled Button — same shape and 48 px height as Elevated;
      // Material's default is a full pill which clashes with the rest
      // of the button language.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Outlined Button — light-grey hairline border, accent text,
      // 48 px height to match the rest of the button family.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightAccent,
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Segmented Button — same corner language as the other buttons,
      // a light-grey outline instead of the M3 onSurface default, and
      // a green-tinted selected fill (rather than the brand-yellow
      // M3 default which reads as a warning).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.success.withValues(alpha: 0.18);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.successDark;
            }
            return null;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.lightBorder, width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),

      // Floating Action Button — flat circle, no shadow.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightAccent,
        foregroundColor: AppColors.lightAccentText,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      // Input Decoration — quiet near-white fill with rounded outline.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.lightHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.lightHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.lightAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
        hintStyle: const TextStyle(color: AppColors.lightTextHint),
        errorStyle: AppTextStyles.error,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.lightHairline,
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: Colors.transparent,
        iconColor: AppColors.lightTextSecondary,
      ),

      // Bottom Navigation Bar — flat with a hairline above (drawn by the
      // bar's own border via the surrounding scaffold; elevation removed
      // here to keep the airy feel).
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightBackground,
        selectedItemColor: AppColors.lightAccent,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.lightAccent,
        unselectedLabelColor: AppColors.lightTextSecondary,
        indicatorColor: AppColors.lightAccent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Chip — pill-shaped on the muted surface.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceMuted,
        side: const BorderSide(color: AppColors.lightHairline),
        labelStyle:
            AppTextStyles.labelSmall.copyWith(color: AppColors.lightText),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightBackground,
        elevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle:
            AppTextStyles.headingSmall.copyWith(color: AppColors.lightText),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.lightText),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBackground,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightText,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.lightBackground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lightAccent,
        linearTrackColor: AppColors.lightHairline,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lightAccent;
          }
          return AppColors.lightTextHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lightAccent.withOpacity(0.5);
          }
          return AppColors.lightHairline;
        }),
      ),

      // Checkbox — softer corner to match the rounded language.
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lightAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.lightAccentText),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lightAccent;
          }
          return AppColors.lightTextSecondary;
        }),
      ),

      // Icon — slightly smaller default to support the airy feel; outlined
      // glyphs are applied at call sites in Phase 2.
      iconTheme: const IconThemeData(
        color: AppColors.lightText,
        size: 22,
      ),

      // Cupertino Override
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.lightAccent,
        brightness: Brightness.light,
      ),

      // Text Theme
      textTheme:
          _buildTextTheme(AppColors.lightText, AppColors.lightTextSecondary),
    );
  }

  // ==================== DARK THEME ====================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkAccent,
        onPrimary: AppColors.darkAccentText,
        secondary: AppColors.primaryAccent,
        onSecondary: AppColors.darkAccentText,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        error: AppColors.error,
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.darkBackground,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.darkText,
        ),
      ),

      // Card — flat with hairline border (dark equivalent).
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.darkHairline),
        ),
      ),

      // Elevated Button — 48 px height (see light-theme block for the
      // padding + minimumSize + tapTargetSize rationale).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkAccent,
          foregroundColor: AppColors.darkAccentText,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Filled Button — 48 px height to match Elevated.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Outlined Button — light-grey (dark variant) hairline border,
      // 48 px height.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Segmented Button — green-tinted selected fill (status semantic),
      // light-grey (dark variant) hairline border, shape matches the
      // other buttons.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.success.withValues(alpha: 0.18);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.success;
            }
            return null;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),

      // Floating Action Button — flat in dark mode too.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkAccent,
        foregroundColor: AppColors.darkAccentText,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextHint),
        errorStyle: AppTextStyles.error,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.darkHairline,
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: Colors.transparent,
        iconColor: AppColors.darkTextSecondary,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBackground,
        selectedItemColor: AppColors.darkAccent,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Tab Bar
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.darkAccent,
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicatorColor: AppColors.darkAccent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceMuted,
        side: const BorderSide(color: AppColors.darkHairline),
        labelStyle:
            AppTextStyles.labelSmall.copyWith(color: AppColors.darkText),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 1,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle:
            AppTextStyles.headingSmall.copyWith(color: AppColors.darkText),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.darkText),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkText,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBackground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.darkAccent,
        linearTrackColor: AppColors.darkHairline,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.darkAccent;
          }
          return AppColors.darkTextHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.darkAccent.withOpacity(0.5);
          }
          return AppColors.darkHairline;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.darkAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.darkAccentText),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.darkAccent;
          }
          return AppColors.darkTextSecondary;
        }),
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: AppColors.darkText,
        size: 22,
      ),

      // Cupertino Override
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.darkAccent,
        brightness: Brightness.dark,
      ),

      // Text Theme
      textTheme:
          _buildTextTheme(AppColors.darkText, AppColors.darkTextSecondary),
    );
  }

  // ==================== TEXT THEME BUILDER ====================

  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: AppTextStyles.headingXL.copyWith(color: primaryColor),
      displayMedium: AppTextStyles.headingLarge.copyWith(color: primaryColor),
      displaySmall: AppTextStyles.headingMedium.copyWith(color: primaryColor),
      headlineLarge: AppTextStyles.headingLarge.copyWith(color: primaryColor),
      headlineMedium: AppTextStyles.headingMedium.copyWith(color: primaryColor),
      headlineSmall: AppTextStyles.headingSmall.copyWith(color: primaryColor),
      titleLarge: AppTextStyles.headingSmall.copyWith(color: primaryColor),
      titleMedium: AppTextStyles.labelLarge.copyWith(color: primaryColor),
      titleSmall: AppTextStyles.labelMedium.copyWith(color: primaryColor),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: primaryColor),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: primaryColor),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: secondaryColor),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: primaryColor),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: primaryColor),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: secondaryColor),
    );
  }
}
