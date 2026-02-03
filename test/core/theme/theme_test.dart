import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

void main() {
  group('AppColors', () {
    test('light theme accent is primaryDark', () {
      expect(AppColors.lightAccent, AppColors.primaryDark);
    });

    test('dark theme accent is primaryAccent (gold)', () {
      expect(AppColors.darkAccent, AppColors.primaryAccent);
    });

    test('primaryDark has correct value', () {
      expect(AppColors.primaryDark, const Color(0xFF121C1D));
    });

    test('primaryAccent has correct value', () {
      expect(AppColors.primaryAccent, const Color(0xFFFCAC18));
    });
  });

  group('AppTheme', () {
    test('light theme has correct background', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme has correct background', () {
      final theme = AppTheme.darkTheme;
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(theme.brightness, Brightness.dark);
    });

    test('light theme accent color is correct', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, AppColors.lightAccent);
    });

    test('dark theme accent color is correct', () {
      final theme = AppTheme.darkTheme;
      expect(theme.colorScheme.primary, AppColors.darkAccent);
    });
  });
}
