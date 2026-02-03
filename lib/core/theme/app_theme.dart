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
          color: AppColors.lightText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.lightText,
        ),
      ),

      // Card
      cardTheme: CardTheme(
        color: AppColors.lightCard,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightAccent,
          foregroundColor: AppColors.lightAccentText,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightAccent,
          side: const BorderSide(color: AppColors.lightAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightAccent,
        foregroundColor: AppColors.lightAccentText,
        elevation: 4,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
        hintStyle: const TextStyle(color: AppColors.lightTextHint),
        errorStyle: AppTextStyles.error,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: Colors.transparent,
        iconColor: AppColors.lightTextSecondary,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightBackground,
        selectedItemColor: AppColors.lightAccent,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Tab Bar
      tabBarTheme: const TabBarTheme(
        labelColor: AppColors.lightAccent,
        unselectedLabelColor: AppColors.lightTextSecondary,
        indicatorColor: AppColors.lightAccent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface,
        labelStyle:
            AppTextStyles.labelSmall.copyWith(color: AppColors.lightText),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle:
            AppTextStyles.headingSmall.copyWith(color: AppColors.lightText),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.lightText),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightText,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.lightBackground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lightAccent,
        linearTrackColor: AppColors.lightDivider,
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
          return AppColors.lightDivider;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lightAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.lightAccentText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
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

      // Icon
      iconTheme: const IconThemeData(
        color: AppColors.lightText,
        size: 24,
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
          color: AppColors.darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: AppColors.darkText,
        ),
      ),

      // Card
      cardTheme: CardTheme(
        color: AppColors.darkCard,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkAccent,
          foregroundColor: AppColors.darkAccentText,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          side: const BorderSide(color: AppColors.darkAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: AppTextStyles.button,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkAccent,
        foregroundColor: AppColors.darkAccentText,
        elevation: 4,
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextHint),
        errorStyle: AppTextStyles.error,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: Colors.transparent,
        iconColor: AppColors.darkTextSecondary,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBackground,
        selectedItemColor: AppColors.darkAccent,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Tab Bar
      tabBarTheme: const TabBarTheme(
        labelColor: AppColors.darkAccent,
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicatorColor: AppColors.darkAccent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        labelStyle:
            AppTextStyles.labelSmall.copyWith(color: AppColors.darkText),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle:
            AppTextStyles.headingSmall.copyWith(color: AppColors.darkText),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.darkText),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkText,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBackground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.darkAccent,
        linearTrackColor: AppColors.darkDivider,
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
          return AppColors.darkDivider;
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
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
        size: 24,
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
